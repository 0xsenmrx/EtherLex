import 'dart:io';

import 'package:etherlex/features/viewer/data/doc_text.dart';
import 'package:etherlex/features/viewer/data/file_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_ft_'));
  tearDown(() {
    // Windows can still hold a just-read file for a moment; a leftover temp folder is harmless.
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  test('document paragraphs become plain text with headings and bullets', () {
    final text = blocksToText(const [
      DocBlock([DocRun('Syllabus')], level: 1),
      DocBlock([DocRun('Grading: '), DocRun('40% exams', bold: true)]),
      DocBlock([DocRun('Homework')], bullet: true),
      DocBlock([DocRun('  ')]),
    ]);
    expect(text, '# Syllabus\nGrading: 40% exams\n- Homework');
  });

  test('text and Markdown files are read; empty and unknown kinds give null', () async {
    final md = File('${dir.path}/notes.md')..writeAsStringSync('# Notes\n\nHello');
    expect(await readFileText(md.path, 'notes.md'), '# Notes\n\nHello');
    final empty = File('${dir.path}/empty.txt')..writeAsStringSync('  \n');
    expect(await readFileText(empty.path, 'empty.txt'), isNull);
    final zip = File('${dir.path}/a.zip')..writeAsBytesSync([1, 2, 3]);
    expect(await readFileText(zip.path, 'a.zip'), isNull);
    expect(await readFileText('${dir.path}/missing.txt', 'missing.txt'), isNull);
  });

  test('a huge text file is only read up to the limit', () async {
    final big = File('${dir.path}/big.txt')..writeAsStringSync('a' * (kMaxReadBytes + 5000));
    final text = await readFileText(big.path, 'big.txt');
    expect(text!.length, kMaxReadBytes);
  });

  test('picture types the AI services accept', () {
    expect(imageMimeFor('Plot.PNG'), 'image/png');
    expect(imageMimeFor('a.jpeg'), 'image/jpeg');
    expect(imageMimeFor('a.jpg'), 'image/jpeg');
    expect(imageMimeFor('a.webp'), 'image/webp');
    expect(imageMimeFor('a.gif'), 'image/gif');
    expect(imageMimeFor('a.bmp'), isNull);
    expect(imageMimeFor('a.pdf'), isNull);
  });
}
