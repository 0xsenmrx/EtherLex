import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../../core/ui/selected_builder.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../courses/domain/course.dart';
import '../domain/assignment.dart';

const double kRowExtent = 52;
const double kHeaderExtent = EGroupHeader.extent;

/// Widths of the right-hand columns, shared with the column header.
const double kPointsColumn = 64;
const double kDueColumn = 112;
const double kStarColumn = 34;

class AssignmentRow extends StatelessWidget {
  const AssignmentRow({
    super.key,
    required this.assignment,
    required this.course,
    required this.cursor,
    required this.now,
    required this.onOpen,
    required this.onToggleDone,
    required this.onToggleStar,
    this.showPoints = true,
  });

  final Assignment assignment;
  final Course? course;

  /// Id of the selected (keyboard cursor) row.
  final ValueListenable<int?> cursor;
  final DateTime now;
  final VoidCallback onOpen;
  final VoidCallback onToggleDone;
  final VoidCallback onToggleStar;
  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final course = this.course; // a local, so a null check promotes it
    final c = context.colors;
    final t = context.text;
    final overdue = a.isOverdue(now);
    final due = a.dueAt;
    final soon = !a.done && !overdue && due != null && due.difference(now).inHours < 24;
    final dueColor = a.done
        ? c.textTertiary
        : (overdue ? c.danger : (soon ? c.dueSoon : c.textSecondary));

    return SizedBox(
      height: kRowExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ETap(
          focusable: false,
          onTap: onOpen,
          pressedScale: 0.995,
          builder: (context, tapState) => SelectedBuilder<int>(
            cursor: cursor,
            id: a.id,
            builder: (context, selected, _) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.only(left: 4, right: 2),
                decoration: BoxDecoration(
                  color: selected ? c.selected : (tapState.hovered ? c.hover : const Color(0x00000000)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    ECheck(checked: a.done, onTap: onToggleDone),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.label.copyWith(
                              color: a.done ? c.textTertiary : c.textPrimary,
                              decoration: a.done ? TextDecoration.lineThrough : TextDecoration.none,
                              decorationColor: c.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              ESwatch(CoursePalette.colorFor(a.courseId), width: 7, height: 10, dim: a.done),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  a.isPersonal
                                      ? (course == null ? 'Personal task' : '${course.name} · personal')
                                      : (course?.name ?? 'Course'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.metaMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (showPoints)
                      SizedBox(
                        width: kPointsColumn,
                        child: Text(
                          a.points == null ? '' : '${a.points!.round()} pts',
                          textAlign: TextAlign.right,
                          style: t.metaMuted,
                        ),
                      ),
                    SizedBox(
                      width: kDueColumn,
                      child: Text(
                        formatDue(a.dueAt, now),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: t.number.copyWith(color: dueColor),
                      ),
                    ),
                    SizedBox(
                      width: kStarColumn,
                      child: EStar(
                        starred: a.starred,
                        visible: tapState.hovered || selected,
                        onTap: onToggleStar,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Oleafly-style column titles above the list.
class AssignmentColumns extends StatelessWidget {
  const AssignmentColumns({super.key, required this.showPoints});
  final bool showPoints;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 16, right: 2),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(child: Text('ASSIGNMENT', style: t.caption)),
          if (showPoints)
            SizedBox(
              width: kPointsColumn,
              child: Text('POINTS', textAlign: TextAlign.right, style: t.caption),
            ),
          SizedBox(width: kDueColumn, child: Text('DUE', textAlign: TextAlign.right, style: t.caption)),
          const SizedBox(width: kStarColumn),
        ],
      ),
    );
  }
}
