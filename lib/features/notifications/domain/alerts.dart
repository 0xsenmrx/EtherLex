import '../../activity/domain/activity_item.dart';
import '../../assignments/domain/assignment.dart';
import '../../courses/domain/course.dart';

class Alert {
  const Alert({required this.key, required this.title, required this.body});
  final String key;
  final String title;
  final String body;
}

/// How long before a deadline we speak up (checked smallest first).
const List<Duration> kLeadTimes = [Duration(hours: 2), Duration(hours: 24)];

/// Grades older than this are never announced (so a first run is quiet).
const Duration kGradeFreshness = Duration(days: 3);

String remainingText(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 1) return 'now';
  if (minutes < 60) return 'in $minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h < 10 && m >= 5) return 'in $h h $m min';
  return 'in ${(minutes / 60).round()} h';
}

class AlertBatch {
  const AlertBatch(this.alerts, this.keys);

  /// Notifications to show now.
  final List<Alert> alerts;

  /// Every key to remember as handled (includes tiers we skipped over).
  final Set<String> keys;
}

/// Deadline alerts: one per assignment per lead time, never repeated. If the
/// app was closed during the 24 h window, only the nearest tier fires.
AlertBatch deadlineAlerts({
  required List<Assignment> assignments,
  required Map<int, Course> courses,
  required Set<int> disabled,
  required Set<String> notified,
  required DateTime now,
}) {
  final alerts = <Alert>[];
  final keys = <String>{};
  // The same assignment twice in the list (or twice in one pass) alerts once.
  final queued = <String>{};
  for (final a in assignments) {
    final due = a.dueAt;
    if (a.done || due == null || disabled.contains(a.courseId)) continue;
    final left = due.difference(now);
    if (left.isNegative) continue;
    String? current;
    for (final lead in kLeadTimes) {
      if (left <= lead) {
        current = 'due:${a.id}:${due.millisecondsSinceEpoch}:${lead.inHours}h';
        break;
      }
    }
    if (current == null) continue;
    // Anything bigger than the current tier is implied.
    for (final lead in kLeadTimes) {
      if (left <= lead) keys.add('due:${a.id}:${due.millisecondsSinceEpoch}:${lead.inHours}h');
    }
    if (notified.contains(current) || !queued.add(current)) continue;
    final course = courses[a.courseId];
    alerts.add(Alert(
      key: current,
      title: a.title,
      body: [if (course != null) course.shortLabel, 'Due ${remainingText(left)}'].join('  ·  '),
    ));
  }
  alerts.sort((x, y) => x.key.compareTo(y.key));
  return AlertBatch(alerts, keys);
}

/// New grades from the activity feed (recent, not seen before).
AlertBatch gradeAlerts({
  required List<ActivityItem> activity,
  required Map<int, Course> courses,
  required Set<int> disabled,
  required Set<String> notified,
  required DateTime now,
}) {
  final alerts = <Alert>[];
  final keys = <String>{};
  final queued = <String>{};
  for (final i in activity) {
    if (i.kind != ActivityKind.grade) continue;
    final cid = i.courseId;
    if (cid != null && disabled.contains(cid)) continue;
    if (now.difference(i.createdAt) > kGradeFreshness) continue;
    final key = 'grade:${i.id}';
    keys.add(key);
    if (notified.contains(key) || !queued.add(key)) continue;
    final course = cid == null ? null : courses[cid];
    alerts.add(Alert(
      key: key,
      title: i.title,
      body: [if (course != null) course.shortLabel, if (i.body.isNotEmpty) i.plainBody.split('\n').first else 'New grade'].join('  ·  '),
    ));
  }
  return AlertBatch(alerts, keys);
}

/// Never flood the desktop: more than [max] alerts become one summary.
List<({String title, String body})> condense(List<Alert> alerts, {int max = 3}) {
  if (alerts.isEmpty) return const [];
  if (alerts.length <= max) {
    return [for (final a in alerts) (title: a.title, body: a.body)];
  }
  final names = alerts.take(3).map((a) => a.title).join(', ');
  return [(title: '${alerts.length} updates', body: '$names and ${alerts.length - 3} more')];
}
