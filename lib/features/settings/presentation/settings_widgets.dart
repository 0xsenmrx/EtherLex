import 'package:flutter/widgets.dart';

import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../domain/settings_search.dart';

/// [text] with the words of [query] marked, for search results.
TextSpan highlightedSpan(String text, String query, TextStyle style, Color mark) {
  final ranges = matchRanges(text, query);
  if (ranges.isEmpty) return TextSpan(text: text, style: style);
  final spans = <TextSpan>[];
  var at = 0;
  for (final (start, end) in ranges) {
    if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
    spans.add(TextSpan(text: text.substring(start, end), style: TextStyle(backgroundColor: mark)));
    at = end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return TextSpan(style: style, children: spans);
}

/// One setting: a rounded row with a title, one line saying what it does, and
/// its control on the right. [query] marks search hits.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.leading,
    this.query = '',
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final Widget? leading;
  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final d = description;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(highlightedSpan(title, query, t.label, c.accentSoft),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (d != null && d.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text.rich(highlightedSpan(d, query, t.meta.copyWith(color: c.textTertiary), c.accentSoft)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}

/// A quiet note between rows (privacy, where things are kept).
class SettingsBanner extends StatelessWidget {
  const SettingsBanner(this.text, {super.key, this.icon = EIcons.info});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: c.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: t.meta.copyWith(color: c.textSecondary))),
        ],
      ),
    );
  }
}
