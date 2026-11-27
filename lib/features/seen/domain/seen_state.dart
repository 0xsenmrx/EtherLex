import '../../activity/domain/activity_item.dart';
import '../../grades/domain/grades.dart';

/// Most opened activity items remembered; the oldest are forgotten first.
const int kMaxSeenActivity = 500;

/// What the student has already looked at, so what is new can be marked.
/// Kept per account (see `SeenNotifier`). Pure values: every change returns a
/// new state, or this one when nothing changed.
///
/// Nothing is "new" before the first look: the first time activity (or grades)
/// arrives it becomes the baseline, so an update does not light up everything.
class SeenState {
  const SeenState({
    this.activityBaseline,
    this.activityIds = const {},
    this.courseGrades,
    this.gradesBaselineAt,
    this.courseSeenAt = const {},
  });

  /// Activity made at or before this was there from the start.
  final DateTime? activityBaseline;

  /// Activity opened since (insertion order: oldest first).
  final Set<String> activityIds;

  /// The standing of each course as last seen (see [fingerprint]); null until
  /// the grades have been looked at for the first time.
  final Map<int, String>? courseGrades;
  final DateTime? gradesBaselineAt;

  /// When each course's grades were last opened.
  final Map<int, DateTime> courseSeenAt;

  // ---- activity

  bool isActivityNew(ActivityItem item) {
    final base = activityBaseline;
    return base != null && item.createdAt.isAfter(base) && !activityIds.contains(item.id);
  }

  int newActivityCount(Iterable<ActivityItem> items) => items.where(isActivityNew).length;

  /// The first non-empty list of activity is the baseline.
  SeenState baselineActivity(List<ActivityItem> items) {
    if (activityBaseline != null || items.isEmpty) return this;
    final newest = items.map((i) => i.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
    return _copy(activityBaseline: newest);
  }

  SeenState markActivity(String id) {
    if (activityIds.contains(id)) return this;
    return _copy(activityIds: _capped({...activityIds, id}));
  }

  SeenState markAllActivity(Iterable<ActivityItem> items) {
    final fresh = [for (final i in items) if (isActivityNew(i)) i.id];
    if (fresh.isEmpty) return this;
    return _copy(activityIds: _capped({...activityIds, ...fresh}));
  }

  static Set<String> _capped(Set<String> ids) =>
      ids.length <= kMaxSeenActivity ? ids : ids.skip(ids.length - kMaxSeenActivity).toSet();

  // ---- grades

  /// What a course's standing looks like, as text; empty when nothing is graded.
  static String fingerprint(CourseGrade? g) {
    if (g == null || (g.currentScore == null && g.finalScore == null && g.currentGrade == null && g.finalGrade == null)) return '';
    return '${g.currentScore ?? ''}|${g.currentGrade ?? ''}|${g.finalScore ?? ''}|${g.finalGrade ?? ''}';
  }

  /// The course's grade changed since it was last opened.
  bool courseUpdated(CourseGrade? g) {
    final seen = courseGrades;
    if (seen == null || g == null) return false;
    return fingerprint(g) != (seen[g.courseId] ?? '');
  }

  int updatedCourseCount(Iterable<CourseGrade> grades) => grades.where(courseUpdated).length;

  /// The first look at the grades is the baseline.
  SeenState baselineGrades(Map<int, CourseGrade> grades, DateTime now) {
    if (courseGrades != null || grades.isEmpty) return this;
    return _copy(courseGrades: {for (final g in grades.values) g.courseId: fingerprint(g)}, gradesBaselineAt: now);
  }

  /// The course's grades were opened.
  SeenState markCourse(int courseId, CourseGrade? g, DateTime now) {
    final seen = courseGrades;
    if (seen == null) return this;
    return _copy(courseGrades: {...seen, courseId: fingerprint(g)}, courseSeenAt: {...courseSeenAt, courseId: now});
  }

  SeenState markAllCourses(Map<int, CourseGrade> grades, DateTime now) {
    final seen = courseGrades;
    if (seen == null || grades.isEmpty) return this;
    return _copy(
      courseGrades: {...seen, for (final g in grades.values) g.courseId: fingerprint(g)},
      courseSeenAt: {...courseSeenAt, for (final g in grades.values) g.courseId: now},
    );
  }

  /// Items graded after this are new when the course is opened.
  DateTime? sinceFor(int courseId) => courseSeenAt[courseId] ?? gradesBaselineAt;

  /// A graded (or excused) item that came in after [since].
  static bool itemIsNew(GradedItem item, DateTime? since) {
    final when = item.when;
    if (since == null || when == null) return false;
    return (item.state == GradeState.graded || item.state == GradeState.excused) && when.isAfter(since);
  }

  // ---- saving

  SeenState _copy({
    DateTime? activityBaseline,
    Set<String>? activityIds,
    Map<int, String>? courseGrades,
    DateTime? gradesBaselineAt,
    Map<int, DateTime>? courseSeenAt,
  }) =>
      SeenState(
        activityBaseline: activityBaseline ?? this.activityBaseline,
        activityIds: activityIds ?? this.activityIds,
        courseGrades: courseGrades ?? this.courseGrades,
        gradesBaselineAt: gradesBaselineAt ?? this.gradesBaselineAt,
        courseSeenAt: courseSeenAt ?? this.courseSeenAt,
      );

  Map<String, Object?> toJson() => {
        'activityBaseline': activityBaseline?.toUtc().toIso8601String(),
        'activityIds': activityIds.toList(),
        'courseGrades': courseGrades == null ? null : {for (final e in courseGrades!.entries) '${e.key}': e.value},
        'gradesBaselineAt': gradesBaselineAt?.toUtc().toIso8601String(),
        'courseSeenAt': {for (final e in courseSeenAt.entries) '${e.key}': e.value.toUtc().toIso8601String()},
      };

  /// The file is untrusted: anything of the wrong type or size is skipped.
  static SeenState fromJson(Object? json) {
    if (json is! Map) return const SeenState();
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
    final ids = json['activityIds'];
    final grades = json['courseGrades'];
    final seenAt = json['courseSeenAt'];
    return SeenState(
      activityBaseline: date(json['activityBaseline']),
      activityIds: ids is List ? _capped({for (final v in ids) if (v is String && v.isNotEmpty && v.length < 200) v}) : const {},
      courseGrades: grades is Map
          ? {
              for (final e in grades.entries)
                if (int.tryParse('${e.key}') case final id? when e.value is String && (e.value as String).length < 200) id: e.value as String,
            }
          : null,
      gradesBaselineAt: date(json['gradesBaselineAt']),
      courseSeenAt: seenAt is Map
          ? {
              for (final e in seenAt.entries)
                if (int.tryParse('${e.key}') case final id? when date(e.value) != null) id: date(e.value)!,
            }
          : const {},
    );
  }
}
