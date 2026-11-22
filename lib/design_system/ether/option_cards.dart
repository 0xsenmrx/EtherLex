import 'package:flutter/widgets.dart';

import '../theme/ether_theme.dart';
import 'tap.dart';

/// One choice of [EOptionCards]: a label, and an icon or a small preview.
class EOptionCard {
  const EOptionCard({required this.label, this.icon, this.preview});

  final String label;
  final IconData? icon;

  /// Drawn above the label instead of the icon (a font sample, a pattern).
  final Widget? preview;
}

/// A row of equal, wide cards to pick one look from (theme, font,
/// background), like Oleafly's Appearance. The chosen card has an accent
/// border; Enter and Space pick the focused one.
class EOptionCards extends StatelessWidget {
  const EOptionCards({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.previewHeight = 52,
  });

  final List<EOptionCard> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final double previewHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: ETap(
              onTap: () => onChanged(i),
              pressedScale: 0.98,
              builder: (context, s) {
                final on = i == selected;
                final o = options[i];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: on ? c.accent : (s.hovered ? c.lineStrong : c.line),
                      width: on ? 2 : 1,
                    ),
                    boxShadow: focusRing(c, s.focused),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: previewHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: o.preview ??
                              Center(
                                child: Icon(o.icon, size: 20, color: on ? c.accent : c.textSecondary),
                              ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        o.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.label.copyWith(color: on ? c.textPrimary : c.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
