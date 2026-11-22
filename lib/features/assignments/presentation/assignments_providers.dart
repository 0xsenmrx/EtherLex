import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../core/notify/toast.dart';
import '../../../core/storage/settings_store.dart';
import '../../../core/sync/sync_state.dart';
import '../../auth/domain/auth_provider.dart';
import '../../auth/domain/session_database.dart';
import '../../settings/presentation/settings_store_provider.dart';
import '../../courses/domain/course.dart';
import '../data/cached_assignments_repository.dart';
import '../data/mock_assignments_repository.dart';
import '../domain/assignment.dart';
import '../domain/assignments_repository.dart';

export '../../../core/sync/sync_state.dart';

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  final db = ref.watch(appDatabaseProvider);
  final AssignmentsRepository repo = (session == null || session.isSample || db == null)
      ? MockAssignmentsRepository()
      : CachedAssignmentsRepository(
          ref.read(canvasClientFactoryProvider)(session.baseUrl, session.token),
          db,
        );
  ref.onDispose(repo.dispose);
  return repo;
});

final assignmentsProvider = StreamProvider<List<Assignment>>((ref) {
  return ref.watch(assignmentsRepositoryProvider).watch();
});

final coursesProvider = StreamProvider<List<Course>>((ref) {
  return ref.watch(assignmentsRepositoryProvider).watchCourses();
});

final coursesByIdProvider = Provider<Map<int, Course>>((ref) {
  final courses = ref.watch(coursesProvider).value ?? const <Course>[];
  return {for (final c in courses) c.id: c};
});

class CourseEntry {
  const CourseEntry(this.course, this.openCount);
  final Course course;
  final int openCount;
}

/// Courses that have at least one assignment, with their open counts.
final filterableCoursesProvider = Provider<List<CourseEntry>>((ref) {
  final items = ref.watch(assignmentsProvider).value;
  final courses = ref.watch(coursesByIdProvider);
  if (items == null) return const [];
  final open = <int, int>{};
  for (final a in items) {
    open[a.courseId] = (open[a.courseId] ?? 0) + (a.done ? 0 : 1);
  }
  final out = [
    for (final e in open.entries)
      if (courses[e.key] != null) CourseEntry(courses[e.key]!, e.value),
  ];
  out.sort((a, b) => a.course.shortLabel.compareTo(b.course.shortLabel));
  return out;
});

class CourseFilterNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    ref.watch(assignmentsRepositoryProvider); // reset when the account changes
    return <int>{};
  }

  void toggle(int id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  void remove(int id) {
    if (state.contains(id)) state = {...state}..remove(id);
  }

  void clear() {
    if (state.isNotEmpty) state = <int>{};
  }
}

final courseFilterProvider =
    NotifierProvider<CourseFilterNotifier, Set<int>>(CourseFilterNotifier.new);

/// Courses the user has hidden (e.g. ones they TA and never submit to).
/// Hidden courses drop out of the list and counts; they live in the
/// sidebar's "Disabled" folder, and selecting one there still shows it.
class DisabledCoursesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _load(ref.watch(settingsStoreProvider));
    return <int>{};
  }

  Future<void> _load(SettingsStore store) async {
    try {
      final v = await store.readDisabledCourses();
      if (identical(store, ref.read(settingsStoreProvider))) state = v;
    } catch (_) {}
  }

  void _save() {
    ref.read(settingsStoreProvider).writeDisabledCourses(state).catchError((Object _) {});
  }

  void disable(int id) {
    state = {...state, id};
    ref.read(courseFilterProvider.notifier).remove(id);
    _save();
  }

  void enable(int id) {
    state = {...state}..remove(id);
    _save();
  }

  /// Settings > Courses > Reset: every course on again.
  void enableAll() {
    if (state.isEmpty) return;
    state = <int>{};
    _save();
  }
}

final disabledCoursesProvider =
    NotifierProvider<DisabledCoursesNotifier, Set<int>>(DisabledCoursesNotifier.new);

class SyncNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    final repo = ref.watch(assignmentsRepositoryProvider); // reset when the account changes
    _restoreLastSynced(repo);
    return const SyncState();
  }

  /// Show "Updated 14:05" right away from the cache, before the first refresh.
  Future<void> _restoreLastSynced(AssignmentsRepository repo) async {
    try {
      final t = await repo.lastSyncedAt();
      if (!ref.mounted || !identical(repo, ref.read(assignmentsRepositoryProvider))) return;
      if (t != null && state.lastUpdated == null && !state.loading) {
        state = SyncState(lastUpdated: t);
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    if (state.loading) return;
    final last = state.lastUpdated;
    state = SyncState(loading: true, lastUpdated: last);
    final repo = ref.read(assignmentsRepositoryProvider);
    // Signed out or switched account while this ran: the result is not for
    // the state we would write it into.
    bool stale() => !ref.mounted || !identical(repo, ref.read(assignmentsRepositoryProvider));
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

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

class AssignmentActions {
  AssignmentActions(this._ref);
  final Ref _ref;

  AssignmentsRepository get _repo => _ref.read(assignmentsRepositoryProvider);

  void toggleStar(Assignment a) => _repo.setStarred(a.id, !a.starred);

  void toggleDone(Assignment a) {
    final next = !a.done;
    _repo.setDone(a.id, next);
    if (next) {
      _ref.read(toastProvider.notifier).show(
            'Marked as done',
            actionLabel: 'Undo',
            onAction: () => _repo.setDone(a.id, false),
          );
    }
  }
}

final assignmentActionsProvider =
    Provider<AssignmentActions>((ref) => AssignmentActions(ref));
