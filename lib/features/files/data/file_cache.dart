import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../../core/storage/account_scope.dart';
import '../../../core/storage/app_dir.dart';
import '../../../core/utils/open_path.dart';
import '../domain/files_models.dart';

/// Bumped whenever a file is added to or removed from any cache, so lists can
/// refresh their "Offline" labels.
final ValueNotifier<int> fileCacheRevision = ValueNotifier<int>(0);

/// Files and file listings kept on this computer so they open without
/// Canvas. One folder per account ([scope]), least recently opened files are
/// dropped when it grows past [maxBytes].
class FileCache {
  FileCache(String scope, {String? root, this.maxBytes = 3 * 1024 * 1024 * 1024})
      : _root = root ?? appDataPath(),
        scope = cleanScope(scope);

  final String scope;

  /// The most kept before the least recently opened files go; see [setLimit].
  int maxBytes;
  final String _root;

  static final String _sep = Platform.pathSeparator;

  Directory get _files => Directory('$_root${_sep}files$_sep$scope');
  Directory get _index => Directory('$_root${_sep}file_index$_sep$scope');

  String _target(FileEntry f) {
    final version = f.updatedAt?.millisecondsSinceEpoch ?? f.size;
    return '${_files.path}$_sep${f.id}_${version}_${sanitizeFileName(f.name)}';
  }

  bool _valid(File file, FileEntry f) {
    if (!file.existsSync()) return false;
    final len = file.lengthSync();
    return len > 0 && (f.size <= 0 || len == f.size);
  }

  /// The saved copy of [f], if there is one (and it is the current version).
  String? lookup(FileEntry f) {
    final path = _target(f);
    return _valid(File(path), f) ? path : null;
  }

  /// A local path for [f]: the saved copy, or [fetch] it first. Fetching
  /// writes to a temporary name, so an interrupted download never looks saved.
  Future<String> ensure(FileEntry f, Future<void> Function(String savePath) fetch) {
    // Opening and downloading the same file at once must not write the same
    // temporary file twice: share the one download.
    final key = _target(f);
    final running = _inFlight[key];
    if (running != null) return running;
    // Block body on purpose: remove() returns this very future, and
    // whenComplete would wait for it, i.e. for itself, forever.
    final future = _ensure(f, fetch).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  static final Map<String, Future<String>> _inFlight = {};

  Future<String> _ensure(FileEntry f, Future<void> Function(String savePath) fetch) async {
    final hit = lookup(f);
    if (hit != null) {
      try {
        File(hit).setLastModifiedSync(DateTime.now()); // recently used
      } catch (_) {}
      return hit;
    }
    _files.createSync(recursive: true);
    final target = _target(f);
    final tmp = '$target.part';
    await fetch(tmp);
    final part = File(tmp);
    if (!part.existsSync()) {
      throw const FileSystemException('The download did not produce a file.');
    }
    final dest = File(target);
    if (dest.existsSync()) dest.deleteSync();
    part.renameSync(target);
    await markFromInternet(target);
    _dropOtherVersions(f, keep: target);
    prune();
    fileCacheRevision.value++;
    return target;
  }

  void _dropOtherVersions(FileEntry f, {required String keep}) {
    try {
      for (final e in _files.listSync()) {
        final name = e.uri.pathSegments.last;
        if (e.path != keep && name.startsWith('${f.id}_') && e is File) e.deleteSync();
      }
    } catch (_) {}
  }

  List<File> _saved() {
    if (!_files.existsSync()) return const [];
    return [
      for (final e in _files.listSync())
        if (e is File && !e.path.endsWith('.part')) e,
    ];
  }

  int sizeBytes() {
    var total = 0;
    for (final f in _saved()) {
      try {
        total += f.lengthSync();
      } catch (_) {}
    }
    return total;
  }

  int count() => _saved().length;

  /// Deletes the least recently opened files until the cache fits.
  void prune() {
    try {
      final files = _saved();
      var total = 0;
      final sized = <(File, int, DateTime)>[];
      for (final f in files) {
        final st = f.statSync();
        total += st.size;
        sized.add((f, st.size, st.modified));
      }
      if (total <= maxBytes) return;
      sized.sort((a, b) => a.$3.compareTo(b.$3));
      for (final (f, size, _) in sized) {
        if (total <= maxBytes) break;
        f.deleteSync();
        total -= size;
      }
    } catch (_) {}
  }

  /// A new [maxBytes]; a lower one removes files at once (oldest first).
  void setLimit(int bytes) {
    if (bytes <= 0 || bytes == maxBytes) return;
    final shrinking = bytes < maxBytes;
    maxBytes = bytes;
    if (shrinking) {
      prune();
      fileCacheRevision.value++;
    }
  }

  /// Bytes per Canvas file id, read in a background isolate so a big cache
  /// never stalls a frame.
  Future<Map<int, int>> sizesByFileId() {
    final path = _files.path;
    return Isolate.run(() => scanCacheSizes(path));
  }

  /// Removes the saved copies of these Canvas files.
  void removeFiles(Set<int> fileIds) {
    if (fileIds.isEmpty) return;
    try {
      for (final f in _saved()) {
        final id = cacheFileId(f.uri.pathSegments.last);
        if (id != null && fileIds.contains(id)) f.deleteSync();
      }
    } catch (_) {}
    fileCacheRevision.value++;
  }

  void clear() {
    try {
      if (_files.existsSync()) _files.deleteSync(recursive: true);
    } catch (_) {}
    fileCacheRevision.value++;
  }

  // ------------------------------------------------------------ listings

  File _indexFile(int courseId) => File('${_index.path}$_sep$courseId.json');

  void saveIndex(int courseId, CourseFiles data) {
    try {
      _index.createSync(recursive: true);
      _indexFile(courseId).writeAsStringSync(jsonEncode(data.toJson()));
    } catch (_) {}
  }

  CourseFiles? loadIndex(int courseId) {
    try {
      final f = _indexFile(courseId);
      if (!f.existsSync()) return null;
      return CourseFiles.fromJson(jsonDecode(f.readAsStringSync()))?.asCached();
    } catch (_) {
      return null;
    }
  }
}

/// The Canvas file id at the start of a cached file's name (`<id>_<version>_<name>`).
int? cacheFileId(String fileName) {
  final cut = fileName.indexOf('_');
  return cut <= 0 ? null : int.tryParse(fileName.substring(0, cut));
}

/// Bytes per file id in the cache folder at [path] (partial downloads left
/// out). Plain function so it can run in an isolate.
Map<int, int> scanCacheSizes(String path) {
  final out = <int, int>{};
  final dir = Directory(path);
  if (!dir.existsSync()) return out;
  for (final e in dir.listSync()) {
    if (e is! File || e.path.endsWith('.part')) continue;
    final id = cacheFileId(e.uri.pathSegments.last);
    if (id == null) continue;
    try {
      out[id] = (out[id] ?? 0) + e.lengthSync();
    } catch (_) {}
  }
  return out;
}
