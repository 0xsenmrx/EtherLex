import 'package:etherlex/core/utils/date_format.dart';
import 'package:etherlex/features/assignments/data/mock_assignments_repository.dart';
import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/assignments/domain/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 13, 12);

  Assignment make(int id, DateTime? due, {bool done = false}) => Assignment(
        id: id,
        courseId: 1,
        title: 'A$id',
        dueAt: due,
        points: 10,
        done: done,
      );

  group('bucketFor', () {
    test('classifies by calendar day', () {
      expect(bucketFor(make(1, DateTime(2026, 11, 12, 9)), now), TimelineBucket.overdue);
      expect(bucketFor(make(2, DateTime(2026, 11, 13, 23, 59)), now), TimelineBucket.today);
      expect(bucketFor(make(3, DateTime(2026, 11, 14, 8)), now), TimelineBucket.tomorrow);
      expect(bucketFor(make(4, DateTime(2026, 11, 18, 8)), now), TimelineBucket.thisWeek);
      expect(bucketFor(make(5, DateTime(2026, 12, 20, 8)), now), TimelineBucket.later);
      expect(bucketFor(make(6, null), now), TimelineBucket.noDate);
    });

    test('done items in the past are Earlier, not Overdue', () {
      expect(
        bucketFor(make(1, DateTime(2026, 11, 1), done: true), now),
        TimelineBucket.earlier,
      );
    });
  });

  group('buildTimeline', () {
    test('headers only for non-empty buckets, items sorted by due', () {
      final entries = buildTimeline([
        make(1, DateTime(2026, 11, 14, 18)),
        make(2, DateTime(2026, 11, 14, 8)),
        make(3, null),
      ], now);
      expect(entries.length, 5);
      expect(entries[0], isA<HeaderEntry>());
      expect((entries[1] as ItemEntry).assignment.id, 2);
      expect((entries[2] as ItemEntry).assignment.id, 1);
      expect((entries[3] as HeaderEntry).bucket, TimelineBucket.noDate);
    });
  });

  group('formatDue', () {
    test('relative labels', () {
      expect(formatDue(DateTime(2026, 11, 13, 23, 59), now), 'Today 23:59');
      expect(formatDue(DateTime(2026, 11, 14, 9, 5), now), 'Tomorrow 09:05');
      expect(formatDue(DateTime(2026, 11, 12, 17), now), 'Yesterday 17:00');
      expect(formatDue(DateTime(2026, 12, 3, 17), now), '3 Dec');
      expect(formatDue(null, now), 'No due date');
    });
  });

  group('MockAssignmentsRepository', () {
    test('setStarred is reflected in the stream', () async {
      final repo = MockAssignmentsRepository(now: now);
      final first = await repo.watch().first;
      final target = first.firstWhere((a) => !a.starred);
      await repo.setStarred(target.id, true);
      final next = await repo.watch().first;
      expect(next.firstWhere((a) => a.id == target.id).starred, isTrue);
      repo.dispose();
    });
  });

  test('assignments compare by value, so unchanged re-emits do not rebuild', () {
    final due = DateTime(2026, 12, 1);
    final a = make(1, due);
    expect(make(1, due), a);
    expect(make(1, due).hashCode, a.hashCode);
    expect(a.copyWith(starred: true), isNot(a));
    expect(a.copyWith(done: true), isNot(a));
    expect(make(2, due), isNot(a));
  });
}
