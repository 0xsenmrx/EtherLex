import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Tooltip;

import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';

/// The copy icon, which shrinks away while a check grows in its place (and the
/// other way round when [copied] goes back to false).
class CopyIcon extends StatelessWidget {
  const CopyIcon({super.key, required this.copied, required this.size, this.color});

  final bool copied;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween<double>(begin: 0.4, end: 1).animate(animation), child: child),
        ),
        child: Icon(
          copied ? EIcons.check : EIcons.copy,
          key: ValueKey<bool>(copied),
          size: size,
          color: color,
        ),
      );
}

/// Copies [text]; the icon turns into a green check for a moment so you can
/// see that it worked.
class CopyButton extends StatefulWidget {
  const CopyButton({super.key, required this.text, this.size = 28, this.iconSize = 14});

  final String text;
  final double size;
  final double iconSize;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: _copied ? 'Copied' : 'Copy',
      child: ETap(
        onTap: _copy,
        pressedScale: 0.92,
        builder: (context, s) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: s.hovered ? c.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(7),
            boxShadow: focusRing(c, s.focused),
          ),
          child: Center(
            child: CopyIcon(
              copied: _copied,
              size: widget.iconSize,
              color: _copied ? c.success : (s.hovered ? c.textPrimary : c.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
