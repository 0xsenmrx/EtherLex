import 'files_models.dart';

abstract interface class FilesRepository {
  /// Throws CanvasException with a user-safe message.
  Future<CourseFiles> load(int courseId);

  /// Saves a copy of [file] at [path] (where the student downloads it),
  /// marked as coming from the internet, and returns [path].
  Future<String> saveCopy(FileEntry file, String path);

  /// One file by id (null if it is locked or unreadable).
  Future<FileEntry?> fileInfo(int courseId, int fileId);

  /// Saves the file exactly at [savePath].
  Future<void> fetchTo(FileEntry file, String savePath);

  /// A path on this computer for [file], downloading it only the first time.
  /// Kept on disk, so it opens again without Canvas.
  Future<String> localPath(FileEntry file);

  /// The saved copy if there is one, without any network.
  String? cachedPath(FileEntry file);

  /// The course's file listing as last saved on this computer (null if the
  /// course was never opened), without any network. For searching files.
  Future<CourseFiles?> savedListing(int courseId);

  /// Bytes saved for offline use, per Canvas file id (read off the UI thread).
  Future<Map<int, int>> offlineSizes();

  /// Removes some saved copies, or all of them.
  void removeOffline(Set<int> fileIds);
  void clearOffline();

  /// The most kept for offline use; a lower limit removes the files opened
  /// longest ago.
  void setOfflineLimit(int bytes);
}
