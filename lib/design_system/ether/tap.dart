import 'package:flutter/widgets.dart';

import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';
import '../theme/ether_colors.dart';

@immutable
class TapStates {
  const TapStates({required this.hovered, required this.focused, required this.pressed});
  final bool hovered;

  /// True only while navigating with the keyboard (never after a mouse click).
  final bool focused;
  final bool pressed;
}

/// Hover, keyboard focus and press for any custom control. Enter and Space
/// activate it. Every interactive EtherLex widget is built on this.
class ETap extends StatefulWidget {
  const ETap({
    super.key,
    required this.builder,
    this.onTap,
    this.pressedScale = 0.97,
    this.focusNode,
    this.autofocus = false,
    this.focusable = true,
  });

  final Widget Function(BuildContext context, TapStates states) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  final FocusNode? focusNode;
  final bool autofocus;

  /// False for rows that the page drives with its own keyboard cursor: they
  /// keep hover and press, but Tab skips them.
  final bool focusable;

  @override
  State<ETap> createState() => _ETapState();
}

class _ETapState extends State<ETap> {
  bool _hover = false;
  bool _focus = false;
  bool _down = false;

  late final Map<Type, Action<Intent>> _actions = {
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
      widget.onTap?.call();
      return null;
    }),
  };

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final detector = FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      actions: _actions,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        onTap: widget.onTap,
        child: SpringValue(
          target: _down ? widget.pressedScale : 1,
          spring: Springs.snappy,
          builder: (context, v, child) =>
              (v - 1).abs() < 0.0005 ? child! : Transform.scale(scale: v, child: child),
          child: widget.builder(
            context,
            TapStates(hovered: _hover && enabled, focused: _focus, pressed: _down),
          ),
        ),
      ),
    );
    return widget.focusable ? detector : ExcludeFocus(child: detector);
  }
}

/// Keyboard focus ring drawn outside the box, so it never shifts layout.
List<BoxShadow>? focusRing(EtherColors c, bool on) =>
    on ? [BoxShadow(color: c.accent.withValues(alpha: 0.65), spreadRadius: 2)] : null;
