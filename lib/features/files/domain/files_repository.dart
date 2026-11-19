import 'files_models.dart';

abstract interface class FilesRepository {
  /// Throws CanvasException with a user-safe message.
  Future<CourseFiles> load(int courseId);

  /// Saves the file into the Downloads folder and returns its path.
  Future<String> download(FileEntry file);

  /// One file by id (null if it is locked or unreadable).
  Future<FileEntry?> fileInfo(int courseId, int fileId);

  /// Saves the file exactly at [savePath].
  Future<void> fetchTo(FileEntry file, String savePath);

  /// A path on this computer for [file], downloading it only the first time.
  /// Kept on disk, so it opens again without Canvas.
  Future<String> localPath(FileEntry file);

  /// The saved copy if there is one, without any network.
  String? cachedPath(FileEntry file);

  /// Size of everything saved for offline use, and removing it.
  int offlineBytes();
  void clearOffline();
}
