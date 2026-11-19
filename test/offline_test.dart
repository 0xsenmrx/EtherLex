import 'dart:io';

import 'package:etherlex/features/files/data/file_cache.dart';
import 'package:etherlex/features/files/domain/files_models.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry file(int id, int folder, {int size = 5, DateTime? updated, String name = 'a.pdf'}) =>
    FileEntry(id: id, folderId: folder, name: name, size: size, mime: 'application/pdf', updatedAt: updated, url: null, courseId: 1);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_cache'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> write(String path, [int n = 5]) async => File(path).writeAsBytesSync(List.filled(n, 1));

  test('fetches once, then serves the saved copy', () async {
    final c = FileCache('host', root: dir.path);
    var calls = 0;
    final f = file(1, 1);
    expect(c.lookup(f), isNull);
    final p1 = await c.ensure(f, (p) async {
      calls++;
      await write(p);
    });
    final p2 = await c.ensure(f, (p) async {
      calls++;
      await write(p);
    });
    expect(p1, p2);
    expect(calls, 1);
    expect(c.lookup(f), p1);
    expect(c.count(), 1);
  });

  test('opening a file twice at once downloads it once', () async {
    final c = FileCache('host', root: dir.path);
    var calls = 0;
    final f = file(1, 1);
    Future<void> fetch(String p) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await write(p);
    }

    final both = await Future.wait([c.ensure(f, fetch), c.ensure(f, fetch)]);
    expect(both[0], both[1]);
    expect(calls, 1);
    // Finished downloads are forgotten: a later call is served from disk.
    expect(await c.ensure(f, fetch), both[0]);
    expect(calls, 1);
  });

  test('a new version replaces the old one', () async {
    final c = FileCache('host', root: dir.path);
    final v1 = file(1, 1, updated: DateTime(2026, 1, 1));
    final v2 = file(1, 1, updated: DateTime(2026, 2, 1));
    await c.ensure(v1, (p) => write(p));
    await c.ensure(v2, (p) => write(p));
    expect(c.lookup(v1), isNull);
    expect(c.lookup(v2), isNotNull);
    expect(c.count(), 1);
  });

  test('wrong size is not trusted', () async {
    final c = FileCache('host', root: dir.path);
    final f = file(1, 1, size: 10);
    await c.ensure(f, (p) => write(p, 3));
    expect(c.lookup(f), isNull);
  });

  test('prune drops the least recently used', () async {
    final c = FileCache('host', root: dir.path, maxBytes: 12);
    final a = file(1, 1, name: 'a.pdf');
    final b = file(2, 1, name: 'b.pdf');
    final d = file(3, 1, name: 'c.pdf');
    final pa = await c.ensure(a, (p) => write(p));
    File(pa).setLastModifiedSync(DateTime(2020));
    await c.ensure(b, (p) => write(p));
    await c.ensure(d, (p) => write(p));
    expect(c.lookup(a), isNull);
    expect(c.lookup(b), isNotNull);
    expect(c.lookup(d), isNotNull);
  });

  test('listing round trip', () {
    final c = FileCache('host', root: dir.path);
    final data = CourseFiles(
      folders: const [FolderNode(id: 1, name: 'root', parentId: null)],
      files: [file(7, 1, updated: DateTime.utc(2026, 3, 4))],
    );
    expect(c.loadIndex(9), isNull);
    c.saveIndex(9, data);
    final back = c.loadIndex(9)!;
    expect(back.fromCache, isTrue);
    expect(back.folders.single.name, 'root');
    expect(back.files.single.id, 7);
    expect(back.files.single.updatedAt!.toUtc(), DateTime.utc(2026, 3, 4));
  });

  test('clear empties the cache', () async {
    final c = FileCache('host', root: dir.path);
    await c.ensure(file(1, 1), (p) => write(p));
    c.clear();
    expect(c.count(), 0);
    expect(c.sizeBytes(), 0);
  });

  test('filesUnder follows folders and skips hidden ones', () {
    final d = CourseFiles(
      folders: const [
        FolderNode(id: 1, name: 'root', parentId: null),
        FolderNode(id: 2, name: 'week1', parentId: 1),
        FolderNode(id: 3, name: 'old', parentId: 1),
        FolderNode(id: 4, name: 'deep', parentId: 3),
      ],
      files: [file(10, 1), file(11, 2), file(12, 3), file(13, 4)],
    );
    expect([for (final f in filesUnder(d, null)) f.id]..sort(), [10, 11, 12, 13]);
    expect([for (final f in filesUnder(d, 2)) f.id], [11]);
    expect([for (final f in filesUnder(d, null, skip: {3})) f.id]..sort(), [10, 11]);
  });
}
