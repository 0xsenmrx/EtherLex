import 'package:flutter/widgets.dart';

/// Colours that tell kinds of things apart and stay the same in every theme
/// and accent palette (like [CoursePalette]): file types, activity kinds,
/// folders, the window's close button, the switch knob. Mid-tones that read on
/// light and dark. Widgets take colours from here or from `context.colors`,
/// never from a literal.
abstract final class FixedColors {
  // File types.
  static const Color pdf = Color(0xFFEF6B6B);
  static const Color document = Color(0xFF4F9CF0);
  static const Color slides = Color(0xFFF08C3C);
  static const Color sheet = Color(0xFF2FB57C);
  static const Color archive = Color(0xFFD9A520);
  static const Color image = Color(0xFF9B7BF0);
  static const Color video = Color(0xFFE6689E);
  static const Color code = Color(0xFF7C83F0);
  static const Color other = Color(0xFF8E9099);
  static const Color folder = Color(0xFFD9A520);

  // Activity kinds.
  static const Color announcement = Color(0xFF8B5CF6);
  static const Color grade = Color(0xFF2FB57C);
  static const Color discussion = Color(0xFF3B9EE8);
  static const Color message = Color(0xFFF08C3C);

  // Window close button (Windows' own red) and the switch knob.
  static const Color close = Color(0xFFE5484D);
  static const Color closePressed = Color(0xFFC53A3F);
  static const Color onClose = Color(0xFFFFFFFF);
  static const Color knob = Color(0xFFFFFFFF);
}
