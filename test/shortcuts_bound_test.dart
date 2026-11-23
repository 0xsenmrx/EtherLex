import 'dart:io';

import 'package:etherlex/features/palette/domain/shortcuts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The LogicalKeyboardKey name of a key cap in the shortcuts list.
String? keyName(String cap) {
  const named = {
    'Enter': 'enter',
    'Esc': 'escape',
    'Backspace': 'backspace',
    ',': 'comma',
    '/': 'slash',
    '[': 'bracketLeft',
    ']': 'bracketRight',
    '←': 'arrowLeft',
    '→': 'arrowRight',
    '↑': 'arrowUp',
    '↓': 'arrowDown',
    'F5': 'f5',
    'F9': 'f9',
  };
  if (named.containsKey(cap)) return named[cap];
  if (RegExp(r'^[A-Z]$').hasMatch(cap)) return 'key$cap';
  if (RegExp(r'^[0-9]$').hasMatch(cap)) return 'digit$cap';
  return null;
}

void main() {
  // Every line of app code that names a key, so the list cannot promise a
  // shortcut that nothing binds.
  final lines = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) ...f.readAsLinesSync(),
  ].where((l) => l.contains('LogicalKeyboardKey.')).toList();

  for (final s in kShortcuts) {
    test('bound: ${s.keys.join('+')} (${s.group}: ${s.description})', () {
      final ctrl = s.keys.contains('Ctrl');
      final alt = s.keys.contains('Alt');
      for (final cap in s.keys) {
        if (cap == 'Ctrl' || cap == 'Alt' || cap == '–') continue;
        final name = keyName(cap);
        expect(name, isNotNull, reason: 'unknown key cap "$cap"');
        final found = lines.any((l) =>
            RegExp('LogicalKeyboardKey\\.$name\\b').hasMatch(l) &&
            l.contains('control: true') == ctrl &&
            l.contains('alt: true') == alt);
        expect(found, isTrue, reason: '${s.keys.join('+')} is listed but not bound');
      }
    });
  }

  test('no shortcut is listed twice in a group', () {
    final seen = <String>{};
    for (final s in kShortcuts) {
      expect(seen.add('${s.group}|${s.keys.join('+')}'), isTrue, reason: '${s.group} ${s.keys}');
    }
  });
}
