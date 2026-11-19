import '../../courses/domain/course.dart';
import '../domain/assignment.dart';

Course? parseCourse(Map<String, dynamic> j) {
  final id = j['id'];
  final name = j['name'];
  if (id is! num || name is! String) return null; // access-restricted courses omit name
  return Course(id: id.toInt(), name: name, code: (j['course_code'] as String?) ?? '');
}

Assignment? parseAssignment(Map<String, dynamic> j, {required int courseId}) {
  final id = j['id'];
  final name = j['name'];
  if (id is! num || name is! String) return null;

  final dueRaw = j['due_at'];
  final dueAt = dueRaw is String ? DateTime.tryParse(dueRaw)?.toLocal() : null;

  var done = false;
  final sub = j['submission'];
  if (sub is Map) {
    final ws = sub['workflow_state'];
    done = sub['excused'] == true ||
        sub['submitted_at'] != null ||
        ws == 'submitted' ||
        ws == 'graded' ||
        ws == 'pending_review';
  }

  return Assignment(
    id: id.toInt(),
    courseId: courseId,
    title: name,
    dueAt: dueAt,
    points: (j['points_possible'] as num?)?.toDouble(),
    done: done,
  );
}
