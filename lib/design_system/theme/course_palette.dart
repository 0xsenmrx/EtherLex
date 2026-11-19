import 'package:flutter/widgets.dart';

/// Stable, deterministic colour per course id. Soft swatches that read on
/// both the light and the dark canvas.
abstract final class CoursePalette {
  static const List<Color> colors = [
    Color(0xFFC9B3F5), // lavender
    Color(0xFF8ED8F2), // sky
    Color(0xFF2F8BD6), // ocean
    Color(0xFFAEF0BC), // mint
    Color(0xFFFFC2A1), // peach
    Color(0xFFF5A9C0), // rose
    Color(0xFFF4DD8A), // butter
    Color(0xFF5CC6B5), // teal
    Color(0xFFFF9C8A), // coral
    Color(0xFFA7B4FF), // periwinkle
  ];

  static Color colorFor(int courseId) {
    final mixed = (courseId * 2654435761) & 0xFFFFFFFF;
    return colors[mixed % colors.length];
  }
}
