import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/menu.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../activity/presentation/activity_providers.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../../grades/presentation/grades_providers.dart';
import '../domain/context_builders.dart';
import '../domain/context_item.dart';
import 'ai_consent.dart';
import 'ai_providers.dart';

/// Makes the item when the student picks it (some need a moment to load).
typedef ContextBuilder = Future<ContextItem?> Function();

/// Asks, once per AI service and account, whether Canvas data may be sent to
/// it. True when it is allowed (now or before). Sample mode has no real
/// service, so it never asks.
Future<bool> ensureConsent(BuildContext context, WidgetRef ref) async {
  final session = ref.read(authProvider).value;
  if (session == null || session.isSample) return true;
  final provider = ref.read(aiSettingsProvider).provider;
  if (ref.read(aiConsentProvider).contains(provider)) return true;
  final ok = await confirmAction(
    context,
    title: 'Send Canvas data to ${provider.label}?',
    message: 'What you attach (assignments, grades, announcements, files or pictures) is sent to '
        '${provider.label} together with your question, using your own API key. '
        'EtherLex sends nothing else, and only when you attach it. '
        'You can take this permission back in Settings.',
    confirmLabel: 'Allow',
  );
  if (ok) ref.read(aiConsentProvider.notifier).grant(provider);
  return ok;
}

/// The "Attach from Canvas" list. Returns what to build, or null.
Future<ContextBuilder?> pickContext(BuildContext context) =>
    showEtherDialog<ContextBuilder>(context, (_) => const _AttachDialog(), maxWidth: 520);

class _AttachDialog extends ConsumerWidget {
  const _AttachDialog();

  Widget _row(BuildContext context, {required IconData icon, required String title, String? subtitle, required ContextBuilder build}) {
    final c = context.colors;
    final t = context.text;
    return ETap(
      onTap: () => Navigator.of(context).pop(build),
      builder: (context, s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: s.hovered ? c.hover : const Color(0x00000000), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) Text(subtitle, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = [...?ref.watch(coursesProvider).value]
      ..sort((a, b) => a.shortLabel.toLowerCase().compareTo(b.shortLabel.toLowerCase()));
    return EDialog(
      title: 'Attach from Canvas',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(
            context,
            icon: EIcons.assignments,
            title: 'Open assignments',
            subtitle: 'Everything not done yet, with due dates',
            build: () async => openAssignmentsContext(
              ref.read(assignmentsProvider).value ?? const [],
              ref.read(coursesByIdProvider),
            ),
          ),
          _row(
            context,
            icon: EIcons.grades,
            title: 'Grades overview',
            subtitle: 'Your current grade in each course',
            build: () async => gradesOverviewContext(
              ref.read(coursesProvider).value ?? const [],
              ref.read(courseGradesProvider),
            ),
          ),
          _row(
            context,
            icon: EIcons.announcement,
            title: 'Recent announcements',
            subtitle: 'The latest ten',
            build: () async => recentAnnouncementsContext(
              ref.read(activityProvider).value ?? const [],
              ref.read(coursesByIdProvider),
            ),
          ),
          if (courses.isNotEmpty) ...[
            const EMenuDivider(),
            const EMenuCaption('Grades of one course'),
            for (final course in courses)
              _row(
                context,
                icon: EIcons.grades,
                title: course.shortLabel,
                subtitle: course.name == course.shortLabel ? null : course.name,
                build: () async {
                  final work = await ref.read(courseWorkProvider(course.id).future);
                  return courseGradesContext(course, ref.read(courseGradesProvider)[course.id], work.items);
                },
              ),
          ],
        ],
      ),
      actions: [EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
    );
  }
}

/// What will be sent with the next message, each with an x to take it off.
class AttachChips extends StatelessWidget {
  const AttachChips({super.key, required this.items, required this.onRemove});

  final List<ContextItem> items;
  final void Function(ContextItem item) onRemove;

  static IconData _icon(ContextKind k) => switch (k) {
        ContextKind.assignments => EIcons.assignments,
        ContextKind.grades => EIcons.grades,
        ContextKind.announcements => EIcons.announcement,
        ContextKind.file => EIcons.fileText,
        ContextKind.image => EIcons.fileImage,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final i in items)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            decoration: BoxDecoration(
              color: c.sunken,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(i.kind), size: 13, color: c.textSecondary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(i.label, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 2),
                EIconButton(
                  icon: EIcons.close,
                  tooltip: 'Remove',
                  size: 20,
                  iconSize: 12,
                  bordered: false,
                  onTap: () => onRemove(i),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
