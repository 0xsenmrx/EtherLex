import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/shell/nav.dart';
import '../../../core/appearance/appearance.dart';
import '../../../core/notify/toast.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../activity/presentation/activity_dialog.dart';
import '../../activity/presentation/activity_providers.dart';
import '../../activity/presentation/activity_row.dart';
import '../../assignments/presentation/assignment_dialog.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../../auth/presentation/sign_out.dart';
import '../../grades/presentation/grades_providers.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../search/domain/search.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../domain/commands.dart';
import 'shortcuts_dialog.dart';

/// Ctrl+K: search plus actions, all from the keyboard. [searchOnly] (Ctrl+F)
/// leaves the actions out. [host] must stay mounted (the shell's context):
/// actions run on it after the palette closes.
Future<void> showCommandPalette(BuildContext host, {bool searchOnly = false}) =>
    showEtherDialog<void>(
      host,
      (_) => CommandPalette(host: host, searchOnly: searchOnly),
      maxWidth: 660,
      topFraction: 0.12,
    );

sealed class _Entry {
  const _Entry();
}

final class _SectionEntry extends _Entry {
  const _SectionEntry(this.label);
  final String label;
}

final class _CommandEntry extends _Entry {
  const _CommandEntry(this.command, this.icon, this.swatch, this.run);
  final PaletteCommand command;
  final IconData? icon;
  final Color? swatch;
  final VoidCallback run;
}

final class _HitEntry extends _Entry {
  const _HitEntry(this.hit);
  final SearchHit hit;
}

const double _sectionExtent = 30;
const double _rowExtent = 46;

class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key, required this.host, this.searchOnly = false});

  final BuildContext host;
  final bool searchOnly;

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  List<_Entry> _entries = const [];
  int _selected = -1;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
    // The dialog frame grabs focus when it opens, so ask for it again after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focus.hasFocus) _focus.requestFocus();
      });
      // Announcements and grades only exist locally once Activity has synced.
      final sync = ref.read(activitySyncProvider);
      if (sync.lastUpdated == null && !sync.loading) {
        ref.read(activitySyncProvider.notifier).refresh();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _ready = true;
      _build();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---- commands ------------------------------------------------------------

  void _close() => Navigator.of(context).pop();

  void _toast(String text) => ref.read(toastProvider.notifier).show(text);

  List<_CommandEntry> _commands() {
    final host = widget.host;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final appearance = ref.read(appearanceProvider);
    final looks = ref.read(appearanceProvider.notifier);
    final notificationsOn = ref.read(notificationsProvider);
    final filter = ref.read(courseFilterProvider);
    final disabled = ref.read(disabledCoursesProvider);
    final courses = [
      for (final e in ref.read(filterableCoursesProvider))
        if (!disabled.contains(e.course.id)) e.course,
    ];

    _CommandEntry cmd(
      String id,
      String title,
      String section,
      IconData? icon,
      VoidCallback run, {
      List<String> keywords = const [],
      String? hint,
      Color? swatch,
    }) =>
        _CommandEntry(
          PaletteCommand(id: id, title: title, section: section, keywords: keywords, hint: hint),
          icon,
          swatch,
          () {
            _close();
            run();
          },
        );

    return [
      for (final d in kDestinations)
        cmd('go:${d.path}', d.label, 'Go to', d.icon, () => GoRouter.of(host).go(d.path),
            keywords: ['go', 'open', 'page']),
      cmd('refresh', 'Refresh everything', 'Actions', EIcons.refresh, () {
        ref.read(syncProvider.notifier).refresh();
        ref.read(activitySyncProvider.notifier).refresh();
        ref.read(gradesSyncProvider.notifier).refresh();
        _toast('Refreshing from Canvas');
      }, keywords: ['sync', 'update', 'reload']),
      cmd(
        'theme:toggle',
        dark ? 'Switch to light theme' : 'Switch to dark theme',
        'Actions',
        dark ? EIcons.sun : EIcons.moon,
        () => looks.setTheme(dark ? ThemeChoice.light : ThemeChoice.dark),
        keywords: ['theme', 'appearance', 'dark', 'light', 'mode'],
      ),
      if (appearance.theme != ThemeChoice.system)
        cmd('theme:system', 'Match the Windows theme', 'Actions', EIcons.monitor,
            () => looks.setTheme(ThemeChoice.system),
            keywords: ['theme', 'system', 'appearance', 'auto']),
      cmd(
        'font',
        appearance.handwritten ? 'Use the clean font' : 'Use the handwritten font',
        'Actions',
        EIcons.pen,
        () => looks.setTypeface(
          appearance.handwritten ? TypefaceChoice.clean : TypefaceChoice.handwritten,
        ),
        keywords: ['font', 'typeface', 'handwriting', 'inter', 'ink'],
      ),
      cmd(
        'notifications',
        notificationsOn ? 'Turn notifications off' : 'Turn notifications on',
        'Actions',
        notificationsOn ? EIcons.bellOff : EIcons.bell,
        () {
          ref.read(notificationsProvider.notifier).toggle();
          _toast(notificationsOn ? 'Notifications off' : 'Notifications on');
        },
        keywords: ['alerts', 'bell', 'deadline'],
      ),
      if (filter.isNotEmpty)
        cmd('courses:all', 'Show all courses', 'Actions', EIcons.courses,
            ref.read(courseFilterProvider.notifier).clear,
            keywords: ['filter', 'clear', 'courses']),
      cmd('settings', 'Open settings', 'Actions', EIcons.settings, () => showSettings(host),
          keywords: ['preferences', 'options', 'account']),
      cmd('shortcuts', 'Keyboard shortcuts', 'Actions', EIcons.keyboard, () => showShortcuts(host),
          keywords: ['keys', 'hotkeys', 'help']),
      cmd('signout', 'Sign out…', 'Actions', EIcons.signOut, () async {
        // The palette is gone after the question; keep what we need now.
        final auth = ref.read(authProvider.notifier);
        final ok = await confirmSignOut(host, sample: ref.read(authProvider).value?.isSample ?? true);
        if (ok) auth.signOut();
      }, keywords: ['logout', 'log out', 'account', 'disconnect']),
      for (final course in courses)
        cmd(
          'course:${course.id}',
          course.name,
          'Courses',
          null,
          () {
            ref.read(courseFilterProvider.notifier).toggle(course.id);
            _toast(filter.contains(course.id) ? 'Stopped filtering by ${course.name}' : 'Showing ${course.name}');
          },
          keywords: ['filter', 'course', course.code],
          hint: filter.contains(course.id) ? 'Filtering' : 'Filter',
          swatch: CoursePalette.colorFor(course.id),
        ),
    ];
  }

  // ---- results -------------------------------------------------------------

  void _recompute() => setState(_build);

  // The controller also notifies on caret and selection moves; only a new
  // query needs new results.
  String _lastQuery = '';
  void _onText() {
    final q = _text.text.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    _recompute();
  }

  void _build() {
    final q = _text.text.trim();
    final entries = <_Entry>[];

    if (!widget.searchOnly) {
      final all = _commands();
      final byId = {for (final e in all) e.command.id: e};
      if (q.isEmpty) {
        // No query: pages and actions; courses only when asked for.
        String? section;
        for (final e in all) {
          if (e.command.section == 'Courses') continue;
          if (e.command.section != section) {
            section = e.command.section;
            entries.add(_SectionEntry(section));
          }
          entries.add(e);
        }
      } else {
        final matched = matchCommands(q, [for (final e in all) e.command], limit: 6);
        if (matched.isNotEmpty) {
          entries.add(const _SectionEntry('Commands'));
          for (final m in matched) {
            entries.add(byId[m.id]!);
          }
        }
      }
    }

    if (q.isNotEmpty) {
      final hits = searchAll(
        q,
        assignments: ref.read(assignmentsProvider).value ?? const [],
        activity: ref.read(activityProvider).value ?? const [],
        courses: ref.read(coursesByIdProvider),
        excludedCourses: ref.read(disabledCoursesProvider),
      );
      final work = [for (final h in hits) if (h.kind == HitKind.assignment) h];
      final posts = [for (final h in hits) if (h.kind == HitKind.activity) h];
      if (work.isNotEmpty) {
        entries.add(const _SectionEntry('Assignments'));
        entries.addAll(work.map(_HitEntry.new));
      }
      if (posts.isNotEmpty) {
        entries.add(const _SectionEntry('Announcements and grades'));
        entries.addAll(posts.map(_HitEntry.new));
      }
    }

    _entries = entries;
    _selected = entries.indexWhere((e) => e is! _SectionEntry);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _move(int delta) {
    if (_selected < 0) return;
    var i = _selected;
    do {
      i += delta;
    } while (i >= 0 && i < _entries.length && _entries[i] is _SectionEntry);
    if (i < 0 || i >= _entries.length) return;
    setState(() => _selected = i);
    if (!_scroll.hasClients) return;
    var top = 0.0;
    for (var k = 0; k < i; k++) {
      top += _entries[k] is _SectionEntry ? _sectionExtent : _rowExtent;
    }
    // Keep the section title visible when moving onto a group's first row.
    final headTop = i > 0 && _entries[i - 1] is _SectionEntry ? top - _sectionExtent : top;
    final view = _scroll.position.viewportDimension;
    if (headTop < _scroll.offset) {
      _scroll.jumpTo(headTop.clamp(0.0, _scroll.position.maxScrollExtent));
    } else if (top + _rowExtent > _scroll.offset + view) {
      _scroll.jumpTo((top + _rowExtent - view + 8).clamp(0.0, _scroll.position.maxScrollExtent));
    }
  }

  Future<void> _activate(int i) async {
    final e = _entries[i];
    switch (e) {
      case _SectionEntry():
        return;
      case _CommandEntry(:final run):
        run();
      case _HitEntry(:final hit):
        final a = hit.assignment;
        if (a != null) {
          await showAssignmentDialog(context, a.id);
        } else {
          await showActivityDialog(context, hit.activity!, hit.course);
        }
        // Back on the palette: put the cursor straight back in the field.
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    // Watching keeps the streams alive; new data re-runs the current query.
    ref.watch(assignmentsProvider);
    ref.watch(activityProvider);
    ref.listen(assignmentsProvider, (_, _) => _recompute());
    ref.listen(activityProvider, (_, _) => _recompute());
    final q = _text.text.trim();
    final now = DateTime.now();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Row(
            children: [
              Icon(EIcons.search, size: 18, color: c.textTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    autofocus: true,
                    style: t.body.copyWith(fontSize: t.handwritten ? 19 : 16.5),
                    cursorColor: c.accent,
                    onSubmitted: (_) {
                      if (_selected >= 0) _activate(_selected);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: widget.searchOnly
                          ? 'Search assignments and announcements'
                          : 'Search, or type a command',
                      hintStyle: t.body.copyWith(
                        fontSize: t.handwritten ? 19 : 16.5,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(height: 1, color: c.line),
        if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Text(
              q.isEmpty ? 'Type to search assignments and announcements.' : 'No matches for “$q”.',
              textAlign: TextAlign.center,
              style: t.bodySecondary,
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              controller: _scroll,
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              itemCount: _entries.length,
              itemExtentBuilder: (i, _) => _entries[i] is _SectionEntry ? _sectionExtent : _rowExtent,
              itemBuilder: (context, i) {
                final e = _entries[i];
                return switch (e) {
                  _SectionEntry(:final label) => Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Text(label.toUpperCase(), style: t.caption),
                    ),
                  _CommandEntry() => _Row(
                      selected: i == _selected,
                      onTap: () => _activate(i),
                      leading: e.swatch != null
                          ? ESwatch(e.swatch!, width: 10, height: 13)
                          : Icon(e.icon, size: 15, color: i == _selected ? c.accent : c.textSecondary),
                      title: e.command.title,
                      subtitle: null,
                      trailing: e.command.hint,
                    ),
                  _HitEntry(:final hit) => _hitRow(hit, i, now),
                };
              },
            ),
          ),
      ],
    );
  }

  Widget _hitRow(SearchHit hit, int i, DateTime now) {
    final a = hit.assignment;
    final item = hit.activity;
    final course = hit.course?.name;
    if (a != null) {
      final when = a.done ? 'Done' : (a.dueAt == null ? 'No due date' : formatDue(a.dueAt, now));
      return _Row(
        selected: i == _selected,
        onTap: () => _activate(i),
        leading: ESwatch(CoursePalette.colorFor(a.courseId), width: 10, height: 13),
        title: hit.title,
        subtitle: course,
        trailing: when,
      );
    }
    final color = activityColor(item!.kind);
    return _Row(
      selected: i == _selected,
      onTap: () => _activate(i),
      leading: Icon(activityIcon(item.kind), size: 15, color: color),
      title: hit.title,
      subtitle: course,
      trailing: formatAgo(item.createdAt, now),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.selected,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final sub = subtitle;
    final tr = trailing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: ETap(
          focusable: false,
        onTap: onTap,
        pressedScale: 0.995,
        builder: (context, tapState) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? c.selected : (tapState.hovered ? c.hover : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              SizedBox(width: 20, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
                    ),
                    if (sub != null) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.metaMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (tr != null) ...[
                const SizedBox(width: 12),
                Text(tr, style: t.metaMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
