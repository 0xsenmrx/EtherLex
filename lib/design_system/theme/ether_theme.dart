import 'package:material_ui/material_ui.dart';

import 'ether_colors.dart';
import 'ether_text.dart';

export 'ether_colors.dart';
export 'ether_text.dart';

/// Carries the EtherLex colours and text styles through [Theme], so a theme
/// switch animates every widget that reads them.
class EtherTheme extends ThemeExtension<EtherTheme> {
  const EtherTheme({required this.colors, required this.text});

  final EtherColors colors;
  final EtherText text;

  @override
  EtherTheme copyWith({EtherColors? colors, EtherText? text}) =>
      EtherTheme(colors: colors ?? this.colors, text: text ?? this.text);

  @override
  EtherTheme lerp(covariant EtherTheme? other, double t) {
    if (other == null) return this;
    final colors = this.colors.lerp(other.colors, t);
    final handwritten = (t < 0.5 ? text : other.text).handwritten;
    return EtherTheme(colors: colors, text: EtherText.build(colors, handwritten: handwritten));
  }
}

extension EtherContext on BuildContext {
  EtherTheme get ether => Theme.of(this).extension<EtherTheme>()!;
  EtherColors get colors => ether.colors;
  EtherText get text => ether.text;
}

ThemeData buildEtherTheme(EtherColors c, {required bool handwritten}) {
  final text = EtherText.build(c, handwritten: handwritten);
  const clear = Color(0x00000000);
  return ThemeData(
    brightness: c.brightness,
    colorScheme: ColorScheme(
      brightness: c.brightness,
      primary: c.accentFill,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.dangerFill,
      onError: c.onAccent,
      surface: c.surface,
      onSurface: c.textPrimary,
    ),
    fontFamily: text.family,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    splashFactory: NoSplash.splashFactory,
    highlightColor: clear,
    hoverColor: clear,
    focusColor: clear,
    dividerColor: c.line,
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll<double?>(6.0),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.resolveWith<Color?>(
        (states) => states.contains(WidgetState.hovered) ? c.textTertiary : c.lineStrong,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accentSoft,
      selectionHandleColor: c.accent,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.tooltip,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: text.meta.copyWith(color: c.onTooltip),
    ),
    extensions: <ThemeExtension<dynamic>>[EtherTheme(colors: c, text: text)],
  );
}
