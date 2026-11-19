import 'package:etherlex/features/submission/domain/submission.dart';
import 'package:etherlex/features/viewer/data/doc_text.dart';
import 'package:etherlex/features/viewer/domain/preview_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previewKindFor', () {
    expect(previewKindFor('Notes.PDF'), PreviewKind.pdf);
    expect(previewKindFor('readme.md'), PreviewKind.markdown);
    expect(previewKindFor('a.docx'), PreviewKind.docx);
    expect(previewKindFor('a.pptx'), PreviewKind.pptx);
    expect(previewKindFor('p.JPG'), PreviewKind.image);
    expect(previewKindFor('main.py'), PreviewKind.text);
    expect(previewKindFor('setup.exe'), PreviewKind.none);
    expect(previewKindFor('noext'), PreviewKind.none);
  });

  test('parseAttachments finds Canvas file links and skips other hosts', () {
    const html = '''
<p>Read this:
<a class="instructure_file_link" title="Problem Set 3.pdf"
   href="https://school.instructure.com/courses/5/files/123?wrap=1"
   data-api-endpoint="https://school.instructure.com/api/v1/courses/5/files/123"
   data-api-returntype="File">Problem Set 3.pdf</a>
and <a href="/courses/5/files/124/download">Data sheet</a>
and <a href="https://evil.example/courses/5/files/999">Other</a>
and <a href="https://school.instructure.com/courses/5/files/123">dupe</a></p>''';
    final refs = parseAttachments(html, host: 'school.instructure.com');
    expect(refs.map((r) => r.fileId), [123, 124]);
    expect(refs[0].name, 'Problem Set 3.pdf');
    expect(refs[1].name, 'Data sheet');
  });

  test('parseSubmissionInfo carries description and attachments', () {
    final info = parseSubmissionInfo({
      'submission_types': ['online_upload'],
      'description': '<p>Do it.</p><a href="/courses/1/files/7/download">x.pdf</a>',
    });
    expect(info.description, contains('Do it.'));
    expect(info.attachments.single.fileId, 7);
  });

  test('parseDocxXml reads headings, bullets, bold and entities', () {
    const xml = '''
<w:body>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Title</w:t></w:r></w:p>
<w:p><w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">Bold </w:t></w:r><w:r><w:t>and &amp; plain</w:t></w:r></w:p>
<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>Item</w:t></w:r></w:p>
<w:p></w:p>
</w:body>''';
    final blocks = parseDocxXml(xml);
    expect(blocks.length, 3);
    expect(blocks[0].level, 1);
    expect(blocks[0].plain, 'Title');
    expect(blocks[1].runs.first.bold, isTrue);
    expect(blocks[1].plain, 'Bold and & plain');
    expect(blocks[2].bullet, isTrue);
  });

  test('parsePptxSlideXml joins runs per paragraph', () {
    const xml = '<a:p><a:r><a:t>Hello </a:t></a:r><a:r><a:t>World</a:t></a:r></a:p><a:p><a:r><a:t> </a:t></a:r></a:p>';
    final blocks = parsePptxSlideXml(xml);
    expect(blocks.length, 1);
    expect(blocks.single.plain, 'Hello World');
  });
}
