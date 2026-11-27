import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../activity/domain/activity_item.dart';
import '../../activity/presentation/activity_providers.dart';
import '../../grades/presentation/grades_providers.dart';
import '../../settings/presentation/settings_store_provider.dart';
import '../domain/seen_state.dart';

/// What the signed-in account has looked at (see [SeenState]), kept in its
/// settings file. The first activity and the first grades that arrive are the
/// baseline; after that, what is newer than it and not yet opened is "new".
class SeenNotifier extends Notifier<SeenState> {
  bool _loaded = false;

  @override
  SeenState build() {
    _loaded = false;
    final store = ref.watch(settingsStoreProvider);
    ref.listen<AsyncValue<List<ActivityItem>>>(activityProvider, (_, _) => _baselineActivity());
    ref.listen(courseGradesProvider, (_, _) => _baselineGrades());
    _load(store);
    return const SeenState();
  }

  Future<void> _load(SettingsStore store) async {
    var saved = const SeenState();
    try {
      saved = SeenState.fromJson(await store.readSeen());
    } catch (_) {}
    if (!ref.mounted || !identical(store, ref.read(settingsStoreProvider))) return;
    state = saved;
    _loaded = true;
    _baselineActivity();
    _baselineGrades();
  }

  void _set(SeenState next) {
    if (!_loaded || identical(next, state)) return;
    state = next;
    ref.read(settingsStoreProvider).writeSeen(next.toJson()).catchError((Object _) {});
  }

  void _baselineActivity() {
    final async = ref.read(activityProvider);
    // While the list reloads (a new account) it still holds the old one.
    if (!_loaded || async.isLoading || !async.hasValue) return;
    _set(state.baselineActivity(async.value ?? const []));
  }

  void _baselineGrades() {
    if (!_loaded) return;
    _set(state.baselineGrades(ref.read(courseGradesProvider), DateTime.now()));
  }

  void markActivity(String id) => _set(state.markActivity(id));

  void markAllActivity() {
    final items = ref.read(activityProvider).value;
    if (items != null) _set(state.markAllActivity(items));
  }

  void markCourse(int courseId) {
    _set(state.markCourse(courseId, ref.read(courseGradesProvider)[courseId], DateTime.now()));
  }

  void markAllCourses() => _set(state.markAllCourses(ref.read(courseGradesProvider), DateTime.now()));
}

final seenProvider = NotifierProvider<SeenNotifier, SeenState>(SeenNotifier.new);
