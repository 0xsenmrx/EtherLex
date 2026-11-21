import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/appearance/appearance.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../courses/domain/course.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../domain/proposed_actions.dart';
import '../domain/proposed_courses.dart';
import '../domain/proposed_settings.dart';
import 'actions_card.dart';

/// The student's real courses with a tick for each one shown in EtherLex. Ticks
/// are only a proposal until Apply is pressed (hiding asks once more); Undo
/// puts it back.
class CoursesCard extends ConsumerStatefulWidget {
  const CoursesCard({super.key, required this.filter, required this.source});

  final CourseListFilter filter;
  final String source;

  @override
  ConsumerState<CoursesCard> createState() => _CoursesCardState();
}

class _CoursesCardState extends ConsumerState<CoursesCard> {
  bool _busy = false;

  /// What the student ticked: course id -> shown.
  final Map<int, bool> _want = {};

  /// The courses listed, fixed when first shown so the list does not jump when one is applied.
  List<Course>? _listed;

  /// The ticks that differ from how things are now, as setting lines.
  List<SettingLine> _lines(List<Course> all, Set<int> disabled) {
    final changes = <SettingChange>[];
    final choices = <int, int>{};
    for (final c in _listed ?? const <Course>[]) {
      final want = _want[c.id];
      if (want == null || want == !disabled.contains(c.id)) continue;
      choices[changes.length] = c.id;
      changes.add(SettingChange(kind: SettingKind.course, text: c.name, flag: want));
    }
    return previewSettings(
      changes,
      SettingsSnapshot(
        theme: ref.read(appearanceProvider).theme,
        typeface: ref.read(appearanceProvider).typeface,
        notifications: ref.read(notificationsProvider),
        disabledCourses: disabled,
        courses: all,
      ),
      courseChoices: choices,
    );
  }

  Future<void> _apply(List<SettingLine> lines) async {
    if (_busy) return;
    final hide = lines.where((l) => l.effect == SettingEffect.change && l.flag == false).length;
    if (hide > 0) {
      final ok = await confirmAction(
        context,
        title: 'Hide $hide ${hide == 1 ? 'course' : 'courses'}?',
        message: 'A hidden course leaves every list and count in EtherLex. Nothing changes in Canvas. '
            'You can undo it right after, or turn it back on in Settings.',
        confirmLabel: 'Hide',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final target = AppTarget(ref, context);
    final notifier = ref.read(appliedActionsProvider.notifier);
    try {
      final undo = applySettings(lines, target);
      notifier.mark(widget.source, AppliedActions(lines: const [], undo: {ActionKind.star: {}, ActionKind.done: {}}, settingLines: lines, settingsUndo: undo));
      _want.clear();
    } on SettingsApplyFailed catch (e) {
      notifier.mark(
        widget.source,
        AppliedActions(
          lines: const [],
          undo: {ActionKind.star: {}, ActionKind.done: {}},
          settingLines: lines,
          settingsUndo: e.done,
          failure: 'It stopped part way. What was changed can be undone.',
        ),
      );
    } catch (_) {
      // Nothing was changed; the button can be pressed again.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo(AppliedActions a) async {
    if (_busy || a.settingsUndo == null) return;
    setState(() => _busy = true);
    final target = AppTarget(ref, context);
    try {
      undoSettings(a.settingsUndo!, target);
      ref.read(appliedActionsProvider.notifier).clear(widget.source);
    } catch (_) {
      // Leave the card as it is so Undo can be tried again.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final all = ref.watch(coursesProvider).value ?? const <Course>[];
    final disabled = ref.watch(disabledCoursesProvider);
    final applied = ref.watch(appliedActionsProvider)[widget.source];
    _listed ??= [
      for (final course in [...all]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
        if (switch (widget.filter) {
          CourseListFilter.all => true,
          CourseListFilter.hidden => disabled.contains(course.id),
          CourseListFilter.shown => !disabled.contains(course.id),
        })
          course,
    ];
    final listed = _listed!;
    final lines = applied == null ? _lines(all, disabled) : const <SettingLine>[];
    final changes = lines.where((l) => l.effect == SettingEffect.change).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(EIcons.sparkles, size: 16, color: c.accent),
              const SizedBox(width: 8),
              Expanded(child: Text('Your courses', style: t.label)),
              Text('ticked = shown in EtherLex', style: t.metaMuted),
            ],
          ),
          const SizedBox(height: 6),
          if (listed.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('No courses here.', style: t.meta))
          else
            for (final course in listed)
              Row(
                children: [
                  ECheck(
                    checked: applied == null ? (_want[course.id] ?? !disabled.contains(course.id)) : !disabled.contains(course.id),
                    onTap: applied != null ? () {} : () => setState(() => _want[course.id] = !(_want[course.id] ?? !disabled.contains(course.id))),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      course.name,
                      style: (disabled.contains(course.id) ? t.meta : t.body),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (course.code.isNotEmpty && course.code != course.name) ...[const SizedBox(width: 8), Text(course.code, style: t.metaMuted)],
                ],
              ),
          const SizedBox(height: 8),
          Container(height: 1, color: c.line),
          const SizedBox(height: 10),
          if (applied == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    changes == 0 ? 'Tick or untick courses, then press Apply.' : 'Nothing changes until you press Apply.',
                    style: t.metaMuted,
                  ),
                ),
                const SizedBox(width: 12),
                EButton(
                  label: changes == 1 ? 'Apply 1 change' : 'Apply $changes changes',
                  icon: EIcons.check,
                  kind: EButtonKind.primary,
                  loading: _busy,
                  onTap: changes == 0 ? null : () => _apply(lines),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(EIcons.check, size: 15, color: c.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    applied.failure ??
                        'Applied ${applied.settingLines.length} ${applied.settingLines.length == 1 ? 'change' : 'changes'}',
                    style: t.label,
                  ),
                ),
                EButton(label: 'Undo', kind: EButtonKind.ghost, loading: _busy, onTap: () => _undo(applied)),
              ],
            ),
        ],
      ),
    );
  }
}
