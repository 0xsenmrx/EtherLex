import 'package:etherlex/core/utils/char_code.dart';
import 'package:etherlex/core/utils/file_link_markup.dart';
import 'package:etherlex/core/utils/html_text.dart';
import 'package:etherlex/features/activity/data/activity_mapper.dart';
import 'package:etherlex/features/files/data/files_mapper.dart';
import 'package:etherlex/features/submission/domain/submission.dart';
import 'package:etherlex/features/viewer/data/doc_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canvas pages, messages and Office files are written by other people.
/// Odd input must give odd text, never an exception (pre-0.3.0 review).
void main() {
  test('entities outside Unicode are dropped, not thrown', () {
    expect(charFromCode(0x41), 'A');
    expect(charFromCode(0x1F600), '😀');
    expect(charFromCode(0x110000), '');
    expect(charFromCode(-1), '');
    expect(charFromCode(null), '');
    expect(htmlToText('<p>a&#99999999;b &#999999999999999999999999;c &#65;</p>'), 'ab c A');
  });

  test('a file link with an impossible id is plain text', () {
    const html = '<a href="https://c.edu/courses/1/files/123456789012345678901234">notes</a> ok';
    expect(() => htmlToText(html, links: true, fileLinks: true, origin: 'https://c.edu'), returnsNormally);
    final text = htmlToText(html, links: true, fileLinks: true, origin: 'https://c.edu');
    expect(fileLinkPattern.hasMatch(text), isFalse);
    expect(text, contains('notes'));
  });

  test('text from Canvas cannot forge a file-link marker', () {
    final forged = '${fileLinkMarker(courseId: 1, fileId: 2, name: 'x')} and \uE0009:9\uE001y\uE002';
    final text = htmlToText(forged);
    expect(fileLinkPattern.hasMatch(text), isFalse);
    expect(stripFileLinkChars(forged), isNot(contains('\uE000')));
  });

  test('markers never carry ids that overflow an int', () {
    final huge = '\uE000${'9' * 25}:1\uE001name\uE002';
    expect(fileLinkPattern.hasMatch(huge), isFalse);
  });

  test('one activity item with odd HTML still maps', () {
    final item = parseActivity({
      'id': 1,
      'type': 'DiscussionTopic',
      'title': 'Hi',
      'created_at': '2026-11-20T10:00:00Z',
      'message': '<a href="/files/99999999999999999999999">x</a> &#99999999;',
    }, host: 'c.edu');
    expect(item, isNotNull);
  });

  test('attachment links with impossible ids are skipped', () {
    final refs = parseAttachments(
      '<a href="https://c.edu/files/99999999999999999999999">big</a><a href="https://c.edu/files/7">ok</a>',
      host: 'c.edu',
    );
    expect([for (final r in refs) r.fileId], [7]);
  });

  test('Office text with impossible entities still reads', () {
    final blocks = parseDocxXml('<w:p><w:r><w:t>A&#x110000;&#99999999999999999999;B</w:t></w:r></w:p>');
    expect(blocks.map((b) => b.plain).join(), 'AB');
  });

  test('a file entry with odd types is still listed', () {
    final f = parseFile({
      'id': 3,
      'folder_id': 4,
      'display_name': 'a.pdf',
      'size': '12',
      'content-type': 5,
    }, courseId: 1);
    expect(f, isNotNull);
    expect(f!.size, 0);
    expect(f.mime, '');
  });
}
