import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/smooth_scroll.dart';
import '../../../core/ui/hover_prefetch.dart';
import '../../../core/ui/selected_builder.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/ether/breakpoint.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/detail_pane.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/ether/new_dot.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../settings/domain/settings_search.dart';
import '../../seen/domain/seen_state.dart';
import '../../seen/presentation/seen_provider.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../../settings/presentation/view_prefs_provider.dart';
import '../../courses/domain/course.dart';
import '../domain/grade_calc.dart';
import '../domain/grades.dart';
import 'grade_plan_dialog.dart';
import 'grades_providers.dart';

const double _rowExtent = 56;

typedef PlanSummary = ({double? mine, String? likely});

/// Your own weighted grade and letter guess for a course, once you have set
/// up its planner. A provider, so the calculation runs once per change of
/// that course's plan or work, not on every rebuild of its row (hover,
/// keyboard cursor, sync).
final planSummaryProvider = Provider.autoDispose.family<PlanSummary, int>((ref, courseId) {
  final plan = ref.watch(gradePlansProvider.select((m) => m[courseId]));
  if (plan == null || plan.isEmpty) return (mine: null, likely: null);
  final work = ref.watch(courseWorkProvider(courseId)).value;
  if (work == null) return (mine: null, likely: null);
  final applied = applyPlan(work, plan);
  final weights = effectiveWeights(applied.groups, plan.weights);
  double? mine;
  String? likely;
  if (plan.weights.isNotEmpty) {
    mine = computeWeighted(applied.items, applied.groups, weights, totals: plan.totals).current;
  }
  if (plan.quotas.isNotEmpty) {
    final st = estimateStanding(applied.items, applied.groups, weights, totals: plan.totals);
    if (st != null) likely = letterForTop(st.topPercent, plan.quotas)?.letter;
  }
  return (mine: mine, likely: likely);
});

/// Call from build (it watches).
PlanSummary planSummary(WidgetRef ref, int courseId) => ref.watch(planSummaryProvider(courseId));

sealed class _Entry {
  const _Entry();
}

final class _Header extends _Entry {
  const _Header(this.label, this.count, {this.foldable = false});
  final String label;
  final int count;
  final bool foldable;
}

final class _Row extends _Entry {
  const _Row(this.course);
  final Course course;
}

class GradesPage extends ConsumerStatefulWidget {
  const GradesPage({super.key});

  @override
  ConsumerState<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends ConsumerState<GradesPage> {
  final FocusNode _focus = FocusNode();
  final SmoothScrollController _scroll = SmoothScrollController();
  final ValueNotifier<int?> _cursor = ValueNotifier<int?>(null);
  // "No grades yet" unfolded: remembered per account.
  bool get _showUngraded => ref.read(viewPrefsProvider).gradesShowUngraded;
  bool _wide = true;
  List<_Entry> _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _scroll.dispose();
    _cursor.dispose();
    super.dispose();
  }

  void _refresh() => ref.read(gradesSyncProvider.notifier).refresh();

  List<int> get _rowIds => [
        for (final e in _entries)
          if (e is _Row) e.course.id,
      ];

  void _move(int delta) {
    final ids = _rowIds;
    if (ids.isEmpty) return;
    final pos = ids.indexOf(_cursor.value ?? -1);
    final next = pos < 0 ? (delta > 0 ? 0 : ids.length - 1) : (pos + delta).clamp(0, ids.length - 1);
    _cursor.value = ids[next];
    _ensureVisible(ids[next]);
  }

  void _ensureVisible(int courseId) {
    if (!_scroll.hasClients) return;
    var top = 0.0;
    for (final e in _entries) {
      if (e is _Row && e.course.id == courseId) break;
      top += e is _Header ? EGroupHeader.extent : _rowExtent;
    }
    final view = _scroll.position.viewportDimension;
    double? target;
    if (top < _scroll.offset) {
      target = top - EGroupHeader.extent;
    } else if (top + _rowExtent > _scroll.offset + view) {
      target = top + _rowExtent - view + 8;
    }
    if (target == null) return;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  void _select(int id) {
    _cursor.value = id;
    if (!_wide) _openDialog(id);
  }

  Future<void> _openDialog(int id) async {
    await showEtherDialog<void>(context, (context) => _CourseDialog(courseId: id), maxWidth: 600, selectable: true);
    if (mounted) _focus.requestFocus();
  }

  Future<void> _openPlanner() async {
    final id = _cursor.value;
    if (id == null) return;
    await showGradePlanner(context, id);
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(viewPrefsProvider); // rebuild when the fold changes
    final sync = ref.watch(gradesSyncProvider);
    final grades = ref.watch(courseGradesProvider);
    final seen = ref.watch(seenProvider);
    final updated = seen.updatedCourseCount(grades.values);
    final courses = ref.watch(coursesByIdProvider);
    final disabled = ref.watch(disabledCoursesProvider);
    final filter = ref.watch(courseFilterProvider);

    final list = [
      for (final c in courses.values)
        if (filter.isNotEmpty ? filter.contains(c.id) : !disabled.contains(c.id)) c,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    bool hasGrade(Course c) =>
        grades[c.id]?.currentScore != null || grades[c.id]?.finalScore != null;
    final graded = [for (final c in list) if (hasGrade(c)) c];
    final ungraded = [for (final c in list) if (!hasGrade(c)) c];
    _entries = [
      if (graded.isNotEmpty) _Header('Courses', graded.length),
      for (final c in graded) _Row(c),
      if (ungraded.isNotEmpty) _Header('No grades yet', ungraded.length, foldable: true),
      if (_showUngraded || graded.isEmpty)
        for (final c in ungraded) _Row(c),
    ];

    final Widget body;
    if (courses.isEmpty) {
      body = sync.error != null && !sync.loading
          ? EErrorState(message: sync.error!, onRetry: _refresh)
          : const ESkeletonList(rowHeight: _rowExtent);
    } else if (list.isEmpty) {
      body = EEmptyState(
        icon: EIcons.grades,
        title: 'No courses here',
        message: filter.isNotEmpty
            ? 'Choose other courses in the sidebar, or show them all.'
            : 'Every course is turned off. Turn some back on in Settings.',
        action: filter.isNotEmpty
            ? EButton(label: 'Show all courses', onTap: ref.read(courseFilterProvider.notifier).clear)
            : EButton(label: 'Open Settings', onTap: () => showSettings(context, section: SettingsSection.courses)),
      );
    } else {
      body = const SizedBox.shrink(); // the list is shown instead
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.keyJ): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.keyK): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          final id = _cursor.value;
          if (id != null && !_wide) _openDialog(id);
        },
        const SingleActivator(LogicalKeyboardKey.keyP): _openPlanner,
        const SingleActivator(LogicalKeyboardKey.escape): () => _cursor.value = null,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
      },
      child: Focus(
        autofocus: true,
        focusNode: _focus,
        child: BreakpointBuilder<(bool, double, bool)>(
          mode: (box) => (
            box.maxWidth >= kDetailPaneBreakpoint,
            detailPaneWidthFor(box.maxWidth),
            box.maxWidth >= 1080,
          ),
          builder: (context, mode) {
            final (wide, paneWidth, showBar) = mode;
            _wide = wide;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EPageHeader(
                  title: 'Grades',
                  subtitle: updated > 0
                      ? '$updated ${updated == 1 ? 'course has' : 'courses have'} new grades'
                      : 'Now counts graded work so far; final counts what is not graded yet as zero',
                  actions: [
                    if (updated > 0)
                      EButton(
                        label: 'Mark all as seen',
                        icon: EIcons.check,
                        onTap: ref.read(seenProvider.notifier).markAllCourses,
                      ),
                    ESyncButton(state: sync, onRefresh: _refresh),
                  ],
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: list.isEmpty || courses.isEmpty
                            ? body
                            : Padding(
                                padding: const EdgeInsets.only(left: 16, right: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _Columns(showBar: showBar),
                                    Expanded(
                                      child: ListView.builder(
                                        controller: _scroll,
                                        padding: const EdgeInsets.only(bottom: 32),
                                        itemCount: _entries.length,
                                        itemExtentBuilder: (i, _) =>
                                            _entries[i] is _Header ? EGroupHeader.extent : _rowExtent,
                                        itemBuilder: (context, i) => switch (_entries[i]) {
                                          _Header(:final label, :final count, :final foldable) => foldable
                                              ? EGroupHeader(
                                                  label: label,
                                                  count: count,
                                                  expanded: _showUngraded || graded.isEmpty,
                                                  onTap: () => ref.read(viewPrefsProvider.notifier).update(
                                                        (p) => p.copyWith(gradesShowUngraded: !p.gradesShowUngraded),
                                                      ),
                                                )
                                              : EGroupHeader(label: label, count: count),
                                          _Row(:final course) => _CourseRow(
                                              key: ValueKey<int>(course.id),
                                              course: course,
                                              grade: grades[course.id],
                                              isNew: seen.courseUpdated(grades[course.id]),
                                              cursor: _cursor,
                                              showBar: showBar,
                                              onTap: () => _select(course.id),
                                            ),
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      if (wide)
                        ValueListenableBuilder<int?>(
                          valueListenable: _cursor,
                          builder: (context, id, _) => DetailPane(
                            width: paneWidth,
                            identity: id,
                            onClose: () => _cursor.value = null,
                            child: id == null ? null : CourseGradeDetail(key: ValueKey<int>(id), courseId: id),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Columns extends StatelessWidget {
  const _Columns({required this.showBar});
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 12, right: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Expanded(child: Text('COURSE', style: t.caption)),
          if (showBar) const SizedBox(width: 140),
          SizedBox(width: 84, child: Text('NOW', textAlign: TextAlign.right, style: t.caption)),
          SizedBox(width: 84, child: Text('FINAL', textAlign: TextAlign.right, style: t.caption)),
        ],
      ),
    );
  }
}

class _CourseRow extends ConsumerWidget {
  const _CourseRow({
    super.key,
    required this.course,
    required this.grade,
    required this.cursor,
    required this.showBar,
    required this.onTap,
    this.isNew = false,
  });

  final Course course;
  final CourseGrade? grade;
  final ValueListenable<int?> cursor;
  final bool showBar;
  final VoidCallback onTap;

  /// The grade changed since this course was last opened.
  final bool isNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final color = CoursePalette.colorFor(course.id);
    final now = grade?.currentScore;
    final fin = grade?.finalScore;
    final summary = planSummary(ref, course.id);
    final meta = [
      ?grade?.currentGrade,
      if (summary.mine != null) 'yours ${formatPercent(summary.mine!)}',
      if (summary.likely != null) 'likely ${summary.likely}',
    ].join('  ·  ');

    return HoverPrefetch(
      onPrefetch: () => ref.read(courseWorkProvider(course.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ETap(
          focusable: false,
          onTap: onTap,
          pressedScale: 0.995,
          builder: (context, tapState) => SelectedBuilder<int>(
            cursor: cursor,
            id: course.id,
            builder: (context, selected, child) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? c.selected : (tapState.hovered ? c.hover : const Color(0x00000000)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: child,
            ),
            child: Row(
              children: [
                ESwatch(color),
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
                            child: Text(course.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
                          ),
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.metaMuted.copyWith(color: summary.likely != null || summary.mine != null ? c.accent : null),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showBar)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: SizedBox(width: 100, child: GradeBar(now: now, fin: fin, color: color)),
                  ),
                SizedBox(
                  width: 84,
                  child: Text(
                    now == null ? '–' : formatPercent(now),
                    textAlign: TextAlign.right,
                    style: t.number.copyWith(color: now == null ? c.textTertiary : c.textPrimary),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Text(
                    fin == null ? '–' : formatPercent(fin),
                    textAlign: TextAlign.right,
                    style: t.number.copyWith(color: c.textTertiary),
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

/// Thin bar: solid up to the final grade, lighter up to the current grade.
class GradeBar extends StatelessWidget {
  const GradeBar({super.key, required this.now, required this.fin, required this.color, this.height = 6});
  final double? now;
  final double? fin;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    double f(double? v) => v == null ? 0 : (v / 100).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: c.selected)),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: f(now),
                child: ColoredBox(color: color.withValues(alpha: 0.4)),
              ),
            ),
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: f(fin ?? now),
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseDialog extends StatelessWidget {
  const _CourseDialog({required this.courseId});
  final int courseId;

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
            child: CourseGradeDetail(courseId: courseId),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const Spacer(),
                EButton(label: 'Close', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One course's grade: the numbers, your plan, and every graded item.
class CourseGradeDetail extends ConsumerStatefulWidget {
  const CourseGradeDetail({super.key, required this.courseId});
  final int courseId;

  @override
  ConsumerState<CourseGradeDetail> createState() => _CourseGradeDetailState();
}

class _CourseGradeDetailState extends ConsumerState<CourseGradeDetail> {
  bool _captured = false;
  DateTime? _since;

  @override
  Widget build(BuildContext context) {
    final seen = ref.watch(seenProvider);
    // Opening a course is looking at it: remember what was new when it was
    // opened (so those items stay marked while it is open), then mark it seen.
    if (!_captured && seen.courseGrades != null) {
      _captured = true;
      _since = seen.sinceFor(widget.courseId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(seenProvider.notifier).markCourse(widget.courseId);
      });
    }
    return _CourseGradeBody(courseId: widget.courseId, since: _since);
  }
}

class _CourseGradeBody extends ConsumerWidget {
  const _CourseGradeBody({required this.courseId, required this.since});
  final int courseId;
  final DateTime? since;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final course = ref.watch(coursesByIdProvider)[courseId];
    final grade = ref.watch(courseGradesProvider)[courseId];
    final work = ref.watch(courseWorkProvider(courseId));
    final summary = planSummary(ref, courseId);
    final color = CoursePalette.colorFor(courseId);
    final now = grade?.currentScore;
    final fin = grade?.finalScore;

    Widget big(String label, String value, {Color? valueColor, String? suffix}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: t.caption),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: t.display.copyWith(fontSize: t.handwritten ? 30 : 24, color: valueColor)),
                if (suffix != null) ...[
                  const SizedBox(width: 8),
                  Text(suffix, style: t.heading.copyWith(color: c.accent)),
                ],
              ],
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 36),
          child: Row(
            children: [
              ESwatch(color),
              const SizedBox(width: 8),
              Expanded(child: Text('Grades', style: t.meta)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(course?.name ?? 'Course', style: t.title),
        const SizedBox(height: 20),
        Wrap(
          spacing: 36,
          runSpacing: 14,
          children: [
            big('Now', now == null ? '–' : formatPercent(now), suffix: grade?.currentGrade),
            big('Final', fin == null ? '–' : formatPercent(fin), valueColor: c.textSecondary),
            if (summary.mine != null || summary.likely != null)
              big(
                'Yours',
                summary.mine == null ? '–' : formatPercent(summary.mine!),
                valueColor: c.accent,
                suffix: summary.likely,
              ),
          ],
        ),
        const SizedBox(height: 14),
        GradeBar(now: now, fin: fin, color: color, height: 8),
        const SizedBox(height: 18),
        EButton(
          label: 'Open grade planner',
          icon: EIcons.grades,
          kind: EButtonKind.primary,
          onTap: () => showGradePlanner(context, courseId),
        ),
        work.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 20),
            child: ESkeletonList(rows: 4, rowHeight: 38),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Text('Could not load this course. Try again later.', style: t.metaMuted),
          ),
          data: (work) {
            final items = [for (final i in work.items) if (i.state != GradeState.open) i];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Text('Nothing graded yet.', style: t.metaMuted),
              );
            }
            final p = progressOf(items);
            final today = DateTime.now();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ESectionLabel(
                  'Graded work',
                  trailing: [
                    '${p.graded} of ${p.counted} graded',
                    if (p.earned != null) '${formatPoints(p.earned!)} / ${formatPoints(p.possible!)} pts',
                  ].join('  ·  '),
                ),
                for (final i in items) _ItemRow(item: i, now: today, isNew: SeenState.itemIsNew(i, since)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.now, this.isNew = false});
  final GradedItem item;
  final DateTime now;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final (String text, Color color) = switch (item.state) {
      GradeState.graded => (
          item.score == null
              ? (item.grade ?? '–')
              : (item.points == null || item.points == 0)
                  ? formatPoints(item.score!)
                  : '${formatPoints(item.score!)} / ${formatPoints(item.points!)}',
          c.textPrimary,
        ),
      GradeState.excused => ('Excused', c.textTertiary),
      GradeState.missing => ('Missing', c.danger),
      GradeState.submitted => ('Submitted', c.textSecondary),
      GradeState.open => ('', c.textSecondary),
    };
    final when = item.when ?? item.dueAt;
    return Container(
      height: 38,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          if (isNew) ...[
            const ENewDot(size: 7),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body)),
          const SizedBox(width: 12),
          if (when != null) Text(formatShortDate(when, now), style: t.metaMuted),
          const SizedBox(width: 14),
          SizedBox(
            width: 92,
            child: Text(text, textAlign: TextAlign.end, style: t.number.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
