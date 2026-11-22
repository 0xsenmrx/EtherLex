import 'dart:convert';

/// The word after the opening fence of the block the assistant writes when it
/// needs to see something it was not given, to do what the student asked. It
/// only asks: the card lets the student allow it, and the answer goes back as
/// an attachment on the student's next message.
const String kLookupFence = 'etherlex-lookup';

class LookupProposal {
  const LookupProposal({required this.course, this.note});

  /// The course whose file list is wanted, as the assistant wrote it.
  final String course;
  final String? note;
}

/// `{"lookup":{"files":"Discrete Mathematics"}}`. Anything else is not a card.
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
  final course = l['files'];
  if (course is! String || course.trim().isEmpty || course.length > 120) return null;
  final note = j['note'];
  return LookupProposal(course: course.trim(), note: note is String && note.trim().isNotEmpty ? note.trim() : null);
}
