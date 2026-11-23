import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/appearance/appearance.dart';
import '../../core/notify/toast.dart';
import '../../design_system/ether/breakpoint.dart';
import '../../design_system/ether/dot_grid.dart';
import '../../features/notifications/presentation/notifications_providers.dart';
import '../../features/palette/presentation/command_palette.dart';
import '../../features/palette/presentation/shortcuts_dialog.dart';
import '../../features/settings/presentation/settings_dialog.dart';
import '../../features/update/presentation/update_dialog.dart';
import '../../features/update/presentation/update_providers.dart';
import '../app_info.dart';
import 'rail.dart';
import 'sidebar.dart';
import 'token_banner.dart';
import 'top_bar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  /// Below this width the sidebar becomes the floating icon rail (and Ctrl+B
  /// can switch to the rail at any width).
  static const double wideBreakpoint = 1080;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the deadline and grade alerts running while signed in.
    ref.watch(notificationsProvider);
    // Looks for a new release shortly after start (see Settings > Updates).
    ref.watch(updateStartupProvider);
    final rejected = ref.watch(tokenRejectedProvider);
    final collapsed = ref.watch(appearanceProvider.select((a) => a.sidebarCollapsed));
    void toggleSidebar() => ref.read(appearanceProvider.notifier).toggleSidebar();
    ref.listen(updateProvider, (prev, next) {
      final info = next.info;
      if (info == null || !next.announce || next.status != UpdateStatus.available) return;
      if (prev?.status == UpdateStatus.available) return;
      ref.read(toastProvider.notifier).show(
            '$kAppName ${info.version} is available',
            actionLabel: "What's new",
            onAction: () => showUpdateDialog(context),
            duration: const Duration(seconds: 15),
          );
    });
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            showCommandPalette(context, searchOnly: true),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () => showSettings(context),
        const SingleActivator(LogicalKeyboardKey.slash, control: true): () => showShortcuts(context),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): toggleSidebar,
        const SingleActivator(LogicalKeyboardKey.digit1, alt: true): () => context.go('/assignments'),
        const SingleActivator(LogicalKeyboardKey.digit2, alt: true): () => context.go('/activity'),
        const SingleActivator(LogicalKeyboardKey.digit3, alt: true): () => context.go('/calendar'),
        const SingleActivator(LogicalKeyboardKey.digit4, alt: true): () => context.go('/grades'),
        const SingleActivator(LogicalKeyboardKey.digit5, alt: true): () => context.go('/files'),
        const SingleActivator(LogicalKeyboardKey.digit6, alt: true): () => context.go('/chat'),
      },
      child: DotGrid(
        pattern: ref.watch(appearanceProvider.select((a) => a.background)),
        child: BreakpointBuilder<bool>(
          mode: (box) => box.maxWidth >= wideBreakpoint,
          builder: (context, roomy) {
            // Roomy: the window has space for the sidebar. Collapsed: the
            // student chose the rail anyway (Ctrl+B).
            final wide = roomy && !collapsed;
            return Column(
              children: [
                TopBar(compact: !wide, onSearch: () => showCommandPalette(context)),
                if (rejected) const TokenBanner(),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RepaintBoundary(
                        child: wide
                            ? Sidebar(location: location, onCollapse: toggleSidebar)
                            : NavRail(location: location, onExpand: roomy ? toggleSidebar : null),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          child: RepaintBoundary(child: child),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
