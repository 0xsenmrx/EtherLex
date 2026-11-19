import 'package:etherlex/features/grades/domain/grades.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enrollment grades per course; teachers/other types skipped', () {
    final g = parseEnrollmentGrades([
      {
        'type': 'StudentEnrollment',
        'course_id': 4,
        'grades': {'current_score': 91.5, 'current_grade': 'A-', 'final_score': 70, 'final_grade': null},
      },
      {'type': 'TaEnrollment', 'course_id': 9, 'grades': {'current_score': 1}},
      {'type': 'StudentEnrollment', 'course_id': 5, 'grades': {'current_score': null}},
    ]);
    expect(g.length, 2);
    expect(g.first.courseId, 4);
    expect(g.first.currentScore, 91.5);
    expect(g.first.currentGrade, 'A-');
    expect(g.first.finalGrade, isNull);
    expect(g.last.currentScore, isNull);
  });

  test('grades survive the cache round-trip', () {
    final raw = encodeGrades(const [CourseGrade(courseId: 1, currentScore: 80.5, currentGrade: 'B')]);
    final back = decodeGrades(raw);
    expect(back.single.currentScore, 80.5);
    expect(decodeGrades('not json'), isEmpty);
  });

  test('graded items: states, ordering and open work left out', () {
    final now = DateTime(2026, 11, 18);
    final items = parseGradedItems([
      {
        'id': 1,
        'name': 'HW1',
        'points_possible': 10,
        'due_at': '2026-11-01T10:00:00Z',
        'submission': {'score': 9, 'grade': '9', 'workflow_state': 'graded', 'graded_at': '2026-11-03T10:00:00Z'},
      },
      {
        'id': 2,
        'name': 'HW2',
        'points_possible': 10,
        'due_at': '2026-11-10T10:00:00Z',
        'submission': {'workflow_state': 'unsubmitted', 'missing': true},
      },
      {
        'id': 3,
        'name': 'HW3',
        'points_possible': 10,
        'due_at': '2026-11-12T10:00:00Z',
        'submission': {'workflow_state': 'submitted', 'submitted_at': '2026-11-12T09:00:00Z'},
      },
      {
        'id': 4,
        'name': 'Future',
        'points_possible': 10,
        'due_at': '2026-12-30T10:00:00Z',
        'submission': {'workflow_state': 'unsubmitted'},
      },
      {
        'id': 5,
        'name': 'Excused one',
        'points_possible': 10,
        'submission': {'excused': true},
      },
    ], now: now);
    expect(items.map((i) => i.id).toSet(), {1, 2, 3, 5});
    expect(items.firstWhere((i) => i.id == 1).state, GradeState.graded);
    expect(items.firstWhere((i) => i.id == 2).state, GradeState.missing);
    expect(items.firstWhere((i) => i.id == 3).state, GradeState.submitted);
    expect(items.firstWhere((i) => i.id == 5).state, GradeState.excused);
    final p = progressOf(items);
    expect(p.graded, 1);
    expect(p.counted, 3); // graded + missing + submitted (excused not counted)
    expect(p.earned, 9);
    expect(p.possible, 10);
  });

  test('formatting', () {
    expect(formatPoints(18.5), '18.5');
    expect(formatPoints(20), '20');
    expect(formatPercent(91.46), '91.5%');
    expect(formatPercent(84), '84%');
  });
}
