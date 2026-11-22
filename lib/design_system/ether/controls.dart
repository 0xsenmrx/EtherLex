import 'package:material_ui/material_ui.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../theme/ether_theme.dart';
import 'icons.dart';
import 'tap.dart';

const Color _clear = Color(0x00000000);
const Duration _fast = Duration(milliseconds: 120);

/// Square icon button. Bordered like Oleafly's toolbar, or plain for rails.
class EIconButton extends StatelessWidget {
  const EIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 36,
    this.iconSize = 17,
    this.bordered = true,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool bordered;
  final bool selected;

  /// Icon colour when idle; defaults to secondary text.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = ETap(
      onTap: onTap,
      pressedScale: 0.92,
      builder: (context, s) => AnimatedContainer(
        duration: _fast,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? c.selected : (s.hovered ? c.hover : _clear),
          borderRadius: BorderRadius.circular(size >= 34 ? 10 : 7),
          border: bordered ? Border.all(color: s.hovered ? c.lineStrong : c.line) : null,
          boxShadow: focusRing(c, s.focused),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: selected
              ? c.accent
              : (s.hovered ? c.textPrimary : (color ?? c.textSecondary)),
        ),
      ),
    );
    final tip = tooltip;
    return tip == null ? button : Tooltip(message: tip, child: button);
  }
}

enum EButtonKind { primary, secondary, ghost, danger }

class EButton extends StatelessWidget {
  const EButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = EButtonKind.secondary,
    this.expand = false,
    this.autofocus = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final EButtonKind kind;
  final bool expand;
  final bool autofocus;

  /// Shows a spinning icon and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return ETap(
      onTap: loading ? null : onTap,
      autofocus: autofocus,
      builder: (context, s) {
        final (Color bg, Color fg, Color? border) = switch (kind) {
          EButtonKind.primary => (s.hovered ? c.accentHover : c.accent, c.onAccent, null),
          EButtonKind.danger => (c.danger.withValues(alpha: s.hovered ? 0.9 : 1), c.onAccent, null),
          EButtonKind.secondary =>
            (s.hovered ? c.hover : _clear, c.textPrimary, s.hovered ? c.lineStrong : c.line),
          EButtonKind.ghost =>
            (s.hovered ? c.hover : _clear, s.hovered ? c.textPrimary : c.textSecondary, null),
        };
        return AnimatedContainer(
          duration: _fast,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: border == null ? null : Border.all(color: border),
            boxShadow: focusRing(c, s.focused),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                _Spinner(child: Icon(EIcons.loader, size: 16, color: fg)),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
              ],
              Text(label, style: t.button.copyWith(color: fg)),
            ],
          ),
        );
      },
    );
  }
}

/// Looks like a search field, opens the search/command palette.
class ESearchTrigger extends StatelessWidget {
  const ESearchTrigger({super.key, required this.onTap, required this.hint});

  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return ETap(
      onTap: onTap,
      pressedScale: 0.99,
      builder: (context, s) => AnimatedContainer(
        duration: _fast,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: s.hovered ? Color.alphaBlend(c.hover, c.canvas) : c.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: s.hovered ? c.lineStrong : c.line),
          boxShadow: focusRing(c, s.focused),
        ),
        child: Row(
          children: [
            Icon(EIcons.search, size: 16, color: c.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.label.copyWith(color: c.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The course colour: a small rounded swatch, like Oleafly's project tiles.
class ESwatch extends StatelessWidget {
  const ESwatch(this.color, {super.key, this.width = 9, this.height = 12, this.dim = false});

  final Color color;
  final double width;
  final double height;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dim ? color.withValues(alpha: 0.4) : color,
        borderRadius: BorderRadius.circular(width >= 20 ? 5 : 2.5),
      ),
    );
  }
}

/// A row of round accent colours; the chosen one has a ring.
class EPalettePicker extends StatelessWidget {
  const EPalettePicker({super.key, required this.colors, required this.labels, required this.selected, required this.onChanged});

  final List<Color> colors;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < colors.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: Tooltip(
              message: labels[i],
              child: ETap(
                onTap: () => onChanged(i),
                pressedScale: 0.9,
                builder: (context, s) {
                  final on = i == selected;
                  return Container(
                    width: 26,
                    height: 26,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: on ? colors[i] : (s.hovered || s.focused ? c.lineStrong : const Color(0x00000000)),
                        width: 2,
                      ),
                    ),
                    child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: colors[i])),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// One-pixel separator in the current line colour.
class EHairline extends StatelessWidget {
  const EHairline({super.key, this.vertical = false});
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.line;
    return vertical
        ? Container(width: 1, color: c)
        : Container(height: 1, color: c);
  }
}

/// On/off switch. The knob glides; Enter and Space toggle it when focused.
class ESwitch extends StatelessWidget {
  const ESwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ETap(
      onTap: () => onChanged(!value),
      pressedScale: 0.95,
      builder: (context, s) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 38,
        height: 22,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? c.accent : c.lineStrong,
          borderRadius: BorderRadius.circular(11),
          boxShadow: focusRing(c, s.focused),
        ),
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// A key cap, for the shortcuts window.
class EKeyCap extends StatelessWidget {
  const EKeyCap(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.line),
        boxShadow: [BoxShadow(color: c.lineStrong, offset: const Offset(0, 1.5))],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: c.textSecondary,
          height: 1,
        ),
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner({required this.child});
  final Widget child;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Own layer: the rotation repaints only the icon, not the page around it.
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: RotationTransition(turns: _c, child: widget.child));
}
