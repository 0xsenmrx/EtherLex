import 'dart:convert';

/// The fenced block language the assistant uses to show the course list.
const String kCoursesFence = 'etherlex-courses';

/// Which courses the list card shows.
enum CourseListFilter { all, hidden, shown }

/// Reads the block: `{}`, empty text, or `{"show":"all"|"hidden"|"shown"}`.
/// Anything else is not a course list card (null), and stays a code block.
CourseListFilter? parseCourseList(String code) {
  final text = code.trim();
  if (text.isEmpty) return CourseListFilter.all;
  Object? j;
  try {
    j = jsonDecode(text);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final show = j['show'];
  if (show == null) return CourseListFilter.all;
  return CourseListFilter.values.where((f) => f.name == show).firstOrNull;
}
