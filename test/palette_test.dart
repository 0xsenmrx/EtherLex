import 'package:etherlex/features/palette/domain/commands.dart';
import 'package:etherlex/features/palette/domain/shortcuts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cmds = [
    PaletteCommand(id: 'go:assignments', title: 'Assignments', section: 'Go to'),
    PaletteCommand(id: 'go:grades', title: 'Grades', section: 'Go to', keywords: ['marks']),
    PaletteCommand(id: 'theme:dark', title: 'Switch to dark theme', section: 'Actions', keywords: ['night']),
    PaletteCommand(id: 'settings', title: 'Open settings', section: 'Actions', keywords: ['preferences']),
  ];

  group('matchCommands', () {
    test('empty query returns all in order', () {
      expect(matchCommands('', cmds), cmds);
      expect(matchCommands('  ', cmds, limit: 2).length, 2);
    });

    test('every word must match', () {
      expect(matchCommands('dark theme', cmds).map((c) => c.id), ['theme:dark']);
      expect(matchCommands('dark grades', cmds), isEmpty);
    });

    test('keywords find commands, below title matches', () {
      expect(matchCommands('marks', cmds).map((c) => c.id), ['go:grades']);
      expect(matchCommands('night', cmds).map((c) => c.id), ['theme:dark']);
    });

    test('title start ranks above a later word', () {
      final list = [
        const PaletteCommand(id: 'b', title: 'Open grades', section: 'x'),
        const PaletteCommand(id: 'a', title: 'Grades', section: 'x'),
      ];
      expect(matchCommands('grades', list).map((c) => c.id), ['a', 'b']);
    });

    test('case does not matter', () {
      expect(matchCommands('SETTINGS', cmds).single.id, 'settings');
    });
  });

  group('filterShortcuts', () {
    test('empty query returns all', () {
      expect(filterShortcuts(''), kShortcuts);
    });

    test('matches description, group and keys', () {
      expect(filterShortcuts('planner').single.keys, ['P']);
      expect(filterShortcuts('calendar week').length, 2);
      expect(filterShortcuts('ctrl k').any((s) => s.description.startsWith('Command palette')), isTrue);
    });
  });
}
