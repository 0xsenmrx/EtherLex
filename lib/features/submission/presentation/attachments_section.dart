import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notify/toast.dart';
import '../../../core/ui/link_text.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/domain/assignment.dart';
import '../../files/domain/files_models.dart';
import '../../files/presentation/file_actions.dart';
import '../../files/presentation/file_row.dart';
import '../../files/presentation/files_providers.dart';
import '../domain/submission.dart';
import 'submission_providers.dart';

/// The assignment's text and the files attached to it. The rows appear as
/// soon as the text is loaded (names come from its links); sizes and dates
/// fill in when Canvas has answered, and a file is only looked up on click.
class AttachmentsSection extends ConsumerWidget {
  const AttachmentsSection({super.key, required this.assignment});
  final Assignment assignment;

  Future<FileEntry?> _resolve(WidgetRef ref, AttachmentRef a, FileEntry? known) async {
    if (known != null) return known;
    try {
      return await ref.read(filesRepositoryProvider).fileInfo(assignment.courseId, a.fileId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    AttachmentRef a,
    FileEntry? known, {
    required bool download,
  }) async {
    final file = await _resolve(ref, a, known);
    // The dialog may have closed while the file was looked up; ref is gone then.
    if (!context.mounted) return;
    if (file == null) {
      ref.read(toastProvider.notifier).show('This file is not available.');
      return;
    }
    if (download) {
      await downloadWithToast(ref, file);
    } else {
      openFile(context, ref, file);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (courseId: assignment.courseId, assignmentId: assignment.id);
    final info = ref.watch(submissionInfoProvider(key)).value;
    final refs = info?.attachments ?? const <AttachmentRef>[];
    final resolved = {
      for (final f in ref.watch(attachmentsProvider(key)).value ?? const <FileEntry>[]) f.id: f,
    };
    final description = info?.description ?? '';
    if (description.isEmpty && refs.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final t = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: LinkText(description, style: t.bodySecondary.copyWith(height: 1.6)),
          ),
        if (refs.isNotEmpty) ...[
          ESectionLabel('Attachments', trailing: '${refs.length}'),
          for (final a in refs)
            Builder(
              builder: (context) {
                final f = resolved[a.fileId];
                final name = f?.name ?? a.name;
                final visual = fileVisual(name);
                return EntryRow(
                  key: ValueKey('att${a.fileId}'),
                  icon: visual.icon,
                  color: visual.color,
                  title: name,
                  subtitle: f == null ? 'Attachment' : fileSubtitle(f),
                  trailing: f?.updatedAt == null ? '' : formatShortDate(f!.updatedAt!, now),
                  showDownload: true,
                  onTap: () => _run(context, ref, a, f, download: false),
                  onActionTap: () => _run(context, ref, a, f, download: true),
                );
              },
            ),
        ],
      ],
    );
  }
}
