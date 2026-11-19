import '../../../core/utils/date_format.dart';
import 'assignment.dart';

enum TimelineBucket {
  overdue('Overdue'),
  earlier('Earlier'),
  today('Today'),
  tomorrow('Tomorrow'),
  thisWeek('This week'),
  later('Later'),
  noDate('No due date');

  const TimelineBucket(this.label);
  final String label;
}

sealed class TimelineEntry {
  const TimelineEntry();
}

final class HeaderEntry extends TimelineEntry {
  const HeaderEntry(this.bucket, this.count);
  final TimelineBucket bucket;
  final int count;
}

final class ItemEntry extends TimelineEntry {
  const ItemEntry(this.assignment);
  final Assignment assignment;
}

TimelineBucket bucketFor(Assignment a, DateTime now) {
  final due = a.dueAt;
  if (due == null) return TimelineBucket.noDate;
  final d = dayDiff(due, now);
  if (d < 0) return a.done ? TimelineBucket.earlier : TimelineBucket.overdue;
  if (d == 0) return TimelineBucket.today;
  if (d == 1) return TimelineBucket.tomorrow;
  if (d <= 7) return TimelineBucket.thisWeek;
  return TimelineBucket.later;
}

/// Pure function: assignments -> flat list of headers and rows.
List<TimelineEntry> buildTimeline(List<Assignment> items, DateTime now) {
  final groups = <TimelineBucket, List<Assignment>>{};
  for (final a in items) {
    groups.putIfAbsent(bucketFor(a, now), () => <Assignment>[]).add(a);
  }
  final out = <TimelineEntry>[];
  for (final bucket in TimelineBucket.values) {
    final list = groups[bucket];
    if (list == null || list.isEmpty) continue;
    list.sort((a, b) {
      final ad = a.dueAt;
      final bd = b.dueAt;
      if (ad != null && bd != null) {
        final c = ad.compareTo(bd);
        if (c != 0) return c;
      } else if (ad != null) {
        return -1;
      } else if (bd != null) {
        return 1;
      }
      return a.title.compareTo(b.title);
    });
    out.add(HeaderEntry(bucket, list.length));
    for (final a in list) {
      out.add(ItemEntry(a));
    }
  }
  return out;
}

/// For display: the done-and-past group moves to the end and can be folded
/// (its header stays, with its count), so what is still to do comes first.
List<TimelineEntry> arrangeTimeline(List<TimelineEntry> entries, {required bool showEarlier}) {
  final head = <TimelineEntry>[];
  final earlier = <TimelineEntry>[];
  var inEarlier = false;
  for (final e in entries) {
    if (e is HeaderEntry) inEarlier = e.bucket == TimelineBucket.earlier;
    (inEarlier ? earlier : head).add(e);
  }
  if (earlier.isEmpty) return entries;
  return [...head, earlier.first, if (showEarlier) ...earlier.skip(1)];
}
