import 'package:etherlex/features/settings/domain/settings_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rows = [
    SettingsSearchText(title: 'Theme', description: 'Light, dark or Windows', keywords: ['mode']),
    SettingsSearchText(title: 'API key', description: 'Kept in the Windows credential store', keywords: ['token']),
    SettingsSearchText(title: 'Deadlines and new grades', description: 'Windows notifications'),
    SettingsSearchText(title: 'Check automatically', description: 'Asks GitHub for a new release', keywords: ['update']),
  ];

  group('matchSettings', () {
    test('empty query matches nothing', () {
      expect(matchSettings('', rows), isEmpty);
      expect(matchSettings('   ', rows), isEmpty);
    });

    test('title, description and keywords all count, case ignored', () {
      expect(matchSettings('THEME', rows), [0]);
      expect(matchSettings('github', rows), [3]);
      expect(matchSettings('token', rows), [1]);
    });

    test('every word must match', () {
      expect(matchSettings('windows dark', rows), [0]);
      expect(matchSettings('windows nothing', rows), isEmpty);
    });

    test('title hits rank before description hits', () {
      // "windows" is in the descriptions of 0, 1 and 2; none in a title.
      expect(matchSettings('windows', rows), [0, 1, 2]);
      expect(matchSettings('grades', rows), [2]);
      final hits = matchSettings('a', rows);
      expect(hits.first, 1, reason: '"API key" starts with a');
    });
  });

  group('matchRanges', () {
    test('finds every occurrence, merged and sorted', () {
      expect(matchRanges('Dark theme, dark', 'dark'), [(0, 4), (12, 16)]);
      expect(matchRanges('Check automatically', 'auto check'), [(0, 5), (6, 10)]);
      expect(matchRanges('abc', 'ab bc'), [(0, 3)]);
      expect(matchRanges('Theme', ''), isEmpty);
    });
  });

  test('every section has a label', () {
    for (final s in SettingsSection.values) {
      expect(s.label, isNotEmpty);
    }
  });
}
