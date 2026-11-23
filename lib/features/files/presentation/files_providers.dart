import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../settings/presentation/settings_store_provider.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../../courses/domain/course.dart';
import '../data/canvas_files_repository.dart';
import '../data/mock_files_repository.dart';
import '../data/file_cache.dart';
import '../domain/files_models.dart';
import '../domain/offline_usage.dart';
import '../domain/files_repository.dart';

final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  final FilesRepository repo = session == null || session.isSample
      ? MockFilesRepository()
      : CanvasFilesRepository(
          ref.read(canvasClientFactoryProvider)(session.baseUrl, session.token),
          scope: session.scope,
        );
  ref.listen<int>(
    offlineLimitProvider,
    (_, gb) => repo.setOfflineLimit(gb * 1024 * 1024 * 1024),
    fireImmediately: true,
  );
  return repo;
});

/// How many GB this account keeps for offline use (Settings > Files).
class OfflineLimitNotifier extends Notifier<int> {
  @override
  int build() {
    _load(ref.watch(settingsStoreProvider));
    return kDefaultOfflineLimitGb;
  }

  Future<void> _load(SettingsStore store) async {
    try {
      final gb = await store.readOfflineLimitGb();
      if (!ref.mounted || !identical(store, ref.read(settingsStoreProvider))) return;
      if (gb != null && kOfflineLimitsGb.contains(gb)) state = gb;
    } catch (_) {}
  }

  void set(int gb) {
    if (!kOfflineLimitsGb.contains(gb) || gb == state) return;
    state = gb;
    ref.read(settingsStoreProvider).writeOfflineLimitGb(gb).catchError((Object _) {});
  }
}

final offlineLimitProvider = NotifierProvider<OfflineLimitNotifier, int>(OfflineLimitNotifier.new);

/// What the offline folder holds, per course. Read off the UI thread and
/// read again whenever a file is saved or removed.
final offlineUsageProvider = FutureProvider.autoDispose<OfflineUsage>((ref) async {
  void again() => ref.invalidateSelf();
  fileCacheRevision.addListener(again);
  ref.onDispose(() => fileCacheRevision.removeListener(again));
  final repo = ref.watch(filesRepositoryProvider);
  final courses = ref.watch(coursesProvider).value ?? const <Course>[];
  final sizes = await repo.offlineSizes();
  if (sizes.isEmpty) return OfflineUsage.empty;
  final listings = await Future.wait([
    for (final c in courses) repo.savedListing(c.id).then<CourseFiles?>((v) => v, onError: (Object _) => null),
  ]);
  return summarizeOffline(sizes, {
    for (var i = 0; i < courses.length; i++)
      if (listings[i] case final data?) courses[i].id: {for (final f in data.files) f.id},
  });
});

/// Folders + files of one course, loaded when first opened.
final courseFilesProvider = FutureProvider.autoDispose.family<CourseFiles, int>((ref, courseId) async {
  // Kept after leaving the tab so reopening a course is instant; the refresh
  // button invalidates it. Failures are not kept.
  final link = ref.keepAlive();
  try {
    return await ref.watch(filesRepositoryProvider).load(courseId);
  } catch (_) {
    link.close();
    rethrow;
  }
});

/// Folders the user never wants to see (Canvas folder ids are unique per
/// instance, so a plain set is enough). Stored next to the disabled courses.
class HiddenFoldersNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _load(ref.watch(settingsStoreProvider));
    return <int>{};
  }

  Future<void> _load(SettingsStore store) async {
    try {
      final v = await store.readHiddenFolders();
      if (identical(store, ref.read(settingsStoreProvider))) state = v;
    } catch (_) {}
  }

  void _save() {
    ref.read(settingsStoreProvider).writeHiddenFolders(state).catchError((Object _) {});
  }

  void hide(int id) {
    state = {...state, id};
    _save();
  }

  void show(int id) {
    state = {...state}..remove(id);
    _save();
  }
}

final hiddenFoldersProvider =
    NotifierProvider<HiddenFoldersNotifier, Set<int>>(HiddenFoldersNotifier.new);

/// Courses hidden from the Files tab only (separate from the sidebar's
/// Disabled list, which also applies here).
class HiddenFileCoursesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _load(ref.watch(settingsStoreProvider));
    return <int>{};
  }

  Future<void> _load(SettingsStore store) async {
    try {
      final v = await store.readHiddenFileCourses();
      if (identical(store, ref.read(settingsStoreProvider))) state = v;
    } catch (_) {}
  }

  void _save() {
    ref.read(settingsStoreProvider).writeHiddenFileCourses(state).catchError((Object _) {});
  }

  void hide(int id) {
    state = {...state, id};
    _save();
  }

  void show(int id) {
    state = {...state}..remove(id);
    _save();
  }
}

final hiddenFileCoursesProvider =
    NotifierProvider<HiddenFileCoursesNotifier, Set<int>>(HiddenFileCoursesNotifier.new);

/// A file another screen (a link in an announcement) wants the Files tab to
/// show. Files takes it once and clears it.
class FileFocusNotifier extends Notifier<FileEntry?> {
  @override
  FileEntry? build() => null;

  void request(FileEntry file) => state = file;

  void clear() => state = null;
}

final fileFocusProvider = NotifierProvider<FileFocusNotifier, FileEntry?>(FileFocusNotifier.new);

/// A course to open in Files from elsewhere (Ctrl+K): Files shows its root.
class FilesCourseRequestNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void request(int courseId) => state = courseId;

  void clear() => state = null;
}

final filesCourseRequestProvider =
    NotifierProvider<FilesCourseRequestNotifier, int?>(FilesCourseRequestNotifier.new);
