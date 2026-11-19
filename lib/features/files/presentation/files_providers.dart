import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../data/canvas_files_repository.dart';
import '../data/mock_files_repository.dart';
import '../domain/files_models.dart';
import '../domain/files_repository.dart';

final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  if (session == null || session.isSample) return MockFilesRepository();
  return CanvasFilesRepository(
    ref.read(canvasClientFactoryProvider)(session.baseUrl, session.token),
  );
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
