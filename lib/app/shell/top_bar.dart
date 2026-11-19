import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/appearance/appearance.dart';
import '../../design_system/ether/controls.dart';
import '../../design_system/ether/icons.dart';
import '../../design_system/theme/ether_theme.dart';
import '../app_info.dart';
import '../window/window_chrome.dart';
import 'account_menu.dart';

/// The title bar: brand, search, theme, account. Empty space drags the
/// window; the window buttons are drawn above it by the app frame.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.onSearch, required this.compact});

  final VoidCallback onSearch;

  /// Narrow window: the wordmark collapses to the mark.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kTitleBarHeight,
      child: Stack(
        children: [
          const Positioned.fill(child: WindowDragArea()),
          Padding(
            padding: EdgeInsets.only(left: 20, right: windowButtonsInset + 14),
            child: Row(
              children: [
                _Brand(compact: compact),
                const SizedBox(width: 16),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ESearchTrigger(
                        onTap: onSearch,
                        hint: 'Search or run a command',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const _ThemeToggle(),
                const SizedBox(width: 10),
                const AccountMenu(),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    // Wide: as wide as the sidebar minus padding, so search centres on the page.
    return SizedBox(
      width: compact ? 40 : 200,
      child: Row(
        children: [
          Icon(EIcons.brand, size: 20, color: c.accent),
          if (!compact) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(kAppName, maxLines: 1, overflow: TextOverflow.clip, style: t.brand),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return EIconButton(
      icon: dark ? EIcons.sun : EIcons.moon,
      tooltip: dark ? 'Light theme' : 'Dark theme',
      onTap: () => ref.read(appearanceProvider.notifier).toggleBrightness(brightness),
    );
  }
}
