import '../../activity/domain/activity_item.dart';
import '../../assignments/domain/assignment.dart';
import '../../courses/domain/course.dart';

enum HitKind { assignment, activity }

class SearchHit {
  const SearchHit({
    required this.kind,
    required this.title,
    required this.course,
    required this.score,
    this.assignment,
    this.activity,
  });

  final HitKind kind;
  final String title;
  final Course? course;
  final double score;
  final Assignment? assignment;
  final ActivityItem? activity;
}

/// Case-insensitive search over assignments and activity. Every word of the
/// query must appear in the title, the course name or (for activity) the text.
/// Title matches rank first; ties go to what is due soonest / newest.
List<SearchHit> searchAll(
  String query, {
  required List<Assignment> assignments,
  required List<ActivityItem> activity,
  required Map<int, Course> courses,
  Set<int> excludedCourses = const {},
  DateTime? now,
  int limit = 40,
}) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final t = now ?? DateTime.now();

  double scoreOf(String title, String course, String body) {
    final lt = title.toLowerCase();
    final lc = course.toLowerCase();
    final lb = body.toLowerCase();
    var score = 0.0;
    for (final w in words) {
      if (lt.startsWith(w)) {
        score += 4;
      } else if (lt.contains(' $w')) {
        score += 3;
      } else if (lt.contains(w)) {
        score += 2;
      } else if (lc.contains(w)) {
        score += 1;
      } else if (lb.contains(w)) {
        score += 0.5;
      } else {
        return 0; // a word is missing: no match
      }
    }
    return score;
  }

  final hits = <SearchHit>[];
  for (final a in assignments) {
    if (excludedCourses.contains(a.courseId)) continue;
    final c = courses[a.courseId];
    final s = scoreOf(a.title, c?.label ?? '', '');
    if (s > 0) {
      hits.add(SearchHit(kind: HitKind.assignment, title: a.title, course: c, score: s, assignment: a));
    }
  }
  for (final i in activity) {
    final cid = i.courseId;
    if (cid != null && excludedCourses.contains(cid)) continue;
    final c = cid == null ? null : courses[cid];
    final s = scoreOf(i.title, c?.label ?? '', i.body);
    if (s > 0) {
      hits.add(SearchHit(kind: HitKind.activity, title: i.title, course: c, score: s, activity: i));
    }
  }

  // Newer / sooner first among equal scores.
  double recency(SearchHit h) {
    final a = h.assignment;
    if (a != null) {
      final d = a.dueAt;
      return d == null ? -1e9 : -d.difference(t).inHours.abs().toDouble();
    }
    return -t.difference(h.activity!.createdAt).inHours.abs().toDouble();
  }

  hits.sort((x, y) {
    final c = y.score.compareTo(x.score);
    return c != 0 ? c : recency(y).compareTo(recency(x));
  });
  return hits.take(limit).toList();
}
