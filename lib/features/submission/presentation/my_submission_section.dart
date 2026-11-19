import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/link_text.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/domain/assignment.dart';
import '../../files/domain/files_models.dart';
import '../../files/presentation/file_actions.dart';
import '../../files/presentation/file_row.dart';
import 'submission_providers.dart';

/// Your grade, what you turned in, and the teacher's feedback (with any files
/// sent back). Shows nothing until there is something.
class MySubmissionSection extends ConsumerWidget {
  const MySubmissionSection({super.key, required this.assignment});
  final Assignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(
      mySubmissionProvider((courseId: assignment.courseId, assignmentId: assignment.id)),
    ).value;
    if (mine == null || !mine.hasContent) return const SizedBox.shrink();
    final now = DateTime.now();
    final c = context.colors;
    final t = context.text;

    Widget rows(List<FileEntry> files) => Column(
          children: [
            for (final f in files)
              Builder(builder: (context) {
                final visual = fileVisual(f.name);
                return EntryRow(
                  key: ValueKey('sub${f.id}'),
                  icon: visual.icon,
                  color: visual.color,
                  title: f.name,
                  subtitle: fileSubtitle(f),
                  trailing: f.updatedAt == null ? '' : formatShortDate(f.updatedAt!, now),
                  showDownload: true,
                  onTap: () => openFile(context, ref, f),
                  onActionTap: () => downloadWithToast(ref, f),
                );
              }),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mine.hasGrade) ...[
          const ESectionLabel('Your grade'),
          Text(mine.gradeText(assignment.points), style: t.title.copyWith(color: c.accent)),
        ],
        if (mine.files.isNotEmpty) ...[
          ESectionLabel(
            'Your submission',
            trailing: mine.submittedAt == null ? null : formatDueFull(mine.submittedAt!),
          ),
          rows(mine.files),
        ],
        if (mine.feedback.isNotEmpty) ...[
          const ESectionLabel('Feedback'),
          for (final f in mine.feedback)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: c.sunken,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [f.author, if (f.at != null) formatAgo(f.at!, now)].join('  ·  '),
                    style: t.meta,
                  ),
                  if (f.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    LinkText(f.text, style: t.body.copyWith(height: 1.55)),
                  ],
                  if (f.files.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    rows(f.files),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}
