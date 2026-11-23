import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Tooltip;
import 'package:go_router/go_router.dart';

import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';
import '../../design_system/ether/tap.dart';
import '../../design_system/theme/ether_theme.dart';
import 'course_section.dart';
import 'nav.dart';
import 'nav_tools.dart';

/// Wide-window navigation: flat on the canvas, no panel behind it.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.location, required this.onCollapse});

  final String location;

  /// Switches to the icon rail (Ctrl+B).
  final VoidCallback onCollapse;

  static const double width = 236;
  static const double itemHeight = 36;
  static const double itemGap = 2;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = destinationIndexFor(location);
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: kDestinations.length * (itemHeight + itemGap),
              child: Stack(
                children: [
                  SpringValue(
                    target: selected * (itemHeight + itemGap),
                    spring: Springs.glide,
                    builder: (context, y, _) => Positioned(
                      top: y,
                      left: 0,
                      right: 0,
                      height: itemHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.selected,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < kDestinations.length; i++)
                    Positioned(
                      top: i * (itemHeight + itemGap),
                      left: 0,
                      right: 0,
                      height: itemHeight,
                      child: Tooltip(
                        message: 'Alt+${i + 1}',
                        child: _NavRow(destination: kDestinations[i], selected: i == selected),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Expanded(child: CourseSection()),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
              child: NavTools(vertical: false, onToggleSidebar: onCollapse),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.destination, required this.selected});

  final NavDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return ETap(
      onTap: () => context.go(destination.path),
      pressedScale: 0.985,
      builder: (context, s) {
        final strong = selected || s.hovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: s.hovered && !selected ? c.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(10),
            boxShadow: focusRing(c, s.focused),
          ),
          child: Row(
            children: [
              Icon(
                destination.icon,
                size: 17,
                color: selected ? c.accent : (strong ? c.textPrimary : c.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.label,
                  style: t.label.copyWith(color: strong ? c.textPrimary : c.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
