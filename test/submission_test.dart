import 'package:etherlex/core/network/canvas_client.dart';
import 'package:etherlex/features/submission/domain/submission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseSubmissionInfo reads upload support, extensions and lock', () {
    final info = parseSubmissionInfo({
      'submission_types': ['online_upload', 'online_text_entry'],
      'allowed_extensions': ['PDF', '.docx', ''],
      'locked_for_user': true,
      'lock_explanation': '<p>Closed   on <b>Friday</b></p>',
    });
    expect(info.acceptsUpload, isTrue);
    expect(info.allowedExtensions, ['pdf', 'docx']);
    expect(info.locked, isTrue);
    expect(info.lockReason, 'Closed on Friday');
  });

  test('assignments without online_upload are not uploadable', () {
    expect(parseSubmissionInfo({'submission_types': ['online_text_entry']}).acceptsUpload, isFalse);
    expect(parseSubmissionInfo({'submission_types': ['none']}).acceptsUpload, isFalse);
    expect(parseSubmissionInfo(<String, dynamic>{}).acceptsUpload, isFalse);
  });

  test('validateFiles enforces allowed extensions, case-insensitively', () {
    const pdfOnly = SubmissionInfo(acceptsUpload: true, allowedExtensions: ['pdf']);
    expect(validateFiles(pdfOnly, [r'C:\x\Report.PDF']), isNull);
    expect(validateFiles(pdfOnly, [r'C:\x\notes.txt']), contains('notes.txt'));
    expect(validateFiles(pdfOnly, ['/a/b/noext']), isNotNull);
    const any = SubmissionInfo(acceptsUpload: true);
    expect(validateFiles(any, ['whatever.bin']), isNull);
  });

  test('buildSubmissionBody repeats file_ids[]', () {
    final pairs = [
      for (final part in buildSubmissionBody([7, 9]).split('&'))
        part.split('=').map(Uri.decodeQueryComponent).toList(),
    ];
    expect(pairs, [
      ['submission[submission_type]', 'online_upload'],
      ['submission[file_ids][]', '7'],
      ['submission[file_ids][]', '9'],
    ]);
  });

  test('parseMySubmission reads own files and teacher feedback files', () {
    final m = parseMySubmission({
      'submitted_at': '2026-11-10T08:00:00Z',
      'grade': '92',
      'score': 92,
      'attachments': [
        {'id': 7, 'display_name': 'hw.pdf', 'size': 1200, 'url': 'https://c.edu/files/7/download?x=1'},
      ],
      'submission_comments': [
        {
          'author_name': 'Prof',
          'comment': 'Nice <b>work</b>',
          'created_at': '2026-11-11T08:00:00Z',
          'attachments': [
            {'id': 8, 'display_name': 'marked.pdf', 'url': 'https://c.edu/files/8/download?x=2'},
          ],
        },
        {'author_name': 'Empty', 'comment': '', 'attachments': []},
      ],
    }, courseId: 3);
    expect(m.files.single.name, 'hw.pdf');
    expect(m.files.single.url, contains('/files/7/'));
    expect(m.grade, '92');
    expect(m.feedback.length, 1);
    expect(m.feedback.single.text, 'Nice work');
    expect(m.feedback.single.files.single.name, 'marked.pdf');
    expect(m.hasContent, isTrue);
    expect(parseMySubmission({'workflow_state': 'unsubmitted'}, courseId: 3).hasContent, isFalse);
  });
  gradeTextTests();
}

void gradeTextTests() {
  group('MySubmission.gradeText', () {
    test('score out of points, with letter', () {
      expect(const MySubmission(score: 85, grade: 'B').gradeText(100), '85 / 100 (B)');
    });
    test('numeric grade is not repeated', () {
      expect(const MySubmission(score: 85, grade: '85').gradeText(100), '85 / 100');
    });
    test('grade only', () {
      expect(const MySubmission(grade: 'complete').gradeText(null), 'complete');
      expect(const MySubmission(grade: 'complete').hasGrade, isTrue);
    });
    test('fractions', () {
      expect(const MySubmission(score: 8.5).gradeText(10), '8.5 / 10');
    });
  });
}
