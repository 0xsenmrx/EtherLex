import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../core/notify/toast.dart';
import '../../../core/utils/open_path.dart';
import '../../viewer/domain/preview_kind.dart';
import '../../viewer/presentation/preview_dialog.dart';
import '../domain/files_models.dart';
import 'files_providers.dart';

/// Saves to Downloads with a toast; "Open" on the toast opens the file.
Future<void> downloadWithToast(WidgetRef ref, FileEntry f) async {
  final toast = ref.read(toastProvider.notifier);
  toast.show('Downloading ${f.name}...', duration: const Duration(seconds: 30));
  try {
    final path = await ref.read(filesRepositoryProvider).download(f);
    toast.show(
      'Saved to Downloads',
      actionLabel: isRiskyFile(path) ? 'Show' : 'Open',
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
