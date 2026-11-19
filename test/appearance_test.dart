import 'dart:io';

import 'package:etherlex/core/appearance/appearance.dart';
import 'package:etherlex/core/utils/initials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('defaults: follow the system, handwritten', () {
    const a = Appearance();
    expect(a.theme, ThemeChoice.system);
    expect(a.handwritten, isTrue);
  });

  test('json round-trip', () {
    const a = Appearance(theme: ThemeChoice.dark, typeface: TypefaceChoice.clean);
    expect(Appearance.fromJson(a.toJson()), a);
  });

  test('unknown or broken values fall back to defaults', () {
    expect(Appearance.fromJson({'theme': 'purple', 'typeface': 3}), const Appearance());
    expect(Appearance.fromJson('nonsense'), const Appearance());
    expect(Appearance.fromJson(null), const Appearance());
  });

  test('store writes and reads back; missing file gives defaults', () async {
    final store = AppearanceStore(file: File('${dir.path}/sub/appearance.json'));
    expect(await store.read(), const Appearance());
    const a = Appearance(theme: ThemeChoice.light);
    await store.write(a);
    expect(await store.read(), a);
  });

  test('corrupt file gives defaults', () async {
    final f = File('${dir.path}/appearance.json')..writeAsStringSync('{not json');
    expect(await AppearanceStore(file: f).read(), const Appearance());
  });

  test('initials', () {
    expect(initialsOf('ARSEN AGHAYAN'), 'AA');
    expect(initialsOf('  arsen  '), 'A');
    expect(initialsOf('Mary Jane Watson'), 'MW');
    expect(initialsOf(''), '?');
  });
}
