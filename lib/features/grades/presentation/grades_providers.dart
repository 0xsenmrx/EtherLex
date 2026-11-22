import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../core/storage/settings_store.dart';
import '../../../core/sync/sync_state.dart';
import '../../settings/presentation/settings_store_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../../auth/domain/session_database.dart';
import '../data/canvas_grades_repository.dart';
import '../data/mock_grades_repository.dart';
import '../domain/grade_plan.dart';
import '../domain/grades.dart';
import '../domain/grades_repository.dart';

final gradesRepositoryProvider = Provider<GradesRepository>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  final db = ref.watch(appDatabaseProvider);
  if (session == null || session.isSample || db == null) return MockGradesRepository();
  return CanvasGradesRepository(ref.read(canvasClientFactoryProvider)(session.baseUrl, session.token), db);
});

/// Standings per course. Starts from the saved copy, then the sync replaces it.
class CourseGradesNotifier extends Notifier<Map<int, CourseGrade>> {
  @override
  Map<int, CourseGrade> build() {
    final repo = ref.watch(gradesRepositoryProvider);
    _loadCached(repo);
    return const {};
  }

  Future<void> _loadCached(GradesRepository repo) async {
    try {
      final cached = await repo.cached();
      if (!ref.mounted || !identical(repo, ref.read(gradesRepositoryProvider))) return;
      if (state.isEmpty && cached.isNotEmpty) set(cached);
    } catch (_) {}
  }

  void set(List<CourseGrade> grades) => state = {for (final g in grades) g.courseId: g};
}

final courseGradesProvider =
    NotifierProvider<CourseGradesNotifier, Map<int, CourseGrade>>(CourseGradesNotifier.new);

class GradesSyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    ref.watch(gradesRepositoryProvider); // reset when the account changes
    return const SyncState();
  }

  Future<void> refresh() async {
    if (state.loading) return;
    final last = state.lastUpdated;
    state = SyncState(loading: true, lastUpdated: last);
    final repo = ref.read(gradesRepositoryProvider);
    // Signed out or switched account while this ran: never show one
    // account's grades under another.
    bool stale() => !ref.mounted || !identical(repo, ref.read(gradesRepositoryProvider));
    try {
      final grades = await repo.refresh();
      if (stale()) return;
      ref.read(courseGradesProvider.notifier).set(grades);
      // Course detail may have changed too.
      ref.invalidate(courseWorkProvider);
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

final gradesSyncProvider = NotifierProvider<GradesSyncNotifier, SyncState>(GradesSyncNotifier.new);

/// Every assignment of one course with its categories; kept for the session.
final courseWorkProvider = FutureProvider.autoDispose.family<CourseWork, int>((ref, courseId) async {
  final link = ref.keepAlive();
  try {
    return await ref.watch(gradesRepositoryProvider).work(courseId);
  } catch (_) {
    link.close();
    rethrow;
  }
});

/// The user's grade planner data per course (weights, class stats, quotas).
class GradePlansNotifier extends Notifier<Map<int, GradePlan>> {
  Future<void> _pending = Future.value();

  @override
  Map<int, GradePlan> build() {
    _load(ref.watch(settingsStoreProvider));
    return const {};
  }

  Future<void> _load(SettingsStore store) async {
    try {
      final raw = await store.readGradePlans();
      if (!identical(store, ref.read(settingsStoreProvider))) return; // account changed
      if (state.isNotEmpty) return; // the user already typed something
      state = {
        for (final e in raw.entries)
          if (int.tryParse(e.key) != null) int.parse(e.key): GradePlan.fromJson(e.value),
      };
    } catch (_) {}
  }

  void update(int courseId, GradePlan plan) {
    state = {...state, courseId: plan};
    final snapshot = {
      for (final e in state.entries)
        if (!e.value.isEmpty) '${e.key}': e.value.toJson(),
    };
    // Writes go one after another so a slow one cannot overwrite a newer one.
    // The store is taken now: this account's plans go to this account's file
    // even if the user switches account before the write runs.
    final store = ref.read(settingsStoreProvider);
    _pending = _pending.then((_) async {
      try {
        await store.writeGradePlans(snapshot);
      } catch (_) {}
    });
  }
}

final gradePlansProvider =
    NotifierProvider<GradePlansNotifier, Map<int, GradePlan>>(GradePlansNotifier.new);
