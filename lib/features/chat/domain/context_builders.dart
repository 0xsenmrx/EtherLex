import '../../activity/domain/activity_item.dart';
import '../../assignments/domain/assignment.dart';
import '../../courses/domain/course.dart';
import '../../grades/domain/grades.dart';
import 'context_item.dart';

String _courseName(Map<int, Course> courses, int? id) => id == null ? 'No course' : (courses[id]?.shortLabel ?? 'Course $id');

/// Everything not done yet, soonest due first (no due date last).
AssignmentsContext openAssignmentsContext(List<Assignment> all, Map<int, Course> courses) {
  final open = [for (final a in all) if (!a.done) a]..sort((a, b) {
      final x = a.dueAt, y = b.dueAt;
      if (x == null && y == null) return a.title.compareTo(b.title);
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
  return AssignmentsContext(
    title: 'Open assignments',
    lines: [
      for (final a in open)
        AssignmentLine(course: _courseName(courses, a.courseId), title: a.title, dueAt: a.dueAt, points: a.points),
    ],
  );
}

/// One line per course that has a grade, as Canvas reports it.
GradesContext gradesOverviewContext(List<Course> courses, Map<int, CourseGrade> grades) {
  final lines = <GradeLine>[];
  for (final c in courses) {
    final g = grades[c.id];
    if (g == null || (g.currentScore == null && g.currentGrade == null)) continue;
    lines.add(GradeLine(course: c.shortLabel, score: g.currentScore, grade: g.currentGrade));
  }
  lines.sort((a, b) => a.course.compareTo(b.course));
  return GradesContext(title: 'Grades overview', lines: lines);
}

String _itemLine(GradedItem i) {
  final points = i.points == null ? '' : '/${formatPoints(i.points!)}';
  return switch (i.state) {
    GradeState.graded => '${i.title}: ${i.score == null ? 'graded' : '${formatPoints(i.score!)}$points'}'
        '${i.grade == null || i.grade!.isEmpty ? '' : ' (${i.grade})'}',
    GradeState.excused => '${i.title}: excused',
    GradeState.missing => '${i.title}: missing',
    GradeState.submitted => '${i.title}: submitted, not graded yet',
    GradeState.open => '${i.title}: not submitted${i.points == null ? '' : ', worth ${formatPoints(i.points!)}'}',
  };
}

/// One course's grade with every graded item.
GradesContext courseGradesContext(Course course, CourseGrade? grade, List<GradedItem> items) => GradesContext(
      title: 'Grades: ${course.shortLabel}',
      lines: [
        GradeLine(
          course: course.shortLabel,
          score: grade?.currentScore,
          grade: grade?.currentGrade,
          items: [for (final i in items) _itemLine(i)],
        ),
      ],
    );

/// The newest announcements, newest first.
AnnouncementsContext recentAnnouncementsContext(List<ActivityItem> all, Map<int, Course> courses, {int limit = 10}) {
  final news = [for (final a in all) if (a.kind == ActivityKind.announcement) a]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return AnnouncementsContext(
    title: 'Recent announcements',
    lines: [
      for (final a in news.take(limit))
        AnnouncementLine(course: _courseName(courses, a.courseId), title: a.title, at: a.createdAt, body: a.plainBody),
    ],
  );
}
