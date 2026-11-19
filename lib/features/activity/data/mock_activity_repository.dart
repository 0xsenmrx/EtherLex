import 'dart:async';

import '../domain/activity_item.dart';
import '../domain/activity_repository.dart';

class MockActivityRepository implements ActivityRepository {
  MockActivityRepository({DateTime? now}) : _items = _seed(now ?? DateTime.now());

  final List<ActivityItem> _items;

  static List<ActivityItem> _seed(DateTime now) {
    DateTime ago({int minutes = 0, int hours = 0, int days = 0}) =>
        now.subtract(Duration(minutes: minutes, hours: hours, days: days));
    return [
      ActivityItem(
        id: 'a1',
        kind: ActivityKind.announcement,
        title: 'Midterm room change',
        body: 'The midterm will now take place in Hall B instead of Room 204.\nPlease arrive 15 minutes early and bring your ID.',
        courseId: 1,
        createdAt: ago(minutes: 25),
      ),
      ActivityItem(
        id: 'g1',
        kind: ActivityKind.grade,
        title: 'Problem Set 5: Consumer Theory',
        body: 'Grade: 38 · Score: 38 / 40',
        courseId: 4,
        createdAt: ago(hours: 3),
      ),
      ActivityItem(
        id: 'd1',
        kind: ActivityKind.discussion,
        title: 'Week 9 discussion: market failures',
        body: 'Prof. Lee replied to your post: "Good point about externalities, consider also public goods."',
        courseId: 4,
        createdAt: ago(hours: 20),
      ),
      ActivityItem(
        id: 'a2',
        kind: ActivityKind.announcement,
        title: 'Office hours moved to Thursday',
        body: 'This week only, office hours are on Thursday 15:00-17:00.',
        courseId: 2,
        createdAt: ago(days: 2),
      ),
      ActivityItem(
        id: 'g2',
        kind: ActivityKind.grade,
        title: 'Homework 6: Variance and Covariance',
        body: 'Grade: 47 · Score: 47 / 50',
        courseId: 3,
        createdAt: ago(days: 5),
      ),
      ActivityItem(
        id: 'a3',
        kind: ActivityKind.announcement,
        title: 'Lab safety reminder',
        body: 'Closed-toe shoes are required in the lab from next week.',
        courseId: 1,
        createdAt: ago(days: 12),
      ),
    ];
  }

  @override
  Stream<List<ActivityItem>> watch() => Stream.value(List.unmodifiable(_items));

  @override
  Future<void> refresh() => Future<void>.delayed(const Duration(milliseconds: 500));

  @override
  Future<DateTime?> lastSyncedAt() async => null;

  @override
  void dispose() {}
}
