import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../domain/proposed_actions.dart';

/// Changes applied from the chat: what was shown, and how to undo it.
class AppliedActions {
  const AppliedActions({required this.lines, required this.undo, this.failure});

  final List<ActionLine> lines;
  final ActionUndo undo;

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

/// Star / mark-done changes the assistant proposed, as a card: each
/// assignment with what would happen to it, and an Apply button. Nothing
/// changes until it is pressed; marking done asks once more.
class ActionsCard extends ConsumerStatefulWidget {
  const ActionsCard({super.key, required this.proposal, required this.source});

  final ActionsProposal proposal;
  final String source;

  @override
  ConsumerState<ActionsCard> createState() => _ActionsCardState();
}

class _ActionsCardState extends ConsumerState<ActionsCard> {
  bool _busy = false;

  Future<void> _setStarred(int id, bool v) => ref.read(assignmentsRepositoryProvider).setStarred(id, v);
  Future<void> _setDone(int id, bool v) => ref.read(assignmentsRepositoryProvider).setDone(id, v);

  Future<void> _apply(List<ActionLine> lines) async {
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
    setState(() => _busy = true);
    final notifier = ref.read(appliedActionsProvider.notifier);
    try {
      final undo = await applyActions(lines, setStarred: _setStarred, setDone: _setDone);
      notifier.mark(widget.source, AppliedActions(lines: lines, undo: undo));
    } on ApplyFailed catch (e) {
      notifier.mark(widget.source, AppliedActions(lines: lines, undo: e.done, failure: 'It stopped part way. What was changed can be undone.'));
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

  static String _effect(ActionLine l) => switch (l.effect) {
        ActionEffect.change => '',
        ActionEffect.same => 'already so',
        ActionEffect.unknown => 'not found, skipped',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final applied = ref.watch(appliedActionsProvider)[widget.source];
    final assignments = ref.watch(assignmentsProvider).value ?? const <Assignment>[];
    final courses = ref.watch(coursesByIdProvider);
    final lines = applied?.lines ?? previewActions(widget.proposal, assignments, courses);
    final changes = lines.where((l) => l.effect == ActionEffect.change).length;
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      _verb(l),
                      style: t.label.copyWith(
                        color: l.effect != ActionEffect.change
                            ? c.textTertiary
                            : (l.kind == ActionKind.done ? c.dueSoon : c.textPrimary),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l.title == null ? 'Assignment #${l.id}' : '${l.title}${l.course == null ? '' : ' · ${l.course}'}',
                      style: l.effect == ActionEffect.change ? t.body : t.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_effect(l).isNotEmpty) ...[const SizedBox(width: 8), Text(_effect(l), style: t.metaMuted)],
                ],
              ),
            ),
          if (lines.length > shown.length)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('and ${lines.length - shown.length} more', style: t.metaMuted)),
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
