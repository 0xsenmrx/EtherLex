import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/components/compact_field.dart';
import '../../../design_system/components/pressable.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../domain/grade_calc.dart';
import '../domain/grade_plan.dart';
import '../domain/grades.dart';
import 'grades_providers.dart';

/// Opens the planner in the shared dialog frame.
Future<void> showGradePlanner(BuildContext context, int courseId) => showEtherDialog<void>(
      context,
      (_) => GradePlanDialog(courseId: courseId),
      maxWidth: 800,
    );

/// Real grade from your own category weights, and a letter guess from the
/// class statistics and the teacher's letter quotas.
class GradePlanDialog extends ConsumerWidget {
  const GradePlanDialog({super.key, required this.courseId});
  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(coursesByIdProvider)[courseId];
    final work = ref.watch(courseWorkProvider(courseId)).value;
    final plan = ref.watch(gradePlansProvider.select((m) => m[courseId])) ?? GradePlan.empty;
    final canvas = ref.watch(courseGradesProvider)[courseId];
    void change(GradePlan p) => ref.read(gradePlansProvider.notifier).update(courseId, p);

    // Canvas's categories, with yours added and your moves applied.
    final applied = work == null ? null : applyPlan(work, plan);
    final groups = applied?.groups ?? const <AssignmentGroup>[];
    final weights = effectiveWeights(groups, plan.weights);
    final calc = applied == null ? null : computeWeighted(applied.items, groups, weights, totals: plan.totals);

    // Use your own weights when set, otherwise Canvas's own numbers.
    final now = calc?.current ?? canvas?.currentScore;
    final worst = calc?.worst ?? canvas?.finalScore;

    return EDialog(
      eyebrow: course?.name ?? 'Course',
      title: 'Grade planner',
      body: work == null || applied == null || calc == null
          ? const ESkeletonList(rows: 5, rowHeight: 44)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Outcome(
                  now: now,
                  worst: worst,
                  half: calc.half,
                  steady: calc.steady,
                  best: calc.best,
                  weighted: calc.current != null,
                  standing: estimateStanding(applied.items, groups, weights, totals: plan.totals),
                  quotas: plan.quotas,
                ),
                const SizedBox(height: 30),
                _Categories(calc: calc, plan: plan, work: work, applied: applied, onChange: change),
                const SizedBox(height: 30),
                _Quotas(plan: plan, onChange: change),
              ],
            ),
      leading: [Text('Saved on this computer as you type.', style: context.text.metaMuted)],
      actions: [
        EButton(label: 'Done', kind: EButtonKind.primary, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, [this.hint]);
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: t.heading),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: t.metaMuted.copyWith(height: 1.45)),
          ],
        ],
      ),
    );
  }
}

String _pct(double? v) => v == null ? '–' : formatPercent(v);

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.now,
    required this.worst,
    required this.half,
    required this.steady,
    required this.best,
    required this.weighted,
    required this.standing,
    required this.quotas,
  });
  final double? now;
  final double? worst;
  final double? half;
  final double? steady;
  final double? best;
  final bool weighted;
  final Standing? standing;
  final Map<String, double> quotas;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final st = standing;
    final estimate = st == null ? null : letterForTop(st.topPercent, quotas);
    final top = st == null ? null : (st.topPercent < 1 ? 1 : st.topPercent.ceil());

    Widget stat(Color dot, String label, double? value, {String? letter, bool tick = false}) => SizedBox(
          width: 128,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  tick
                      ? Container(width: 2, height: 10, color: dot)
                      : Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(_pct(value), style: t.heading),
                  if (letter != null) ...[
                    const SizedBox(width: 6),
                    Text(letter, style: t.label.copyWith(color: c.accent)),
                  ],
                ],
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(
          'Where this course can end',
          weighted
              ? 'If everything still to do (including work not released yet) scores nothing, half marks, the same share as so far, or full marks.'
              : 'Using Canvas\'s own numbers until you set the category weights below.',
        ),
        _RangeBar(now: now, worst: worst, half: half, steady: steady, best: best),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            stat(c.danger, 'Worst', worst),
            stat(c.dueSoon, 'Half marks', half),
            stat(c.accent, 'Same as before', steady, letter: estimate?.letter),
            stat(c.success, 'Best', best),
            stat(c.textPrimary, 'Now', now, tick: true),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: c.sunken,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.line),
          ),
          child: st == null
              ? Text(
                  'No class statistics yet. Your standing appears here once your teacher shows score statistics on graded assignments.',
                  style: t.metaMuted.copyWith(height: 1.45),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR STANDING', style: t.caption),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Top $top%', style: t.title),
                        if (estimate != null) ...[
                          const SizedBox(width: 12),
                          Text('likely ${estimate.letter}', style: t.title.copyWith(color: c.accent)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (estimate?.nextLetter != null && estimate?.nextTopPercent != null)
                      Text(
                        '${estimate!.nextLetter} starts at the top ${formatPoints(estimate.nextTopPercent!)}% of the class.',
                        style: t.meta,
                      ),
                    if (estimate == null)
                      Text('Add the letter shares below to turn this into a letter.', style: t.meta),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'Based on ${st.assignments} of ${st.graded} graded assignments',
                        if (st.yourPercent != null && st.classPercent != null)
                          'you average ${formatPercent(st.yourPercent!)}, the class ${formatPercent(st.classPercent!)}',
                      ].join('  ·  '),
                      style: t.metaMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'An estimate: your position on each assignment, averaged by how much it counts. Finals and unseen work can move it.',
                      style: t.metaMuted.copyWith(height: 1.45),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 0–100% track. The band runs from worst to best; dots mark half marks and
/// "same as before"; a tick marks where you are now.
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.now,
    required this.worst,
    required this.half,
    required this.steady,
    required this.best,
  });

  final double? now;
  final double? worst;
  final double? half;
  final double? steady;
  final double? best;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          double x(double v) => (v / 100).clamp(0.0, 1.0) * w;
          Widget dot(double? v, Color color, double size) => v == null
              ? const SizedBox.shrink()
              : Positioned(
                  left: x(v) - size / 2,
                  top: 11 - size / 2,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 2),
                    ),
                  ),
                );
          final lo = worst;
          final hi = best;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 7,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.selected, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              if (lo != null && hi != null)
                Positioned(
                  left: x(lo),
                  width: (x(hi) - x(lo)).clamp(0.0, w),
                  top: 7,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              dot(worst, c.danger, 12),
              dot(half, c.dueSoon, 12),
              dot(best, c.success, 12),
              dot(steady, c.accent, 16),
              if (now != null)
                Positioned(
                  left: x(now!) - 1,
                  top: 1,
                  width: 2,
                  height: 20,
                  child: ColoredBox(color: c.textPrimary),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Categories extends StatefulWidget {
  const _Categories({
    required this.calc,
    required this.plan,
    required this.work,
    required this.applied,
    required this.onChange,
  });
  final WeightedGrade calc;
  final GradePlan plan;
  final CourseWork work; // as Canvas has it
  final CourseWork applied; // with your categories and moves
  final void Function(GradePlan) onChange;

  @override
  State<_Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<_Categories> {
  final Set<int> _open = {};

  Future<void> _add() async {
    final name = await _askName(context, title: 'New category');
    if (name == null || !mounted) return;
    var id = 0;
    widget.onChange(widget.plan.withNewGroup(name, onId: (v) => id = v));
    setState(() => _open.add(id));
  }

  Future<void> _rename(int id, String current) async {
    final name = await _askName(context, title: 'Rename category', initial: current);
    if (name != null && mounted) widget.onChange(widget.plan.withRenamedGroup(id, name));
  }

  Future<void> _move(GradedItem item) async {
    final choice = await showEtherDialog<int>(
      context,
      (_) => _GroupPicker(
        title: item.title,
        groups: widget.applied.groups,
        current: item.groupId,
        canReset: widget.plan.moves.containsKey(item.id),
      ),
      maxWidth: 420,
    );
    if (choice == null || !mounted) return;
    widget.onChange(widget.plan.withMove(item.id, choice == _kReset ? null : choice));
  }

  void _suggest() => widget.onChange(suggestFromNames(widget.plan, widget.work));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final calc = widget.calc;
    final plan = widget.plan;
    final weightTotal = calc.categories.fold<double>(0, (s, c) => s + (c.weight ?? 0));
    // Empty Canvas categories are hidden, unless they carry a weight or an
    // expected count: whatever counts toward the total must be visible.
    final shown = [
      for (final c in calc.categories)
        if (c.count > 0 ||
            c.total > 0 ||
            (c.weight ?? 0) > 0 ||
            plan.customGroups.containsKey(c.group.id))
          c,
    ];
    final off = weightTotal != 0 && (weightTotal - 100).abs() >= 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title(
          'Categories',
          'How much each category counts. If the weights are only in the syllabus, add the categories yourself and move the assignments into them. If a category will have more assignments than Canvas shows yet (6 quizzes, 2 released), enter the total under Items.',
        ),
        if (shown.isEmpty)
          Text('No graded categories found.', style: t.metaMuted)
        else
          Container(
            height: 28,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(
              children: [
                Expanded(child: Text('CATEGORY', style: t.caption)),
                SizedBox(width: 96, child: Text('ITEMS', style: t.caption)),
                const SizedBox(width: 8),
                SizedBox(width: 76, child: Text('WEIGHT', style: t.caption)),
              ],
            ),
          ),
        for (final r in shown)
          _CategoryBlock(
            key: ValueKey('cat${r.group.id}'),
            result: r,
            custom: plan.customGroups.containsKey(r.group.id),
            open: _open.contains(r.group.id),
            items: [for (final i in widget.applied.items) if ((i.groupId ?? -1) == r.group.id) i],
            moved: plan.moves.keys.toSet(),
            onTotal: (v) => widget.onChange(plan.withTotal(r.group.id, int.tryParse(v.trim()))),
            total: plan.totals[r.group.id],
            onToggle: () => setState(
              () => _open.contains(r.group.id) ? _open.remove(r.group.id) : _open.add(r.group.id),
            ),
            onWeight: (v) => widget.onChange(plan.withWeight(r.group.id, parseNumber(v))),
            onRename: () => _rename(r.group.id, r.group.name),
            onDelete: () => widget.onChange(plan.withoutGroup(r.group.id)),
            onMove: _move,
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            EButton(label: 'Add category', icon: EIcons.plus, onTap: _add),
            const SizedBox(width: 8),
            EButton(label: 'Suggest from names', icon: EIcons.sparkles, kind: EButtonKind.ghost, onTap: _suggest),
            const Spacer(),
            if (shown.isNotEmpty)
              Flexible(
                child: Text(
                  weightTotal == 0
                      ? 'No weights yet'
                      : !off
                          ? 'Weights add up to 100%'
                          : 'Weights add up to ${formatPoints(weightTotal)}%, scaled to 100%',
                  textAlign: TextAlign.right,
                  style: t.metaMuted.copyWith(color: off ? c.dueSoon : null),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    super.key,
    required this.result,
    required this.custom,
    required this.open,
    required this.items,
    required this.moved,
    required this.total,
    required this.onTotal,
    required this.onToggle,
    required this.onWeight,
    required this.onRename,
    required this.onDelete,
    required this.onMove,
  });

  final CategoryResult result;
  final bool custom;
  final bool open;
  final List<GradedItem> items;
  final Set<int> moved;
  final int? total;
  final ValueChanged<String> onTotal;
  final VoidCallback onToggle;
  final ValueChanged<String> onWeight;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final void Function(GradedItem) onMove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = context.text;
    final c = result;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Pressable(
                    onTap: onToggle,
                    pressedScale: 0.995,
                    builder: (context, hovered) => Row(
                      children: [
                        AnimatedRotation(
                          turns: open ? 0.25 : 0,
                          duration: const Duration(milliseconds: 160),
                          child: Icon(
                            EIcons.chevronRight,
                            size: 15,
                            color: hovered ? colors.textPrimary : colors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.group.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  c.total > c.count
                                      ? '${c.count} of ${c.total} so far'
                                      : '${c.count} item${c.count == 1 ? '' : 's'}',
                                  if (c.fraction != null) 'you have ${formatPercent(c.fraction! * 100)}',
                                  if (c.eachWeight != null) 'each ≈ ${c.eachWeight!.toStringAsFixed(2)}%',
                                ].join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.metaMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (custom) ...[
                  EIconButton(
                    icon: EIcons.edit,
                    tooltip: 'Rename',
                    size: 28,
                    iconSize: 14,
                    bordered: false,
                    onTap: onRename,
                  ),
                  EIconButton(
                    icon: EIcons.trash,
                    tooltip: 'Delete category',
                    size: 28,
                    iconSize: 14,
                    bordered: false,
                    onTap: onDelete,
                  ),
                  const SizedBox(width: 8),
                ],
                CompactField(
                  key: ValueKey('n${c.group.id}'),
                  width: 96,
                  initial: total == null ? '' : '$total',
                  hint: '${c.count}',
                  suffix: ' items',
                  onChanged: onTotal,
                ),
                const SizedBox(width: 8),
                CompactField(
                  key: ValueKey('w${c.group.id}'),
                  initial: c.weight == null ? '' : formatPoints(c.weight!),
                  hint: '0',
                  suffix: '%',
                  onChanged: onWeight,
                ),
              ],
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(left: 23, bottom: 8),
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'No assignments yet. Move some here from another category, or enter how many it will have under Items so it counts.',
                        style: t.metaMuted,
                      ),
                    )
                  : Column(
                      children: [
                        for (final i in items)
                          SizedBox(
                            height: 36,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    i.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.body.copyWith(
                                      color: moved.contains(i.id) ? colors.accent : colors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(_itemScore(i), style: t.number.copyWith(color: colors.textTertiary)),
                                const SizedBox(width: 6),
                                EButton(label: 'Move', kind: EButtonKind.ghost, onTap: () => onMove(i)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

String _itemScore(GradedItem i) {
  final p = i.points == null ? '' : formatPoints(i.points!);
  if (i.state == GradeState.graded && i.score != null) return '${formatPoints(i.score!)} / $p';
  if (i.state == GradeState.excused) return 'excused';
  return p.isEmpty ? '' : '— / $p';
}

const int _kReset = -1000000000;

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({required this.title, required this.groups, required this.current, required this.canReset});
  final String title;
  final List<AssignmentGroup> groups;
  final int? current;
  final bool canReset;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return EDialog(
      eyebrow: title,
      title: 'Move to',
      body: Column(
        children: [
          for (final g in groups)
            ETap(
              onTap: () => Navigator.of(context).pop(g.id),
              pressedScale: 0.99,
              builder: (context, s) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: g.id == current ? c.accentSoft : (s.hovered ? c.hover : const Color(0x00000000)),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: focusRing(c, s.focused),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label)),
                    if (g.id == current) Icon(EIcons.check, size: 15, color: c.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
      leading: [
        if (canReset)
          EButton(label: 'Back to Canvas', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop(_kReset)),
      ],
      actions: [
        EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

Future<String?> _askName(BuildContext context, {required String title, String initial = ''}) {
  return showEtherDialog<String>(context, (_) => _NameDialog(title: title, initial: initial), maxWidth: 420);
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _c.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return EDialog(
      title: widget.title,
      body: AppTextField(
        controller: _c,
        label: 'Name',
        hint: 'Quizzes, Midterm, Participation',
        autofocus: true,
        onSubmitted: _submit,
      ),
      actions: [
        EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop()),
        EButton(label: 'Save', kind: EButtonKind.primary, onTap: _submit),
      ],
    );
  }
}

class _Quotas extends StatelessWidget {
  const _Quotas({required this.plan, required this.onChange});
  final GradePlan plan;
  final void Function(GradePlan) onChange;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final total = plan.quotas.values.fold<double>(0, (s, v) => s + v);
    final ok = (total - 100).abs() < 0.01;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Title(
          'Letter shares',
          'The share of the class that gets each letter, best first (for example 10% get A+, 20% get A). Leave unused letters empty.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final l in kLetters)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l, style: t.label),
                  const SizedBox(height: 4),
                  CompactField(
                    key: ValueKey('q$l'),
                    width: 70,
                    initial: plan.quotas[l] == null ? '' : formatPoints(plan.quotas[l]!),
                    suffix: '%',
                    onChanged: (v) => onChange(plan.withQuota(l, parseNumber(v))),
                  ),
                ],
              ),
          ],
        ),
        if (total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              ok ? 'Shares add up to 100%' : 'Shares add up to ${formatPoints(total)}%, scaled to 100%',
              style: t.metaMuted.copyWith(color: ok ? null : c.dueSoon),
            ),
          ),
      ],
    );
  }
}
