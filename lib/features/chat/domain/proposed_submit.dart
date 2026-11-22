import 'dart:convert';

import '../../submission/domain/submission.dart';

/// The word after the opening fence of the block the assistant writes when the
/// student wants to hand in an assignment. It only names the assignment: the
/// files are chosen by the student on the card, never by the assistant, and the
/// card asks for consent before anything is sent.
const String kSubmitFence = 'etherlex-submit';

class SubmitProposal {
  const SubmitProposal({required this.assignmentId, this.note});

  final int assignmentId;
  final String? note;
}

/// `{"submit":{"assignment":12},"note":"..."}`. Anything else (extra fields,
/// a text body, file paths) makes the block invalid, so it stays plain code.
SubmitProposal? parseSubmit(String source) {
  final Object? j;
  try {
    j = jsonDecode(source);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final s = j['submit'];
  if (s is! Map || s.length != 1) return null;
  final id = s['assignment'];
  if (id is! int || id <= 0) return null;
  final note = j['note'];
  return SubmitProposal(assignmentId: id, note: note is String && note.trim().isNotEmpty ? note.trim() : null);
}

/// Most files handed in at once.
const int kMaxSubmitFiles = 10;

/// Why [paths] cannot be turned in now, or null when they can.
String? submitProblem(SubmissionInfo info, List<String> paths) {
  if (info.locked) return info.lockReason ?? 'Submissions are closed for this assignment.';
  if (!info.acceptsUpload) return 'This assignment does not take file uploads here.';
  if (paths.isEmpty) return 'Choose at least one file.';
  if (paths.length > kMaxSubmitFiles) return 'Choose at most $kMaxSubmitFiles files.';
  return validateFiles(info, paths);
}

/// What the consent dialog says is about to happen: nothing is left out.
String consentMessage({
  required String course,
  required String title,
  required List<String> fileNames,
  required bool late,
}) =>
    'You are about to hand in "$title" ($course) to your teacher in Canvas with '
    '${fileNames.length == 1 ? 'this file' : 'these ${fileNames.length} files'}: ${fileNames.join(', ')}.'
    '${late ? '\n\nThe due date has passed: it will count as late.' : ''}'
    '\n\nThis is sent for real. EtherLex cannot take it back; whether you can submit again depends on the course.';
