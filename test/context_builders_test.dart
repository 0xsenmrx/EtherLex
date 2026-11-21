import 'package:etherlex/features/activity/domain/activity_item.dart';
import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/chat/domain/context_builders.dart';
import 'package:etherlex/features/courses/domain/course.dart';
import 'package:etherlex/features/grades/domain/grades.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const courses = {
    1: Course(id: 1, name: 'Physics', code: 'PHYS101'),
    2: Course(id: 2, name: 'Mathematics for Engineers', code: 'MATH201 Section 3'),
  };

  test('open assignments: done ones left out, soonest due first, no date last', () {
    final c = openAssignmentsContext([
      Assignment(id: 1, courseId: 1, title: 'Later', dueAt: DateTime(2026, 12, 1), points: 5),
      const Assignment(id: 2, courseId: 2, title: 'No date', dueAt: null, points: null),
      Assignment(id: 3, courseId: 1, title: 'Sooner', dueAt: DateTime(2026, 11, 22), points: 10),
      Assignment(id: 4, courseId: 1, title: 'Finished', dueAt: DateTime(2026, 11, 1), points: 1, done: true),
    ], courses);
    expect([for (final l in c.lines) l.title], ['Sooner', 'Later', 'No date']);
    expect(c.lines.first.course, 'PHYS101');
    expect(c.lines.last.course, 'Mathematics for Engineers');
  });

  test('the grades overview lists every course and says when Canvas gave no grade', () {
    final g = gradesOverviewContext(
      courses.values.toList(),
      const {1: CourseGrade(courseId: 1, currentScore: 91.5, currentGrade: 'A-'), 2: CourseGrade(courseId: 2)},
    );
    expect(g.lines.length, 2);
    expect(g.text, 'Mathematics for Engineers: no grade yet\nPHYS101: 91.5%, A-');
    expect(gradesOverviewContext(courses.values.toList(), const {}).text, contains('PHYS101: no grade yet'));
  });

  test('a course report spells out each graded item', () {
    final g = courseGradesContext(
      courses[1]!,
      const CourseGrade(courseId: 1, currentScore: 88, currentGrade: 'B+'),
      const [
        GradedItem(id: 1, title: 'Midterm', state: GradeState.graded, points: 50, score: 42, grade: '84%'),
        GradedItem(id: 2, title: 'HW1', state: GradeState.missing),
        GradedItem(id: 3, title: 'HW2', state: GradeState.excused),
        GradedItem(id: 4, title: 'Lab', state: GradeState.submitted),
        GradedItem(id: 5, title: 'Final', state: GradeState.open, points: 100),
      ],
    );
    expect(g.label, 'Grades: PHYS101');
    expect(g.text, contains('PHYS101: 88%, B+'));
    expect(g.text, contains('- Midterm: 42/50 (84%)'));
    expect(g.text, contains('- HW1: missing'));
    expect(g.text, contains('- HW2: excused'));
    expect(g.text, contains('- Lab: submitted, not graded yet'));
    expect(g.text, contains('- Final: not submitted, worth 100'));
  });

  test('announcements: only announcements, newest first, limited', () {
    final all = [
      for (var i = 0; i < 12; i++)
        ActivityItem(id: 'a$i', kind: ActivityKind.announcement, title: 'N$i', body: 'b', createdAt: DateTime(2026, 11, 1 + i), courseId: 1),
      ActivityItem(id: 'g', kind: ActivityKind.grade, title: 'Graded', body: '', createdAt: DateTime(2026, 12, 1)),
    ];
    final c = recentAnnouncementsContext(all, courses);
    expect(c.lines.length, 10);
    expect(c.lines.first.title, 'N11');
    expect(c.lines.any((l) => l.title == 'Graded'), isFalse);
  });
}
