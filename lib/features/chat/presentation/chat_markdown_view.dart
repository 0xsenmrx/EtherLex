import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show SelectableText;

import '../../../design_system/theme/ether_theme.dart';
import '../../viewer/presentation/markdown_view.dart';
import '../domain/chat_markdown.dart';

/// An assistant answer: Markdown blocks in the clean reading font, selectable.
class ChatMarkdown extends StatelessWidget {
  const ChatMarkdown(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final base = readerStyle(context);
    final mono = TextStyle(
      fontFamily: kMonoFallback.first,
      fontFamilyFallback: kMonoFallback.sublist(1),
      fontSize: 13,
      height: 1.5,
      color: c.textPrimary,
    );

    Widget text(String s, TextStyle style) => SelectableText.rich(
          TextSpan(children: inlineSpans(s, style, code: c.textPrimary, codeBackground: c.sunken)),
        );

    final children = <Widget>[];
    for (final block in parseChatMarkdown(source)) {
      final Widget w;
      switch (block.kind) {
        case MdKind.paragraph:
          w = text(block.text, base);
        case MdKind.heading:
          w = text(block.text, base.copyWith(fontWeight: FontWeight.w700, fontSize: 16));
        case MdKind.bullet:
        case MdKind.numbered:
          w = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(block.kind == MdKind.bullet ? '•' : block.marker, style: base.copyWith(color: c.textSecondary)),
              ),
              Expanded(child: text(block.text, base)),
            ],
          );
        case MdKind.quote:
          w = Container(
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: c.lineStrong, width: 3))),
            child: text(block.text, base.copyWith(color: c.textSecondary)),
          );
        case MdKind.code:
          w = Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.sunken,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line),
            ),
            child: SelectableText(block.text, style: mono),
          );
      }
      if (children.isNotEmpty) children.add(const SizedBox(height: 8));
      children.add(w);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
