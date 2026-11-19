import 'package:etherlex/features/activity/domain/activity_feed.dart';
import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/assignments/domain/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 19, 12);

  Assignment a(int id, DateTime? due, {bool done = false}) =>
      Assignment(id: id, courseId: 1, title: 'A$id', dueAt: due, points: 10, done: done);

  group('arrangeTimeline', () {
    final entries = buildTimeline([
      a(1, now.subtract(const Duration(days: 3)), done: true),
      a(2, now.subtract(const Duration(days: 2)), done: true),
      a(3, now.add(const Duration(hours: 2))),
      a(4, null),
    ], now);

    List<Object> shape(List<TimelineEntry> list) => [
          for (final e in list)
            switch (e) {
              HeaderEntry(:final bucket) => bucket,
              ItemEntry(:final assignment) => assignment.id,
            },
        ];

    test('folded: Earlier header goes last, its rows are hidden', () {
      expect(shape(arrangeTimeline(entries, showEarlier: false)), [
        TimelineBucket.today, 3, TimelineBucket.noDate, 4, TimelineBucket.earlier,
      ]);
    });

    test('unfolded: Earlier rows follow their header at the end', () {
      expect(shape(arrangeTimeline(entries, showEarlier: true)), [
        TimelineBucket.today, 3, TimelineBucket.noDate, 4, TimelineBucket.earlier, 1, 2,
      ]);
    });

    test('nothing done earlier: unchanged', () {
      final open = buildTimeline([a(3, now.add(const Duration(hours: 2)))], now);
      expect(identical(arrangeTimeline(open, showEarlier: false), open), isTrue);
    });
  });

  group('activityExcerpt', () {
    test('skips a greeting line when more follows', () {
      expect(activityExcerpt('Dear students,\n\nThe midterm  is on\nMonday.'),
          'The midterm is on Monday.');
    });

    test('keeps a greeting that is the only text', () {
      expect(activityExcerpt('Dear students,'), 'Dear students,');
    });

    test('does not drop long first lines that start like a greeting', () {
      const long = 'Hi everyone, the lab report deadline has moved to next Friday at noon';
      expect(activityExcerpt('$long\nThanks'), '$long Thanks');
    });

    test('cuts long text with an ellipsis', () {
      final text = activityExcerpt('word ' * 100, max: 20);
      expect(text.length, lessThanOrEqualTo(21));
      expect(text.endsWith('…'), isTrue);
    });
  });
}
