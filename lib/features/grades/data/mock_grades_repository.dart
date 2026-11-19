import '../domain/grade_plan.dart';
import '../domain/grades.dart';
import '../domain/grades_repository.dart';

/// Sample mode: the five sample courses (ids 1..5).
class MockGradesRepository implements GradesRepository {
  static const _grades = [
    CourseGrade(courseId: 1, currentScore: 91.4, currentGrade: 'A-', finalScore: 74.2, finalGrade: 'C'),
    CourseGrade(courseId: 2, currentScore: 84, currentGrade: 'B', finalScore: 80, finalGrade: 'B-'),
    CourseGrade(courseId: 3, currentScore: 67.5, currentGrade: 'D+', finalScore: 60.1, finalGrade: 'D-'),
    CourseGrade(courseId: 4, currentScore: 95, currentGrade: 'A', finalScore: 90, finalGrade: 'A-'),
    CourseGrade(courseId: 5),
  ];

  @override
  Future<List<CourseGrade>> cached() async => const [];

  @override
  Future<List<CourseGrade>> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _grades;
  }

  @override
  Future<CourseWork> work(int courseId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final now = DateTime.now();
    final hw = courseId * 100 + 1, quiz = courseId * 100 + 2, exam = courseId * 100 + 3;
    GradedItem item(int n, String title, int group, double points, {double? score, GradeState? state, int dueDays = -5}) =>
        GradedItem(
          id: courseId * 1000 + n,
          title: title,
          state: state ?? (score != null ? GradeState.graded : GradeState.open),
          points: points,
          score: score,
          dueAt: now.add(Duration(days: dueDays)),
          when: score != null ? now.add(Duration(days: dueDays + 2)) : null,
          groupId: group,
          stats: score == null
              ? null
              : ClassStats(
                  low: points * 0.45,
                  q1: points * 0.65,
                  median: points * 0.78,
                  q3: points * 0.88,
                  high: points,
                  mean: points * 0.76,
                ),
        );
    return CourseWork(
      groups: [
        AssignmentGroup(id: hw, name: 'Homework', position: 1),
        AssignmentGroup(id: quiz, name: 'Quizzes', position: 2),
        AssignmentGroup(id: exam, name: 'Exams', weight: 40, position: 3),
      ],
      items: [
        item(1, 'Problem Set 1', hw, 20, score: 18.5, dueDays: -20),
        item(2, 'Problem Set 2', hw, 20, score: 16, dueDays: -12),
        item(3, 'Problem Set 3', hw, 20, state: GradeState.submitted, dueDays: -1),
        item(4, 'Problem Set 4', hw, 20, dueDays: 6),
        item(5, 'Quiz 1', quiz, 1, score: 1, dueDays: -18),
        item(6, 'Quiz 2', quiz, 1, score: 0.5, dueDays: -10),
        item(7, 'Quiz 3', quiz, 1, dueDays: 3),
        item(8, 'Quiz 4', quiz, 1, dueDays: 12),
        item(9, 'Midterm', exam, 100, score: 78, dueDays: -8),
        item(10, 'Final exam', exam, 100, dueDays: 30),
        if (courseId % 2 == 1)
          item(11, 'Reading response', hw, 5, state: GradeState.missing, dueDays: -20),
      ],
    );
  }
}
