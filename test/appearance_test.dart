import 'dart:io';

import 'package:etherlex/core/appearance/appearance.dart';
import 'package:etherlex/core/utils/initials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_test_'));
  tearDown(() {
    // Windows can still hold a just-written file for a moment; a leftover temp folder is harmless.
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  test('defaults: follow the system, handwritten', () {
    const a = Appearance();
    expect(a.theme, ThemeChoice.system);
    expect(a.handwritten, isTrue);
  });

  test('json round-trip', () {
    const a = Appearance(theme: ThemeChoice.dark, typeface: TypefaceChoice.clean);
    expect(Appearance.fromJson(a.toJson()), a);
  });

  test('the colour palette is saved and defaults to violet', () {
    expect(const Appearance().palette, PaletteChoice.violet);
    const a = Appearance(palette: PaletteChoice.green);
    expect(Appearance.fromJson(a.toJson()), a);
    expect(Appearance.fromJson({'theme': 'dark'}).palette, PaletteChoice.violet);
    expect(Appearance.fromJson({'palette': 'neon'}).palette, PaletteChoice.violet);
  });

  test('the background pattern is saved and defaults to dots', () {
    expect(const Appearance().background, BackgroundPattern.dots);
    const a = Appearance(background: BackgroundPattern.grid);
    expect(Appearance.fromJson(a.toJson()), a);
    expect(Appearance.fromJson({'theme': 'dark'}).background, BackgroundPattern.dots);
    expect(Appearance.fromJson({'background': 'stripes'}).background, BackgroundPattern.dots);
    expect(a == const Appearance(), isFalse);
  });

  test('the collapsed sidebar is remembered; reset keeps it', () {
    expect(const Appearance().sidebarCollapsed, isFalse);
    const a = Appearance(sidebarCollapsed: true);
    expect(Appearance.fromJson(a.toJson()), a);
    expect(Appearance.fromJson({'sidebarCollapsed': 'yes'}).sidebarCollapsed, isFalse);
    expect(a == const Appearance(), isFalse);
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
