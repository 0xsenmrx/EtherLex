import 'assignment.dart';

/// Course id of a task that belongs to no course.
const int kPersonalCourseId = 0;

const int kMaxTaskTitle = 200;
const int kMaxTaskNotes = 4000;

/// A task you add yourself, for work that is not an assignment in Canvas.
///
/// It lives only on this computer (in the account's settings file) and shows
/// next to the assignments, in the calendar and in search. Its [id] is always
/// negative, so it can never be mistaken for a Canvas id.
class CustomTask {
  const CustomTask({
    required this.id,
    required this.title,
    this.courseId = kPersonalCourseId,
    this.dueAt,
    this.notes = '',
    this.done = false,
    this.starred = false,
  });

  final int id;
  final String title;

  /// A Canvas course id, or [kPersonalCourseId] for none.
  final int courseId;
  final DateTime? dueAt;
  final String notes;
  final bool done;
  final bool starred;

  CustomTask copyWith({
    String? title,
    int? courseId,
    DateTime? dueAt,
    bool clearDue = false,
    String? notes,
    bool? done,
    bool? starred,
  }) =>
      CustomTask(
        id: id,
        title: title ?? this.title,
        courseId: courseId ?? this.courseId,
        dueAt: clearDue ? null : (dueAt ?? this.dueAt),
        notes: notes ?? this.notes,
        done: done ?? this.done,
        starred: starred ?? this.starred,
      );

  /// How the rest of the app sees it.
  Assignment toAssignment() =>
      Assignment(id: id, courseId: courseId, title: title, dueAt: dueAt, points: null, done: done, starred: starred);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'courseId': courseId,
        'dueAt': dueAt?.millisecondsSinceEpoch,
        'notes': notes,
        'done': done,
        'starred': starred,
      };

  /// Null when [raw] is not a usable task (the file is not trusted: a task
  /// that does not parse is skipped, the others stay).
  static CustomTask? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    if (id is! num || id.toInt() >= 0 || title is! String) return null;
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return null;
    final course = raw['courseId'];
    final due = raw['dueAt'];
    final notes = raw['notes'];
    return CustomTask(
      id: id.toInt(),
      title: cleanTitle.length > kMaxTaskTitle ? cleanTitle.substring(0, kMaxTaskTitle) : cleanTitle,
      courseId: course is num && course.toInt() >= 0 ? course.toInt() : kPersonalCourseId,
      dueAt: due is num ? DateTime.fromMillisecondsSinceEpoch(due.toInt()) : null,
      notes: notes is String ? (notes.length > kMaxTaskNotes ? notes.substring(0, kMaxTaskNotes) : notes) : '',
      done: raw['done'] == true,
      starred: raw['starred'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CustomTask &&
      other.id == id &&
      other.title == title &&
      other.courseId == courseId &&
      other.dueAt == dueAt &&
      other.notes == notes &&
      other.done == done &&
      other.starred == starred;

  @override
  int get hashCode => Object.hash(id, title, courseId, dueAt, notes, done, starred);
}

/// The tasks in a settings file's list; entries that do not parse are skipped
/// and a repeated id keeps its first entry.
List<CustomTask> parseCustomTasks(Object? raw) {
  if (raw is! List) return const [];
  final seen = <int>{};
  return [
    for (final item in raw)
      if (CustomTask.fromJson(item) case final task? when seen.add(task.id)) task,
  ];
}

/// A new id: negative, built from the clock, and not in [existing].
int nextCustomTaskId(Iterable<int> existing, {DateTime? now}) {
  final taken = existing.toSet();
  var id = -(now ?? DateTime.now()).millisecondsSinceEpoch;
  while (taken.contains(id)) {
    id--;
  }
  return id;
}

final RegExp _isoDue = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?$');
final RegExp _dottedDue = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[ T](\d{1,2}):(\d{2}))?$');

/// A due date typed as `2026-12-05`, `2026-12-05 18:30` or `5.12.2026 18:30`.
/// Without a time it is 23:59. Null when it is not a real date and time.
DateTime? parseTaskDue(String text) {
  final s = text.trim();
  int g(Match m, int i) => int.tryParse(m.group(i) ?? '') ?? -1;
  int year, month, day;
  Match? m = _isoDue.firstMatch(s);
  if (m != null) {
    year = g(m, 1);
    month = g(m, 2);
    day = g(m, 3);
  } else {
    m = _dottedDue.firstMatch(s);
    if (m == null) return null;
    day = g(m, 1);
    month = g(m, 2);
    year = g(m, 3);
  }
  final hour = m.group(4) == null ? 23 : g(m, 4);
  final minute = m.group(5) == null ? 59 : g(m, 5);
  if (year < 1970 || year > 2200 || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  final d = DateTime(year, month, day, hour, minute);
  // 31 February rolls over into March: not a real date.
  if (d.year != year || d.month != month || d.day != day) return null;
  return d;
}

/// The form [parseTaskDue] reads back: `2026-12-05 18:30`.
String formatTaskDue(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
