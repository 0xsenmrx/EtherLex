import 'package:etherlex/features/chat/domain/local_collect.dart';
import 'package:flutter_test/flutter_test.dart';

/// folders: path -> (files, subfolders); files: path -> size.
class FakeDisk implements LocalDisk {
  FakeDisk(this.tree, this.sizes, {this.skips = const {}});

  final Map<String, ({List<String> files, List<String> folders})> tree;
  final Map<String, int> sizes;
  final Set<String> skips;

  @override
  Future<LocalKind> kindOf(String path) async {
    if (skips.contains(path)) return LocalKind.skip;
    if (tree.containsKey(path)) return LocalKind.folder;
    if (sizes.containsKey(path)) return LocalKind.file;
    return LocalKind.skip;
  }

  @override
  Future<int> sizeOf(String file) async => sizes[file] ?? 0;

  @override
  Future<({List<String> files, List<String> folders})> list(String folder) async => tree[folder] ?? (files: <String>[], folders: <String>[]);
}

void main() {
  final disk = FakeDisk(
    {
      r'C:\w': (files: [r'C:\w\b.pdf', r'C:\w\a.pdf'], folders: [r'C:\w\sub']),
      r'C:\w\sub': (files: [r'C:\w\sub\c.pdf'], folders: [r'C:\w\sub\deep']),
      r'C:\w\sub\deep': (files: [r'C:\w\sub\deep\d.pdf'], folders: <String>[]),
    },
    {
      r'C:\w\a.pdf': 1,
      r'C:\w\b.pdf': 1,
      r'C:\w\sub\c.pdf': 1,
      r'C:\w\sub\deep\d.pdf': 1,
      r'C:\x.pdf': 1,
      r'C:\big.pdf': 999,
    },
  );

  test('fileNameOf handles both separators', () {
    expect(fileNameOf(r'C:\a\b.pdf'), 'b.pdf');
    expect(fileNameOf('/home/a/b.pdf'), 'b.pdf');
    expect(fileNameOf(r'C:\a\folder\'), 'folder');
  });

  test('a folder gives its files, nearest first, then its subfolders', () async {
    final r = await collectLocal(disk, [r'C:\w']);
    expect(r.files, [r'C:\w\a.pdf', r'C:\w\b.pdf', r'C:\w\sub\c.pdf', r'C:\w\sub\deep\d.pdf']);
    expect(r.notes, isEmpty);
  });

  test('single files and folders mix, each file once', () async {
    final r = await collectLocal(disk, [r'C:\x.pdf', r'C:\w\a.pdf', r'C:\w'], maxDepth: 0);
    expect(r.files, [r'C:\x.pdf', r'C:\w\a.pdf', r'C:\w\b.pdf']);
    expect(r.notes.single, contains('levels down'));
  });

  test('the file limit stops the search', () async {
    final r = await collectLocal(disk, [r'C:\w'], maxFiles: 2);
    expect(r.files.length, 2);
    expect(r.notes.single, contains('Stopped at 2 files'));
  });

  test('the folder limit stops the search', () async {
    final r = await collectLocal(disk, [r'C:\w'], maxFolders: 1);
    expect(r.notes.single, contains('Stopped after 1 folders'));
  });

  test('files that cannot be attached are reported and not counted', () async {
    final r = await collectLocal(
      disk,
      [r'C:\big.pdf', r'C:\x.pdf'],
      maxFiles: 1,
      problemOf: (name, size) => size > 100 ? 'too big' : null,
    );
    expect(r.files, [r'C:\x.pdf']);
    expect(r.skipped.single.reason, 'too big');
    expect(r.notes, isEmpty);
  });

  test('links and other things are skipped with a reason', () async {
    final r = await collectLocal(FakeDisk(disk.tree, disk.sizes, skips: {r'C:\link'}), [r'C:\link', r'C:\missing']);
    expect(r.files, isEmpty);
    expect(r.skipped.length, 2);
  });

  test('a folder listing itself cannot loop', () async {
    final loop = FakeDisk({
      'a': (files: <String>[], folders: ['b']),
      'b': (files: <String>[], folders: ['a']),
    }, {});
    final r = await collectLocal(loop, ['a']);
    expect(r.files, isEmpty);
    expect(r.notes, isEmpty);
  });
}
