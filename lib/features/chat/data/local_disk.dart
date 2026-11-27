import 'dart:io';

import '../domain/local_collect.dart';

/// The real disk for [collectLocal]. Links (and Windows junctions) are never
/// followed, so a folder that points back at its parent cannot loop; hidden
/// items and a few system or tool folders are left out.
class IoLocalDisk implements LocalDisk {
  const IoLocalDisk();

  static const _skipNames = {'node_modules', r'$recycle.bin', 'system volume information', '__pycache__', '__macosx'};

  static bool _left(String path) {
    final name = fileNameOf(path).toLowerCase();
    return name.startsWith('.') || _skipNames.contains(name);
  }

  @override
  Future<LocalKind> kindOf(String path) async {
    try {
      final t = await FileSystemEntity.type(path, followLinks: false);
      if (t == FileSystemEntityType.file) return LocalKind.file;
      if (t == FileSystemEntityType.directory) return _left(path) ? LocalKind.skip : LocalKind.folder;
    } on FileSystemException {
      // falls through
    }
    return LocalKind.skip;
  }

  @override
  Future<int> sizeOf(String file) async {
    try {
      return await File(file).length();
    } on FileSystemException {
      return 0;
    }
  }

  @override
  Future<({List<String> files, List<String> folders})> list(String folder) async {
    final files = <String>[];
    final folders = <String>[];
    try {
      await for (final e in Directory(folder).list(followLinks: false)) {
        if (_left(e.path)) continue;
        if (e is File) {
          files.add(e.path);
        } else if (e is Directory) {
          folders.add(e.path);
        }
      }
    } on FileSystemException {
      // A folder that cannot be opened gives nothing.
    }
    return (files: files, folders: folders);
  }
}
