/// One keyboard shortcut, as shown in the shortcuts window.
class ShortcutInfo {
  const ShortcutInfo(this.group, this.keys, this.description);

  /// Where it works: "Everywhere", "Lists", "Calendar"...
  final String group;

  /// Key caps, for example ['Ctrl', 'K']. Alternatives are separate entries.
  final List<String> keys;
  final String description;
}

/// Every shortcut in the app. Keep in sync with the CallbackShortcuts:
/// `test/shortcuts_bound_test.dart` checks each one is bound somewhere.
const List<ShortcutInfo> kShortcuts = [
  ShortcutInfo('Everywhere', ['Ctrl', 'K'], 'Command palette: search and actions'),
  ShortcutInfo('Everywhere', ['Ctrl', 'F'], 'Search assignments, announcements, files and chats'),
  ShortcutInfo('Everywhere', ['Alt', '1'], 'Go to Assignments'),
  ShortcutInfo('Everywhere', ['Alt', '2'], 'Go to Activity'),
  ShortcutInfo('Everywhere', ['Alt', '3'], 'Go to Calendar'),
  ShortcutInfo('Everywhere', ['Alt', '4'], 'Go to Grades'),
  ShortcutInfo('Everywhere', ['Alt', '5'], 'Go to Files'),
  ShortcutInfo('Everywhere', ['Alt', '6'], 'Go to Assistant'),
  ShortcutInfo('Everywhere', ['Ctrl', ','], 'Settings'),
  ShortcutInfo('Everywhere', ['Ctrl', '/'], 'Keyboard shortcuts'),
  ShortcutInfo('Everywhere', ['Ctrl', 'B'], 'Collapse or expand the sidebar'),
  ShortcutInfo('Everywhere', ['Ctrl', 'R'], 'Refresh this page from Canvas'),
  ShortcutInfo('Everywhere', ['F5'], 'Refresh this page from Canvas'),
  ShortcutInfo('Everywhere', ['Ctrl', 'N'], 'New chat with the assistant'),
  ShortcutInfo('Everywhere', ['F9'], 'Show frame times'),
  ShortcutInfo('Everywhere', ['Esc'], 'Close a dialog, clear the selection'),
  ShortcutInfo('Lists', ['J'], 'Next item'),
  ShortcutInfo('Lists', ['↓'], 'Next item'),
  ShortcutInfo('Lists', ['K'], 'Previous item'),
  ShortcutInfo('Lists', ['↑'], 'Previous item'),
  ShortcutInfo('Lists', ['Enter'], 'Open the selected item'),
  ShortcutInfo('Assignments', ['S'], 'Star or unstar'),
  ShortcutInfo('Assignments', ['R'], 'Mark done, or not done again'),
  ShortcutInfo('Assignments', ['1', '–', '9'], 'Filter by the nth course'),
  ShortcutInfo('Assignments', ['0'], 'Show all courses'),
  ShortcutInfo('Assignments', ['[', ']'], 'All or starred'),
  ShortcutInfo('Activity', ['[', ']'], 'Previous or next filter'),
  ShortcutInfo('Activity', ['U'], 'Mark as new again, to find it later'),
  ShortcutInfo('Calendar', ['←', '→'], 'Previous or next week'),
  ShortcutInfo('Calendar', ['T'], 'This week'),
  ShortcutInfo('Grades', ['P'], 'Open the grade planner'),
  ShortcutInfo('Grades', ['U'], 'Mark the course as new again, to find it later'),
  ShortcutInfo('Files', ['Backspace'], 'Up one folder'),
  ShortcutInfo('Files', ['Esc'], 'Up one folder'),
  ShortcutInfo('Files', ['Alt', '←'], 'Up one folder'),
  ShortcutInfo('Files', ['D'], 'Download the selected file'),
  ShortcutInfo('Files', ['H'], 'Hide or show the selected folder or course'),
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
