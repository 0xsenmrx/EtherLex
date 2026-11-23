import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/smooth_scroll.dart';
import '../../../design_system/ether/breakpoint.dart';
import '../../../design_system/ether/detail_pane.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../settings/presentation/view_prefs_provider.dart';
import '../domain/activity_feed.dart';
import '../domain/activity_item.dart';
import 'activity_dialog.dart';
import 'activity_providers.dart';
import 'activity_row.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  static const _filters = <(String, ActivityKind?)>[
    ('All', null),
    ('Announcements', ActivityKind.announcement),
    ('Grades', ActivityKind.grade),
    ('Discussions', ActivityKind.discussion),
  ];

  final SmoothScrollController _scroll = SmoothScrollController();
  final ValueNotifier<String?> _cursor = ValueNotifier<String?>(null);
  final FocusNode _focus = FocusNode();
  // The kind filter, remembered per account (by kind name, so a new filter
  // order never shows the wrong one).
  int get _filter {
    final kind = ref.read(viewPrefsProvider).activityKind;
    final i = _filters.indexWhere((f) => f.$2?.name == kind);
    return i < 0 ? 0 : i;
  }
  bool _wide = true;

  List<ActivityEntry> _feed = const [];
  List<double> _offsets = const [0];
  List<int> _rowIndexes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(activitySyncProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _cursor.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setFilter(int i) {
    ref.read(viewPrefsProvider.notifier).update((p) => p.copyWith(activityKind: () => _filters[i].$2?.name));
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  void _index(List<ActivityEntry> feed) {
    _feed = feed;
    final offsets = <double>[0];
    final rows = <int>[];
    for (var i = 0; i < feed.length; i++) {
      final e = feed[i];
      offsets.add(offsets.last + (e is ActivityHeader ? EGroupHeader.extent : kActivityRowExtent));
      if (e is ActivityRowEntry) rows.add(i);
    }
    _offsets = offsets;
    _rowIndexes = rows;
  }

  ActivityItem? _itemById(String? id) {
    if (id == null) return null;
    for (final i in _rowIndexes) {
      final item = (_feed[i] as ActivityRowEntry).item;
      if (item.id == id) return item;
    }
    return null;
  }

  void _move(int delta) {
    if (_rowIndexes.isEmpty) return;
    var pos = -1;
    final cur = _cursor.value;
    if (cur != null) {
      pos = _rowIndexes.indexWhere((i) => (_feed[i] as ActivityRowEntry).item.id == cur);
    }
    final next = pos < 0
        ? (delta > 0 ? 0 : _rowIndexes.length - 1)
        : (pos + delta).clamp(0, _rowIndexes.length - 1);
    final entryIndex = _rowIndexes[next];
    _cursor.value = (_feed[entryIndex] as ActivityRowEntry).item.id;
    _ensureVisible(entryIndex);
  }

  void _ensureVisible(int entryIndex) {
    if (!_scroll.hasClients) return;
    var top = _offsets[entryIndex];
    if (entryIndex > 0 && _feed[entryIndex - 1] is ActivityHeader) top = _offsets[entryIndex - 1];
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

  void _select(ActivityItem item) {
    _cursor.value = item.id;
    if (!_wide) _openDialog(item);
  }

  Future<void> _openDialog(ActivityItem item) async {
    final courses = ref.read(coursesByIdProvider);
    await showActivityDialog(context, item, item.courseId == null ? null : courses[item.courseId]);
    if (mounted) _focus.requestFocus();
  }

  void _refresh() => ref.read(activitySyncProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    ref.watch(viewPrefsProvider); // rebuild when the filter changes
    final async = ref.watch(activityProvider);
    final sync = ref.watch(activitySyncProvider);
    final courses = ref.watch(coursesByIdProvider);
    final disabled = ref.watch(disabledCoursesProvider);
    final courseFilter = ref.watch(courseFilterProvider);
    ref.listen(courseFilterProvider, (_, _) => _scrollToTop());
    final now = DateTime.now();
    final kind = _filters[_filter].$2;

    final all = async.value;
    final items = all == null
        ? null
        : [
            for (final i in all)
              if ((kind == null || i.kind == kind) &&
                  (courseFilter.isNotEmpty
                      ? courseFilter.contains(i.courseId)
                      : (i.courseId == null || !disabled.contains(i.courseId))))
                i,
          ];
    _index(items == null ? const <ActivityEntry>[] : buildActivityFeed(items, now));

    final Widget body;
    if (async.hasError && all == null) {
      body = EErrorState(message: 'Something went wrong.', onRetry: _refresh);
    } else if (all == null || (_feed.isEmpty && sync.lastUpdated == null && sync.error == null)) {
      body = sync.error != null && !sync.loading
          ? EErrorState(message: sync.error!, onRetry: _refresh)
          : const ESkeletonList(rowHeight: kActivityRowExtent);
    } else if (_feed.isEmpty) {
      body = EEmptyState(
        icon: EIcons.inbox,
        title: kind == null ? 'No recent activity' : 'Nothing here yet',
        message: 'Announcements, grades and discussions from your courses show up here.',
      );
    } else {
      body = ListView.builder(
            controller: _scroll,
            // Flutter is pinned to 3.47, which only has cacheExtent. Use scrollCacheExtent after unpinning (CLAUDE.md).
            // ignore: deprecated_member_use
            cacheExtent: 800,
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 32),
            itemCount: _feed.length,
            itemExtentBuilder: (index, _) =>
                _feed[index] is ActivityHeader ? EGroupHeader.extent : kActivityRowExtent,
            itemBuilder: (context, index) {
              final e = _feed[index];
              return switch (e) {
                ActivityHeader(:final bucket, :final count) =>
                  EGroupHeader(label: bucket.label, count: count),
                ActivityRowEntry(:final item) => ActivityRow(
                    key: ValueKey<String>(item.id),
                    item: item,
                    course: item.courseId == null ? null : courses[item.courseId],
                    now: now,
                    cursor: _cursor,
                    onOpen: () => _select(item),
                  ),
              };
            },
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.keyJ): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.keyK): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          final item = _itemById(_cursor.value);
          if (item != null && !_wide) _openDialog(item);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () => _cursor.value = null,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
        const SingleActivator(LogicalKeyboardKey.bracketLeft): () =>
            _setFilter((_filter - 1) % _filters.length),
        const SingleActivator(LogicalKeyboardKey.bracketRight): () =>
            _setFilter((_filter + 1) % _filters.length),
      },
      child: Focus(
        autofocus: true,
        focusNode: _focus,
        child: BreakpointBuilder<(bool, double)>(
          mode: (box) => (box.maxWidth >= kDetailPaneBreakpoint, detailPaneWidthFor(box.maxWidth)),
          builder: (context, mode) {
            final (wide, paneWidth) = mode;
            _wide = wide;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EPageHeader(
                  title: 'Activity',
                  subtitle: items == null ? null : '${items.length} updates',
                  actions: [ESyncButton(state: sync, onRefresh: _refresh)],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ESegmented(
                      labels: [for (final f in _filters) f.$1],
                      selected: _filter,
                      onChanged: _setFilter,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: body),
                      if (_wide)
                        ValueListenableBuilder<String?>(
                          valueListenable: _cursor,
                          builder: (context, id, _) {
                            final item = _itemById(id);
                            return DetailPane(
                              width: paneWidth,
                              identity: id,
                              onClose: () => _cursor.value = null,
                              child: item == null
                                  ? null
                                  : ActivityDetail(
                                      key: ValueKey<String>(item.id),
                                      item: item,
                                      course: item.courseId == null ? null : courses[item.courseId],
                                    ),
                            );
                          },
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
