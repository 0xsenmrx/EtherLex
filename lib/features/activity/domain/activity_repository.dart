import 'activity_item.dart';

abstract interface class ActivityRepository {
  Stream<List<ActivityItem>> watch();

  /// Throws CanvasException with a user-safe message.
  Future<void> refresh();
  Future<DateTime?> lastSyncedAt();
  void dispose();
}
