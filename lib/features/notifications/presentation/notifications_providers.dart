import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity/presentation/activity_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/storage/settings_store.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../settings/presentation/settings_store_provider.dart';
import '../data/notification_service.dart';
import '../domain/alerts.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => LocalNotificationService());

/// State = whether notifications are on. While alive (the signed-in shell),
/// it checks deadlines every minute and whenever assignments or activity change.
class NotificationsController extends Notifier<bool> {
  Timer? _timer;
  Set<String> _notified = {};
  bool _loaded = false;
  bool _busy = false;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    final store = ref.watch(settingsStoreProvider);
    _loaded = false;
    _notified = {};
    ref.listen(assignmentsProvider, (_, _) => _check());
    ref.listen(activityProvider, (_, _) => _check());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
    _load(store);
    return true;
  }

  Future<void> _load(SettingsStore store) async {
    try {
      final on = await store.readNotificationsEnabled();
      final seen = await store.readNotified();
      // Signed out or switched account while reading.
      if (!ref.mounted || !identical(store, ref.read(settingsStoreProvider))) return;
      state = on;
      _notified = seen;
    } catch (_) {}
    if (!ref.mounted) return;
    _loaded = true;
    _check();
  }

  void set(bool on) {
    if (on != state) toggle();
  }

  void toggle() {
    state = !state;
    ref.read(settingsStoreProvider).writeNotificationsEnabled(state).catchError((Object _) {});
    if (state) _check();
  }

  /// The list of a provider, but only once it has loaded for the current
  /// account. While it reloads after signing in or switching account, a
  /// StreamProvider still holds the previous account's value (the sample data
  /// when you come from sample mode), and that must never raise alerts.
  List<T> _current<T>(AsyncValue<List<T>> v) => v.isLoading ? const [] : (v.value ?? const []);

  Future<void> _check() async {
    if (!ref.mounted || !state || !_loaded || _busy) return;
    // Not signed in (yet): whatever the providers hold is not this account's.
    if (ref.read(authProvider).value == null) return;
    _busy = true;
    try {
      final now = DateTime.now();
      final courses = ref.read(coursesByIdProvider);
      final disabled = ref.read(disabledCoursesProvider);
      final deadlines = deadlineAlerts(
        assignments: _current(ref.read(assignmentsProvider)),
        courses: courses,
        disabled: disabled,
        notified: _notified,
        now: now,
      );
      final grades = gradeAlerts(
        activity: _current(ref.read(activityProvider)),
        courses: courses,
        disabled: disabled,
        notified: _notified,
        now: now,
      );
      final fresh = [...deadlines.alerts, ...grades.alerts];
      final before = _notified.length;
      _notified = {..._notified, ...deadlines.keys, ...grades.keys};
      if (fresh.isEmpty && _notified.length == before) return;

      // Keep the file small: forget the oldest keys.
      if (_notified.length > 800) {
        _notified = _notified.skip(_notified.length - 600).toSet();
      }
      ref.read(settingsStoreProvider).writeNotified(_notified).catchError((Object _) {});

      final service = ref.read(notificationServiceProvider);
      for (final n in condense(fresh)) {
        await service.show(n.title, n.body);
      }
    } finally {
      _busy = false;
    }
  }
}

final notificationsProvider =
    NotifierProvider.autoDispose<NotificationsController, bool>(NotificationsController.new);
