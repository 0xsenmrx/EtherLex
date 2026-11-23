/// How a table column is aligned.
enum ColumnAlign { none, left, center, right }

/// One block of an assistant answer. The text inside paragraphs, headings,
/// table cells and the like is still raw Markdown: see parseInline.
sealed class ChatBlock {
  const ChatBlock();
}

final class ParagraphBlock extends ChatBlock {
  const ParagraphBlock(this.text);
  final String text;

  @override
  String toString() => 'P($text)';
}

final class HeadingBlock extends ChatBlock {
  const HeadingBlock(this.level, this.text);
  final int level;
  final String text;

  @override
  String toString() => 'H$level($text)';
}

/// A fenced code block. [language] is lower case, empty when none was given.
final class CodeBlock extends ChatBlock {
  const CodeBlock(this.language, this.code);
  final String language;
  final String code;

  @override
  String toString() => 'CODE[$language]($code)';
}

final class QuoteBlock extends ChatBlock {
  const QuoteBlock(this.blocks);
  final List<ChatBlock> blocks;

  @override
  String toString() => 'Q{${blocks.join(';')}}';
}

final class ListItem {
  const ListItem(this.blocks, [this.checked]);
  final List<ChatBlock> blocks;

  /// null for a normal item, true or false for a task-list item.
  final bool? checked;

  @override
  String toString() => '${checked == null ? '' : (checked! ? '[x] ' : '[ ] ')}${blocks.join(',')}';
}

final class ListBlock extends ChatBlock {
  const ListBlock({required this.ordered, required this.start, required this.items});
  final bool ordered;
  final int start;
  final List<ListItem> items;

  @override
  String toString() => '${ordered ? 'OL$start' : 'UL'}[${items.join('|')}]';
}

final class RuleBlock extends ChatBlock {
  const RuleBlock();

  @override
  String toString() => 'HR';
}

final class TableBlock extends ChatBlock {
  const TableBlock({required this.header, required this.aligns, required this.rows});
  final List<String> header;
  final List<ColumnAlign> aligns;
  final List<List<String>> rows;

  @override
  String toString() =>
      'T(${header.join('|')}; ${aligns.map((a) => a.name[0]).join()}; ${rows.map((r) => r.join('|')).join(' / ')})';
}

final RegExp _fenceOpen = RegExp(r'^ {0,3}(`{3,}|~{3,})[ \t]*([^\s`]*)');
final RegExp _heading = RegExp(r'^ {0,3}(#{1,6})[ \t]+(.+?)(?:[ \t]+#+)?[ \t]*$');
final RegExp _rule = RegExp(r'^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$');
final RegExp _item = RegExp(r'^( *)([-*+]|\d{1,9}[.)])[ \t]+(\S.*)$');
final RegExp _quote = RegExp(r'^ {0,3}> ?(.*)$');
final RegExp _tableSep = RegExp(r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$');
final RegExp _sepCell = RegExp(r'^:?-+:?$');
final RegExp _task = RegExp(r'^\[([ xX])\][ \t]+(.*)$');
final RegExp _digit = RegExp(r'^\d');

/// The blocks of an answer, GitHub style: headings, paragraphs, nested bullet,
/// numbered and task lists, quotes, fenced code, tables and rules. An unclosed
/// code fence runs to the end, so a half-arrived answer already looks right.
///
/// Left out on purpose: indented code blocks (they clash with nested lists),
/// "setext" headings (a line of dashes is always a rule) and raw HTML.
List<ChatBlock> parseBlocks(String source) =>
    _parse(source.replaceAll('\r\n', '\n').replaceAll('\t', '    ').split('\n'));

bool _blockStart(String line) =>
    _fenceOpen.hasMatch(line) ||
    _heading.hasMatch(line) ||
    _rule.hasMatch(line) ||
    _item.hasMatch(line) ||
    _quote.hasMatch(line);

int _indent(String line) => line.length - line.trimLeft().length;

/// [line] without up to [n] leading spaces.
String _dedent(String line, int n) {
  var k = 0;
  while (k < n && k < line.length && line[k] == ' ') {
    k++;
  }
  return line.substring(k);
}

List<ChatBlock> _parse(List<String> lines) {
  final blocks = <ChatBlock>[];
  final para = <String>[];

  void flush() {
    if (para.isEmpty) return;
    blocks.add(ParagraphBlock(_joinLines(para)));
    para.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      flush();
      i++;
      continue;
    }

    final fence = _fenceOpen.firstMatch(line);
    if (fence != null) {
      flush();
      final marker = fence.group(1)!;
      final language = (fence.group(2) ?? '').toLowerCase();
      final indent = _indent(line);
      final close = RegExp('^ {0,3}${marker[0]}{${marker.length},}[ \\t]*\$');
      final code = <String>[];
      i++;
      while (i < lines.length && !close.hasMatch(lines[i])) {
        code.add(_dedent(lines[i], indent));
        i++;
      }
      i++; // the closing fence, if there is one
      blocks.add(CodeBlock(language, code.join('\n')));
      continue;
    }

    final heading = _heading.firstMatch(line);
    if (heading != null) {
      flush();
      blocks.add(HeadingBlock(heading.group(1)!.length, heading.group(2)!.trim()));
      i++;
      continue;
    }

    if (_rule.hasMatch(line)) {
      flush();
      blocks.add(const RuleBlock());
      i++;
      continue;
    }

    if (line.contains('|') && i + 1 < lines.length && lines[i + 1].contains('|') && _tableSep.hasMatch(lines[i + 1])) {
      final header = _cells(line);
      final sep = _cells(lines[i + 1]);
      if (header.length == sep.length && sep.every(_sepCell.hasMatch)) {
        flush();
        final aligns = [
          for (final c in sep)
            c.startsWith(':') && c.endsWith(':')
                ? ColumnAlign.center
                : c.endsWith(':')
                    ? ColumnAlign.right
                    : c.startsWith(':')
                        ? ColumnAlign.left
                        : ColumnAlign.none,
        ];
        final rows = <List<String>>[];
        var j = i + 2;
        while (j < lines.length && lines[j].trim().isNotEmpty && lines[j].contains('|')) {
          final cells = _cells(lines[j]);
          rows.add([for (var c = 0; c < header.length; c++) c < cells.length ? cells[c] : '']);
          j++;
        }
        blocks.add(TableBlock(header: header, aligns: aligns, rows: rows));
        i = j;
        continue;
      }
    }

    if (_quote.hasMatch(line)) {
      flush();
      final inner = <String>[];
      while (i < lines.length) {
        final m = _quote.firstMatch(lines[i]);
        if (m == null) {
          // A plain line right after quoted text still belongs to the quote.
          final plain = lines[i].trim().isNotEmpty && inner.isNotEmpty && inner.last.trim().isNotEmpty;
          if (plain && !_blockStart(lines[i])) {
            inner.add(lines[i]);
            i++;
            continue;
          }
          break;
        }
        inner.add(m.group(1)!);
        i++;
      }
      blocks.add(QuoteBlock(_parse(inner)));
      continue;
    }

    if (_item.hasMatch(line)) {
      flush();
      final (list, next) = _list(lines, i);
      blocks.add(list);
      i = next;
      continue;
    }

    para.add(line);
    i++;
  }
  flush();
  return blocks;
}

/// The list that starts at [start], and the line after it.
(ListBlock, int) _list(List<String> lines, int start) {
  final first = _item.firstMatch(lines[start])!;
  final baseIndent = first.group(1)!.length;
  final ordered = _digit.hasMatch(first.group(2)!);
  final startNumber = ordered ? int.tryParse(first.group(2)!.replaceAll(RegExp(r'\D'), '')) ?? 1 : 1;
  final items = <ListItem>[];

  var i = start;
  while (i < lines.length) {
    final m = _item.firstMatch(lines[i]);
    if (m == null || m.group(1)!.length != baseIndent || _digit.hasMatch(m.group(2)!) != ordered) break;

    var content = m.group(3)!;
    final contentIndent = baseIndent + m.group(2)!.length + 1;
    bool? checked;
    final task = _task.firstMatch(content);
    if (task != null) {
      checked = task.group(1) != ' ';
      content = task.group(2)!;
    }

    final itemLines = <String>[content];
    var j = i + 1;
    while (j < lines.length) {
      final l = lines[j];
      if (l.trim().isEmpty) {
        // Blank lines stay in the item only when more of it follows.
        var k = j + 1;
        while (k < lines.length && lines[k].trim().isEmpty) {
          k++;
        }
        if (k < lines.length && _indent(lines[k]) > baseIndent) {
          for (var b = j; b < k; b++) {
            itemLines.add('');
          }
          j = k;
          continue;
        }
        break;
      }
      if (_indent(l) > baseIndent) {
        itemLines.add(_dedent(l, contentIndent));
        j++;
        continue;
      }
      // Not indented: only a plain line right after text carries on the item.
      if (itemLines.last.trim().isNotEmpty && !_blockStart(l)) {
        itemLines.add(l.trim());
        j++;
        continue;
      }
      break;
    }
    items.add(ListItem(_parse(itemLines), checked));

    var k = j;
    while (k < lines.length && lines[k].trim().isEmpty) {
      k++;
    }
    final next = k < lines.length ? _item.firstMatch(lines[k]) : null;
    if (next != null && next.group(1)!.length == baseIndent && _digit.hasMatch(next.group(2)!) == ordered) {
      i = k;
      continue;
    }
    i = j;
    break;
  }
  return (ListBlock(ordered: ordered, start: startNumber, items: items), i);
}

/// The lines of a paragraph as one string. Two spaces or a backslash at the
/// end of a line is a hard break; any other line end becomes a space.
String _joinLines(List<String> lines) {
  final b = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i].trimLeft();
    var text = raw.trimRight();
    if (i == lines.length - 1) {
      b.write(text);
      break;
    }
    var hard = false;
    if (raw.endsWith('  ')) {
      hard = true;
    } else if (text.endsWith(r'\')) {
      hard = true;
      text = text.substring(0, text.length - 1);
    }
    b.write(text);
    b.write(hard ? '\n' : ' ');
  }
  return b.toString();
}

/// The cells of a table row, without the outer pipes. `\|` is a pipe in text.
List<String> _cells(String line) {
  var t = line.trim();
  if (t.startsWith('|')) t = t.substring(1);
  if (t.endsWith('|') && !t.endsWith(r'\|')) t = t.substring(0, t.length - 1);
  final cells = <String>[];
  final cell = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    if (t[i] == r'\' && i + 1 < t.length && t[i + 1] == '|') {
      cell.write('|');
      i++;
    } else if (t[i] == '|') {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(t[i]);
    }
  }
  cells.add(cell.toString().trim());
  return cells;
}
