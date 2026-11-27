import 'package:etherlex/features/activity/domain/activity_item.dart';
import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/courses/domain/course.dart';
import 'package:etherlex/features/notifications/domain/alerts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 18, 12);
  const courses = {1: Course(id: 1, name: 'Linear Algebra', code: 'MATH2140J')};

  Assignment a(int id, Duration inFuture, {bool done = false, int course = 1}) => Assignment(
        id: id,
        courseId: course,
        title: 'HW $id',
        dueAt: now.add(inFuture),
        points: null,
        done: done,
      );

  AlertBatch run(List<Assignment> list, {Set<String> notified = const {}, Set<int> disabled = const {}}) =>
      deadlineAlerts(assignments: list, courses: courses, disabled: disabled, notified: notified, now: now);

  test('nothing for far, done, overdue or disabled', () {
    expect(run([a(1, const Duration(days: 3))]).alerts, isEmpty);
    expect(run([a(2, const Duration(hours: 5), done: true)]).alerts, isEmpty);
    expect(run([a(3, const Duration(hours: -1))]).alerts, isEmpty);
    expect(run([a(4, const Duration(hours: 5))], disabled: {1}).alerts, isEmpty);
  });

  test('24h tier fires once, then the 2h tier fires', () {
    final first = run([a(1, const Duration(hours: 20))]);
    expect(first.alerts.length, 1);
    expect(run([a(1, const Duration(hours: 20))], notified: first.keys).alerts, isEmpty);
    final later = run([a(1, const Duration(hours: 1, minutes: 30))], notified: first.keys);
    expect(later.alerts.length, 1);
  });

  test('the same assignment listed twice alerts once', () {
    final batch = run([a(1, const Duration(hours: 5)), a(1, const Duration(hours: 5))]);
    expect(batch.alerts.length, 1);
  });

  test('closed app: only the nearest tier fires', () {
    final batch = run([a(1, const Duration(hours: 1))]);
    expect(batch.alerts.length, 1);
    expect(batch.keys.length, 2);
  });

  test('new recent grades alert once; old ones never', () {
    ActivityItem g(String id, Duration age) => ActivityItem(
          id: id,
          kind: ActivityKind.grade,
          title: 'Quiz',
          body: '95 / 100',
          createdAt: now.subtract(age),
          courseId: 1,
        );
    final items = [g('s1', const Duration(hours: 3)), g('s2', const Duration(days: 20))];
    final batch = gradeAlerts(activity: items, courses: courses, disabled: {}, notified: {}, now: now);
    expect(batch.alerts.map((e) => e.key), ['grade:s1']);
    expect(gradeAlerts(activity: items, courses: courses, disabled: {}, notified: batch.keys, now: now).alerts, isEmpty);
    // The same grade twice in one feed is one alert.
    final twice = gradeAlerts(
        activity: [items.first, items.first], courses: courses, disabled: {}, notified: {}, now: now);
    expect(twice.alerts.length, 1);
  });

  test('condense summarises floods', () {
    final many = [for (var i = 0; i < 5; i++) Alert(key: 'k$i', title: 'T$i', body: 'b')];
    expect(condense(many).length, 1);
    expect(condense(many.take(2).toList()).length, 2);
  });

  test('remainingText', () {
    expect(remainingText(const Duration(minutes: 20)), 'in 20 min');
    expect(remainingText(const Duration(hours: 1, minutes: 30)), 'in 1 h 30 min');
    expect(remainingText(const Duration(hours: 20)), 'in 20 h');
  });
}
