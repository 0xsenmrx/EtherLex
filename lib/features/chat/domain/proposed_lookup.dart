import 'dart:convert';

/// The word after the opening fence of the block the assistant writes when it
/// needs to see something it was not given, to do what the student asked. It
/// only asks: the card lets the student allow it, and the answer goes back as
/// an attachment on the student's next message.
const String kLookupFence = 'etherlex-lookup';

/// Most courses (file lists, assignments) and files (to read) asked for at once.
const int kMaxLookupCourses = 4;
const int kMaxLookupReads = 3;

/// A file whose text is wanted: the course, and a name the app matches against
/// the course's files (so "syllabus" is enough).
class ReadRequest {
  const ReadRequest({required this.course, required this.file});

  final String course;
  final String file;
}

class LookupProposal {
  const LookupProposal({this.courses = const [], this.assignmentCourses = const [], this.reads = const [], this.note});

  /// Courses whose file lists (folders and file names) are wanted.
  final List<String> courses;

  /// Courses whose assignments (with item numbers) are wanted.
  final List<String> assignmentCourses;

  /// Files whose text is wanted.
  final List<ReadRequest> reads;
  final String? note;
}

List<String>? _names(Object? raw) {
  if (raw == null) return const [];
  final list = raw is List ? raw : [raw];
  if (list.length > kMaxLookupCourses) return null;
  final out = <String>[];
  for (final n in list) {
    if (n is! String || n.trim().isEmpty || n.length > 120) return null;
    if (!out.contains(n.trim())) out.add(n.trim());
  }
  return out;
}

/// `{"lookup":{"files":["TechComm"],"assignments":["Linear Algebra"],"read":[{"course":"TechComm","file":"syllabus"}]}}`:
/// any of the three, each a name or a list. Anything else is not a card.
LookupProposal? parseLookup(String source) {
  final Object? j;
  try {
    j = jsonDecode(source);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final l = j['lookup'];
  if (l is! Map || l.keys.any((k) => k != 'files' && k != 'assignments' && k != 'read')) return null;
  final files = _names(l['files']);
  final assignments = _names(l['assignments']);
  if (files == null || assignments == null) return null;
  final rawReads = l['read'];
  final reads = <ReadRequest>[];
  if (rawReads != null) {
    final list = rawReads is List ? rawReads : [rawReads];
    if (list.length > kMaxLookupReads) return null;
    for (final r in list) {
      if (r is! Map || r.length != 2) return null;
      final course = r['course'], file = r['file'];
      if (course is! String || file is! String || course.trim().isEmpty || file.trim().isEmpty || course.length > 120 || file.length > 160) return null;
      reads.add(ReadRequest(course: course.trim(), file: file.trim()));
    }
  }
  if (files.isEmpty && assignments.isEmpty && reads.isEmpty) return null;
  final note = j['note'];
  return LookupProposal(courses: files, assignmentCourses: assignments, reads: reads, note: note is String && note.trim().isNotEmpty ? note.trim() : null);
}
