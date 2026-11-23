import '../../../core/utils/html_text.dart';
import '../../files/domain/files_models.dart';

/// A file linked from an assignment's description.
class AttachmentRef {
  const AttachmentRef(this.fileId, this.name);
  final int fileId;
  final String name;
}

class SubmissionInfo {
  const SubmissionInfo({
    required this.acceptsUpload,
    this.allowedExtensions = const [],
    this.locked = false,
    this.lockReason,
    this.description = '',
    this.attachments = const [],
  });

  /// The assignment text as plain text.
  final String description;

  /// Files linked from the description.
  final List<AttachmentRef> attachments;

  /// The assignment takes file uploads.
  final bool acceptsUpload;

  /// Lower-case, no dot. Empty = any type.
  final List<String> allowedExtensions;
  final bool locked;
  final String? lockReason;
}

abstract interface class SubmissionRepository {
  Future<SubmissionInfo> info(int courseId, int assignmentId);

  /// What the student turned in and what the teacher sent back.
  Future<MySubmission> mine(int courseId, int assignmentId);

  /// Uploads [paths] and turns them in. [onProgress] goes 0..1.
  /// Throws CanvasException with a user-safe message.
  Future<void> submit(
    int courseId,
    int assignmentId,
    List<String> paths,
    void Function(double progress) onProgress,
  );
}

/// Pulls linked Canvas files out of description HTML.
List<AttachmentRef> parseAttachments(String html, {String? host}) {
  final found = <int, AttachmentRef>{};
  for (final m in RegExp(r'<a\b([^>]*)>([\s\S]*?)</a>', caseSensitive: false).allMatches(html)) {
    final attrs = m.group(1)!;
    String? attr(String name) =>
        RegExp('$name\\s*=\\s*"([^"]*)"', caseSensitive: false).firstMatch(attrs)?.group(1);
    final endpoint = attr('data-api-endpoint');
    final href = attr('href');
    final fromEndpoint = endpoint == null ? null : RegExp(r'/files/(\d+)').firstMatch(endpoint);
    final fromHref = href == null ? null : RegExp(r'/files/(\d+)').firstMatch(href);
    final hit = fromEndpoint ?? fromHref;
    if (hit == null) continue;
    final link = Uri.tryParse(endpoint ?? href ?? '');
    if (host != null && link != null && link.hasAuthority && link.host != host) continue;
    final id = int.tryParse(hit.group(1)!);
    if (id == null) continue; // too long to be a real id
    var name = attr('title') ?? htmlToText(m.group(2)!, maxLength: 200);
    if (name.isEmpty) name = 'File $id';
    found.putIfAbsent(id, () => AttachmentRef(id, name));
  }
  return found.values.toList();
}

SubmissionInfo parseSubmissionInfo(Map<String, dynamic> j, {String? host}) {
  final descHtml = j['description'] is String ? j['description'] as String : '';
  final types = j['submission_types'];
  final exts = j['allowed_extensions'];
  return SubmissionInfo(
    acceptsUpload: types is List && types.contains('online_upload'),
    allowedExtensions: [
      if (exts is List)
        for (final e in exts)
          if (e is String && e.trim().isNotEmpty) e.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), ''),
    ],
    locked: j['locked_for_user'] == true,
    lockReason: _plain(j['lock_explanation']),
    description: htmlToText(descHtml, maxLength: 4000, links: true, origin: host == null ? null : 'https://$host'),
    attachments: parseAttachments(descHtml, host: host),
  );
}

String? _plain(Object? v) {
  if (v is! String) return null;
  final t = v.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.isEmpty ? null : t;
}

String fileBaseName(String path) => path.split(RegExp(r'[\\/]')).last;

String _extOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
}

/// A message if some file is not accepted, else null.
String? validateFiles(SubmissionInfo info, List<String> paths) {
  if (info.allowedExtensions.isEmpty) return null;
  for (final p in paths) {
    final name = fileBaseName(p);
    if (!info.allowedExtensions.contains(_extOf(name))) {
      return '$name is not accepted here. Allowed: ${info.allowedExtensions.join(', ')}.';
    }
  }
  return null;
}

/// A teacher's comment on a submission, possibly with files (e.g. a marked-up copy).
class FeedbackComment {
  const FeedbackComment({required this.author, required this.text, required this.at, required this.files});
  final String author;
  final String text;
  final DateTime? at;
  final List<FileEntry> files;
}

class MySubmission {
  const MySubmission({
    this.submittedAt,
    this.grade,
    this.score,
    this.files = const [],
    this.feedback = const [],
  });

  static const MySubmission empty = MySubmission();

  final DateTime? submittedAt;

  /// Canvas's display grade ("A", "95", "complete"...) and the raw score.
  final String? grade;
  final double? score;

  /// Files the student turned in (latest attempt).
  final List<FileEntry> files;
  final List<FeedbackComment> feedback;

  bool get hasContent => files.isNotEmpty || feedback.isNotEmpty || hasGrade;

  bool get hasGrade => score != null || grade != null;

  /// "85 / 100 (B)", "85 (B)", or just the Canvas grade text.
  String gradeText(double? outOf) {
    String n(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    final s = score;
    final g = grade;
    if (s == null) return g ?? '';
    final base = outOf != null && outOf > 0 ? '${n(s)} / ${n(outOf)}' : n(s);
    final extra = g != null && g != n(s) && g != s.toString() ? ' ($g)' : '';
    return '$base$extra';
  }
}

FileEntry? _attachment(Object? v, int courseId) {
  if (v is! Map) return null;
  final id = v['id'];
  final name = v['display_name'] ?? v['filename'];
  if (id is! num || name is! String || name.isEmpty) return null;
  final updated = v['modified_at'] ?? v['updated_at'] ?? v['created_at'];
  final url = v['url'];
  return FileEntry(
    id: id.toInt(),
    folderId: (v['folder_id'] as num?)?.toInt() ?? 0,
    name: name,
    size: (v['size'] as num?)?.toInt() ?? 0,
    mime: (v['content-type'] ?? v['mime_class'] ?? '') as String,
    updatedAt: updated is String ? DateTime.tryParse(updated)?.toLocal() : null,
    url: url is String && url.isNotEmpty ? url : null,
    courseId: courseId,
  );
}

List<FileEntry> _attachments(Object? list, int courseId) => [
      if (list is List)
        for (final a in list) ?_attachment(a, courseId),
    ];

/// Parses `/submissions/self?include[]=submission_comments`.
MySubmission parseMySubmission(Map<String, dynamic> j, {required int courseId}) {
  final at = j['submitted_at'];
  final score = j['score'];
  final grade = j['grade'];
  final comments = j['submission_comments'];
  return MySubmission(
    submittedAt: at is String ? DateTime.tryParse(at)?.toLocal() : null,
    grade: grade is String && grade.isNotEmpty ? grade : null,
    score: score is num ? score.toDouble() : null,
    files: _attachments(j['attachments'], courseId),
    feedback: [
      if (comments is List)
        for (final c in comments)
          if (c is Map)
            ?_comment(c, courseId),
    ],
  );
}

FeedbackComment? _comment(Map c, int courseId) {
  final files = _attachments(c['attachments'], courseId);
  final raw = c['comment'];
  final text = raw is String ? htmlToText(raw, maxLength: 3000, links: true) : '';
  if (files.isEmpty && text.isEmpty) return null;
  final at = c['created_at'];
  final author = c['author_name'];
  return FeedbackComment(
    author: author is String && author.isNotEmpty ? author : 'Teacher',
    text: text,
    at: at is String ? DateTime.tryParse(at)?.toLocal() : null,
    files: files,
  );
}
