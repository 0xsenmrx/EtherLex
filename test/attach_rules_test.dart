import 'package:etherlex/features/chat/domain/attach_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('readable kinds and sizes are accepted without downloading', () {
    expect(attachProblemFor('syllabus.pdf', 3 * 1024 * 1024), isNull);
    expect(attachProblemFor('notes.md', 10), isNull);
    expect(attachProblemFor('slides.pptx', 20 * 1024 * 1024), isNull);
    expect(attachProblemFor('plot.png', kMaxImageBytes), isNull);
  });

  test('unreadable kinds and too big files say why', () {
    expect(attachProblemFor('data.xlsx', 10), 'Cannot be read yet');
    expect(attachProblemFor('video.mp4', 10), 'Cannot be read yet');
    expect(attachProblemFor('scan.bmp', 10), contains('PNG, JPEG'));
    expect(attachProblemFor('big.png', kMaxImageBytes + 1), startsWith('Too big: '));
    expect(attachProblemFor('big.pdf', kMaxDocumentBytes + 1), startsWith('Too big: '));
  });

  test('search needs every word, ignoring case and order', () {
    expect(nameMatches('Week 3 Lecture Notes.pdf', 'lecture 3'), isTrue);
    expect(nameMatches('Week 3 Lecture Notes.pdf', 'exam'), isFalse);
    expect(nameMatches('anything', '  '), isTrue);
  });
}
