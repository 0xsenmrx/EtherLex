import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';
import '../theme/ether_theme.dart';
import 'icons.dart';

/// Shown over a page while files are dragged onto it: a soft veil, a dashed
/// frame in the accent colour and a card saying what a drop does. It fades and
/// settles with a spring (not at all with reduced motion, like every
/// [SpringValue]) and never takes clicks.
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
                  ColoredBox(color: c.canvas.withValues(alpha: 0.82)),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: CustomPaint(
                      painter: _DashedFrame(color: c.accentFill, fill: c.accentSoft.withValues(alpha: 0.55), radius: 18),
                    ),
                  ),
                  Center(
                    child: Transform.scale(
                      scale: 0.94 + 0.06 * k,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.line),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: c.accentFill, borderRadius: BorderRadius.circular(14)),
                              child: Icon(EIcons.upload, size: 22, color: c.onAccent),
                            ),
                            const SizedBox(height: 14),
                            Text(title, style: t.title, textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text(hint, style: t.meta, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
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

class _DashedFrame extends CustomPainter {
  _DashedFrame({required this.color, required this.fill, required this.radius});

  final Color color;
  final Color fill;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = fill);
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
  bool shouldRepaint(_DashedFrame old) => old.color != color || old.fill != fill || old.radius != radius;
}
