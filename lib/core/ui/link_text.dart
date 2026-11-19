import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../design_system/theme/ether_theme.dart';
import '../utils/open_url.dart';

final RegExp _url = RegExp(r'https?://[^\s<>"]+');

/// Plain text where http(s) URLs are clickable and open in the browser.
class LinkText extends StatefulWidget {
  const LinkText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  List<InlineSpan> _spans(Color accent) {
    _disposeRecognizers();
    final text = widget.text;
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _url.allMatches(text)) {
      var url = m.group(0)!;
      // Trailing punctuation belongs to the sentence, not the link.
      final trimmed = url.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');
      final end = m.start + trimmed.length;
      url = trimmed;
      if (url.length < 9) continue;
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tap = TapGestureRecognizer()..onTap = () => openExternal(url.replaceFirst('http://', 'https://'));
      _recognizers.add(tap);
      spans.add(TextSpan(
        text: url,
        recognizer: tap,
        mouseCursor: SystemMouseCursors.click,
        style: TextStyle(color: accent, decoration: TextDecoration.underline, decorationColor: accent),
      ));
      last = end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) =>
      Text.rich(TextSpan(style: widget.style, children: _spans(context.colors.accent)));
}
