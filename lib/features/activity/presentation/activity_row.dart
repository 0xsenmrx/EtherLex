import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../../core/ui/selected_builder.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/new_dot.dart';
import '../../../design_system/theme/fixed_colors.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../courses/domain/course.dart';
import '../domain/activity_feed.dart';
import '../domain/activity_item.dart';

const double kActivityRowExtent = 60;

IconData activityIcon(ActivityKind kind) => switch (kind) {
      ActivityKind.announcement => EIcons.announcement,
      ActivityKind.grade => EIcons.grades,
      ActivityKind.discussion => EIcons.discussion,
      ActivityKind.message => EIcons.message,
      ActivityKind.other => EIcons.bell,
    };

/// Mid-tone colours that read on both themes.
Color activityColor(ActivityKind kind) => switch (kind) {
      ActivityKind.announcement => FixedColors.announcement,
      ActivityKind.grade => FixedColors.grade,
      ActivityKind.discussion => FixedColors.discussion,
      ActivityKind.message => FixedColors.message,
      ActivityKind.other => FixedColors.other,
    };

class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.item,
    required this.course,
    required this.now,
    required this.cursor,
    required this.onOpen,
    this.isNew = false,
  });

  final ActivityItem item;
  final Course? course;
  final DateTime now;

  /// Id of the selected (keyboard cursor) row.
  final ValueListenable<String?> cursor;
  final VoidCallback onOpen;

  /// Arrived since the last look and not opened yet.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final color = activityColor(item.kind);
    final excerpt = activityExcerpt(item.plainBody);
    final courseId = item.courseId;

    return SizedBox(
      height: kActivityRowExtent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ETap(
          focusable: false,
          onTap: onOpen,
          pressedScale: 0.995,
          builder: (context, tapState) => SelectedBuilder<String>(
            cursor: cursor,
            id: item.id,
            builder: (context, selected, child) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.only(left: 10, right: 12),
              decoration: BoxDecoration(
                color: selected ? c.selected : (tapState.hovered ? c.hover : const Color(0x00000000)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: child,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: c.isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(activityIcon(item.kind), size: 15, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isNew) ...[
                            const ENewDot(size: 7),
                            const SizedBox(width: 7),
                          ],
                          Expanded(
                            child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
                          ),
                          const SizedBox(width: 12),
                          Text(formatAgo(item.createdAt, now), style: t.metaMuted),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (courseId != null) ...[
                            ESwatch(CoursePalette.colorFor(courseId), width: 7, height: 10),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                course?.name ?? 'Course',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.meta,
                              ),
                            ),
                            if (excerpt.isNotEmpty) Text('  ·  ', style: t.metaMuted),
                          ],
                          Expanded(
                            child: Text(excerpt, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.metaMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
