/// Something the command palette can do: go somewhere or run an action.
class PaletteCommand {
  const PaletteCommand({
    required this.id,
    required this.title,
    required this.section,
    this.keywords = const [],
    this.hint,
  });

  final String id;
  final String title;

  /// "Go to", "Actions", "Courses".
  final String section;

  /// Other words that should find it ("dark", "theme").
  final List<String> keywords;

  /// Quiet text on the right of the row.
  final String? hint;
}

/// Commands where every word of [query] appears in the title or keywords.
/// Title-start matches rank first; ties keep the given order. An empty
/// query returns everything in order.
List<PaletteCommand> matchCommands(String query, List<PaletteCommand> all, {int? limit}) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return limit == null ? all : all.take(limit).toList();
  final scored = <(PaletteCommand, double, int)>[];
  for (var i = 0; i < all.length; i++) {
    final cmd = all[i];
    final title = cmd.title.toLowerCase();
    final keys = cmd.keywords.map((k) => k.toLowerCase()).join(' ');
    var score = 0.0;
    var ok = true;
    for (final w in words) {
      if (title.startsWith(w)) {
        score += 3;
      } else if (title.contains(' $w')) {
        score += 2;
      } else if (title.contains(w)) {
        score += 1;
      } else if (keys.contains(w)) {
        score += 0.5;
      } else {
        ok = false;
        break;
      }
    }
    if (ok) scored.add((cmd, score, i));
  }
  scored.sort((a, b) {
    final c = b.$2.compareTo(a.$2);
    return c != 0 ? c : a.$3.compareTo(b.$3);
  });
  final out = [for (final s in scored) s.$1];
  return limit == null ? out : out.take(limit).toList();
}
