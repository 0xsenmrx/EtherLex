import 'dart:io';

import 'package:etherlex/features/files/data/file_cache.dart';
import 'package:etherlex/features/files/domain/files_models.dart';
import 'package:etherlex/features/files/domain/offline_usage.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry file(int id, {int size = 5}) =>
    FileEntry(id: id, folderId: 1, name: 'f$id.pdf', size: size, mime: 'application/pdf', updatedAt: null, url: null, courseId: 1);

void main() {
  group('summarizeOffline', () {
    test('groups by course, biggest first, unknown files last', () {
      final u = summarizeOffline(
        {1: 100, 2: 50, 3: 500, 9: 7},
        {
          10: {1, 2},
          20: {3},
        },
      );
      expect(u.total, 657);
      expect([for (final c in u.courses) c.courseId], [20, 10, null]);
      expect([for (final c in u.courses) c.bytes], [500, 150, 7]);
      expect(u.courses[1].fileIds, {1, 2});
      expect(u.courses.last.fileIds, {9});
    });

    test('nothing saved', () {
      final u = summarizeOffline({}, {10: {1}});
      expect(u.total, 0);
      expect(u.courses, isEmpty);
    });

    test('a file in two listings counts once', () {
      final u = summarizeOffline({1: 10}, {10: {1}, 20: {1}});
      expect(u.courses.single.bytes, 10);
    });

    test('limits', () {
      expect(kOfflineLimitsGb, contains(kDefaultOfflineLimitGb));
    });
  });

  group('cache sizes and removal', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_usage'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold a file for a moment.
      }
    });

    Future<void> save(FileCache c, FileEntry f) =>
        c.ensure(f, (p) async => File(p).writeAsBytesSync(List.filled(f.size, 1)));

    test('cacheFileId reads the id at the start of the name', () {
      expect(cacheFileId('123_456_notes.pdf'), 123);
      expect(cacheFileId('notes.pdf'), isNull);
      expect(cacheFileId('_x'), isNull);
    });

    test('sizes per file id, without partial downloads', () async {
      final c = FileCache('host', root: dir.path);
      await save(c, file(1, size: 4));
      await save(c, file(2, size: 6));
      File('${dir.path}/files/host/3_0_x.pdf.part').writeAsBytesSync([1, 2, 3]);
      expect(scanCacheSizes('${dir.path}/files/host'), {1: 4, 2: 6});
      expect(await c.sizesByFileId(), {1: 4, 2: 6});
      expect(scanCacheSizes('${dir.path}/nothing'), isEmpty);
    });

    test('removeFiles takes only those files', () async {
      final c = FileCache('host', root: dir.path);
      await save(c, file(1));
      await save(c, file(2));
      c.removeFiles({1});
      expect(c.lookup(file(1)), isNull);
      expect(c.lookup(file(2)), isNotNull);
    });

    test('a lower limit removes the files opened longest ago', () async {
      final c = FileCache('host', root: dir.path, maxBytes: 100);
      await save(c, file(1, size: 30));
      final old = File(c.lookup(file(1, size: 30))!);
      old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
      await save(c, file(2, size: 30));
      c.setLimit(40);
      expect(c.lookup(file(1, size: 30)), isNull);
      expect(c.lookup(file(2, size: 30)), isNotNull);
      expect(c.maxBytes, 40);
    });
  });
}
