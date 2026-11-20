import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../design_system/theme/ether_theme.dart';
import '../utils/file_link_markup.dart';
import '../utils/open_url.dart';

final RegExp _url = RegExp(r'https?://[^\s<>"]+');

/// Plain text where http(s) URLs are clickable and open in the browser.
///
/// Canvas file links (see file_link_markup.dart) are clickable too when
/// [onFile] is given; without it they show as plain words.
class LinkText extends StatefulWidget {
  const LinkText(this.text, {super.key, required this.style, this.onFile});

  final String text;
  final TextStyle style;

  /// Called with the course (0 if the link did not say) and the file id.
  final void Function(int courseId, int fileId)? onFile;

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
    final linkStyle = TextStyle(color: accent, decoration: TextDecoration.underline, decorationColor: accent);
    final spans = <InlineSpan>[];
    var last = 0;
    final text = widget.text;
    for (final m in fileLinkPattern.allMatches(text)) {
      _urlSpans(text.substring(last, m.start), linkStyle, spans);
      final file = fileLinkOf(m);
      final onFile = widget.onFile;
      if (onFile == null) {
        spans.add(TextSpan(text: file.name));
      } else {
        final tap = TapGestureRecognizer()..onTap = () => onFile(file.courseId, file.fileId);
        _recognizers.add(tap);
        spans.add(TextSpan(
          text: file.name,
          recognizer: tap,
          mouseCursor: SystemMouseCursors.click,
          style: linkStyle,
        ));
      }
      last = m.end;
    }
    _urlSpans(text.substring(last), linkStyle, spans);
    return spans;
  }

  /// [text] with its web addresses as links, added to [spans].
  void _urlSpans(String text, TextStyle linkStyle, List<InlineSpan> spans) {
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
        style: linkStyle,
      ));
      last = end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  }

  @override
  Widget build(BuildContext context) =>
      Text.rich(TextSpan(style: widget.style, children: _spans(context.colors.accent)));
}
