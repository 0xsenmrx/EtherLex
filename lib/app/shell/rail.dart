import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../design_system/ether/controls.dart';
import '../../design_system/ether/icons.dart';
import '../../design_system/ether/menu.dart';
import '../../design_system/theme/course_palette.dart';
import '../../design_system/theme/ether_theme.dart';
import '../../features/assignments/presentation/assignments_providers.dart';
import 'nav.dart';
import 'nav_tools.dart';

/// Narrow-window navigation: a floating icon rail, courses in a popover.
class NavRail extends StatelessWidget {
  const NavRail({super.key, required this.location, this.onExpand});

  final String location;

  /// Back to the full sidebar; null when the window is too narrow for it.
  final VoidCallback? onExpand;

  static const double width = 76;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = destinationIndexFor(location);
    final pill = BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: c.line),
      boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 4))],
    );
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: pill,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < kDestinations.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: EIconButton(
                          icon: kDestinations[i].icon,
                          tooltip: kDestinations[i].label,
                          size: 40,
                          iconSize: 18,
                          bordered: false,
                          selected: i == selected,
                          onTap: () => context.go(kDestinations[i].path),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(width: 24, child: Container(height: 1, color: c.line)),
                    ),
                    const _CoursesButton(),
                  ],
                ),
              ),
            ),
          ),
          // Settings, theme and (in a wide window) back to the sidebar.
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            padding: const EdgeInsets.all(6),
            decoration: pill,
            child: NavTools(vertical: true, compactSet: true, onToggleSidebar: onExpand),
          ),
        ],
      ),
    );
  }
}

class _CoursesButton extends ConsumerWidget {
  const _CoursesButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final disabled = ref.watch(disabledCoursesProvider);
    final entries = [
      for (final e in ref.watch(filterableCoursesProvider))
        if (!disabled.contains(e.course.id)) e,
    ];
    final selected = ref.watch(courseFilterProvider);
    final filter = ref.read(courseFilterProvider.notifier);
    final item = etherMenuItemStyle(c, t);

    return MenuAnchor(
      style: etherMenuStyle(c),
      alignmentOffset: const Offset(52, -40),
      menuChildren: [
        const EMenuCaption('Courses'),
        for (final e in entries)
          MenuItemButton(
            style: item,
            closeOnActivate: false,
            leadingIcon: ESwatch(CoursePalette.colorFor(e.course.id)),
            trailingIcon: selected.contains(e.course.id)
                ? Icon(EIcons.check, size: 15, color: c.accent)
                : null,
            onPressed: () => filter.toggle(e.course.id),
            child: Text(e.course.shortLabel),
          ),
        if (selected.isNotEmpty) ...[
          const EMenuDivider(),
          MenuItemButton(style: item, onPressed: filter.clear, child: const Text('Show all courses')),
        ],
      ],
      builder: (context, controller, _) => EIconButton(
        icon: EIcons.courses,
        tooltip: 'Courses',
        size: 40,
        iconSize: 18,
        bordered: false,
        selected: selected.isNotEmpty,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
