const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Whole calendar days from [now] to [date] (negative = in the past).
int dayDiff(DateTime date, DateTime now) {
  return DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(now.year, now.month, now.day))
      .inDays;
}

String formatDue(DateTime? due, DateTime now) {
  if (due == null) return 'No due date';
  final d = dayDiff(due, now);
  final time = _hm(due);
  if (d == 0) return 'Today $time';
  if (d == 1) return 'Tomorrow $time';
  if (d == -1) return 'Yesterday $time';
  if (d > 1 && d < 7) return '${_weekdays[due.weekday - 1]} $time';
  final base = '${due.day} ${_months[due.month - 1]}';
  return due.year == now.year ? base : '$base ${due.year}';
}

String formatDueFull(DateTime due) =>
    '${_weekdays[due.weekday - 1]}, ${due.day} ${_months[due.month - 1]} ${due.year} at ${_hm(due)}';

/// "5m ago", "3h ago", "Yesterday 17:00", "Tue 09:00", "1 Nov".
String formatAgo(DateTime t, DateTime now) {
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  final d = dayDiff(t, now);
  if (d == 0) return '${diff.inHours}h ago';
  if (d == -1) return 'Yesterday ${_hm(t)}';
  if (d > -7) return '${_weekdays[t.weekday - 1]} ${_hm(t)}';
  final base = '${t.day} ${_months[t.month - 1]}';
  return t.year == now.year ? base : '$base ${t.year}';
}

/// "14 Nov" (adds the year when it is not the current one).
String formatShortDate(DateTime t, DateTime now) {
  final base = '${t.day} ${_months[t.month - 1]}';
  return t.year == now.year ? base : '$base ${t.year}';
}
