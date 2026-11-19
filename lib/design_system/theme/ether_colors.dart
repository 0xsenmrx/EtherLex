import 'package:flutter/widgets.dart';

/// Every colour of the EtherLex look. One instance per brightness; both share
/// the same names so widgets never branch on the theme.
@immutable
class EtherColors {
  const EtherColors({
    required this.brightness,
    required this.canvas,
    required this.dot,
    required this.surface,
    required this.sunken,
    required this.hover,
    required this.selected,
    required this.line,
    required this.lineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.onAccent,
    required this.accentSoft,
    required this.danger,
    required this.dueSoon,
    required this.success,
    required this.star,
    required this.scrim,
    required this.shadow,
  });

  final Brightness brightness;

  /// Window background behind everything: the dotted canvas.
  final Color canvas;
  final Color dot;

  /// Raised things: menus, dialogs, the floating rail.
  final Color surface;

  /// Inputs and wells, a step below the canvas.
  final Color sunken;
  final Color hover;
  final Color selected;
  final Color line;
  final Color lineStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentHover;
  final Color onAccent;
  final Color accentSoft;
  final Color danger;

  /// Due within a day: warm, but not alarming like [danger].
  final Color dueSoon;
  final Color success;
  final Color star;
  final Color scrim;
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  static const EtherColors dark = EtherColors(
    brightness: Brightness.dark,
    canvas: Color(0xFF0B0C0E),
    dot: Color(0xFF2A2C31),
    surface: Color(0xFF141519),
    sunken: Color(0xFF101114),
    hover: Color(0x0DFFFFFF),
    selected: Color(0x17FFFFFF),
    line: Color(0x17FFFFFF),
    lineStrong: Color(0x29FFFFFF),
    textPrimary: Color(0xFFEEEEF0),
    textSecondary: Color(0xFF9C9DA4),
    textTertiary: Color(0xFF64656C),
    accent: Color(0xFF8B5CF6),
    accentHover: Color(0xFF9F7AF8),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x298B5CF6),
    danger: Color(0xFFF87171),
    dueSoon: Color(0xFFFB923C),
    success: Color(0xFF4ADE80),
    star: Color(0xFFFACC15),
    scrim: Color(0x99000000),
    shadow: Color(0x80000000),
  );

  static const EtherColors light = EtherColors(
    brightness: Brightness.light,
    canvas: Color(0xFFFFFFFF),
    dot: Color(0xFFD5D5DA),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFF5F5F7),
    hover: Color(0x0A000000),
    selected: Color(0x12000000),
    line: Color(0x17000000),
    lineStrong: Color(0x29000000),
    textPrimary: Color(0xFF141416),
    textSecondary: Color(0xFF5C5D65),
    textTertiary: Color(0xFF95969D),
    accent: Color(0xFF7C3AED),
    accentHover: Color(0xFF6D28D9),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0x1A7C3AED),
    danger: Color(0xFFDC2626),
    dueSoon: Color(0xFFEA580C),
    success: Color(0xFF16A34A),
    star: Color(0xFFEAB308),
    scrim: Color(0x4D000000),
    shadow: Color(0x24000000),
  );

  EtherColors lerp(EtherColors o, double t) {
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return EtherColors(
      brightness: t < 0.5 ? brightness : o.brightness,
      canvas: l(canvas, o.canvas),
      dot: l(dot, o.dot),
      surface: l(surface, o.surface),
      sunken: l(sunken, o.sunken),
      hover: l(hover, o.hover),
      selected: l(selected, o.selected),
      line: l(line, o.line),
      lineStrong: l(lineStrong, o.lineStrong),
      textPrimary: l(textPrimary, o.textPrimary),
      textSecondary: l(textSecondary, o.textSecondary),
      textTertiary: l(textTertiary, o.textTertiary),
      accent: l(accent, o.accent),
      accentHover: l(accentHover, o.accentHover),
      onAccent: l(onAccent, o.onAccent),
      accentSoft: l(accentSoft, o.accentSoft),
      danger: l(danger, o.danger),
      dueSoon: l(dueSoon, o.dueSoon),
      success: l(success, o.success),
      star: l(star, o.star),
      scrim: l(scrim, o.scrim),
      shadow: l(shadow, o.shadow),
    );
  }
}
