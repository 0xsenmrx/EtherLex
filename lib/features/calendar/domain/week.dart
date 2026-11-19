import '../../assignments/domain/assignment.dart';

/// Monday 00:00 (local) of the week containing [d].
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// [start] moved by whole [weeks] (calendar arithmetic, safe across DST).
DateTime addWeeks(DateTime start, int weeks) => DateTime(start.year, start.month, start.day + 7 * weeks);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Seven lists (Mon..Sun) of the assignments due that week, earliest first.
/// Assignments without a due date never appear.
List<List<Assignment>> assignmentsByDay(List<Assignment> items, DateTime start) {
  final days = List.generate(7, (_) => <Assignment>[]);
  for (final a in items) {
    final due = a.dueAt;
    if (due == null) continue;
    for (var i = 0; i < 7; i++) {
      if (sameDay(due, DateTime(start.year, start.month, start.day + i))) {
        days[i].add(a);
        break;
      }
    }
  }
  for (final d in days) {
    d.sort((x, y) => x.dueAt!.compareTo(y.dueAt!));
  }
  return days;
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "16 – 22 Nov 2026", "30 Nov – 6 Dec 2026", "28 Dec 2026 – 3 Jan 2027".
String weekRangeLabel(DateTime start) {
  final end = DateTime(start.year, start.month, start.day + 6);
  if (start.year != end.year) {
    return '${start.day} ${_months[start.month - 1]} ${start.year} – ${end.day} ${_months[end.month - 1]} ${end.year}';
  }
  if (start.month != end.month) {
    return '${start.day} ${_months[start.month - 1]} – ${end.day} ${_months[end.month - 1]} ${end.year}';
  }
  return '${start.day} – ${end.day} ${_months[end.month - 1]} ${end.year}';
}
