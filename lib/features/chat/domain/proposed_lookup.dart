import 'dart:convert';

/// The word after the opening fence of the block the assistant writes when it
/// needs to see something it was not given, to do what the student asked. It
/// only asks: the card lets the student allow it, and the answer goes back as
/// an attachment on the student's next message.
const String kLookupFence = 'etherlex-lookup';

/// Most courses asked for at once.
const int kMaxLookupCourses = 4;

class LookupProposal {
  const LookupProposal({required this.courses, this.note});

  /// The courses whose file lists are wanted, as the assistant wrote them.
  final List<String> courses;
  final String? note;
}

/// `{"lookup":{"files":"Discrete Mathematics"}}`, or a list of up to four
/// course names. Anything else is not a card.
LookupProposal? parseLookup(String source) {
  final Object? j;
  try {
    j = jsonDecode(source);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final l = j['lookup'];
  if (l is! Map || l.length != 1) return null;
  final raw = l['files'];
  final names = raw is List ? raw : [raw];
  if (names.isEmpty || names.length > kMaxLookupCourses) return null;
  final courses = <String>[];
  for (final n in names) {
    if (n is! String || n.trim().isEmpty || n.length > 120) return null;
    if (!courses.contains(n.trim())) courses.add(n.trim());
  }
  final note = j['note'];
  return LookupProposal(courses: courses, note: note is String && note.trim().isNotEmpty ? note.trim() : null);
}
