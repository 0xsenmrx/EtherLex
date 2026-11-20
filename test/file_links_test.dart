import 'package:etherlex/core/utils/file_link_markup.dart';
import 'package:etherlex/core/utils/html_text.dart';
import 'package:etherlex/features/activity/data/activity_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

const _origin = 'https://c.edu';

String _text(String html, {bool fileLinks = true, String? origin = _origin, int maxLength = 2000}) =>
    htmlToText(html, links: true, fileLinks: fileLinks, origin: origin, maxLength: maxLength);

List<FileLinkRef> _links(String text) => [for (final m in fileLinkPattern.allMatches(text)) fileLinkOf(m)];

void main() {
  group('file link markers', () {
    test('a marker reads back as course, file and name', () {
      final text = 'See ${fileLinkMarker(courseId: 12, fileId: 345, name: 'Syllabus.pdf')} today';
      expect(_links(text), [(courseId: 12, fileId: 345, name: 'Syllabus.pdf')]);
      expect(stripFileLinks(text), 'See Syllabus.pdf today');
    });

    test('an empty name becomes "File" and marker characters are removed from names', () {
      expect(stripFileLinks(fileLinkMarker(courseId: 1, fileId: 2, name: '  ')), 'File');
      expect(stripFileLinks(fileLinkMarker(courseId: 1, fileId: 2, name: 'ab')), 'ab');
    });

    test('plain text is left alone', () {
      expect(stripFileLinks('no files here'), 'no files here');
      expect(_links('no files here'), isEmpty);
    });
  });

  group('htmlToText fileLinks', () {
    test('a file link on this site becomes a marker with its course', () {
      final t = _text('<a href="https://c.edu/courses/12/files/345?wrap=1">Syllabus.pdf</a>');
      expect(_links(t), [(courseId: 12, fileId: 345, name: 'Syllabus.pdf')]);
    });

    test('relative and download links work, a missing course is 0', () {
      expect(_links(_text('<a href="/courses/7/files/9/download?download_frd=1">Notes</a>')),
          [(courseId: 7, fileId: 9, name: 'Notes')]);
      expect(_links(_text('<a href="/files/5/download">Slides</a>')), [(courseId: 0, fileId: 5, name: 'Slides')]);
    });

    test('tags inside the link are dropped from the name', () {
      expect(stripFileLinks(_text('<a href="/courses/1/files/2"><strong>Lab</strong>&nbsp;1.pdf</a>')), 'Lab 1.pdf');
    });

    test('text around the link is kept and several links are found in order', () {
      final t = _text('<p>Read <a href="/courses/1/files/2">A.pdf</a> and <a href="/courses/1/files/3">B.pdf</a>.</p>');
      expect(stripFileLinks(t), 'Read A.pdf and B.pdf.');
      expect([for (final l in _links(t)) l.fileId], [2, 3]);
    });

    test('links to another site, picture links and no-origin calls stay plain', () {
      expect(_links(_text('<a href="https://other.org/files/5">x</a>')), isEmpty);
      expect(_links(_text('<a href="/courses/1/files/2"><img src="/x.png"></a>')), isEmpty);
      expect(_links(_text('<a href="https://c.edu/courses/1/files/2">x</a>', origin: null)), isEmpty);
    });

    test('off by default: the old behaviour (plain name) is unchanged', () {
      expect(_text('<a href="https://c.edu/files/5/download">slides.pdf</a>', fileLinks: false), 'slides.pdf');
    });

    test('shortening the text never leaves half a marker', () {
      final html = 'x' * 20 + '<a href="/courses/1/files/2">Very long file name.pdf</a>';
      final t = _text(html, maxLength: 30);
      expect(t.contains(''), isFalse);
      expect(t.endsWith('…'), isTrue);
    });
  });

  group('announcements', () {
    test('an announcement keeps its file link, and plainBody shows only words', () {
      final a = parseAnnouncement({
        'id': 1,
        'posted_at': '2026-11-10T10:00:00Z',
        'title': 'Slides',
        'context_code': 'course_12',
        'message': '<p>Slides: <a href="https://c.edu/courses/12/files/345?wrap=1">Lecture 3.pdf</a></p>',
      }, host: 'c.edu');
      expect(a, isNotNull);
      expect(_links(a!.body), [(courseId: 12, fileId: 345, name: 'Lecture 3.pdf')]);
      expect(a.plainBody, 'Slides: Lecture 3.pdf');
    });
  });
}
