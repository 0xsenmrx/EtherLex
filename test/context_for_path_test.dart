import 'dart:io';

import 'package:etherlex/features/chat/domain/attach_rules.dart';
import 'package:etherlex/features/chat/domain/context_item.dart';
import 'package:etherlex/features/chat/presentation/chat_attach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_cp_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a text file becomes a file attachment', () async {
    final f = File('${dir.path}/syllabus.md')..writeAsStringSync('# Grading\n40% exams');
    final item = await contextForPath(f.path, 'syllabus.md', fileId: 7);
    expect(item, isA<FileContext>());
    expect(item.label, 'syllabus.md');
    expect(item.text, '# Grading\n40% exams');
    expect(item.key, 'file:7');
  });

  test('a picture becomes an image attachment with its type', () async {
    final f = File('${dir.path}/plot.PNG')..writeAsBytesSync([1, 2, 3]);
    final item = await contextForPath(f.path, 'plot.PNG');
    expect(item, isA<ImageContext>());
    expect((item as ImageContext).mimeType, 'image/png');
    expect(item.bytes, [1, 2, 3]);
  });

  test('a too big picture and a file without text are refused with a message', () async {
    final big = File('${dir.path}/big.png')..writeAsBytesSync(List.filled(kMaxImageBytes + 1, 0));
    expect(
      contextForPath(big.path, 'big.png'),
      throwsA(isA<AttachException>().having((e) => e.message, 'message', contains('not sent'))),
    );
    final empty = File('${dir.path}/empty.txt')..writeAsStringSync('');
    expect(
      contextForPath(empty.path, 'empty.txt'),
      throwsA(isA<AttachException>().having((e) => e.message, 'message', contains('No readable text'))),
    );
  });
}
