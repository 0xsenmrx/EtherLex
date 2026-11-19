import 'grades.dart';

abstract interface class GradesRepository {
  /// Last saved standings (instant, no network).
  Future<List<CourseGrade>> cached();

  /// Fetches and saves the standings. Throws CanvasException.
  Future<List<CourseGrade>> refresh();

  /// Every assignment of one course (graded or not) and its categories.
  Future<CourseWork> work(int courseId);
}
