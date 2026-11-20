import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notify/toast.dart';
import '../../../core/utils/open_url.dart';
import '../../auth/domain/auth_provider.dart';
import '../domain/files_models.dart';
import 'files_providers.dart';

/// A link to a Canvas file inside a message: asks Canvas for the file, closes
/// the dialog the link was tapped in, and opens the Files tab on it. A file
/// that is locked, deleted or unreadable gives a message with a way to Canvas.
///
/// [courseId] is null or 0 when the link did not say which course it is in.
Future<void> openFileLink(
  BuildContext context,
  WidgetRef ref, {
  required int? courseId,
  required int fileId,
}) async {
  // Everything needed is taken before waiting: the dialog may close meanwhile.
  final files = ref.read(filesRepositoryProvider);
  final focus = ref.read(fileFocusProvider.notifier);
  final toast = ref.read(toastProvider.notifier);
  final baseUrl = ref.read(authProvider).value?.baseUrl ?? '';
  final router = GoRouter.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  final course = (courseId == null || courseId == 0) ? null : courseId;
  void unavailable() {
    final link = course == null || baseUrl.isEmpty ? null : '$baseUrl/courses/$course/files/$fileId';
    toast.show(
      "That file isn't available.",
      actionLabel: link == null ? null : 'Open in Canvas',
      onAction: link == null ? null : () => openExternal(link),
    );
  }

  if (course == null) {
    unavailable();
    return;
  }
  FileEntry? file;
  try {
    file = await files.fileInfo(course, fileId);
  } catch (_) {}
  if (file == null) {
    unavailable();
    return;
  }
  // Dialogs are popup routes; the page underneath stays.
  navigator.popUntil((route) => route is! PopupRoute);
  focus.request(file);
  router.go('/files');
}
