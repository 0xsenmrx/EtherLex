/// How the student left each page, per account: kept in the account's
/// settings file so leaving a page, restarting or updating keeps it.
/// (The calendar always opens on this week on purpose.)
class ViewPrefs {
  const ViewPrefs({
    this.assignmentsStarredOnly = false,
    this.assignmentsShowDone = false,
    this.activityKind,
    this.gradesShowUngraded = false,
    this.filesCourseId,
    this.filesFolderPath = const [],
  });

  /// Assignments: the Starred view instead of All.
  final bool assignmentsStarredOnly;

  /// Assignments: "Done earlier" unfolded.
  final bool assignmentsShowDone;

  /// Activity: the kind filter by name ("announcement"), null for All.
  final String? activityKind;

  /// Grades: "No grades yet" unfolded.
  final bool gradesShowUngraded;

  /// Files: the course and folder path last open (null: the course list).
  final int? filesCourseId;
  final List<int> filesFolderPath;

  ViewPrefs copyWith({
    bool? assignmentsStarredOnly,
    bool? assignmentsShowDone,
    String? Function()? activityKind,
    bool? gradesShowUngraded,
    int? Function()? filesCourseId,
    List<int>? filesFolderPath,
  }) =>
      ViewPrefs(
        assignmentsStarredOnly: assignmentsStarredOnly ?? this.assignmentsStarredOnly,
        assignmentsShowDone: assignmentsShowDone ?? this.assignmentsShowDone,
        activityKind: activityKind == null ? this.activityKind : activityKind(),
        gradesShowUngraded: gradesShowUngraded ?? this.gradesShowUngraded,
        filesCourseId: filesCourseId == null ? this.filesCourseId : filesCourseId(),
        filesFolderPath: filesFolderPath ?? this.filesFolderPath,
      );

  Map<String, Object?> toJson() => {
        'assignmentsStarredOnly': assignmentsStarredOnly,
        'assignmentsShowDone': assignmentsShowDone,
        'activityKind': activityKind,
        'gradesShowUngraded': gradesShowUngraded,
        'filesCourseId': filesCourseId,
        'filesFolderPath': filesFolderPath,
      };

  /// Anything missing or of the wrong type falls back to the default.
  static ViewPrefs fromJson(Object? json) {
    if (json is! Map) return const ViewPrefs();
    bool flag(String k) => json[k] == true;
    final kind = json['activityKind'];
    final course = json['filesCourseId'];
    final path = json['filesFolderPath'];
    return ViewPrefs(
      assignmentsStarredOnly: flag('assignmentsStarredOnly'),
      assignmentsShowDone: flag('assignmentsShowDone'),
      activityKind: kind is String && kind.isNotEmpty ? kind : null,
      gradesShowUngraded: flag('gradesShowUngraded'),
      filesCourseId: course is num ? course.toInt() : null,
      filesFolderPath: path is List ? [for (final v in path) if (v is num) v.toInt()] : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ViewPrefs &&
      other.assignmentsStarredOnly == assignmentsStarredOnly &&
      other.assignmentsShowDone == assignmentsShowDone &&
      other.activityKind == activityKind &&
      other.gradesShowUngraded == gradesShowUngraded &&
      other.filesCourseId == filesCourseId &&
      other.filesFolderPath.length == filesFolderPath.length &&
      Iterable<int>.generate(filesFolderPath.length).every((i) => other.filesFolderPath[i] == filesFolderPath[i]);

  @override
  int get hashCode => Object.hash(assignmentsStarredOnly, assignmentsShowDone, activityKind, gradesShowUngraded,
      filesCourseId, Object.hashAll(filesFolderPath));
}
