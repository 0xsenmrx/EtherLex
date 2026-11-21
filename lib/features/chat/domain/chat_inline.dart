/// A run of text inside one paragraph, with everything that applies to it.
///
/// For an image, [text] is the alt text and [link] the address of the picture.
class InlineRun {
  const InlineRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.link,
    this.image = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool strike;
  final bool code;

  /// Where a link points (or where an image lives).
  final String? link;
  final bool image;

  bool sameStyle(InlineRun o) =>
      o.bold == bold && o.italic == italic && o.strike == strike && o.code == code && o.link == link && o.image == image;

  @override
  bool operator ==(Object other) => other is InlineRun && other.text == text && sameStyle(other);

  @override
  int get hashCode => Object.hash(text, bold, italic, strike, code, link, image);

  /// "text" plus flags, for tests: `**b**` is `b{b}`, a link is `t{>url}`.
  @override
  String toString() {
    final f = [
      if (bold) 'b',
      if (italic) 'i',
      if (strike) 's',
      if (code) 'c',
      if (image) 'img',
      if (link != null) '>$link',
    ];
    return f.isEmpty ? text : '$text{${f.join(',')}}';
  }
}

class _Style {
  const _Style({this.bold = false, this.italic = false, this.strike = false, this.link});

  final bool bold;
  final bool italic;
  final bool strike;
  final String? link;

  _Style styled({bool? bold, bool? italic, bool? strike, String? link}) => _Style(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        strike: strike ?? this.strike,
        link: link ?? this.link,
      );
}

/// Characters a backslash turns into plain text.
const String _escapable = r'\`*_{}[]()#+-.!~|<>$';

/// The inline Markdown of one paragraph: **bold**, *italic*, ***both***,
/// ~~strike~~, `code`, [links](url), ![images](url), <https://autolinks> and
/// bare web addresses. Anything unfinished stays literal, so an answer that is
/// still arriving never flickers into the wrong shape for long.
List<InlineRun> parseInline(String source) {
  final out = <InlineRun>[];
  _inline(source, const _Style(), out);
  return _merge(out);
}

List<InlineRun> _merge(List<InlineRun> runs) {
  final merged = <InlineRun>[];
  for (final r in runs) {
    if (r.text.isEmpty && !r.image) continue;
    if (merged.isNotEmpty && !r.image && merged.last.sameStyle(r)) {
      final last = merged.removeLast();
      merged.add(InlineRun(
        last.text + r.text,
        bold: r.bold,
        italic: r.italic,
        strike: r.strike,
        code: r.code,
        link: r.link,
      ));
    } else {
      merged.add(r);
    }
  }
  return merged;
}

bool _isWord(String ch) => RegExp(r'[A-Za-z0-9]').hasMatch(ch);
bool _isSpace(String ch) => ch.trim().isEmpty;

void _inline(String s, _Style st, List<InlineRun> out) {
  final buf = StringBuffer();

  void flush() {
    if (buf.isEmpty) return;
    out.add(InlineRun(buf.toString(), bold: st.bold, italic: st.italic, strike: st.strike, link: st.link));
    buf.clear();
  }

  var i = 0;
  while (i < s.length) {
    final ch = s[i];

    if (ch == r'\' && i + 1 < s.length && _escapable.contains(s[i + 1])) {
      buf.write(s[i + 1]);
      i += 2;
      continue;
    }

    if (ch == '`') {
      var n = 1;
      while (i + n < s.length && s[i + n] == '`') {
        n++;
      }
      final close = _codeClose(s, i + n, n);
      if (close < 0) {
        buf.write(s.substring(i, i + n));
        i += n;
        continue;
      }
      var code = s.substring(i + n, close);
      if (code.length >= 2 && code.startsWith(' ') && code.endsWith(' ') && code.trim().isNotEmpty) {
        code = code.substring(1, code.length - 1);
      }
      flush();
      out.add(InlineRun(code, bold: st.bold, italic: st.italic, strike: st.strike, code: true, link: st.link));
      i = close + n;
      continue;
    }

    if (ch == '!' && i + 1 < s.length && s[i + 1] == '[') {
      final end = _bracketClose(s, i + 1);
      if (end > 0 && end + 1 < s.length && s[end + 1] == '(') {
        final dest = _destination(s, end + 2);
        if (dest != null) {
          flush();
          out.add(InlineRun(_plain(s.substring(i + 2, end)), image: true, link: dest.url));
          i = dest.end;
          continue;
        }
      }
    }

    if (ch == '[') {
      final end = _bracketClose(s, i);
      if (end > 0 && end + 1 < s.length && s[end + 1] == '(' && st.link == null) {
        final dest = _destination(s, end + 2);
        if (dest != null) {
          flush();
          _inline(s.substring(i + 1, end), st.styled(link: dest.url), out);
          i = dest.end;
          continue;
        }
      }
    }

    if (ch == '<' && st.link == null) {
      final close = s.indexOf('>', i + 1);
      if (close > i) {
        final inner = s.substring(i + 1, close);
        if (RegExp(r'^https?://\S+$').hasMatch(inner)) {
          flush();
          out.add(InlineRun(inner, bold: st.bold, italic: st.italic, strike: st.strike, link: inner));
          i = close + 1;
          continue;
        }
      }
    }

    if (ch == 'h' &&
        st.link == null &&
        (s.startsWith('https://', i) || s.startsWith('http://', i)) &&
        (i == 0 || !_isWord(s[i - 1]))) {
      var end = i;
      while (end < s.length && !_isSpace(s[end]) && s[end] != '<') {
        end++;
      }
      var url = s.substring(i, end);
      url = _trimUrl(url);
      if (url.length >= 9) {
        flush();
        out.add(InlineRun(url, bold: st.bold, italic: st.italic, strike: st.strike, link: url));
        i += url.length;
        continue;
      }
    }

    if (ch == '*' || ch == '_' || ch == '~') {
      var n = 1;
      while (i + n < s.length && s[i + n] == ch) {
        n++;
      }
      final maxUse = ch == '~' ? 2 : (n >= 3 ? 3 : n);
      final canOpen = i + n < s.length &&
          !_isSpace(s[i + n]) &&
          !(ch == '_' && i > 0 && _isWord(s[i - 1])) &&
          !(ch == '~' && n < 2);
      var used = 0;
      if (canOpen) {
        for (var use = maxUse; use >= 1; use--) {
          if (ch == '~' && use < 2) break;
          final close = _emphasisClose(s, i + use, ch, use);
          if (close < 0) continue;
          flush();
          final inner = s.substring(i + use, close);
          final style = switch ((ch, use)) {
            ('~', _) => st.styled(strike: true),
            (_, 3) => st.styled(bold: true, italic: true),
            (_, 2) => st.styled(bold: true),
            _ => st.styled(italic: true),
          };
          _inline(inner, style, out);
          i = close + use;
          used = use;
          break;
        }
      }
      if (used > 0) continue;
      buf.write(s.substring(i, i + n));
      i += n;
      continue;
    }

    buf.write(ch);
    i++;
  }
  flush();
}

/// The start of the closing backtick run that is exactly [n] long, or -1.
int _codeClose(String s, int from, int n) {
  var i = from;
  while (i < s.length) {
    if (s[i] == '`') {
      var m = 1;
      while (i + m < s.length && s[i + m] == '`') {
        m++;
      }
      if (m == n) return i;
      i += m;
    } else {
      i++;
    }
  }
  return -1;
}

/// The index of the `]` that closes the `[` at [open], or -1.
int _bracketClose(String s, int open) {
  var depth = 0;
  var i = open;
  while (i < s.length) {
    final ch = s[i];
    if (ch == r'\') {
      i += 2;
      continue;
    }
    if (ch == '[') depth++;
    if (ch == ']') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return -1;
}

/// The closing delimiter of an emphasis run: exactly [use] characters, with a
/// non-space before it. Skips code spans, escapes and longer or shorter runs
/// (those belong to emphasis nested inside).
int _emphasisClose(String s, int from, String ch, int use) {
  var i = from;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\') {
      i += 2;
      continue;
    }
    if (c == '`') {
      var n = 1;
      while (i + n < s.length && s[i + n] == '`') {
        n++;
      }
      final close = _codeClose(s, i + n, n);
      i = close < 0 ? i + n : close + n;
      continue;
    }
    if (c == ch) {
      var m = 1;
      while (i + m < s.length && s[i + m] == ch) {
        m++;
      }
      final afterOk = ch != '_' || i + m >= s.length || !_isWord(s[i + m]);
      if (m == use && i > from && !_isSpace(s[i - 1]) && afterOk) return i;
      i += m;
      continue;
    }
    i++;
  }
  return -1;
}

class _Dest {
  const _Dest(this.url, this.end);
  final String url;

  /// Just after the closing parenthesis.
  final int end;
}

/// The `(address "title")` part of a link, starting right after the `(`.
_Dest? _destination(String s, int from) {
  var i = from;
  while (i < s.length && (s[i] == ' ' || s[i] == '\n')) {
    i++;
  }
  String url;
  if (i < s.length && s[i] == '<') {
    final close = s.indexOf('>', i + 1);
    if (close < 0) return null;
    url = s.substring(i + 1, close);
    i = close + 1;
  } else {
    final start = i;
    var depth = 0;
    while (i < s.length && !_isSpace(s[i])) {
      if (s[i] == '(') depth++;
      if (s[i] == ')') {
        if (depth == 0) break;
        depth--;
      }
      i++;
    }
    url = s.substring(start, i);
  }
  while (i < s.length && _isSpace(s[i])) {
    i++;
  }
  if (i < s.length && (s[i] == '"' || s[i] == "'")) {
    final close = s.indexOf(s[i], i + 1);
    if (close < 0) return null;
    i = close + 1;
    while (i < s.length && _isSpace(s[i])) {
      i++;
    }
  }
  if (i >= s.length || s[i] != ')') return null;
  return _Dest(url, i + 1);
}

/// Alt text without its own Markup.
String _plain(String s) => s.replaceAll(RegExp(r'[*_`~]'), '');

/// A bare address without the punctuation that ends the sentence.
String _trimUrl(String url) {
  var u = url;
  while (u.isNotEmpty) {
    final last = u[u.length - 1];
    if ('.,;:!?\'"*_~]'.contains(last)) {
      u = u.substring(0, u.length - 1);
    } else if (last == ')' && ')'.allMatches(u).length > '('.allMatches(u).length) {
      u = u.substring(0, u.length - 1);
    } else {
      break;
    }
  }
  return u;
}
