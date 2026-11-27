import 'dart:ui' show ImageFilter, PathMetric;

import 'package:flutter/widgets.dart';

import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';
import '../theme/ether_theme.dart';
import 'icons.dart';

/// Shown over a page while files are dragged onto it: the page behind goes
/// soft and blurred, a dashed accent frame marks the target, and three file
/// sheets fan out above a line saying what a drop does. It fades and the sheets
/// spread with a spring (not at all with reduced motion, like every
/// [SpringValue]) and it never takes clicks. The blur only exists while it is
/// showing, so it costs nothing the rest of the time.
class EDropOverlay extends StatelessWidget {
  const EDropOverlay({super.key, required this.active, required this.title, required this.hint});

  final bool active;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Positioned.fill(
      child: IgnorePointer(
        child: SpringValue(
          target: active ? 1 : 0,
          spring: Springs.glide,
          builder: (context, v, _) {
            if (v < 0.01) return const SizedBox.shrink();
            final k = v > 1 ? 1.0 : v;
            return Opacity(
              opacity: k,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: ColoredBox(color: c.canvas.withValues(alpha: 0.5)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: CustomPaint(painter: _DashedFrame(color: c.accentFill, radius: 18)),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FileFan(spread: k),
                        const SizedBox(height: 22),
                        Text(title, style: t.title, textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text(hint, style: t.meta, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Three sheets, fanned: two plain ones behind a filled one with an arrow.
class _FileFan extends StatelessWidget {
  const _FileFan({required this.spread});

  /// 0 = stacked, 1 = fanned out.
  final double spread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget sheet({required double dx, required double angle, required double dy, required IconData icon, bool filled = false}) {
      return Transform.translate(
        offset: Offset(dx * spread, dy - 8 * (1 - spread)),
        child: Transform.rotate(
          angle: angle * spread,
          child: Container(
            width: 68,
            height: 86,
            decoration: BoxDecoration(
              color: filled ? c.accentFill : c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: filled ? c.accentFill : c.lineStrong),
              boxShadow: [BoxShadow(color: const Color(0x26000000), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: Center(child: Icon(icon, size: 28, color: filled ? c.onAccent : c.accent)),
          ),
        ),
      );
    }

    return SizedBox(
      width: 220,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          sheet(dx: -58, angle: -0.26, dy: 10, icon: EIcons.fileText),
          sheet(dx: 58, angle: 0.26, dy: 10, icon: EIcons.fileImage),
          sheet(dx: 0, angle: 0, dy: -4, icon: EIcons.upload, filled: true),
        ],
      ),
    );
  }
}

class _DashedFrame extends CustomPainter {
  _DashedFrame({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 9.0, gap = 7.0;
    for (final PathMetric m in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += dash + gap) {
        canvas.drawPath(m.extractPath(d, d + dash > m.length ? m.length : d + dash), line);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFrame old) => old.color != color || old.radius != radius;
}
