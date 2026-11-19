import 'package:material_ui/material_ui.dart';

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../domain/shortcuts.dart';

/// Ctrl+/: every shortcut, grouped, with a filter box.
Future<void> showShortcuts(BuildContext context) =>
    showEtherDialog<void>(context, (_) => const ShortcutsDialog(), maxWidth: 600, topFraction: 0.08);

class ShortcutsDialog extends StatefulWidget {
  const ShortcutsDialog({super.key});

  @override
  State<ShortcutsDialog> createState() => _ShortcutsDialogState();
}

class _ShortcutsDialogState extends State<ShortcutsDialog> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final list = filterShortcuts(_text.text);
    final groups = <String, List<ShortcutInfo>>{};
    for (final s in list) {
      groups.putIfAbsent(s.group, () => []).add(s);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
          child: Row(
            children: [
              Expanded(child: Text('Keyboard shortcuts', style: t.title)),
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.sunken,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Icon(EIcons.search, size: 15, color: c.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    style: t.body,
                    cursorColor: c.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Filter shortcuts',
                      hintStyle: t.body.copyWith(color: c.textTertiary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(height: 1, color: c.line),
        Flexible(
          child: list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text('No shortcut matches.', textAlign: TextAlign.center, style: t.bodySecondary),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 4),
                        child: Text(entry.key.toUpperCase(), style: t.caption),
                      ),
                      for (final s in entry.value)
                        Container(
                          height: 38,
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(s.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body),
                              ),
                              const SizedBox(width: 12),
                              for (var i = 0; i < s.keys.length; i++) ...[
                                if (i > 0) const SizedBox(width: 4),
                                EKeyCap(s.keys[i]),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
