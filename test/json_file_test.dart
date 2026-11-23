import 'dart:io';

import 'package:etherlex/core/storage/json_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_json_'));
  tearDown(() {
    // Windows can still hold a just-written file for a moment; a leftover temp folder is harmless.
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  File file(String name) => File('${dir.path}${Platform.pathSeparator}$name');

  test('missing and damaged files read as null or an empty map', () async {
    expect(await JsonFile(file('none.json')).read(), isNull);
    final bad = file('bad.json')..writeAsStringSync('{not json');
    expect(await JsonFile(bad).read(), isNull);
    expect(await JsonFile(bad).readMap(), isEmpty);
    final list = file('list.json')..writeAsStringSync('[1, 2]');
    expect(await JsonFile(list).readMap(), isEmpty);
  });

  test('write then read', () async {
    final f = JsonFile(file('a.json'));
    await f.write({'x': 1});
    expect(await f.read(), {'x': 1});
  });

  test('a read waits for a write queued before it, even from another object', () async {
    final a = JsonFile(file('w.json'));
    final b = JsonFile(file('w.json'));
    await a.write({'n': 1});
    final writing = a.write({'n': 2}); // not awaited
    expect(await b.read(), {'n': 2});
    await writing;
  });

  test('update still works (it reads inside the queue)', () async {
    final f = JsonFile(file('u.json'));
    await f.write({'a': 1});
    await f.update((m) => m['b'] = 2);
    expect(await f.read(), {'a': 1, 'b': 2});
  });

  test('updates from two objects on the same file both land', () async {
    final a = JsonFile(file('s.json'));
    final b = JsonFile(file('s.json'));
    await Future.wait([
      a.update((m) => m['one'] = 1),
      b.update((m) => m['two'] = 2),
      a.update((m) => m['three'] = 3),
    ]);
    expect(await a.readMap(), {'one': 1, 'two': 2, 'three': 3});
  });

  test('the last of several quick writes wins', () async {
    final f = JsonFile(file('q.json'));
    final writes = [for (var i = 0; i < 20; i++) f.write({'n': i})];
    await Future.wait(writes);
    expect(await f.read(), {'n': 19});
  });

  test('a failed write does not block the next one', () async {
    final f = JsonFile(file('ok.json'));
    await expectLater(f.update((_) => throw StateError('boom')), throwsStateError);
    await f.write({'after': true});
    expect(await f.read(), {'after': true});
  });
}
