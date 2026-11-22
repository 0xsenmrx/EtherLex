import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_info.dart';
import '../../../core/motion/smooth_scroll.dart';
import '../../../core/notify/toast.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../domain/settings_search.dart';
import 'settings_sections.dart';

/// The section Settings opened on last time (this run of the app).
SettingsSection _lastSection = SettingsSection.account;

/// Ctrl+,: every setting in sections, with search. [section] opens one
/// directly (for example the Assistant's "Open settings").
Future<void> showSettings(BuildContext context, {SettingsSection? section}) => showEtherDialog<void>(
      context,
      (_) => SettingsDialog(initial: section ?? _lastSection),
      maxWidth: 940,
      topFraction: 0.06,
    );

IconData _iconOf(SettingsSection s) => switch (s) {
      SettingsSection.account => EIcons.account,
      SettingsSection.appearance => EIcons.palette,
      SettingsSection.notifications => EIcons.bell,
      SettingsSection.courses => EIcons.courses,
      SettingsSection.assistant => EIcons.sparkles,
      SettingsSection.files => EIcons.storage,
      SettingsSection.updates => EIcons.download,
      SettingsSection.shortcuts => EIcons.keyboard,
      SettingsSection.about => EIcons.help,
    };

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key, this.initial = SettingsSection.account});

  final SettingsSection initial;

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late SettingsSection _section = widget.initial;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final SmoothScrollController _scroll = SmoothScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _lastSection = _section;
    _search.addListener(() {
      if (_search.text == _query) return; // caret moves notify too
      setState(() => _query = _search.text);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _go(SettingsSection s) {
    setState(() => _section = s);
    _lastSection = s;
    _search.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _reset(SettingsSection s, SettingsReset r) async {
    final ok = await confirmAction(
      context,
      title: 'Reset ${s.label}?',
      message: r.message,
      confirmLabel: 'Reset',
    );
    if (!ok || !mounted) return;
    r.run();
    ref.read(toastProvider.notifier).show('${s.label} reset to defaults');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = buildSettingsItems(context, ref);
    final resets = settingsResets(ref);
    final query = _query.trim();
    final searchable = [for (final i in items) if (i.searchable) i];
    final hits = query.isEmpty
        ? const <SettingsItem>[]
        : [for (final i in matchSettings(query, [for (final s in searchable) s.search])) searchable[i]];
    final hitCount = <SettingsSection, int>{};
    for (final h in hits) {
      hitCount[h.section] = (hitCount[h.section] ?? 0) + 1;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _searchFocus.requestFocus,
      },
      child: SizedBox(
        height: 660,
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < 700;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: compact ? 64 : 232,
                  child: _Sidebar(
                    compact: compact,
                    selected: query.isEmpty ? _section : null,
                    hitCount: query.isEmpty ? null : hitCount,
                    search: _search,
                    searchFocus: _searchFocus,
                    onSearchSubmit: () {
                      if (hits.isNotEmpty) _go(hits.first.section);
                    },
                    onSelect: _go,
                  ),
                ),
                Container(width: 1, color: c.line),
                Expanded(
                  child: query.isEmpty
                      ? _SectionPane(
                          section: _section,
                          items: [for (final i in items) if (i.section == _section) i],
                          reset: resets[_section],
                          onReset: (r) => _reset(_section, r),
                          scroll: _scroll,
                        )
                      : _ResultsPane(query: query, hits: hits, onOpen: _go, scroll: _scroll),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.selected,
    required this.hitCount,
    required this.search,
    required this.searchFocus,
    required this.onSearchSubmit,
    required this.onSelect,
  });

  final bool compact;

  /// Null while searching: no section is "open" then.
  final SettingsSection? selected;

  /// Hits per section while searching, else null.
  final Map<SettingsSection, int>? hitCount;
  final TextEditingController search;
  final FocusNode searchFocus;
  final VoidCallback onSearchSubmit;
  final ValueChanged<SettingsSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 20, compact ? 12 : 14, 12),
          child: compact
              ? Icon(EIcons.settings, size: 20, color: c.textSecondary)
              : Text('Settings', style: t.title),
        ),
        if (!compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: c.sunken,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  Icon(EIcons.search, size: 14, color: c.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: search,
                      focusNode: searchFocus,
                      autofocus: true,
                      style: t.body,
                      cursorColor: c.accent,
                      onSubmitted: (_) => onSearchSubmit(),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search settings',
                        hintStyle: t.body.copyWith(color: c.textTertiary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(compact ? 8 : 10, 0, compact ? 8 : 10, 12),
            children: [
              for (final s in SettingsSection.values)
                _SidebarItem(
                  section: s,
                  compact: compact,
                  selected: s == selected,
                  hits: hitCount?[s],
                  searching: hitCount != null,
                  onTap: () => onSelect(s),
                ),
            ],
          ),
        ),
        if (!compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 14, 16),
            child: Text('$kAppName $kAppVersion', style: t.metaMuted),
          ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.section,
    required this.compact,
    required this.selected,
    required this.hits,
    required this.searching,
    required this.onTap,
  });

  final SettingsSection section;
  final bool compact;
  final bool selected;
  final int? hits;
  final bool searching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final dim = searching && (hits ?? 0) == 0;
    final item = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ETap(
        onTap: onTap,
        pressedScale: 0.985,
        builder: (context, s) {
          final fg = dim
              ? c.textTertiary
              : (selected || s.hovered ? c.textPrimary : c.textSecondary);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 10),
            decoration: BoxDecoration(
              color: selected ? c.selected : (s.hovered ? c.hover : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(9),
              boxShadow: focusRing(c, s.focused),
            ),
            child: Row(
              mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(_iconOf(section), size: 16, color: selected ? c.accent : fg),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(section.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label.copyWith(color: fg)),
                  ),
                  if ((hits ?? 0) > 0) Text('$hits', style: t.metaMuted),
                ],
              ],
            ),
          );
        },
      ),
    );
    return compact ? Tooltip(message: section.label, child: item) : item;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 16, 14),
      child: Row(
        children: [
          Expanded(child: Text(title, style: t.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ...actions,
          const SizedBox(width: 6),
          EIconButton(
            icon: EIcons.close,
            tooltip: 'Close',
            size: 30,
            iconSize: 15,
            bordered: false,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _SectionPane extends StatelessWidget {
  const _SectionPane({
    required this.section,
    required this.items,
    required this.reset,
    required this.onReset,
    required this.scroll,
  });

  final SettingsSection section;
  final List<SettingsItem> items;
  final SettingsReset? reset;
  final ValueChanged<SettingsReset> onReset;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final r = reset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: section.label,
          actions: [
            if (r != null)
              EButton(label: 'Reset to defaults', icon: EIcons.reset, kind: EButtonKind.ghost, onTap: () => onReset(r)),
          ],
        ),
        Expanded(
          child: ListView.separated(
            key: ValueKey<SettingsSection>(section),
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => items[i].build(''),
          ),
        ),
      ],
    );
  }
}

class _ResultsPane extends StatelessWidget {
  const _ResultsPane({required this.query, required this.hits, required this.onOpen, required this.scroll});

  final String query;
  final List<SettingsItem> hits;
  final ValueChanged<SettingsSection> onOpen;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    // Grouped by section, in sidebar order; best hits first inside a section.
    final groups = <SettingsSection, List<SettingsItem>>{
      for (final s in SettingsSection.values)
        if (hits.any((h) => h.section == s)) s: [for (final h in hits) if (h.section == s) h],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: hits.isEmpty ? 'No setting matches' : 'Results for \u201c$query\u201d'),
        Expanded(
          child: hits.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Text('Try another word, like "dark", "key" or "notifications".', style: t.bodySecondary),
                )
              : ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: ETap(
                          onTap: () => onOpen(entry.key),
                          builder: (context, s) => Row(
                            children: [
                              Icon(_iconOf(entry.key), size: 14, color: s.hovered ? c.accent : c.textTertiary),
                              const SizedBox(width: 8),
                              Text(entry.key.label.toUpperCase(),
                                  style: t.caption.copyWith(color: s.hovered ? c.accent : c.textTertiary)),
                              const SizedBox(width: 6),
                              Icon(EIcons.chevronRight, size: 12, color: s.hovered ? c.accent : c.textTertiary),
                            ],
                          ),
                        ),
                      ),
                      for (final h in entry.value)
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: h.build(query)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
