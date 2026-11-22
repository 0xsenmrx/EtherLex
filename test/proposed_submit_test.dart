import 'package:etherlex/features/chat/domain/proposed_submit.dart';
import 'package:etherlex/features/submission/domain/submission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSubmit', () {
    test('names only the assignment', () {
      final p = parseSubmit('{"submit":{"assignment":12},"note":" ready "}')!;
      expect(p.assignmentId, 12);
      expect(p.note, 'ready');
      expect(parseSubmit('{"submit":{"assignment":12}}')!.note, isNull);
    });

    test('files, text or anything else make it invalid', () {
      expect(parseSubmit('{"submit":{"assignment":12,"files":["C:/a.pdf"]}}'), isNull);
      expect(parseSubmit('{"submit":{"assignment":12,"text":"hi"}}'), isNull);
      expect(parseSubmit('{"submit":{"assignment":"12"}}'), isNull);
      expect(parseSubmit('{"submit":{"assignment":0}}'), isNull);
      expect(parseSubmit('{"submit":{}}'), isNull);
      expect(parseSubmit('{"assignment":12}'), isNull);
      expect(parseSubmit('nope'), isNull);
    });
  });

  group('submitProblem', () {
    const open = SubmissionInfo(acceptsUpload: true, allowedExtensions: ['pdf']);

    test('a closed or non-upload assignment cannot be handed in', () {
      expect(submitProblem(const SubmissionInfo(acceptsUpload: true, locked: true, lockReason: 'Closed on Friday'), ['a.pdf']), 'Closed on Friday');
      expect(submitProblem(const SubmissionInfo(acceptsUpload: true, locked: true), ['a.pdf']), contains('closed'));
      expect(submitProblem(const SubmissionInfo(acceptsUpload: false), ['a.pdf']), contains('does not take file uploads'));
    });

    test('needs files, not too many, of an accepted type', () {
      expect(submitProblem(open, []), 'Choose at least one file.');
      expect(submitProblem(open, [for (var i = 0; i < 11; i++) 'f$i.pdf']), contains('at most 10'));
      expect(submitProblem(open, ['C:\\x\\report.docx']), contains('not accepted'));
      expect(submitProblem(open, ['C:\\x\\report.PDF']), isNull);
    });
  });

  test('the consent text names the assignment, the course and every file, and warns when late', () {
    final one = consentMessage(course: 'PHYS2', title: 'Lab 3', fileNames: ['lab3.pdf'], late: false);
    expect(one, contains('"Lab 3" (PHYS2)'));
    expect(one, contains('this file: lab3.pdf'));
    expect(one, contains('cannot take it back'));
    expect(one, isNot(contains('late')));
    final two = consentMessage(course: 'PHYS2', title: 'Lab 3', fileNames: ['a.pdf', 'b.pdf'], late: true);
    expect(two, contains('these 2 files: a.pdf, b.pdf'));
    expect(two, contains('count as late'));
  });
}
