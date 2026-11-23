import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/appearance/appearance.dart';
import '../../design_system/ether/controls.dart';
import '../../design_system/ether/icons.dart';
import '../../features/palette/presentation/shortcuts_dialog.dart';
import '../../features/settings/domain/settings_search.dart';
import '../../features/settings/presentation/settings_dialog.dart';

/// The tools pinned under the navigation, like Oleafly's dock footer:
/// Settings, shortcuts, help, the theme, and collapsing the sidebar. [vertical]
/// stacks them for the icon rail, where [onToggleSidebar] is null when the
/// window is too narrow for the full sidebar.
class NavTools extends ConsumerWidget {
  const NavTools({super.key, required this.vertical, this.onToggleSidebar, this.compactSet = false});

  final bool vertical;
  final VoidCallback? onToggleSidebar;

  /// The rail shows fewer tools (Settings, theme, expand).
  final bool compactSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final collapsed = ref.watch(appearanceProvider.select((a) => a.sidebarCollapsed));
    final size = vertical ? 40.0 : 32.0;
    final iconSize = vertical ? 18.0 : 16.0;
    Widget tool(IconData icon, String tip, VoidCallback onTap) => EIconButton(
          icon: icon,
          tooltip: tip,
          size: size,
          iconSize: iconSize,
          bordered: false,
          onTap: onTap,
        );
    final toggle = onToggleSidebar;
    final items = <Widget>[
      tool(EIcons.settings, 'Settings  Ctrl+,', () => showSettings(context)),
      if (!compactSet) ...[
        tool(EIcons.keyboard, 'Keyboard shortcuts  Ctrl+/', () => showShortcuts(context)),
        tool(EIcons.help, 'Help and feedback', () => showSettings(context, section: SettingsSection.about)),
      ],
      tool(
        dark ? EIcons.sun : EIcons.moon,
        dark ? 'Light theme' : 'Dark theme',
        () => ref.read(appearanceProvider.notifier).toggleBrightness(Theme.of(context).brightness),
      ),
      if (toggle != null)
        tool(
          collapsed ? EIcons.expand : EIcons.collapse,
          collapsed ? 'Expand the sidebar  Ctrl+B' : 'Collapse the sidebar  Ctrl+B',
          toggle,
        ),
    ];
    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final w in items) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: w),
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          // Settings, shortcuts and help on the left; theme and collapse on the right.
          if (i == (compactSet ? 1 : 3)) const Spacer(),
          items[i],
        ],
      ],
    );
  }
}
