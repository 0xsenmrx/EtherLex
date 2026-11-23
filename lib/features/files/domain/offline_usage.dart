/// The offline copies of one course (or, with no [courseId], of files no
/// saved listing knows any more).
class CourseSpace {
  const CourseSpace({required this.courseId, required this.bytes, required this.fileIds});
  final int? courseId;
  final int bytes;
  final Set<int> fileIds;
}

/// What the offline folder holds: the total, and per course, biggest first,
/// with the unknown files last.
class OfflineUsage {
  const OfflineUsage({required this.total, required this.courses});
  static const empty = OfflineUsage(total: 0, courses: []);

  final int total;
  final List<CourseSpace> courses;
}

/// The limits the student can pick, in GB; 3 is the default.
const List<int> kOfflineLimitsGb = [1, 3, 5, 10];
const int kDefaultOfflineLimitGb = 3;

/// [sizes] (bytes per file id) grouped by the courses whose saved listings
/// name the file ([fileIdsByCourse]).
OfflineUsage summarizeOffline(Map<int, int> sizes, Map<int, Set<int>> fileIdsByCourse) {
  final courseOf = <int, int>{};
  for (final e in fileIdsByCourse.entries) {
    for (final id in e.value) {
      courseOf.putIfAbsent(id, () => e.key);
    }
  }
  final bytes = <int?, int>{};
  final ids = <int?, Set<int>>{};
  var total = 0;
  for (final e in sizes.entries) {
    final course = courseOf[e.key];
    bytes[course] = (bytes[course] ?? 0) + e.value;
    (ids[course] ??= {}).add(e.key);
    total += e.value;
  }
  final known = [
    for (final e in bytes.entries)
      if (e.key != null) CourseSpace(courseId: e.key, bytes: e.value, fileIds: ids[e.key]!),
  ]..sort((a, b) => b.bytes.compareTo(a.bytes));
  return OfflineUsage(total: total, courses: [
    ...known,
    if (bytes[null] case final other?) CourseSpace(courseId: null, bytes: other, fileIds: ids[null]!),
  ]);
}
