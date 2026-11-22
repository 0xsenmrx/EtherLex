import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/appearance/appearance.dart' show BackgroundPattern;
import '../../core/diag.dart';
import '../theme/ether_theme.dart';

/// The canvas behind the whole app: dots, a grid or plain ([pattern]). One
/// small tile is drawn once and repeated by the GPU, so the cost is the same at any window
/// size (resizing stays smooth). It sits in its own layer, so content
/// scrolling on top never repaints it.
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, required this.child, this.spacing = 24, this.pattern = BackgroundPattern.dots});

  final Widget child;
  final double spacing;
  final BackgroundPattern pattern;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: PatternPainter(c.canvas, c.dot, spacing, dpr, pattern)),
          ),
        ),
        child,
      ],
    );
  }
}

/// Paints [pattern] on [background]; also used small, for the previews in
/// Settings > Appearance.
class PatternPainter extends CustomPainter {
  PatternPainter(this.background, this.dot, this.spacing, this.dpr, this.pattern);

  final Color background;
  final Color dot;
  final double spacing;
  final double dpr;
  final BackgroundPattern pattern;

  // A few tiles are kept (the canvas plus the small previews in Settings);
  // a theme change makes new ones.
  static final Map<(Color, double, double, BackgroundPattern), ui.ImageShader> _shaders = {};

  ui.ImageShader _tile() {
    final key = (dot, spacing, dpr, pattern);
    final cached = _shaders[key];
    if (cached != null) return cached;
    final px = (spacing * dpr).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (pattern == BackgroundPattern.grid) {
      // One hairline along the top and the left of the tile; repeated, a grid.
      final line = Paint()..color = dot.withValues(alpha: dot.a * 0.7);
      final width = dpr.clamp(1.0, 2.0).toDouble();
      canvas
        ..drawRect(Rect.fromLTWH(0, 0, px.toDouble(), width), line)
        ..drawRect(Rect.fromLTWH(0, 0, width, px.toDouble()), line);
    } else {
      canvas.drawCircle(
        Offset(px / 2, px / 2),
        0.8 * dpr,
        Paint()
          ..color = dot
          ..isAntiAlias = true,
      );
    }
    final image = recorder.endRecording().toImageSync(px, px);
    final scale = 1 / dpr;
    final shader = ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.diagonal3Values(scale, scale, 1).storage,
    );
    if (_shaders.length >= 8) _shaders.clear();
    _shaders[key] = shader;
    return shader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = background);
    if (pattern == BackgroundPattern.none || diag('nodots')) return;
    canvas.drawRect(rect, Paint()..shader = _tile());
  }

  @override
  bool shouldRepaint(PatternPainter old) =>
      old.background != background ||
      old.dot != dot ||
      old.spacing != spacing ||
      old.dpr != dpr ||
      old.pattern != pattern;
}
