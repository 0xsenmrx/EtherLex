import 'dart:convert';

import 'grade_plan.dart';

/// A course's standing as Canvas reports it (null = hidden or not graded yet).
class CourseGrade {
  const CourseGrade({
    required this.courseId,
    this.currentScore,
    this.currentGrade,
    this.finalScore,
    this.finalGrade,
  });

  final int courseId;

  /// Percent over the work graded so far / over everything (ungraded = 0).
  final double? currentScore;
  final String? currentGrade;
  final double? finalScore;
  final String? finalGrade;

  Map<String, dynamic> toJson() => {
        'courseId': courseId,
        'currentScore': currentScore,
        'currentGrade': currentGrade,
        'finalScore': finalScore,
        'finalGrade': finalGrade,
      };

  static CourseGrade? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['courseId'];
    if (id is! num) return null;
    return CourseGrade(
      courseId: id.toInt(),
      currentScore: (j['currentScore'] as num?)?.toDouble(),
      currentGrade: j['currentGrade'] as String?,
      finalScore: (j['finalScore'] as num?)?.toDouble(),
      finalGrade: j['finalGrade'] as String?,
    );
  }
}

String encodeGrades(List<CourseGrade> grades) => jsonEncode([for (final g in grades) g.toJson()]);

List<CourseGrade> decodeGrades(String raw) {
  try {
    final data = jsonDecode(raw);
    if (data is! List) return const [];
    return [for (final j in data) ?CourseGrade.fromJson(j)];
  } catch (_) {
    return const [];
  }
}

/// `/users/self/enrollments` -> one grade per student course.
List<CourseGrade> parseEnrollmentGrades(List<Map<String, dynamic>> enrollments) {
  final byCourse = <int, CourseGrade>{};
  for (final e in enrollments) {
    final type = e['type'];
    if (type is String && !type.contains('Student')) continue;
    final course = e['course_id'];
    final grades = e['grades'];
    if (course is! num || grades is! Map) continue;
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    byCourse[course.toInt()] = CourseGrade(
      courseId: course.toInt(),
      currentScore: (grades['current_score'] as num?)?.toDouble(),
      currentGrade: str(grades['current_grade']),
      finalScore: (grades['final_score'] as num?)?.toDouble(),
      finalGrade: str(grades['final_grade']),
    );
  }
  return byCourse.values.toList();
}

enum GradeState { graded, excused, missing, submitted, open }

class GradedItem {
  const GradedItem({
    required this.id,
    required this.title,
    required this.state,
    this.points,
    this.score,
    this.grade,
    this.dueAt,
    this.when,
    this.groupId,
    this.stats,
  });

  final int id;
  final String title;
  final GradeState state;
  final double? points;
  final double? score;
  final String? grade;
  final DateTime? dueAt;

  /// The Canvas assignment group (category) it belongs to.
  final int? groupId;

  /// How the class did on this assignment, when the teacher shows it.
  final ClassStats? stats;

  /// When it was graded, else submitted.
  final DateTime? when;

  GradedItem withGroup(int? group) => GradedItem(
        id: id,
        title: title,
        state: state,
        points: points,
        score: score,
        grade: grade,
        dueAt: dueAt,
        when: when,
        groupId: group,
        stats: stats,
      );
}

/// What is graded so far; open work that is not yet due is left out.
List<GradedItem> parseGradedItems(List<Map<String, dynamic>> json, {DateTime? now}) =>
    [for (final i in parseWorkItems(json, now: now)) if (i.state != GradeState.open) i];

/// `/courses/:id/assignments?include[]=submission` -> every assignment with its
/// state, including open ones (needed to know what the course could still give).
List<GradedItem> parseWorkItems(List<Map<String, dynamic>> json, {DateTime? now}) {
  final t = now ?? DateTime.now();
  final out = <GradedItem>[];
  for (final j in json) {
    final id = j['id'];
    final name = j['name'];
    if (id is! num || name is! String) continue;
    final sub = j['submission'];
    final s = sub is Map ? sub : const <String, dynamic>{};
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final due = date(j['due_at']);
    final score = (s['score'] as num?)?.toDouble();
    final workflow = s['workflow_state'];
    final GradeState state;
    if (s['excused'] == true) {
      state = GradeState.excused;
    } else if ((score != null && workflow != 'unsubmitted') || workflow == 'graded') {
      state = GradeState.graded;
    } else if (s['missing'] == true || (due != null && due.isBefore(t) && workflow == 'unsubmitted')) {
      state = GradeState.missing;
    } else if (workflow == 'submitted' || workflow == 'pending_review') {
      state = GradeState.submitted;
    } else {
      state = GradeState.open;
    }
    final grade = s['grade'];
    out.add(GradedItem(
      id: id.toInt(),
      title: name,
      state: state,
      points: (j['points_possible'] as num?)?.toDouble(),
      score: score,
      grade: grade is String && grade.isNotEmpty ? grade : null,
      dueAt: due,
      when: date(s['graded_at']) ?? date(s['submitted_at']),
      groupId: (j['assignment_group_id'] as num?)?.toInt(),
      stats: ClassStats.fromCanvas(j['score_statistics']),
    ));
  }
  out.sort((a, b) {
    final x = a.when ?? a.dueAt;
    final y = b.when ?? b.dueAt;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return y.compareTo(x);
  });
  return out;
}

class Progress {
  const Progress({required this.graded, required this.counted, this.earned, this.possible});
  final int graded;

  /// Graded + submitted-waiting + missing: everything that has come due.
  final int counted;
  final double? earned;
  final double? possible;
}

Progress progressOf(List<GradedItem> items) {
  var graded = 0;
  double earned = 0;
  double possible = 0;
  for (final i in items) {
    if (i.state == GradeState.graded) {
      graded++;
      if (i.score != null && i.points != null && i.points! > 0) {
        earned += i.score!;
        possible += i.points!;
      }
    }
  }
  return Progress(
    graded: graded,
    counted: items.where((i) => i.state != GradeState.excused).length,
    earned: possible > 0 ? earned : null,
    possible: possible > 0 ? possible : null,
  );
}

String formatPoints(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

String formatPercent(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';

/// A Canvas assignment group ("Homework", "Quizzes"...), with its own weight if set.
class AssignmentGroup {
  const AssignmentGroup({required this.id, required this.name, this.weight = 0, this.position = 0});
  final int id;
  final String name;

  /// Percent of the course grade, 0 when Canvas does not weight groups.
  final double weight;
  final int position;
}

List<AssignmentGroup> parseGroups(List<Map<String, dynamic>> json) {
  final out = <AssignmentGroup>[];
  for (final j in json) {
    final id = j['id'];
    final name = j['name'];
    if (id is! num || name is! String) continue;
    out.add(AssignmentGroup(
      id: id.toInt(),
      name: name,
      weight: (j['group_weight'] as num?)?.toDouble() ?? 0,
      position: (j['position'] as num?)?.toInt() ?? 0,
    ));
  }
  out.sort((a, b) => a.position.compareTo(b.position));
  return out;
}

/// Everything about one course's work.
class CourseWork {
  const CourseWork({required this.items, required this.groups});
  final List<GradedItem> items;
  final List<AssignmentGroup> groups;
}
