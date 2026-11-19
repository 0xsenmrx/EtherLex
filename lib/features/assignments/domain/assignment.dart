class Assignment {
  const Assignment({
    required this.id,
    required this.courseId,
    required this.title,
    required this.dueAt,
    required this.points,
    this.done = false,
    this.starred = false,
  });

  final int id;
  final int courseId;
  final String title;
  final DateTime? dueAt;
  final double? points;
  final bool done;
  final bool starred;

  Assignment copyWith({bool? done, bool? starred}) => Assignment(
        id: id,
        courseId: courseId,
        title: title,
        dueAt: dueAt,
        points: points,
        done: done ?? this.done,
        starred: starred ?? this.starred,
      );

  bool isOverdue(DateTime now) => !done && dueAt != null && dueAt!.isBefore(now);

  // Value equality, so a view of one assignment can skip rebuilding when a
  // sync re-emits the list unchanged.
  @override
  bool operator ==(Object other) =>
      other is Assignment &&
      other.id == id &&
      other.courseId == courseId &&
      other.title == title &&
      other.dueAt == dueAt &&
      other.points == points &&
      other.done == done &&
      other.starred == starred;

  @override
  int get hashCode => Object.hash(id, courseId, title, dueAt, points, done, starred);
}
