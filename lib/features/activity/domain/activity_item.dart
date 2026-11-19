enum ActivityKind { announcement, grade, discussion, message, other }

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.courseId,
    this.url,
    this.images = const [],
  });

  final String id;
  final ActivityKind kind;
  final String title;
  final String body;
  final int? courseId;
  final DateTime createdAt;
  final String? url;

  /// "file:123" (a Canvas file) or "url:https://..." for pictures in the text.
  final List<String> images;
}
