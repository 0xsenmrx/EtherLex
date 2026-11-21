import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../courses/domain/course.dart';
import '../../grades/domain/grade_plan.dart';
import '../../grades/domain/grades.dart';
import '../../grades/domain/plan_proposal.dart';
import '../../grades/presentation/grade_plan_dialog.dart';
import '../../grades/presentation/grades_providers.dart';

/// A plan that was applied from the chat: which course, and the plan before,
/// so Undo can put it back. Kept for the session (and per account).
class AppliedProposal {
  const AppliedProposal({required this.courseId, required this.before});

  final int courseId;
  final GradePlan before;
}

class AppliedProposalsNotifier extends Notifier<Map<String, AppliedProposal>> {
  @override
  Map<String, AppliedProposal> build() {
    ref.watch(settingsStoreProvider); // starts over with the account
    return const {};
  }

  void mark(String key, AppliedProposal a) => state = {...state, key: a};

  void clear(String key) => state = {...state}..remove(key);
}

final appliedProposalsProvider =
    NotifierProvider<AppliedProposalsNotifier, Map<String, AppliedProposal>>(AppliedProposalsNotifier.new);

/// What the assistant proposed, as a card: what would change, and an Apply
/// button. Nothing is changed until the student presses it.
class PlanCard extends ConsumerStatefulWidget {
  const PlanCard({super.key, required this.proposal, required this.source});

  final PlanProposal proposal;

  /// The block's text; also what tells this card's applied state apart from another's.
  final String source;

  @override
  ConsumerState<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<PlanCard> {
  int? _chosen;
  bool _busy = false;

  List<Course> _courses() {
    final disabled = ref.read(disabledCoursesProvider);
    return [
      for (final c in ref.read(coursesProvider).value ?? const <Course>[])
        if (!disabled.contains(c.id)) c,
    ];
  }

  Future<void> _choose() async {
    final courses = [..._courses()]..sort((a, b) => a.shortLabel.toLowerCase().compareTo(b.shortLabel.toLowerCase()));
    final picked = await showEtherDialog<Course>(context, (_) => _CoursePick(courses), maxWidth: 460);
    if (picked != null && mounted) setState(() => _chosen = picked.id);
  }

  Future<void> _apply(int courseId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final work = await ref.read(courseWorkProvider(courseId).future);
      if (!mounted) return;
      final plans = ref.read(gradePlansProvider.notifier);
      final before = ref.read(gradePlansProvider)[courseId] ?? GradePlan.empty;
      final result = applyProposal(before, widget.proposal, work.groups, knownAssignments: {for (final i in work.items) i.id});
      plans.update(courseId, result.plan);
      ref.read(appliedProposalsProvider.notifier).mark(widget.source, AppliedProposal(courseId: courseId, before: before));
    } catch (_) {
      // The card stays as it was; the button can be pressed again.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _undo(AppliedProposal a) {
    ref.read(gradePlansProvider.notifier).update(a.courseId, a.before);
    ref.read(appliedProposalsProvider.notifier).clear(widget.source);
  }

  String _kindText(PlanRow r) => switch (r.kind) {
        PlanRowKind.canvas => 'Canvas category',
        PlanRowKind.own => 'Your category',
        PlanRowKind.created => 'New category',
        PlanRowKind.dropped => 'Not in the plan: set to 0%',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final p = widget.proposal;
    final applied = ref.watch(appliedProposalsProvider)[widget.source];
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final matched = matchCourse(p.course, courses);
    final courseId = applied?.courseId ?? _chosen ?? matched?.id;
    final course = courseId == null ? null : ref.watch(coursesByIdProvider)[courseId];
    final work = courseId == null ? null : ref.watch(courseWorkProvider(courseId)).value;
    final plan = courseId == null ? GradePlan.empty : (ref.watch(gradePlansProvider)[courseId] ?? GradePlan.empty);
    // Before applying, show what it would do; after, what it did (no longer a guess).
    final result = work == null
        ? null
        : applyProposal(applied?.before ?? plan, p, work.groups, knownAssignments: {for (final i in work.items) i.id});
    final rows = result?.rows;
    final moves = result?.moves ?? const <MoveRow>[];
    final titles = {for (final i in work?.items ?? const <GradedItem>[]) i.id: i.title};
    final total = p.weightTotal;

    Widget line(Widget left, Widget right) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [Expanded(child: left), const SizedBox(width: 12), right]),
        );

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
              Icon(EIcons.grades, size: 16, color: c.accent),
              const SizedBox(width: 8),
              Expanded(child: Text('Proposed grade plan', style: t.label)),
              if (course != null) Flexible(child: Text(course.shortLabel, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          if (courseId == null)
            line(
              Text(p.course == null ? 'Which course is this for?' : 'Which course is "${p.course}"?', style: t.meta),
              EButton(label: 'Choose course', onTap: _choose),
            )
          else if (rows == null)
            Text('Matching with the categories of this course…', style: t.meta)
          else
            for (final r in rows)
              line(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(_kindText(r), style: t.metaMuted),
                  ],
                ),
                Text(
                  '${formatPercent(r.weight)}${r.count == null ? '' : ' · ${r.count} items${p.guessed.contains('counts') ? ' (guess)' : ''}'}',
                  style: t.number,
                ),
              ),
          if (moves.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Moves between categories', style: t.label),
            const SizedBox(height: 4),
            for (final m in moves.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${titles[m.assignment] ?? 'Assignment #${m.assignment}'}  →  ${m.category}',
                        style: m.status == MoveStatus.ok ? t.body : t.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (m.status != MoveStatus.ok) ...[
                      const SizedBox(width: 8),
                      Text(
                        m.status == MoveStatus.unknownAssignment ? 'not in this course, skipped' : 'no such category, skipped',
                        style: t.metaMuted,
                      ),
                    ],
                  ],
                ),
              ),
            if (moves.length > 12) Text('and ${moves.length - 12} more', style: t.metaMuted),
          ],
          if (p.curve.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Letter curve${p.guessed.contains('curve') ? ' (a guess, not from your documents)' : ''}: '
              '${[for (final e in p.curve.entries) '${e.key} ${formatPercent(e.value)}'].join(' · ')} of the class',
              style: p.guessed.contains('curve') ? t.meta.copyWith(color: c.dueSoon) : t.meta,
            ),
          ],
          if (p.guessed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Guesses are estimates, not facts. Check them before relying on them.', style: t.meta.copyWith(color: c.dueSoon)),
          ],
          if (p.categories.isNotEmpty && (total - 100).abs() > 0.01) ...[
            const SizedBox(height: 6),
            Text('The weights add up to ${formatPercent(total)}, not 100%. Check the syllabus.', style: t.meta.copyWith(color: c.dueSoon)),
          ],
          if (p.note != null) ...[
            const SizedBox(height: 6),
            Text(p.note!, style: t.metaMuted),
          ],
          const SizedBox(height: 10),
          Container(height: 1, color: c.line),
          const SizedBox(height: 10),
          if (applied == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nothing changes until you press Apply. Assignments stay in the categories Canvas has; move them in the planner.',
                    style: t.metaMuted,
                  ),
                ),
                const SizedBox(width: 12),
                EButton(
                  label: course == null ? 'Apply' : 'Apply to ${course.shortLabel}',
                  icon: EIcons.check,
                  kind: EButtonKind.primary,
                  loading: _busy,
                  onTap: courseId == null || work == null ? null : () => _apply(courseId),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(EIcons.check, size: 15, color: c.success),
                const SizedBox(width: 6),
                Expanded(child: Text('Applied${course == null ? '' : ' to ${course.shortLabel}'}', style: t.label)),
                EButton(label: 'Undo', kind: EButtonKind.ghost, onTap: () => _undo(applied)),
                const SizedBox(width: 8),
                EButton(label: 'Open planner', onTap: () => showGradePlanner(context, applied.courseId)),
              ],
            ),
        ],
      ),
    );
  }
}

class _CoursePick extends StatelessWidget {
  const _CoursePick(this.courses);

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return EDialog(
      title: 'Which course?',
      body: courses.isEmpty
          ? Padding(padding: const EdgeInsets.all(16), child: Text('No courses yet.', style: t.meta))
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final course in courses)
                      ETap(
                        onTap: () => Navigator.of(context).pop(course),
                        builder: (context, s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(color: s.hovered ? c.hover : const Color(0x00000000), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(course.shortLabel, style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (course.name != course.shortLabel) Text(course.name, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      actions: [EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
    );
  }
}
