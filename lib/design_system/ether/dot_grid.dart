import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/diag.dart';
import '../theme/ether_theme.dart';

/// The dotted canvas behind the whole app. One small tile with one dot is
/// drawn once and repeated by the GPU, so the cost is the same at any window
/// size (resizing stays smooth). It sits in its own layer, so content
/// scrolling on top never repaints it.
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, required this.child, this.spacing = 24});

  final Widget child;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _DotPainter(c.canvas, c.dot, spacing, dpr)),
          ),
        ),
        child,
      ],
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.background, this.dot, this.spacing, this.dpr);

  final Color background;
  final Color dot;
  final double spacing;
  final double dpr;

  // Only the latest tile is kept; a theme change makes a new one.
  static ui.ImageShader? _shader;
  static (Color, double, double)? _shaderKey;

  ui.ImageShader _tile() {
    final key = (dot, spacing, dpr);
    final cached = _shader;
    if (cached != null && _shaderKey == key) return cached;
    final px = (spacing * dpr).round();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawCircle(
      Offset(px / 2, px / 2),
      0.8 * dpr,
      Paint()
        ..color = dot
        ..isAntiAlias = true,
    );
    final image = recorder.endRecording().toImageSync(px, px);
    final scale = 1 / dpr;
    final shader = ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.diagonal3Values(scale, scale, 1).storage,
    );
    _shader = shader;
    _shaderKey = key;
    return shader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = background);
    if (diag('nodots')) return;
    canvas.drawRect(rect, Paint()..shader = _tile());
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.background != background || old.dot != dot || old.spacing != spacing || old.dpr != dpr;
}
