import 'dart:convert';

import 'package:etherlex/features/chat/data/sse.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<(String?, String)>> _read(List<List<int>> chunks) async => [
      await for (final e in parseSse(Stream.fromIterable(chunks))) (e.event, e.data),
    ];

List<int> _b(String s) => utf8.encode(s);

void main() {
  test('reads events with and without a name', () async {
    final out = await _read([_b('event: ping\ndata: {"a":1}\n\ndata: hello\n\n')]);
    expect(out, [('ping', '{"a":1}'), (null, 'hello')]);
  });

  test('lines cut between chunks are put back together', () async {
    final out = await _read([_b('da'), _b('ta: hel'), _b('lo\n'), _b('\n')]);
    expect(out, [(null, 'hello')]);
  });

  test('a letter split across two chunks survives', () async {
    final bytes = _b('data: é\n\n'); // é is two bytes
    final out = await _read([bytes.sublist(0, 7), bytes.sublist(7)]);
    expect(out, [(null, 'é')]);
  });

  test('windows line ends and comment lines', () async {
    final out = await _read([_b(': keep-alive\r\ndata: one\r\n\r\n')]);
    expect(out, [(null, 'one')]);
  });

  test('several data lines are joined with a newline', () async {
    final out = await _read([_b('data: a\ndata: b\n\n')]);
    expect(out, [(null, 'a\nb')]);
  });

  test('the last event counts even without the closing blank line', () async {
    final out = await _read([_b('data: tail\n')]);
    expect(out, [(null, 'tail')]);
  });

  test('blank lines alone give nothing', () async {
    expect(await _read([_b('\n\n\n')]), isEmpty);
  });
}
