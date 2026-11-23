import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../core/notify/toast.dart';
import '../../../core/storage/app_dir.dart';
import '../../../core/utils/open_path.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../domain/download_prefs.dart';
import '../../viewer/domain/preview_kind.dart';
import '../../viewer/presentation/preview_dialog.dart';
import '../domain/files_models.dart';
import 'files_providers.dart';

/// Where a download of [f] goes, following Settings > Files & downloads:
/// the chosen folder or Windows Downloads (with a course subfolder if asked),
/// or a Save dialog. Null when the student cancelled or picked a folder
/// EtherLex must not write into.
Future<String?> downloadTarget(WidgetRef ref, FileEntry f) async {
  final prefs = ref.read(downloadPrefsProvider);
  final windows = await ref.read(windowsDownloadsProvider.future);
  final course = ref.read(coursesByIdProvider)[f.courseId];
  final dir = downloadDirectory(prefs, windowsDownloads: windows, courseName: course?.name, sep: Platform.pathSeparator);
  final name = sanitizeFileName(f.name);
  if (prefs.askEachTime) {
    final where = await getSaveLocation(suggestedName: name, initialDirectory: dir);
    if (where == null) return null;
    if (!isAllowedDownloadDir(File(where.path).parent.path, appData: appDataPath())) {
      ref.read(toastProvider.notifier).show("That folder belongs to EtherLex itself. Choose another one.");
      return null;
    }
    return where.path;
  }
  if (!isAllowedDownloadDir(dir, appData: appDataPath())) {
    ref.read(toastProvider.notifier).show('The downloads folder in Settings is not allowed. Choose another one.');
    return null;
  }
  return uniquePath(dir, name);
}

/// Downloads [f] where Settings says, with a toast; "Open" on the toast opens
/// the file (programs and web pages: "Show").
Future<void> downloadWithToast(WidgetRef ref, FileEntry f) async {
  final toast = ref.read(toastProvider.notifier);
  final String? target;
  try {
    target = await downloadTarget(ref, f);
  } catch (_) {
    toast.show('Could not choose where to save. Please try again.');
    return;
  }
  if (target == null) return;
  toast.show('Downloading ${f.name}...', duration: const Duration(seconds: 30));
  try {
    final path = await ref.read(filesRepositoryProvider).saveCopy(f, target);
    final folder = File(path).parent.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? 'your folder';
    toast.show(
      'Saved to $folder',
      actionLabel: openSafetyOf(path) == OpenSafety.open ? 'Open' : 'Show',
      onAction: () => openDownloaded(path),
      duration: const Duration(seconds: 6),
    );
  } on CanvasException catch (e) {
    toast.show(e.message);
  } catch (_) {
    toast.show('Download failed. Please try again.');
  }
}

/// Previewable files open in the built-in viewer; others are downloaded.
void openFile(BuildContext context, WidgetRef ref, FileEntry f) {
  if (previewKindFor(f.name) == PreviewKind.none) {
    downloadWithToast(ref, f);
  } else {
    showFilePreview(context, f);
  }
}

bool _saving = false;
bool _stopSaving = false;

/// Saves [files] on this computer so they open without Canvas, three at a time.
Future<void> saveOffline(WidgetRef ref, List<FileEntry> files) async {
  final toast = ref.read(toastProvider.notifier);
  final repo = ref.read(filesRepositoryProvider);
  if (_saving) {
    toast.show('Already saving files. Press Stop on the progress message to cancel.');
    return;
  }
  final todo = [for (final f in files) if (repo.cachedPath(f) == null) f];
  if (todo.isEmpty) {
    toast.show(files.isEmpty ? 'No files here.' : 'Everything here is already saved offline.');
    return;
  }
  _saving = true;
  _stopSaving = false;
  var done = 0, failed = 0;
  var next = 0;
  void progress() => toast.show(
        'Saving ${done + failed} of ${todo.length} for offline...',
        actionLabel: 'Stop',
        onAction: () => _stopSaving = true,
        duration: const Duration(minutes: 10),
      );
  progress();
  Future<void> worker() async {
    while (next < todo.length && !_stopSaving) {
      final f = todo[next++];
      try {
        await repo.localPath(f);
        done++;
      } catch (_) {
        failed++;
      }
      if (!_stopSaving) progress();
    }
  }

  await Future.wait([for (var i = 0; i < 3; i++) worker()]);
  final stopped = _stopSaving;
  _saving = false;
  _stopSaving = false;
  toast.show(
    stopped
        ? 'Stopped. Saved $done file${done == 1 ? '' : 's'} for offline use'
        : failed == 0
        ? 'Saved $done file${done == 1 ? '' : 's'} for offline use'
        : 'Saved $done, $failed failed. Try again later.',
    duration: const Duration(seconds: 6),
  );
}
