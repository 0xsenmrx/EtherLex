import 'package:etherlex/core/appearance/appearance.dart';
import 'package:etherlex/design_system/theme/ether_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final base in [EtherColors.light, EtherColors.dark]) {
    final mode = base.isDark ? 'dark' : 'light';

    test('violet is the unchanged base ($mode)', () {
      expect(identical(base.withPalette(PaletteChoice.violet), base), isTrue);
    });

    test('every palette keeps surfaces, text and status colours ($mode)', () {
      for (final p in PaletteChoice.values) {
        final c = base.withPalette(p);
        expect(c.brightness, base.brightness, reason: p.name);
        expect(c.canvas, base.canvas, reason: p.name);
        expect(c.surface, base.surface, reason: p.name);
        expect(c.textPrimary, base.textPrimary, reason: p.name);
        expect(c.danger, base.danger, reason: p.name);
        expect(c.success, base.success, reason: p.name);
      }
    });

    test('palettes differ from each other in accent ($mode)', () {
      final accents = {for (final p in PaletteChoice.values) base.swatchOf(p).toARGB32()};
      expect(accents.length, PaletteChoice.values.length);
    });

    // WCAG AA for normal text: 4.5:1. Checked for every palette, on every
    // background text sits on.
    test('text colours reach 4.5:1 on canvas, surface and sunken ($mode)', () {
      for (final p in PaletteChoice.values) {
        final c = base.withPalette(p);
        final text = {
          'textPrimary': c.textPrimary,
          'textSecondary': c.textSecondary,
          'textTertiary': c.textTertiary,
          'accent (links)': c.accent,
          'danger': c.danger,
          'dueSoon': c.dueSoon,
          'success': c.success,
        };
        final backgrounds = {'canvas': c.canvas, 'surface': c.surface, 'sunken': c.sunken};
        for (final fg in text.entries) {
          for (final bg in backgrounds.entries) {
            expect(_contrast(fg.value, bg.value), greaterThanOrEqualTo(4.5),
                reason: '${fg.key} on ${bg.key}, ${p.name} $mode');
          }
        }
      }
    });

    test('white text on filled buttons reaches 4.5:1 ($mode)', () {
      for (final p in PaletteChoice.values) {
        final c = base.withPalette(p);
        expect(_contrast(c.onAccent, c.accentFill), greaterThanOrEqualTo(4.5), reason: 'accentFill ${p.name} $mode');
        expect(_contrast(c.onAccent, c.accentFillHover), greaterThanOrEqualTo(4.5),
            reason: 'accentFillHover ${p.name} $mode');
        expect(_contrast(c.onAccent, c.dangerFill), greaterThanOrEqualTo(4.5), reason: 'dangerFill $mode');
      }
    });

    test('tooltips are readable ($mode)', () {
      expect(_contrast(base.onTooltip, base.tooltip), greaterThanOrEqualTo(4.5));
    });
  }
}
