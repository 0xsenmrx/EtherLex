import '../../../core/utils/html_text.dart';
import '../domain/activity_item.dart';

String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Maps one activity_stream entry. Defensive: unknown shapes become
/// "other" items instead of errors; entries without an id or date are skipped.
ActivityItem? parseActivity(Map<String, dynamic> j, {String? host}) {
  final id = j['id'];
  final type = j['type'];
  if (id is! num || type is! String) return null;

  final kind = switch (type) {
    'Announcement' => ActivityKind.announcement,
    'Submission' => ActivityKind.grade,
    'DiscussionTopic' => ActivityKind.discussion,
    'Conversation' => ActivityKind.message,
    _ => ActivityKind.other,
  };

  final assignment = j['assignment'];
  final assignmentName = assignment is Map ? assignment['name'] : null;
  var title = (j['title'] as String?)?.trim() ?? '';
  if (title.isEmpty) title = assignmentName is String ? assignmentName : 'Update';

  final message = j['message'];
  var body = message is String ? htmlToText(message, links: true, origin: host == null ? null : 'https://$host') : '';

  if (kind == ActivityKind.grade) {
    final grade = j['grade'];
    final score = j['score'];
    final points = assignment is Map ? assignment['points_possible'] : null;
    final parts = <String>[];
    if (grade is String && grade.isNotEmpty) parts.add('Grade: $grade');
    if (score is num) {
      parts.add(points is num ? 'Score: ${_n(score)} / ${_n(points)}' : 'Score: ${_n(score)}');
    }
    if (parts.isNotEmpty) {
      body = body.isEmpty ? parts.join(' · ') : '${parts.join(' · ')}\n$body';
    }
  }

  final when = DateTime.tryParse('${j['updated_at'] ?? j['created_at'] ?? ''}')?.toLocal();
  if (when == null) return null;

  final courseId = j['course_id'];
  final url = j['html_url'];
  return ActivityItem(
    id: '$type-${id.toInt()}',
    kind: kind,
    title: title,
    body: body,
    createdAt: when,
    courseId: courseId is num ? courseId.toInt() : null,
    url: url is String && url.isNotEmpty ? url : null,
    images: message is String ? parseImages(message, host: host) : const [],
  );
}

/// Pictures inside message HTML: Canvas files become "file:ID" (resolved
/// later to a download link), other https images "url:LINK".
List<String> parseImages(String html, {String? host}) {
  final out = <String>[];
  for (final m in RegExp(r'<img\b[^>]*>', caseSensitive: false).allMatches(html)) {
    final tag = m.group(0)!;
    String? attr(String name) =>
        RegExp('(?:^|\\s)$name\\s*=\\s*"([^"]*)"', caseSensitive: false).firstMatch(tag)?.group(1);
    final endpoint = attr('data-api-endpoint');
    final src = attr('src')?.replaceAll('&amp;', '&');
    final id = RegExp(r'/files/(\d+)').firstMatch(endpoint ?? src ?? '')?.group(1);
    final srcHost = src == null ? null : Uri.tryParse(src)?.host;
    final sameSite = srcHost == null || srcHost.isEmpty || host == null || srcHost == host;
    String? token;
    if (id != null && sameSite) {
      token = 'file:$id';
    } else if (src != null && src.startsWith('https://')) {
      token = 'url:$src';
    }
    if (token != null && !out.contains(token)) out.add(token);
    if (out.length >= 8) break;
  }
  return out;
}

/// One entry of /announcements.
ActivityItem? parseAnnouncement(Map<String, dynamic> j, {String? host}) {
  final id = j['id'];
  if (id is! num) return null;
  final when = DateTime.tryParse('${j['posted_at'] ?? j['created_at'] ?? ''}')?.toLocal();
  if (when == null) return null;
  final message = j['message'];
  final title = (j['title'] as String?)?.trim() ?? '';
  final code = j['context_code'];
  final course = code is String ? int.tryParse(code.replaceFirst('course_', '')) : null;
  final url = j['html_url'];
  return ActivityItem(
    id: 'Announcement-${id.toInt()}',
    kind: ActivityKind.announcement,
    title: title.isEmpty ? 'Announcement' : title,
    body: message is String ? htmlToText(message, maxLength: 6000, links: true, origin: host == null ? null : 'https://$host') : '',
    createdAt: when,
    courseId: course,
    url: url is String && url.isNotEmpty ? url : null,
    images: message is String ? parseImages(message, host: host) : const [],
  );
}

/// One entry of /users/self/graded_submissions.
ActivityItem? parseGraded(Map<String, dynamic> j, {String? baseUrl}) {
  final id = j['id'];
  if (id is! num) return null;
  final when = DateTime.tryParse('${j['graded_at'] ?? j['submitted_at'] ?? ''}')?.toLocal();
  if (when == null) return null;
  final assignment = j['assignment'];
  final name = assignment is Map ? assignment['name'] : null;
  final points = assignment is Map ? assignment['points_possible'] : null;
  final grade = j['grade'];
  final score = j['score'];
  final parts = <String>[
    if (grade is String && grade.isNotEmpty) 'Grade: $grade',
    if (score is num) points is num ? 'Score: ${_n(score)} / ${_n(points)}' : 'Score: ${_n(score)}',
  ];
  final courseId = (assignment is Map ? assignment['course_id'] : null) ?? j['course_id'];
  final assignmentId = j['assignment_id'];
  final url = baseUrl != null && courseId is num && assignmentId is num
      ? '$baseUrl/courses/${courseId.toInt()}/assignments/${assignmentId.toInt()}'
      : null;
  return ActivityItem(
    id: 'Graded-${id.toInt()}',
    kind: ActivityKind.grade,
    title: name is String && name.isNotEmpty ? name : 'Graded',
    body: parts.join(' · '),
    createdAt: when,
    courseId: courseId is num ? courseId.toInt() : null,
    url: url,
  );
}
