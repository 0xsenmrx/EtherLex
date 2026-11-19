import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/link_text.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/open_url.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../auth/domain/auth_provider.dart';
import '../../courses/domain/course.dart';
import '../domain/activity_item.dart';
import 'activity_images.dart';
import 'activity_row.dart';

/// One post in the shared dialog frame: narrow windows and Search.
Future<void> showActivityDialog(BuildContext context, ActivityItem item, Course? course) =>
    showEtherDialog<void>(
      context,
      (context) {
        final c = context.colors;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                child: ActivityDetail(item: item, course: course),
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
      },
      maxWidth: 680,
    );

/// The whole post: text with clickable links, pictures, and a way to Canvas.
class ActivityDetail extends ConsumerWidget {
  const ActivityDetail({super.key, required this.item, required this.course});

  final ActivityItem item;
  final Course? course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final color = activityColor(item.kind);
    final baseHost = Uri.tryParse(ref.read(authProvider).value?.baseUrl ?? '')?.host;
    final link = item.url;
    final canOpen = link != null &&
        baseHost != null &&
        baseHost.isNotEmpty &&
        Uri.tryParse(link)?.host == baseHost;
    final meta = [
      if (course != null) course!.name,
      formatAgo(item.createdAt, DateTime.now()),
    ].join('  ·  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 36),
          child: Row(
            children: [
              Icon(activityIcon(item.kind), size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.meta),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(item.title, style: t.title),
        if (item.body.isNotEmpty) ...[
          const SizedBox(height: 16),
          LinkText(item.body, style: t.bodySecondary.copyWith(height: 1.6)),
        ],
        if (item.images.isNotEmpty) ActivityImages(tokens: item.images),
        if (canOpen) ...[
          const SizedBox(height: 20),
          EButton(
            label: 'Open in Canvas',
            icon: EIcons.externalLink,
            onTap: () => openExternal(link),
          ),
        ],
      ],
    );
  }
}
