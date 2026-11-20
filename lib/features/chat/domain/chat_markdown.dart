enum MdKind { paragraph, heading, bullet, numbered, quote, code }

class MdBlock {
  const MdBlock(this.kind, this.text, {this.marker = ''});

  final MdKind kind;
  final String text;

  /// "1." for numbered items, empty otherwise.
  final String marker;

  @override
  bool operator ==(Object other) =>
      other is MdBlock && other.kind == kind && other.text == text && other.marker == marker;

  @override
  int get hashCode => Object.hash(kind, text, marker);

  @override
  String toString() => 'MdBlock(${kind.name}, $text${marker.isEmpty ? '' : ', $marker'})';
}

final RegExp _heading = RegExp(r'^#{1,6}\s+(.*)$');
final RegExp _bullet = RegExp(r'^[-*+]\s+(.*)$');
final RegExp _numbered = RegExp(r'^(\d+)[.)]\s+(.*)$');

/// The blocks of an answer: paragraphs, headings, lists, quotes and code.
/// Small on purpose (the inline bold, italic and `code` are handled where the
/// text is drawn). An unclosed code fence runs to the end, so a half-streamed
/// answer already looks right.
List<MdBlock> parseChatMarkdown(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    blocks.add(MdBlock(MdKind.paragraph, paragraph.join(' ')));
    paragraph.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trim();
    if (trimmed.startsWith('```')) {
      flush();
      final code = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        code.add(lines[i]);
        i++;
      }
      i++; // the closing fence, if there is one
      blocks.add(MdBlock(MdKind.code, code.join('\n')));
      continue;
    }
    i++;
    if (trimmed.isEmpty) {
      flush();
      continue;
    }
    final h = _heading.firstMatch(trimmed);
    final b = _bullet.firstMatch(trimmed);
    final n = _numbered.firstMatch(trimmed);
    if (h != null) {
      flush();
      blocks.add(MdBlock(MdKind.heading, h.group(1)!));
    } else if (b != null) {
      flush();
      blocks.add(MdBlock(MdKind.bullet, b.group(1)!));
    } else if (n != null) {
      flush();
      blocks.add(MdBlock(MdKind.numbered, n.group(2)!, marker: '${n.group(1)}.'));
    } else if (trimmed.startsWith('>')) {
      flush();
      blocks.add(MdBlock(MdKind.quote, trimmed.replaceFirst(RegExp(r'^>\s?'), '')));
    } else {
      paragraph.add(trimmed);
    }
  }
  flush();
  return blocks;
}
