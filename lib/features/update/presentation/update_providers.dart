import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_info.dart';
import '../data/update_prefs_store.dart';
import '../data/update_service.dart';
import '../domain/update_info.dart';
import '../domain/update_prefs.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
final updatePrefsStoreProvider = Provider<UpdatePrefsStore>((ref) => UpdatePrefsStore());

class UpdatePrefsNotifier extends Notifier<UpdatePrefs> {
  Future<UpdatePrefs>? _loading;

  @override
  UpdatePrefs build() {
    _loading = _load();
    return const UpdatePrefs();
  }

  Future<UpdatePrefs> _load() async {
    try {
      final saved = await ref.read(updatePrefsStoreProvider).read();
      state = saved;
      return saved;
    } catch (_) {
      return state;
    }
  }

  /// The saved settings, once they have been read from disk.
  Future<UpdatePrefs> ensureLoaded() => _loading ?? Future.value(state);

  void _set(UpdatePrefs next) {
    if (next == state) return;
    state = next;
    ref.read(updatePrefsStoreProvider).write(next).catchError((Object _) {});
  }

  void setAutoCheck(bool on) => _set(state.copyWith(autoCheck: on));
  void skip(String version) => _set(state.copyWith(skippedVersion: version));
  void markChecked(DateTime when) => _set(state.copyWith(lastCheck: when));
}

final updatePrefsProvider =
    NotifierProvider<UpdatePrefsNotifier, UpdatePrefs>(UpdatePrefsNotifier.new);

enum UpdateStatus { idle, checking, upToDate, available, downloading, failed }

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.info,
    this.progress = 0,
    this.message,
    this.announce = false,
  });

  final UpdateStatus status;
  final UpdateInfo? info;

  /// 0 to 1 while downloading.
  final double progress;
  final String? message;

  /// A check the app started by itself found this: tell the user once.
  final bool announce;
}

class UpdateNotifier extends Notifier<UpdateState> {
  bool _busy = false;

  @override
  UpdateState build() => const UpdateState();

  /// Looks for a newer release. [manual] checks (the Settings button) show
  /// errors and ignore a skipped version; automatic ones stay quiet.
  Future<void> check({bool manual = false}) async {
    if (!UpdateService.supported || _busy || state.status == UpdateStatus.downloading) return;
    _busy = true;
    state = const UpdateState(status: UpdateStatus.checking);
    final prefs = ref.read(updatePrefsProvider.notifier);
    try {
      final saved = await prefs.ensureLoaded();
      final info = await ref.read(updateServiceProvider).fetchLatest();
      prefs.markChecked(DateTime.now());
      final current = AppVersion.tryParse(kAppVersion);
      if (info != null && current != null && shouldOffer(info, current, saved, ignoreSkip: manual)) {
        state = UpdateState(status: UpdateStatus.available, info: info, announce: !manual);
      } else {
        state = const UpdateState(status: UpdateStatus.upToDate);
      }
    } on UpdateException catch (e) {
      state = manual ? UpdateState(status: UpdateStatus.failed, message: e.message) : const UpdateState();
    } catch (_) {
      state = manual
          ? const UpdateState(status: UpdateStatus.failed, message: 'Could not check for updates.')
          : const UpdateState();
    } finally {
      _busy = false;
    }
  }

  /// Downloads, verifies and starts the installer. The app closes when the
  /// installer starts and comes back as the new version.
  Future<void> install() async {
    final info = state.info;
    if (info == null || state.status == UpdateStatus.downloading) return;
    state = UpdateState(status: UpdateStatus.downloading, info: info);
    var lastPercent = -1;
    try {
      final service = ref.read(updateServiceProvider);
      final file = await service.download(info, onProgress: (p) {
        final percent = (p * 100).floor();
        if (percent == lastPercent) return;
        lastPercent = percent;
        state = UpdateState(status: UpdateStatus.downloading, info: info, progress: p);
      });
      await service.installAndExit(file);
    } on UpdateException catch (e) {
      state = UpdateState(status: UpdateStatus.failed, info: info, message: e.message);
    } catch (_) {
      state = UpdateState(
        status: UpdateStatus.failed,
        info: info,
        message: 'The update could not be installed. Please try again.',
      );
    }
  }

  void skipVersion() {
    final info = state.info;
    if (info == null) return;
    ref.read(updatePrefsProvider.notifier).skip('${info.version}');
    state = const UpdateState();
  }
}

final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);

/// Looks for a release a few seconds after the app starts, at most about
/// twice a day, unless switched off in Settings. Watched by the app shell.
final updateStartupProvider = FutureProvider<void>((ref) async {
  if (!UpdateService.supported) return;
  await Future<void>.delayed(const Duration(seconds: 5));
  final prefs = await ref.read(updatePrefsProvider.notifier).ensureLoaded();
  if (!shouldAutoCheck(prefs, DateTime.now())) return;
  await ref.read(updateProvider.notifier).check();
});
