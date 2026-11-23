import 'dart:io';

import '../../../core/network/canvas_client.dart';
import '../../../core/network/canvas_exception.dart';
import '../../../core/utils/open_path.dart';
import '../domain/files_models.dart';
import '../domain/files_repository.dart';
import 'file_cache.dart';
import 'files_mapper.dart';

class CanvasFilesRepository implements FilesRepository {
  /// [scope] names the account's folder in the offline cache (default: the host).
  CanvasFilesRepository(this._client, {String? scope}) : _cache = FileCache(scope ?? _client.host);
  final CanvasClient _client;
  final FileCache _cache;

  @override
  Future<CourseFiles> load(int courseId) async {
    try {
      final results = await Future.wait([
        _client.fetchFoldersJson(courseId),
        _client.fetchFilesJson(courseId),
      ]);
      final data = CourseFiles(
        folders: [for (final j in results[0]) ?parseFolder(j)],
        files: [for (final j in results[1]) ?parseFile(j, courseId: courseId)],
      );
      _cache.saveIndex(courseId, data);
      return data;
    } on CanvasException catch (e) {
      // Canvas unreachable: show the last listing we saved, if any.
      if (e.kind != CanvasErrorKind.unauthorized && e.kind != CanvasErrorKind.invalidUrl) {
        final saved = _cache.loadIndex(courseId);
        if (saved != null) return saved;
      }
      rethrow;
    }
  }

  @override
  Future<String> localPath(FileEntry file) => _cache.ensure(file, (p) => fetchTo(file, p));

  @override
  String? cachedPath(FileEntry file) => _cache.lookup(file);

  @override
  Future<Map<int, int>> offlineSizes() => _cache.sizesByFileId();

  @override
  void removeOffline(Set<int> fileIds) => _cache.removeFiles(fileIds);

  @override
  void setOfflineLimit(int bytes) => _cache.setLimit(bytes);

  @override
  void clearOffline() => _cache.clear();

  @override
  Future<FileEntry?> fileInfo(int courseId, int fileId) async =>
      parseFile(await _client.fetchFileJson(fileId), courseId: courseId);

  @override
  Future<void> fetchTo(FileEntry file, String savePath) async {
    final url = file.url;
    if (url == null) {
      throw const CanvasException(CanvasErrorKind.unexpected, 'This file has no download link.');
    }
    try {
      await _client.downloadFile(url, savePath);
    } catch (_) {
      try {
        final f = File(savePath);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<CourseFiles?> savedListing(int courseId) async => _cache.loadIndex(courseId);

  @override
  Future<String> saveCopy(FileEntry file, String path) async {
    // Through the cache: a file you download is then also available offline.
    final saved = await localPath(file);
    await File(path).parent.create(recursive: true);
    await File(saved).copy(path); // async: large files must not freeze the window
    await markFromInternet(path);
    return path;
  }
}
