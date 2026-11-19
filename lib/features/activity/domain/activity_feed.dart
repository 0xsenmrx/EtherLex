import '../../../core/utils/date_format.dart';
import 'activity_item.dart';

enum ActivityBucket {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This week'),
  earlier('Earlier');

  const ActivityBucket(this.label);
  final String label;
}

sealed class ActivityEntry {
  const ActivityEntry();
}

final class ActivityHeader extends ActivityEntry {
  const ActivityHeader(this.bucket, this.count);
  final ActivityBucket bucket;
  final int count;
}

final class ActivityRowEntry extends ActivityEntry {
  const ActivityRowEntry(this.item);
  final ActivityItem item;
}

ActivityBucket activityBucketFor(DateTime t, DateTime now) {
  final d = dayDiff(t, now);
  if (d >= 0) return ActivityBucket.today;
  if (d == -1) return ActivityBucket.yesterday;
  if (d > -7) return ActivityBucket.thisWeek;
  return ActivityBucket.earlier;
}

/// Newest first, grouped by day buckets.
List<ActivityEntry> buildActivityFeed(List<ActivityItem> items, DateTime now) {
  final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final groups = <ActivityBucket, List<ActivityItem>>{};
  for (final i in sorted) {
    groups.putIfAbsent(activityBucketFor(i.createdAt, now), () => []).add(i);
  }
  final out = <ActivityEntry>[];
  for (final b in ActivityBucket.values) {
    final list = groups[b];
    if (list == null || list.isEmpty) continue;
    out.add(ActivityHeader(b, list.length));
    for (final i in list) {
      out.add(ActivityRowEntry(i));
    }
  }
  return out;
}

final RegExp _greeting = RegExp(
  r'^(dear|hello|hi|hey|good (morning|afternoon|evening))\b',
  caseSensitive: false,
);

/// One-line preview of a post: greetings like "Dear students," are skipped
/// when there is more to show, whitespace collapsed, long text cut.
String activityExcerpt(String body, {int max = 180}) {
  final lines = [
    for (final l in body.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  while (lines.length > 1 && lines.first.length <= 40 && _greeting.hasMatch(lines.first)) {
    lines.removeAt(0);
  }
  final text = lines.join(' ').replaceAll(RegExp(r'\s+'), ' ');
  return text.length <= max ? text : '${text.substring(0, max).trimRight()}…';
}
