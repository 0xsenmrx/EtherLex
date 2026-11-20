import 'package:flutter/widgets.dart';

import '../../../design_system/theme/ether_theme.dart';

const List<String> kMonoFallback = ['Cascadia Mono', 'Consolas', 'Menlo', 'monospace'];
const _mono = TextStyle(fontFamilyFallback: kMonoFallback, fontSize: 13, height: 1.5);

/// Documents always read in the clean face, even with the handwritten UI font.
TextStyle readerStyle(BuildContext context) => TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Segoe UI'],
      fontSize: 14.5,
      height: 1.6,
      color: context.colors.textPrimary,
    );

/// **bold**, *italic*, `code` inside one line.
List<InlineSpan> inlineSpans(String text, TextStyle base, {required Color code, required Color codeBackground}) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|_(.+?)_|`(.+?)`');
  var i = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start), style: base));
    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1), style: base.copyWith(fontWeight: FontWeight.w700)));
    } else if (m.group(2) != null || m.group(3) != null) {
      spans.add(TextSpan(text: m.group(2) ?? m.group(3), style: base.copyWith(fontStyle: FontStyle.italic)));
    } else {
      spans.add(
        TextSpan(
          text: m.group(4),
          style: base.merge(_mono).copyWith(color: code, backgroundColor: codeBackground),
        ),
      );
    }
    i = m.end;
  }
  if (i < text.length) spans.add(TextSpan(text: text.substring(i), style: base));
  return spans;
}

/// A small, fast Markdown renderer: headings, lists, quotes, code, rules.
class MarkdownView extends StatefulWidget {
  const MarkdownView({super.key, required this.source});
  final String source;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  // Parsed once per source and theme: the dialog rebuilds on every frame of
  // a window resize, and re-parsing a long document each time is wasted work.
  List<Widget>? _children;
  String? _parsedSource;
  Object? _parsedColors;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var children = _children;
    if (children == null || _parsedSource != widget.source || !identical(_parsedColors, colors)) {
      children = _children = _parse(context);
      _parsedSource = widget.source;
      _parsedColors = colors;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      // Flutter is pinned to 3.47, which only has cacheExtent. Use scrollCacheExtent after unpinning (CLAUDE.md).
      // ignore: deprecated_member_use
      cacheExtent: 600,
      children: children,
    );
  }

  List<Widget> _parse(BuildContext context) {
    final source = widget.source;
    final c = context.colors;
    final body = readerStyle(context);
    List<InlineSpan> spans(String text, TextStyle base) =>
        inlineSpans(text, base, code: c.accent, codeBackground: c.selected);
    final children = <Widget>[];
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        final code = <String>[];
        i++;
        while (i < lines.length && !lines[i].trimLeft().startsWith('```')) {
          code.add(lines[i++]);
        }
        i++;
        children.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.sunken,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line),
            ),
            child: Text(code.join('\n'), style: _mono.copyWith(color: c.textPrimary)),
          ),
        );
        continue;
      }
      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (h != null) {
        final level = h.group(1)!.length;
        final size = const [26.0, 21.0, 17.0, 15.0, 14.0, 14.0][level - 1];
        children.add(
          Padding(
            padding: EdgeInsets.only(top: level <= 2 ? 18 : 12, bottom: 6),
            child: Text.rich(
              TextSpan(
                children: spans(
                  h.group(2)!,
                  body.copyWith(fontSize: size, fontWeight: FontWeight.w700, height: 1.3),
                ),
              ),
            ),
          ),
        );
      } else if (RegExp(r'^\s*([-*+]|\d+[.)])\s+').hasMatch(line)) {
        final m = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(.*)$').firstMatch(line)!;
        final ordered = RegExp(r'\d').hasMatch(m.group(2)!);
        children.add(
          Padding(
            padding: EdgeInsets.only(left: 6.0 + m.group(1)!.length * 6, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 24, child: Text(ordered ? m.group(2)! : '•', style: body)),
                Expanded(
                  child: Text.rich(TextSpan(children: spans(m.group(3)!, body.copyWith(height: 1.5)))),
                ),
              ],
            ),
          ),
        );
      } else if (line.trimLeft().startsWith('>')) {
        children.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: c.lineStrong, width: 3)),
            ),
            child: Text.rich(
              TextSpan(
                children: spans(
                  line.trimLeft().substring(1).trim(),
                  body.copyWith(color: c.textSecondary, height: 1.5),
                ),
              ),
            ),
          ),
        );
      } else if (RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$').hasMatch(line)) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(height: 1, child: ColoredBox(color: c.line)),
          ),
        );
      } else if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(TextSpan(children: spans(line, body))),
          ),
        );
      }
      i++;
    }
    return children;
  }
}
