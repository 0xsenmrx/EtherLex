/// The sections of the Settings dialog, in sidebar order.
enum SettingsSection {
  account('Account'),
  appearance('Appearance'),
  notifications('Notifications'),
  courses('Courses'),
  assistant('Assistant'),
  files('Files & downloads'),
  updates('Updates'),
  shortcuts('Keyboard shortcuts'),
  about('Help & About');

  const SettingsSection(this.label);
  final String label;
}

/// What the Settings search reads for one row.
class SettingsSearchText {
  const SettingsSearchText({required this.title, this.description = '', this.keywords = const []});

  final String title;
  final String description;

  /// Other words that should find the row ("dark" for Theme).
  final List<String> keywords;
}

List<String> _words(String query) =>
    query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Indexes of the [rows] where every word of [query] appears in the title,
/// description or keywords (case ignored), best first: words at the start of
/// the title, then anywhere in it, then in the description, then keywords.
/// Ties keep their order. An empty query matches nothing.
List<int> matchSettings(String query, List<SettingsSearchText> rows) {
  final words = _words(query);
  if (words.isEmpty) return const [];
  final scored = <(int, double)>[];
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final title = r.title.toLowerCase();
    final description = r.description.toLowerCase();
    final keywords = r.keywords.map((k) => k.toLowerCase()).join(' ');
    var score = 0.0;
    var all = true;
    for (final w in words) {
      if (title.startsWith(w)) {
        score += 4;
      } else if (title.contains(' $w')) {
        score += 3;
      } else if (title.contains(w)) {
        score += 2;
      } else if (description.contains(w)) {
        score += 1;
      } else if (keywords.contains(w)) {
        score += 0.5;
      } else {
        all = false;
        break;
      }
    }
    if (all) scored.add((i, score));
  }
  // Stable: equal scores keep the given order.
  final order = [for (var i = 0; i < scored.length; i++) i]
    ..sort((a, b) {
      final c = scored[b].$2.compareTo(scored[a].$2);
      return c != 0 ? c : a.compareTo(b);
    });
  return [for (final i in order) scored[i].$1];
}

/// Where the words of [query] occur in [text], as sorted, non-overlapping
/// (start, end) ranges, for highlighting a search hit.
List<(int, int)> matchRanges(String text, String query) {
  final lower = text.toLowerCase();
  final ranges = <(int, int)>[];
  for (final w in _words(query)) {
    var from = 0;
    while (true) {
      final i = lower.indexOf(w, from);
      if (i < 0) break;
      ranges.add((i, i + w.length));
      from = i + w.length;
    }
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final r in ranges) {
    if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
    } else {
      merged.add(r);
    }
  }
  return merged;
}
