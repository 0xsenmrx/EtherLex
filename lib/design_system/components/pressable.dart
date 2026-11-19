import 'package:flutter/widgets.dart';

import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';

/// Hover-aware tap target with a springy press-scale. Interruptible.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    this.onTap,
    this.pressedScale = 0.97,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: SpringValue(
          target: _down ? widget.pressedScale : 1,
          spring: Springs.snappy,
          builder: (context, v, child) =>
              (v - 1).abs() < 0.0005 ? child! : Transform.scale(scale: v, child: child),
          child: widget.builder(context, _hover),
        ),
      ),
    );
  }
}
