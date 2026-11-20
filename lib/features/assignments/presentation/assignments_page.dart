import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/smooth_scroll.dart';
import '../../../core/ui/hover_prefetch.dart';
import '../../../design_system/ether/breakpoint.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/detail_pane.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../courses/domain/course.dart';
import '../../submission/presentation/submission_providers.dart';
import '../domain/assignment.dart';
import '../domain/timeline.dart';
import 'assignment_dialog.dart';
import 'assignment_row.dart';
import 'assignments_providers.dart';

class AssignmentsPage extends ConsumerStatefulWidget {
  const AssignmentsPage({super.key});

  @override
  ConsumerState<AssignmentsPage> createState() => _AssignmentsPageState();
}

const List<LogicalKeyboardKey> _digitKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

class _AssignmentsPageState extends ConsumerState<AssignmentsPage> {
  final SmoothScrollController _scroll = SmoothScrollController();

  /// Selected assignment: keyboard cursor and what the details pane shows.
  final ValueNotifier<int?> _cursor = ValueNotifier<int?>(null);
  final FocusNode _focus = FocusNode();

  List<TimelineEntry> _entries = const [];
  List<double> _offsets = const [0];
  List<int> _itemIndexes = const [];
  bool _showEarlier = false;

  /// 0 = everything, 1 = starred only.
  int _view = 0;

  /// Wide enough for the details pane (else details open in a dialog).
  bool _wide = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(syncProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _cursor.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _sync(List<TimelineEntry> entries) {
    _entries = entries;
    final offsets = <double>[0];
    final items = <int>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      offsets.add(offsets.last + (e is HeaderEntry ? kHeaderExtent : kRowExtent));
      if (e is ItemEntry) items.add(i);
    }
    _offsets = offsets;
    _itemIndexes = items;
  }

  int? _entryIndexOf(int id) {
    for (final i in _itemIndexes) {
      if ((_entries[i] as ItemEntry).assignment.id == id) return i;
    }
    return null;
  }

  void _move(int delta) {
    if (_itemIndexes.isEmpty) return;
    final cur = _cursor.value;
    var pos = -1;
    if (cur != null) {
      final e = _entryIndexOf(cur);
      if (e != null) pos = _itemIndexes.indexOf(e);
    }
    final next = pos < 0
        ? (delta > 0 ? 0 : _itemIndexes.length - 1)
        : (pos + delta).clamp(0, _itemIndexes.length - 1);
    final entryIndex = _itemIndexes[next];
    _cursor.value = (_entries[entryIndex] as ItemEntry).assignment.id;
    _ensureVisible(entryIndex);
  }

  void _ensureVisible(int entryIndex) {
    if (!_scroll.hasClients) return;
    var top = _offsets[entryIndex];
    if (entryIndex > 0 && _entries[entryIndex - 1] is HeaderEntry) {
      top = _offsets[entryIndex - 1];
    }
    final bottom = _offsets[entryIndex + 1];
    final cur = _scroll.offset;
    final viewport = _scroll.position.viewportDimension;
    double? target;
    if (top < cur) {
      target = top;
    } else if (bottom > cur + viewport) {
      target = bottom - viewport + 8;
    }
    if (target == null) return;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    });
  }

  void _toggleChipAt(int index) {
    final disabled = ref.read(disabledCoursesProvider);
    final entries = [
      for (final e in ref.read(filterableCoursesProvider))
        if (!disabled.contains(e.course.id)) e,
    ];
    if (index < entries.length) {
      ref.read(courseFilterProvider.notifier).toggle(entries[index].course.id);
    }
  }

  Assignment? _cursorAssignment() {
    final id = _cursor.value;
    if (id == null) return null;
    final e = _entryIndexOf(id);
    return e == null ? null : (_entries[e] as ItemEntry).assignment;
  }

  /// Click: select (the pane follows). Narrow windows open a dialog instead.
  void _select(int id) {
    _cursor.value = id;
    if (!_wide) _openDialog(id);
  }

  Future<void> _openDialog(int id) async {
    await showAssignmentDialog(context, id);
    if (mounted) _focus.requestFocus();
  }

  void _refresh() => ref.read(syncProvider.notifier).refresh();

  void _setView(int v) {
    if (v == _view) return;
    setState(() {
      _view = v;
      // Starred done work is worth seeing, so open the folded group there.
      _showEarlier = v == 1;
    });
    _scrollToTop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(assignmentsProvider);
    final courses = ref.watch(coursesByIdProvider);
    final actions = ref.read(assignmentActionsProvider);
    final sync = ref.watch(syncProvider);
    final now = DateTime.now();

    final filter = ref.watch(courseFilterProvider);
    ref.listen(courseFilterProvider, (_, _) => _scrollToTop());
    final all = async.value;
    final disabled = ref.watch(disabledCoursesProvider);
    final inScope = all == null
        ? null
        : (filter.isNotEmpty
            ? all.where((a) => filter.contains(a.courseId)).toList()
            : all.where((a) => !disabled.contains(a.courseId)).toList());
    final starredCount = inScope?.where((a) => a.starred).length ?? 0;
    final items = inScope == null || _view == 0 ? inScope : inScope.where((a) => a.starred).toList();
    if (items != null) {
      _sync(arrangeTimeline(buildTimeline(items, now), showEarlier: _showEarlier));
    }

    final open = items?.where((a) => !a.done).length ?? 0;
    final soon = items
            ?.where((a) => !a.done && a.dueAt != null && a.dueAt!.difference(now).inDays < 7)
            .length ??
        0;
    final subtitle = items == null
        ? null
        : '$open open · $soon due this week${filter.isEmpty ? '' : ' · filtered'}';

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
        const SingleActivator(LogicalKeyboardKey.keyS): () {
          final a = _cursorAssignment();
          if (a != null) actions.toggleStar(a);
        },
        const SingleActivator(LogicalKeyboardKey.keyR): () {
          final a = _cursorAssignment();
          if (a != null) actions.toggleDone(a);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () => _cursor.value = null,
        const SingleActivator(LogicalKeyboardKey.bracketLeft): () => _setView(0),
        const SingleActivator(LogicalKeyboardKey.bracketRight): () => _setView(1),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
        const SingleActivator(LogicalKeyboardKey.digit0): ref.read(courseFilterProvider.notifier).clear,
        for (var i = 0; i < _digitKeys.length; i++)
          SingleActivator(_digitKeys[i]): () => _toggleChipAt(i),
      },
      child: Focus(
        autofocus: true,
        focusNode: _focus,
        child: BreakpointBuilder<(bool, double, bool)>(
          mode: (box) => (
            box.maxWidth >= kDetailPaneBreakpoint,
            detailPaneWidthFor(box.maxWidth),
            box.maxWidth >= 1040,
          ),
          builder: (context, mode) {
            final (wide, paneWidth, showPoints) = mode;
            _wide = wide;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EPageHeader(
                  title: 'Assignments',
                  subtitle: subtitle,
                  actions: [ESyncButton(state: sync, onRefresh: _refresh)],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ESegmented(
                      labels: ['All', starredCount == 0 ? 'Starred' : 'Starred  $starredCount'],
                      selected: _view,
                      onChanged: _setView,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _body(
                          hasData: all != null,
                          failed: async.hasError && all == null,
                          sync: sync,
                          filterOn: filter.isNotEmpty,
                          courses: courses,
                          actions: actions,
                          now: now,
                          showPoints: showPoints,
                        ),
                      ),
                      if (_wide)
                        ValueListenableBuilder<int?>(
                          valueListenable: _cursor,
                          builder: (context, id, _) => DetailPane(
                            width: paneWidth,
                            identity: id,
                            onClose: () => _cursor.value = null,
                            child: id == null
                                ? null
                                : AssignmentDetail(key: ValueKey<int>(id), assignmentId: id),
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

  Widget _body({
    required bool hasData,
    required bool failed,
    required SyncState sync,
    required bool filterOn,
    required Map<int, Course> courses,
    required AssignmentActions actions,
    required DateTime now,
    required bool showPoints,
  }) {
    final error = sync.error;
    if (failed) return EErrorState(message: 'Something went wrong.', onRetry: _refresh);
    if (!hasData) {
      if (error != null && !sync.loading) {
        return EErrorState(message: error, onRetry: _refresh);
      }
      return const ESkeletonList();
    }
    if (_entries.isEmpty && _view == 1) {
      return const EEmptyState(
        icon: EIcons.star,
        title: 'No starred assignments',
        message: 'Star an assignment (click its star, or press S) to keep it here.',
      );
    }
    if (_entries.isEmpty) {
      // Fresh install: wait for the first sync before claiming it is empty.
      if (sync.lastUpdated == null && error == null) return const ESkeletonList();
      return EEmptyState(
        icon: EIcons.assignments,
        title: filterOn ? 'Nothing for these courses' : 'Nothing due',
        message: filterOn
            ? 'Choose other courses in the sidebar, or show them all.'
            : 'Enjoy the quiet. New work appears here as soon as Canvas has it.',
        action: filterOn
            ? EButton(
                label: 'Show all courses',
                onTap: ref.read(courseFilterProvider.notifier).clear,
              )
            : null,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AssignmentColumns(showPoints: showPoints),
          Expanded(
            child: ListView.builder(
                  controller: _scroll,
                  // Flutter is pinned to 3.47, which only has cacheExtent. Use scrollCacheExtent after unpinning (CLAUDE.md).
                  // ignore: deprecated_member_use
                  cacheExtent: 800,
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _entries.length,
                  itemExtentBuilder: (index, _) =>
                      _entries[index] is HeaderEntry ? kHeaderExtent : kRowExtent,
                  itemBuilder: (context, index) {
                    final e = _entries[index];
                    return switch (e) {
                      HeaderEntry(:final bucket, :final count) => bucket == TimelineBucket.earlier
                          ? EGroupHeader(
                              label: 'Done earlier',
                              count: count,
                              expanded: _showEarlier,
                              onTap: () => setState(() => _showEarlier = !_showEarlier),
                            )
                          : EGroupHeader(label: bucket.label, count: count),
                      ItemEntry(:final assignment) => HoverPrefetch(
                          key: ValueKey<int>(assignment.id),
                          onPrefetch: () => ref.read(
                            submissionInfoProvider(
                              (courseId: assignment.courseId, assignmentId: assignment.id),
                            ),
                          ),
                          child: AssignmentRow(
                            assignment: assignment,
                            course: courses[assignment.courseId],
                            cursor: _cursor,
                            now: now,
                            showPoints: showPoints,
                            onOpen: () => _select(assignment.id),
                            onToggleDone: () => actions.toggleDone(assignment),
                            onToggleStar: () => actions.toggleStar(assignment),
                          ),
                        ),
                    };
                  },
            ),
          ),
        ],
      ),
    );
  }
}
