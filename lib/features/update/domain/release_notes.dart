enum NoteKind { heading, bullet, text }

class NoteLine {
  const NoteLine(this.kind, this.text);

  final NoteKind kind;
  final String text;

  @override
  bool operator ==(Object other) => other is NoteLine && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => '${kind.name}: $text';
}

/// Turns a release description (Markdown) into a few plain lines for the
/// update dialog: headings, bullets and paragraphs, without Markdown marks.
List<NoteLine> parseReleaseNotes(String body, {int maxLines = 60}) {
  final out = <NoteLine>[];
  for (final raw in body.split(RegExp(r'\r?\n'))) {
    if (out.length >= maxLines) break;
    final line = raw.trim();
    if (line.isEmpty || RegExp(r'^[-*_]{3,}$').hasMatch(line)) continue;
    final heading = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
    if (heading != null) {
      final text = _plain(heading[1]!);
      if (text.isNotEmpty) out.add(NoteLine(NoteKind.heading, text));
      continue;
    }
    final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      final text = _plain(bullet[1]!);
      if (text.isNotEmpty) out.add(NoteLine(NoteKind.bullet, text));
      continue;
    }
    final text = _plain(line);
    if (text.isNotEmpty) out.add(NoteLine(NoteKind.text, text));
  }
  return out;
}

String _plain(String s) => s
    .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*|__(.+?)__'), (m) => m[1] ?? m[2]!)
    .replaceAll('`', '')
    .trim();
