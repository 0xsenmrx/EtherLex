import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/calendar/domain/week.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Assignment a(int id, DateTime? due) =>
      Assignment(id: id, courseId: 1, title: 'A$id', dueAt: due, points: null);

  test('weekStart is the Monday of the week', () {
    expect(weekStart(DateTime(2026, 11, 18, 15)), DateTime(2026, 11, 16)); // Wed
    expect(weekStart(DateTime(2026, 11, 16)), DateTime(2026, 11, 16)); // Mon
    expect(weekStart(DateTime(2026, 11, 22, 23, 59)), DateTime(2026, 11, 16)); // Sun
    expect(weekStart(DateTime(2026, 11, 1)), DateTime(2026, 10, 26)); // Sun, month edge
  });

  test('addWeeks crosses month and year boundaries', () {
    expect(addWeeks(DateTime(2026, 12, 28), 1), DateTime(2027, 1, 4));
    expect(addWeeks(DateTime(2026, 11, 16), -3), DateTime(2026, 10, 26));
  });

  test('assignments land on their day, sorted, undated ignored', () {
    final start = DateTime(2026, 11, 16);
    final days = assignmentsByDay([
      a(1, DateTime(2026, 11, 18, 23, 59)),
      a(2, DateTime(2026, 11, 18, 9)),
      a(3, DateTime(2026, 11, 22, 20)),
      a(4, DateTime(2026, 11, 23, 0, 1)), // next Monday
      a(5, null),
    ], start);
    expect(days[2].map((e) => e.id), [2, 1]);
    expect(days[6].map((e) => e.id), [3]);
    expect(days.expand((d) => d).length, 3);
  });

  test('weekRangeLabel', () {
    expect(weekRangeLabel(DateTime(2026, 11, 16)), '16 – 22 Nov 2026');
    expect(weekRangeLabel(DateTime(2026, 11, 30)), '30 Nov – 6 Dec 2026');
    expect(weekRangeLabel(DateTime(2026, 12, 28)), '28 Dec 2026 – 3 Jan 2027');
  });
}
