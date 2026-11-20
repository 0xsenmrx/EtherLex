import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../core/sync/sync_state.dart';
import '../../auth/domain/auth_provider.dart';
import '../../auth/domain/session_database.dart';
import '../data/cached_activity_repository.dart';
import '../data/mock_activity_repository.dart';
import '../domain/activity_item.dart';
import '../domain/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  final db = ref.watch(appDatabaseProvider);
  final ActivityRepository repo = (session == null || session.isSample || db == null)
      ? MockActivityRepository()
      : CachedActivityRepository(
          ref.read(canvasClientFactoryProvider)(session.baseUrl, session.token),
          db,
        );
  ref.onDispose(repo.dispose);
  return repo;
});

final activityProvider = StreamProvider<List<ActivityItem>>((ref) {
  return ref.watch(activityRepositoryProvider).watch();
});

class ActivitySyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    final repo = ref.watch(activityRepositoryProvider);
    _restoreLastSynced(repo);
    return const SyncState();
  }

  Future<void> _restoreLastSynced(ActivityRepository repo) async {
    try {
      final t = await repo.lastSyncedAt();
      if (!ref.mounted || !identical(repo, ref.read(activityRepositoryProvider))) return;
      if (t != null && state.lastUpdated == null && !state.loading) {
        state = SyncState(lastUpdated: t);
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (state.loading) return;
    final last = state.lastUpdated;
    state = SyncState(loading: true, lastUpdated: last);
    final repo = ref.read(activityRepositoryProvider);
    // Signed out or switched account while this ran.
    bool stale() => !ref.mounted || !identical(repo, ref.read(activityRepositoryProvider));
    try {
      await repo.refresh();
      if (stale()) return;
      state = SyncState(lastUpdated: DateTime.now());
    } on CanvasException catch (e) {
      if (stale()) return;
      state = SyncState(
        error: e.message,
        authFailed: e.kind == CanvasErrorKind.unauthorized,
        lastUpdated: last,
      );
    } catch (_) {
      if (stale()) return;
      state = SyncState(error: 'Could not refresh. Please try again.', lastUpdated: last);
    }
  }
}

final activitySyncProvider =
    NotifierProvider<ActivitySyncNotifier, SyncState>(ActivitySyncNotifier.new);
