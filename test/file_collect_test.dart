import 'package:etherlex/features/chat/domain/file_collect.dart';
import 'package:etherlex/features/files/domain/files_models.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry file(int id, String name, int folder) => FileEntry(
      id: id,
      folderId: folder,
      name: name,
      size: 10,
      mime: 'text/plain',
      updatedAt: DateTime(2026),
      url: 'https://x/$id',
      courseId: 1,
    );

FolderNode folder(int id, String name, int? parent) => FolderNode(id: id, name: name, parentId: parent);

void main() {
  // root(1) > week1(2) > extra(3); root > week2(4)
  final data = CourseFiles(
    folders: [folder(1, 'root', null), folder(2, 'week1', 1), folder(3, 'extra', 2), folder(4, 'week2', 1)],
    files: [file(10, 'a.pdf', 1), file(11, 'b.pdf', 2), file(12, 'c.pdf', 3), file(13, 'd.pdf', 4), file(14, 'e.pdf', 2)],
  );
  List<int> ids(CollectedFiles r) => [for (final f in r.files) f.id];

  test('ticked files come back once, in listing order', () {
    expect(ids(collectFiles(data, fileIds: {13, 10})), [10, 13]);
    expect(ids(collectFiles(data, fileIds: {99})), isEmpty);
  });

  test('a folder gives its own files; subfolders only when asked', () {
    expect(ids(collectFiles(data, folderIds: {2})), [11, 14]);
    expect(ids(collectFiles(data, folderIds: {2}, includeSubfolders: true)), [11, 14, 12]);
  });

  test('a file ticked and also inside a ticked folder is not doubled', () {
    expect(ids(collectFiles(data, fileIds: {14}, folderIds: {2})), [14, 11]);
  });

  test('the file limit stops the search and says so', () {
    final r = collectFiles(data, folderIds: {1}, includeSubfolders: true, maxFiles: 3);
    expect(r.files.length, 3);
    expect(r.notes.single, contains('Stopped at 3 files'));
  });

  test('files that cannot be attached are listed, not counted', () {
    final r = collectFiles(data, folderIds: {2}, problemOf: (f) => f.id == 11 ? 'too big' : null, maxFiles: 1);
    expect(ids(r), [14]);
    expect(r.skipped.single.reason, 'too big');
    expect(r.notes, isEmpty);
  });

  test('depth is limited', () {
    final r = collectFiles(data, folderIds: {1}, includeSubfolders: true, maxDepth: 1);
    expect(ids(r), [10, 11, 14, 13]);
    expect(r.notes.single, contains('levels down'));
  });

  test('the folder count is limited', () {
    final r = collectFiles(data, folderIds: {1}, includeSubfolders: true, maxFolders: 2);
    expect(r.notes.single, contains('Stopped after 2 folders'));
  });

  test('a folder that is its own parent, or two that point at each other, cannot loop', () {
    final loop = CourseFiles(
      folders: [folder(1, 'a', 2), folder(2, 'b', 1), folder(3, 'self', 3)],
      files: [file(1, 'x.txt', 1), file(2, 'y.txt', 2), file(3, 'z.txt', 3)],
    );
    expect(ids(collectFiles(loop, folderIds: {1}, includeSubfolders: true)), [1, 2]);
    expect(ids(collectFiles(loop, folderIds: {3}, includeSubfolders: true)), [3]);
  });

  test('hidden folders are never entered', () {
    final r = collectFiles(data, folderIds: {1}, includeSubfolders: true, skipFolders: {2});
    expect(ids(r), [10, 13]);
  });
}
