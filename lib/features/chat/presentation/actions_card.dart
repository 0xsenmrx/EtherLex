import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/appearance/appearance.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../courses/domain/course.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../domain/proposed_actions.dart';
import '../domain/proposed_settings.dart';

/// Changes applied from the chat: what was shown, and how to undo it.
class AppliedActions {
  const AppliedActions({
    required this.lines,
    required this.undo,
    this.settingLines = const [],
    this.settingsUndo,
    this.failure,
  });

  final List<ActionLine> lines;
  final ActionUndo undo;
  final List<SettingLine> settingLines;
  final SettingsUndo? settingsUndo;

  /// Set when it stopped half way.
  final String? failure;
}

class AppliedActionsNotifier extends Notifier<Map<String, AppliedActions>> {
  @override
  Map<String, AppliedActions> build() {
    ref.watch(settingsStoreProvider); // starts over with the account
    return const {};
  }

  void mark(String key, AppliedActions a) => state = {...state, key: a};

  void clear(String key) => state = {...state}..remove(key);
}

final appliedActionsProvider =
    NotifierProvider<AppliedActionsNotifier, Map<String, AppliedActions>>(AppliedActionsNotifier.new);

/// Changes the assistant proposed (starring, marking done, app settings,
/// opening a page), as a card: each with what would happen, and an Apply
/// button. Nothing changes until it is pressed; marking done and hiding
/// courses ask once more.
class ActionsCard extends ConsumerStatefulWidget {
  const ActionsCard({super.key, required this.proposal, required this.source});

  final ActionsProposal proposal;
  final String source;

  @override
  ConsumerState<ActionsCard> createState() => _ActionsCardState();
}

class _AppTarget implements SettingsTarget {
  _AppTarget(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  @override
  void setTheme(String name) => ref.read(appearanceProvider.notifier).setTheme(ThemeChoice.values.firstWhere((t) => t.name == name));

  @override
  void setFont(String name) => ref.read(appearanceProvider.notifier).setTypeface(TypefaceChoice.values.firstWhere((t) => t.name == name));

  @override
  void setNotifications(bool on) {
    if (ref.read(notificationsProvider) != on) ref.read(notificationsProvider.notifier).toggle();
  }

  @override
  void setCourseShown(int courseId, bool shown) {
    final courses = ref.read(disabledCoursesProvider.notifier);
    shown ? courses.enable(courseId) : courses.disable(courseId);
  }

  @override
  void open(String page) {
    if (context.mounted) GoRouter.of(context).go('/$page');
  }
}

class _ActionsCardState extends ConsumerState<ActionsCard> {
  bool _busy = false;

  Future<void> _setStarred(int id, bool v) => ref.read(assignmentsRepositoryProvider).setStarred(id, v);
  Future<void> _setDone(int id, bool v) => ref.read(assignmentsRepositoryProvider).setDone(id, v);

  SettingsSnapshot _snapshot() => SettingsSnapshot(
        theme: ref.read(appearanceProvider).theme,
        typeface: ref.read(appearanceProvider).typeface,
        notifications: ref.read(notificationsProvider),
        disabledCourses: ref.read(disabledCoursesProvider),
        courses: ref.read(coursesProvider).value ?? const <Course>[],
      );

  Future<void> _apply(List<ActionLine> lines, List<SettingLine> settings) async {
    if (_busy) return;
    final doneCount = lines.where((l) => l.effect == ActionEffect.change && l.kind == ActionKind.done).length;
    if (doneCount > 0) {
      final ok = await confirmAction(
        context,
        title: 'Mark $doneCount ${doneCount == 1 ? 'assignment' : 'assignments'} as done?',
        message: 'This only changes EtherLex: nothing is submitted to Canvas, and your teacher sees nothing. '
            'You can undo it right after.',
        confirmLabel: 'Mark as done',
      );
      if (!ok || !mounted) return;
    }
    final hideCount = settings.where((l) => l.effect == SettingEffect.change && l.kind == SettingKind.course && l.flag == false).length;
    if (hideCount > 0) {
      final ok = await confirmAction(
        context,
        title: 'Hide $hideCount ${hideCount == 1 ? 'course' : 'courses'}?',
        message: 'A hidden course leaves every list and count in EtherLex. Nothing changes in Canvas. '
            'You can undo it right after, or turn it back on in Settings.',
        confirmLabel: 'Hide',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final notifier = ref.read(appliedActionsProvider.notifier);
    ActionUndo undo = {ActionKind.star: {}, ActionKind.done: {}};
    try {
      undo = await applyActions(lines, setStarred: _setStarred, setDone: _setDone);
      final settingsUndo = applySettings(settings, _AppTarget(ref, context));
      notifier.mark(widget.source, AppliedActions(lines: lines, undo: undo, settingLines: settings, settingsUndo: settingsUndo));
    } on ApplyFailed catch (e) {
      notifier.mark(widget.source, AppliedActions(lines: lines, undo: e.done, failure: 'It stopped part way. What was changed can be undone.'));
    } on SettingsApplyFailed catch (e) {
      notifier.mark(
        widget.source,
        AppliedActions(lines: lines, undo: undo, settingLines: settings, settingsUndo: e.done, failure: 'It stopped part way. What was changed can be undone.'),
      );
    } catch (_) {
      // Nothing was changed; the button can be pressed again.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo(AppliedActions a) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await undoActions(a.undo, setStarred: _setStarred, setDone: _setDone);
      if (a.settingsUndo != null) undoSettings(a.settingsUndo!, _AppTarget(ref, context));
      ref.read(appliedActionsProvider.notifier).clear(widget.source);
    } catch (_) {
      // Leave the card as it is so Undo can be tried again.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _verb(ActionLine l) => switch (l.kind) {
        ActionKind.star => l.value ? 'Star' : 'Unstar',
        ActionKind.done => l.value ? 'Mark done' : 'Mark not done',
      };

  static String _effect(ActionEffect e) => switch (e) {
        ActionEffect.change => '',
        ActionEffect.same => 'already so',
        ActionEffect.unknown => 'not found, skipped',
      };

  static String _settingEffect(SettingEffect e) => switch (e) {
        SettingEffect.change => '',
        SettingEffect.same => 'already so',
        SettingEffect.unknown => 'no single course matches, skipped',
      };

  Widget _row(BuildContext context, {required String verb, required Color verbColor, required String what, required bool active, required String note}) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(verb, style: t.label.copyWith(color: verbColor))),
          Expanded(child: Text(what, style: active ? t.body : t.meta, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (note.isNotEmpty) ...[const SizedBox(width: 8), Text(note, style: t.metaMuted)],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final applied = ref.watch(appliedActionsProvider)[widget.source];
    final assignments = ref.watch(assignmentsProvider).value ?? const <Assignment>[];
    final courses = ref.watch(coursesByIdProvider);
    final appearance = ref.watch(appearanceProvider);
    final snapshot = SettingsSnapshot(
      theme: appearance.theme,
      typeface: appearance.typeface,
      notifications: ref.watch(notificationsProvider),
      disabledCourses: ref.watch(disabledCoursesProvider),
      courses: courses.values.toList(),
    );
    final lines = applied?.lines ?? previewActions(widget.proposal, assignments, courses);
    final settings = applied == null ? previewSettings(widget.proposal.settings, snapshot) : applied.settingLines;
    final changes = lines.where((l) => l.effect == ActionEffect.change).length +
        settings.where((l) => l.effect == SettingEffect.change).length;
    final hasDone = lines.any((l) => l.kind == ActionKind.done && l.effect == ActionEffect.change);
    final shown = lines.take(30).toList();

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
              Expanded(child: Text(applied == null ? 'Proposed changes' : 'Changes', style: t.label)),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in shown)
            _row(
              context,
              verb: _verb(l),
              verbColor: l.effect != ActionEffect.change ? c.textTertiary : (l.kind == ActionKind.done ? c.dueSoon : c.textPrimary),
              what: l.title == null ? 'Assignment #${l.id}' : '${l.title}${l.course == null ? '' : ' · ${l.course}'}',
              active: l.effect == ActionEffect.change,
              note: _effect(l.effect),
            ),
          if (lines.length > shown.length)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('and ${lines.length - shown.length} more', style: t.metaMuted)),
          for (final l in settings)
            _row(
              context,
              verb: l.label,
              verbColor: l.effect != SettingEffect.change
                  ? c.textTertiary
                  : (l.kind == SettingKind.course && l.flag == false ? c.dueSoon : c.textPrimary),
              what: l.detail,
              active: l.effect == SettingEffect.change,
              note: _settingEffect(l.effect),
            ),
          if (widget.proposal.note != null) ...[
            const SizedBox(height: 6),
            Text(widget.proposal.note!, style: t.metaMuted),
          ],
          if (applied == null && hasDone) ...[
            const SizedBox(height: 8),
            Text(
              'Marking done only changes EtherLex. Nothing is submitted to Canvas.',
              style: t.meta.copyWith(color: c.dueSoon),
            ),
          ],
          const SizedBox(height: 10),
          Container(height: 1, color: c.line),
          const SizedBox(height: 10),
          if (applied == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    changes == 0 ? 'Nothing here would change anything.' : 'Nothing changes until you press Apply.',
                    style: t.metaMuted,
                  ),
                ),
                const SizedBox(width: 12),
                EButton(
                  label: changes == 1 ? 'Apply 1 change' : 'Apply $changes changes',
                  icon: EIcons.check,
                  kind: EButtonKind.primary,
                  loading: _busy,
                  onTap: changes == 0 ? null : () => _apply(lines, previewSettings(widget.proposal.settings, _snapshot())),
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
                    applied.failure ?? 'Applied $changes ${changes == 1 ? 'change' : 'changes'}',
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
