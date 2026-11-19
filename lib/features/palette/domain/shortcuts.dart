/// One keyboard shortcut, as shown in the shortcuts window.
class ShortcutInfo {
  const ShortcutInfo(this.group, this.keys, this.description);

  /// Where it works: "Everywhere", "Lists", "Calendar"...
  final String group;

  /// Key caps, for example ['Ctrl', 'K']. Alternatives are separate entries.
  final List<String> keys;
  final String description;
}

/// Every shortcut in the app. Keep in sync with the CallbackShortcuts.
const List<ShortcutInfo> kShortcuts = [
  ShortcutInfo('Everywhere', ['Ctrl', 'K'], 'Command palette: search and actions'),
  ShortcutInfo('Everywhere', ['Ctrl', 'F'], 'Search assignments and announcements'),
  ShortcutInfo('Everywhere', ['Alt', '1'], 'Go to Assignments'),
  ShortcutInfo('Everywhere', ['Alt', '2'], 'Go to Activity'),
  ShortcutInfo('Everywhere', ['Alt', '3'], 'Go to Calendar'),
  ShortcutInfo('Everywhere', ['Alt', '4'], 'Go to Grades'),
  ShortcutInfo('Everywhere', ['Alt', '5'], 'Go to Files'),
  ShortcutInfo('Everywhere', ['Ctrl', ','], 'Settings'),
  ShortcutInfo('Everywhere', ['Ctrl', '/'], 'Keyboard shortcuts'),
  ShortcutInfo('Everywhere', ['Ctrl', 'R'], 'Refresh this page (also F5)'),
  ShortcutInfo('Everywhere', ['F9'], 'Show frame times'),
  ShortcutInfo('Everywhere', ['Esc'], 'Close a dialog, clear the selection'),
  ShortcutInfo('Lists', ['J'], 'Next item (also ↓)'),
  ShortcutInfo('Lists', ['K'], 'Previous item (also ↑)'),
  ShortcutInfo('Lists', ['Enter'], 'Open the selected item'),
  ShortcutInfo('Assignments', ['S'], 'Star or unstar'),
  ShortcutInfo('Assignments', ['R'], 'Mark done or open'),
  ShortcutInfo('Assignments', ['1', '–', '9'], 'Filter by the nth course'),
  ShortcutInfo('Assignments', ['0'], 'Show all courses'),
  ShortcutInfo('Assignments', ['[', ']'], 'All or starred'),
  ShortcutInfo('Activity', ['[', ']'], 'Previous or next filter'),
  ShortcutInfo('Calendar', ['←', '→'], 'Previous or next week'),
  ShortcutInfo('Calendar', ['T'], 'This week'),
  ShortcutInfo('Grades', ['P'], 'Open the grade planner'),
  ShortcutInfo('Files', ['Backspace'], 'Up one folder (also Esc, Alt+←)'),
  ShortcutInfo('Files', ['D'], 'Download the selected file'),
];

/// Shortcuts whose description, group or keys contain every word of [query].
List<ShortcutInfo> filterShortcuts(String query, [List<ShortcutInfo> all = kShortcuts]) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return all;
  return [
    for (final s in all)
      if (words.every((w) {
        final hay = '${s.description} ${s.group} ${s.keys.join(' ')}'.toLowerCase();
        return hay.contains(w);
      }))
        s,
  ];
}
