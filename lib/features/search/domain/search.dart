import '../../activity/domain/activity_item.dart';
import '../../assignments/domain/assignment.dart';
import '../../courses/domain/course.dart';
import '../../files/domain/files_models.dart';

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
    final s = scoreOf(i.title, c?.label ?? '', i.plainBody);
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

/// A file found by [searchFiles].
class FileHit {
  const FileHit({required this.file, required this.course, required this.score});
  final FileEntry file;
  final Course? course;
  final double score;
}

/// Files whose name (or, for a word, the course) holds every word of
/// [query], best first: words at the start of the name, then inside it, then
/// in the course. Ties go to the newest file.
List<FileHit> searchFiles(String query, List<(FileEntry, Course?)> files, {int limit = 6}) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  // A word that starts a part of the name ("set" in "Problem_Set_3.pdf").
  final starts = [for (final w in words) RegExp('[ _.()-]${RegExp.escape(w)}')];
  final hits = <FileHit>[];
  for (final (file, course) in files) {
    final name = file.name.toLowerCase();
    final where = (course?.label ?? '').toLowerCase();
    var score = 0.0;
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (name.startsWith(w)) {
        score += 4;
      } else if (starts[i].hasMatch(name)) {
        score += 3;
      } else if (name.contains(w)) {
        score += 2;
      } else if (where.contains(w)) {
        score += 1;
      } else {
        score = 0;
        break;
      }
    }
    if (score > 0) hits.add(FileHit(file: file, course: course, score: score));
  }
  hits.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    final old = DateTime.fromMillisecondsSinceEpoch(0);
    return (b.file.updatedAt ?? old).compareTo(a.file.updatedAt ?? old);
  });
  return hits.take(limit).toList();
}

/// A conversation found by [searchConversations].
class ChatHit {
  const ChatHit({
    required this.id,
    required this.title,
    required this.inMessages,
    required this.score,
    this.messageId,
  });
  final String id;
  final String title;

  /// The message to show: the first holding every word, else the first
  /// holding any of them (null when only the title matched).
  final String? messageId;

  /// Found in what was written, not in the title.
  final bool inMessages;
  final double score;
}

/// One conversation to search: its title, and each message's id and text in
/// lower case (made once per palette opening, not per key press).
typedef ChatSearchText = ({String id, String title, List<({String id, String text})> messages});

/// Conversations whose title, or else whose messages, hold every word of
/// [query]. Title hits rank first (start of the title best); among equals
/// the given order (newest first) is kept.
List<ChatHit> searchConversations(String query, List<ChatSearchText> chats, {int limit = 4}) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final hits = <(ChatHit, int)>[];
  for (var i = 0; i < chats.length; i++) {
    final c = chats[i];
    final title = c.title.toLowerCase();
    var score = 0.0;
    var inTitle = true;
    for (final w in words) {
      if (title.startsWith(w)) {
        score += 4;
      } else if (title.contains(' $w')) {
        score += 3;
      } else if (title.contains(w)) {
        score += 2;
      } else {
        inTitle = false;
        break;
      }
    }
    final all = c.messages.where((m) => words.every(m.text.contains)).firstOrNull;
    final any = all ?? c.messages.where((m) => words.any(m.text.contains)).firstOrNull;
    if (!inTitle) {
      if (!words.every((w) => title.contains(w) || c.messages.any((m) => m.text.contains(w)))) continue;
      score = words.length.toDouble();
    }
    hits.add((ChatHit(id: c.id, title: c.title, inMessages: !inTitle, score: score, messageId: any?.id), i));
  }
  hits.sort((a, b) {
    final s = b.$1.score.compareTo(a.$1.score);
    return s != 0 ? s : a.$2.compareTo(b.$2);
  });
  return [for (final h in hits.take(limit)) h.$1];
}
