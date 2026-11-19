import 'package:flutter/widgets.dart';

import 'ether_colors.dart';

/// Text styles for one colour set and one typeface choice.
///
/// Handwritten uses Windows' own Ink Free (falls back to Segoe Print, then
/// Inter). It has a single weight and a small eye, so it runs larger and
/// builds hierarchy from size and colour instead of weight.
@immutable
class EtherText {
  const EtherText._({
    required this.handwritten,
    required this.family,
    required this.brand,
    required this.display,
    required this.title,
    required this.heading,
    required this.body,
    required this.bodySecondary,
    required this.label,
    required this.meta,
    required this.metaMuted,
    required this.caption,
    required this.number,
    required this.button,
  });

  factory EtherText.build(EtherColors c, {required bool handwritten}) {
    final family = handwritten ? 'Ink Free' : 'Inter';
    final fallback = handwritten ? const ['Segoe Print', 'Inter'] : const ['Segoe UI'];

    TextStyle s(
      double clean,
      double hand, {
      FontWeight weight = FontWeight.w400,
      Color? color,
      double height = 1.3,
      double spacing = 0,
      double handSpacing = 0,
    }) {
      return TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: handwritten ? hand : clean,
        fontWeight: handwritten ? FontWeight.w400 : weight,
        height: height,
        letterSpacing: handwritten ? handSpacing : spacing,
        color: color ?? c.textPrimary,
      );
    }

    return EtherText._(
      handwritten: handwritten,
      family: family,
      brand: s(17, 22, spacing: -0.3).copyWith(fontWeight: FontWeight.w700),
      display: s(26, 32, weight: FontWeight.w600, spacing: -0.6, height: 1.15),
      title: s(18, 22, weight: FontWeight.w600, spacing: -0.3, height: 1.25),
      heading: s(15, 18, weight: FontWeight.w600, spacing: -0.2),
      body: s(14, 16, height: 1.45),
      bodySecondary: s(14, 16, height: 1.45, color: c.textSecondary),
      label: s(13.5, 15.5, weight: FontWeight.w500, spacing: -0.1, height: 1.2),
      meta: s(12.5, 14, height: 1.2, color: c.textSecondary),
      metaMuted: s(12.5, 14, height: 1.2, color: c.textTertiary),
      caption: s(11, 12.5,
          weight: FontWeight.w600, spacing: 0.9, handSpacing: 1.6, height: 1.2, color: c.textTertiary),
      number: s(13, 15, weight: FontWeight.w500, height: 1.2, color: c.textSecondary)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      button: s(13.5, 15.5, weight: FontWeight.w500, height: 1.2),
    );
  }

  final bool handwritten;
  final String family;

  /// The wordmark.
  final TextStyle brand;

  /// Page titles.
  final TextStyle display;

  /// Dialog titles.
  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodySecondary;

  /// Row titles, nav items, menu items.
  final TextStyle label;
  final TextStyle meta;
  final TextStyle metaMuted;

  /// Spaced small caps for column and section headers (write the text in caps).
  final TextStyle caption;

  /// Times, points, grades.
  final TextStyle number;
  final TextStyle button;
}
