import '../../courses/domain/course.dart';
import 'assignment.dart';

/// The UI talks only to this. Implementations: in-memory mock (sample data),
/// a Drift-backed cache fed by Canvas.
abstract interface class AssignmentsRepository {
  Stream<List<Course>> watchCourses();
  Stream<List<Assignment>> watch();

  /// Pulls fresh data. Throws CanvasException with a user-safe message.
  Future<void> refresh();

  /// When the cache was last filled from Canvas (null = never).
  Future<DateTime?> lastSyncedAt();
  Future<void> setStarred(int id, bool value);
  Future<void> setDone(int id, bool value);
  void dispose();
}
