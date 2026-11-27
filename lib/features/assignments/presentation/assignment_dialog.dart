import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../submission/presentation/attachments_section.dart';
import '../../submission/presentation/my_submission_section.dart';
import '../../submission/presentation/submit_section.dart';
import '../domain/assignment.dart';
import 'assignments_providers.dart';

/// The assignment in the shared dialog frame: narrow windows, Calendar, Search.
Future<void> showAssignmentDialog(BuildContext context, int id) => showEtherDialog<void>(
      context,
      (_) => _AssignmentDialog(id: id),
      maxWidth: 640,
      selectable: true,
    );

class _AssignmentDialog extends StatelessWidget {
  const _AssignmentDialog({required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
            child: AssignmentDetail(assignmentId: id),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Spacer(),
                EButton(
                  label: 'Close',
                  kind: EButtonKind.ghost,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Everything about one assignment. Used in the details pane and the dialog.
class AssignmentDetail extends ConsumerWidget {
  const AssignmentDetail({super.key, required this.assignmentId});

  final int assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only this assignment: other changes in the list (a sync filling in)
    // do not rebuild the details.
    final a = ref.watch(
      assignmentsProvider.select((async) {
        for (final x in async.value ?? const <Assignment>[]) {
          if (x.id == assignmentId) return x;
        }
        return null;
      }),
    );
    if (a == null) return const SizedBox.shrink();
    final course = ref.watch(coursesByIdProvider)[a.courseId];
    final actions = ref.read(assignmentActionsProvider);
    final c = context.colors;
    final t = context.text;
    final now = DateTime.now();
    final overdue = a.isOverdue(now);
    final due = a.dueAt;
    final soon = !a.done && !overdue && due != null && due.difference(now).inHours < 24;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 36),
          child: Row(
            children: [
              ESwatch(CoursePalette.colorFor(a.courseId)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  course?.name ?? 'Course',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.meta,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(a.title, style: t.title),
        const SizedBox(height: 18),
        Wrap(
          spacing: 32,
          runSpacing: 12,
          children: [
            _Fact(
              label: 'Due',
              value: due == null ? 'No due date' : formatDueFull(due),
              color: overdue ? c.danger : (soon ? c.dueSoon : null),
            ),
            _Fact(label: 'Points', value: a.points == null ? '–' : '${a.points!.round()}'),
            _Fact(label: 'Status', value: a.done ? 'Done' : (overdue ? 'Overdue' : 'Open')),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            EButton(
              label: a.done ? 'Mark open' : 'Mark done',
              icon: EIcons.check,
              onTap: () => actions.toggleDone(a),
            ),
            EButton(
              label: a.starred ? 'Starred' : 'Star',
              icon: a.starred ? EIcons.starFilled : EIcons.star,
              onTap: () => actions.toggleStar(a),
            ),
          ],
        ),
        AttachmentsSection(assignment: a),
        MySubmissionSection(assignment: a),
        SubmitSection(assignment: a),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: t.caption),
        const SizedBox(height: 5),
        Text(value, style: t.label.copyWith(color: color)),
      ],
    );
  }
}
