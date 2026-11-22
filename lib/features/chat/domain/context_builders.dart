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
        AssignmentLine(
          id: a.id,
          course: _courseName(courses, a.courseId),
          title: a.title,
          dueAt: a.dueAt,
          points: a.points,
          starred: a.starred,
        ),
    ],
  );
}

/// Every assignment of one course, open ones first (soonest due first), done
/// ones after, each with its item number so the assistant can name it.
AssignmentsContext courseAssignmentsContext(Course course, List<Assignment> all) {
  final mine = [for (final a in all) if (a.courseId == course.id) a]..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final x = a.dueAt, y = b.dueAt;
      if (x == null && y == null) return a.title.compareTo(b.title);
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
  return AssignmentsContext(
    title: 'Assignments of ${course.name}',
    lines: [
      for (final a in mine)
        AssignmentLine(id: a.id, course: course.shortLabel, title: a.title, dueAt: a.dueAt, points: a.points, done: a.done, starred: a.starred),
    ],
  );
}

/// One line per course, as Canvas reports it. A course Canvas gives no grade
/// for (nothing graded yet, hidden by the teacher, or one the student teaches)
/// is listed as such, so the model never has to guess why it is missing.
GradesContext gradesOverviewContext(List<Course> courses, Map<int, CourseGrade> grades) {
  final lines = <GradeLine>[
    for (final c in courses)
      GradeLine(
        course: c.shortLabel,
        score: grades[c.id]?.currentScore,
        grade: grades[c.id]?.currentGrade,
      ),
  ]..sort((a, b) => a.course.compareTo(b.course));
  return GradesContext(title: 'Grades overview', lines: lines);
}

String _itemLine(GradedItem i, Map<int, String> groupNames) {
  final points = i.points == null ? '' : '/${formatPoints(i.points!)}';
  final group = groupNames[i.groupId];
  // The number lets the assistant name exactly this item when it proposes a change.
  final title = '${i.title} [#${i.id}${group == null ? '' : ', in $group'}]';
  return switch (i.state) {
    GradeState.graded => '$title: ${i.score == null ? 'graded' : '${formatPoints(i.score!)}$points'}'
        '${i.grade == null || i.grade!.isEmpty ? '' : ' (${i.grade})'}',
    GradeState.excused => '$title: excused',
    GradeState.missing => '$title: missing',
    GradeState.submitted => '$title: submitted, not graded yet',
    GradeState.open => '$title: not submitted${i.points == null ? '' : ', worth ${formatPoints(i.points!)}'}',
  };
}

/// One course's grade with every graded item.
GradesContext courseGradesContext(
  Course course,
  CourseGrade? grade,
  List<GradedItem> items, {
  List<AssignmentGroup> groups = const [],
}) {
  final names = {for (final g in groups) g.id: g.name};
  return GradesContext(
      title: 'Grades: ${course.shortLabel}',
      lines: [
        GradeLine(
          course: course.shortLabel,
          score: grade?.currentScore,
          grade: grade?.currentGrade,
          items: [for (final i in items) _itemLine(i, names)],
          categories: [for (final g in groups) '${g.name} (${formatPercent(g.weight)})'].join(', '),
        ),
      ],
    );
}

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
