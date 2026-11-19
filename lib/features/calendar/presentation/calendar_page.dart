import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/smooth_scroll.dart';
import '../../../core/ui/hover_prefetch.dart';
import '../../../core/ui/selected_builder.dart';
import '../../../design_system/components/pressable.dart';
import '../../../design_system/ether/breakpoint.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/presentation/assignment_dialog.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../courses/domain/course.dart';
import '../../submission/presentation/submission_providers.dart';
import '../domain/week.dart';

const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Below this content width the week grid becomes a day-by-day agenda.
const double _gridBreakpoint = 760;

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  final FocusNode _focus = FocusNode();
  final ValueNotifier<int?> _cursor = ValueNotifier<int?>(null);
  DateTime _start = weekStart(DateTime.now());

  /// Direction of the last week change, for the slide.
  int _direction = 0;

  /// This week's assignments in time order (what ↑/↓ walk through).
  List<Assignment> _ordered = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sync = ref.read(syncProvider);
      if (sync.lastUpdated == null && !sync.loading) ref.read(syncProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _cursor.dispose();
    super.dispose();
  }

  void _shift(int weeks) => setState(() {
        _direction = weeks.sign;
        _start = addWeeks(_start, weeks);
        _cursor.value = null;
      });

  void _today() {
    final target = weekStart(DateTime.now());
    if (sameDay(target, _start)) return;
    setState(() {
      _direction = target.isAfter(_start) ? 1 : -1;
      _start = target;
      _cursor.value = null;
    });
  }

  void _move(int delta) {
    if (_ordered.isEmpty) return;
    final pos = _ordered.indexWhere((a) => a.id == _cursor.value);
    final next = pos < 0 ? (delta > 0 ? 0 : _ordered.length - 1) : (pos + delta).clamp(0, _ordered.length - 1);
    _cursor.value = _ordered[next].id;
  }

  Future<void> _open(Assignment a) async {
    _cursor.value = a.id;
    await showAssignmentDialog(context, a.id);
    if (mounted) _focus.requestFocus();
  }

  void _refresh() => ref.read(syncProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(assignmentsProvider);
    final courses = ref.watch(coursesByIdProvider);
    final sync = ref.watch(syncProvider);
    final filter = ref.watch(courseFilterProvider);
    final disabled = ref.watch(disabledCoursesProvider);
    final now = DateTime.now();

    final all = async.value ?? const <Assignment>[];
    final items = filter.isNotEmpty
        ? all.where((a) => filter.contains(a.courseId)).toList()
        : all.where((a) => !disabled.contains(a.courseId)).toList();
    final days = assignmentsByDay(items, _start);
    _ordered = [for (final d in days) ...d];
    final count = _ordered.length;
    final open = _ordered.where((a) => !a.done).length;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _shift(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _shift(1),
        const SingleActivator(LogicalKeyboardKey.keyT): _today,
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.keyJ): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.keyK): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          final id = _cursor.value;
          for (final a in _ordered) {
            if (a.id == id) _open(a);
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () => _cursor.value = null,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
      },
      child: Focus(
        autofocus: true,
        focusNode: _focus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EPageHeader(
              title: 'Calendar',
              subtitle:
                  '${weekRangeLabel(_start)}  ·  ${count == 0 ? 'nothing due' : '$open of $count open'}',
              actions: [
                ESyncButton(state: sync, onRefresh: _refresh),
                const SizedBox(width: 6),
                EIconButton(icon: EIcons.chevronLeft, tooltip: 'Previous week', onTap: () => _shift(-1)),
                EButton(label: 'Today', onTap: _today),
                EIconButton(icon: EIcons.chevronRight, tooltip: 'Next week', onTap: () => _shift(1)),
              ],
            ),
            Expanded(
              child: BreakpointBuilder<bool>(
                mode: (box) => box.maxWidth >= _gridBreakpoint,
                builder: (context, grid) {
                  final week = KeyedSubtree(
                    key: ValueKey<DateTime>(_start),
                    child: grid
                        ? _WeekGrid(
                            start: _start,
                            days: days,
                            courses: courses,
                            now: now,
                            cursor: _cursor,
                            onOpen: _open,
                          )
                        : _Agenda(
                            start: _start,
                            days: days,
                            courses: courses,
                            now: now,
                            cursor: _cursor,
                            onOpen: _open,
                          ),
                  );
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [...previous, ?current],
                    ),
                    transitionBuilder: (child, animation) {
                      final incoming = child.key == ValueKey<DateTime>(_start);
                      final dx = (incoming ? 0.03 : -0.03) * _direction;
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: week,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.start,
    required this.days,
    required this.courses,
    required this.now,
    required this.cursor,
    required this.onOpen,
  });

  final DateTime start;
  final List<List<Assignment>> days;
  final Map<int, Course> courses;
  final DateTime now;
  final ValueListenable<int?> cursor;
  final void Function(Assignment) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) Container(width: 1, color: c.line),
            Expanded(
              flex: i >= 5 ? 5 : 6,
              child: _DayColumn(
                date: DateTime(start.year, start.month, start.day + i),
                items: days[i],
                courses: courses,
                now: now,
                cursor: cursor,
                onOpen: onOpen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayColumn extends StatefulWidget {
  const _DayColumn({
    required this.date,
    required this.items,
    required this.courses,
    required this.now,
    required this.cursor,
    required this.onOpen,
  });

  final DateTime date;
  final List<Assignment> items;
  final Map<int, Course> courses;
  final DateTime now;
  final ValueListenable<int?> cursor;
  final void Function(Assignment) onOpen;

  @override
  State<_DayColumn> createState() => _DayColumnState();
}

class _DayColumnState extends State<_DayColumn> {
  final SmoothScrollController _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final date = widget.date;
    final today = sameDay(date, widget.now);
    final weekend = date.weekday >= 6;
    final items = widget.items;
    // Where "now" falls among today's items.
    final nowAt = today ? items.indexWhere((a) => a.dueAt!.isAfter(widget.now)) : -1;
    final nowIndex = !today ? -1 : (nowAt < 0 ? items.length : nowAt);
    final count = items.length + (nowIndex >= 0 ? 1 : 0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: today ? c.accent.withValues(alpha: c.isDark ? 0.06 : 0.04) : const Color(0x00000000),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: [
                Text(
                  _weekdays[date.weekday - 1].toUpperCase(),
                  style: t.caption.copyWith(color: today ? c.accent : (weekend ? c.textTertiary : null)),
                ),
                const Spacer(),
                Container(
                  constraints: const BoxConstraints(minWidth: 30),
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: today ? c.accent : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '${date.day}',
                    style: t.heading.copyWith(
                      color: today ? c.onAccent : (weekend ? c.textSecondary : c.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
              itemCount: count,
              itemBuilder: (context, i) {
                if (i == nowIndex) return _NowLine(time: widget.now);
                final a = items[nowIndex >= 0 && i > nowIndex ? i - 1 : i];
                return _Chip(
                  key: ValueKey<int>(a.id),
                  assignment: a,
                  course: widget.courses[a.courseId],
                  now: widget.now,
                  cursor: widget.cursor,
                  onTap: () => widget.onOpen(a),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin accent line with the time, between what is past and what is coming.
class _NowLine extends StatelessWidget {
  const _NowLine({required this.time});
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 1.5, color: c.accent)),
          const SizedBox(width: 6),
          Text(_hm(time), style: t.number.copyWith(color: c.accent, fontSize: t.handwritten ? 13 : 11.5)),
        ],
      ),
    );
  }
}

class _Chip extends ConsumerWidget {
  const _Chip({
    super.key,
    required this.assignment,
    required this.course,
    required this.now,
    required this.cursor,
    required this.onTap,
  });

  final Assignment assignment;
  final Course? course;
  final DateTime now;
  final ValueListenable<int?> cursor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = assignment;
    final c = context.colors;
    final t = context.text;
    final overdue = a.isOverdue(now);
    final soon = !a.done && !overdue && a.dueAt!.difference(now).inHours < 24;
    final timeColor = overdue ? c.danger : (soon ? c.dueSoon : c.textSecondary);
    Color fade(Color color) => a.done ? color.withValues(alpha: color.a * 0.55) : color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HoverPrefetch(
        onPrefetch: () => ref.read(submissionInfoProvider((courseId: a.courseId, assignmentId: a.id))),
        child: Pressable(
          onTap: onTap,
          pressedScale: 0.98,
          builder: (context, hovered) => SelectedBuilder<int>(
            cursor: cursor,
            id: a.id,
            builder: (context, selected, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                decoration: BoxDecoration(
                  color: hovered ? Color.alphaBlend(c.hover, c.surface) : c.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? c.accent : (hovered ? c.lineStrong : c.line),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: child,
              );
            },
            // Done work is faded through its colours, not an Opacity layer:
            // a week can hold many done chips, and each layer costs a
            // separate offscreen pass when the window resizes.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ESwatch(CoursePalette.colorFor(a.courseId), width: 7, height: 10, dim: a.done),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_hm(a.dueAt!), style: t.number.copyWith(color: fade(timeColor)))),
                    if (a.starred) Icon(EIcons.starFilled, size: 14, color: fade(c.star)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  a.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    color: fade(t.label.color ?? c.textPrimary),
                    decoration: a.done ? TextDecoration.lineThrough : null,
                    decorationColor: c.textTertiary,
                  ),
                ),
                if (course != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    course!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.metaMuted.copyWith(color: fade(t.metaMuted.color ?? c.textTertiary)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Narrow windows: the week as a list of days.
class _Agenda extends StatefulWidget {
  const _Agenda({
    required this.start,
    required this.days,
    required this.courses,
    required this.now,
    required this.cursor,
    required this.onOpen,
  });

  final DateTime start;
  final List<List<Assignment>> days;
  final Map<int, Course> courses;
  final DateTime now;
  final ValueListenable<int?> cursor;
  final void Function(Assignment) onOpen;

  @override
  State<_Agenda> createState() => _AgendaState();
}

class _AgendaState extends State<_Agenda> {
  final SmoothScrollController _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final children = <Widget>[];
    for (var i = 0; i < 7; i++) {
      final date = DateTime(widget.start.year, widget.start.month, widget.start.day + i);
      final items = widget.days[i];
      final today = sameDay(date, widget.now);
      children.add(EGroupHeader(
        label: '${_weekdays[date.weekday - 1]} ${date.day}${today ? '  ·  today' : ''}',
        count: items.length,
      ));
      if (items.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 0, 6),
          child: Text('Nothing due', style: t.metaMuted.copyWith(color: c.textTertiary)),
        ));
      }
      for (final a in items) {
        children.add(_Chip(
          key: ValueKey<int>(a.id),
          assignment: a,
          course: widget.courses[a.courseId],
          now: widget.now,
          cursor: widget.cursor,
          onTap: () => widget.onOpen(a),
        ));
      }
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 24),
      children: children,
    );
  }
}
