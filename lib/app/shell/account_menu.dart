import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/notify/toast.dart';
import '../../core/utils/initials.dart';
import '../../design_system/ether/icons.dart';
import '../../design_system/ether/menu.dart';
import '../../design_system/ether/tap.dart';
import '../../design_system/theme/ether_theme.dart';
import '../../features/auth/domain/auth_provider.dart';
import '../../features/auth/presentation/sign_out.dart';
import '../../features/notifications/presentation/notifications_providers.dart';
import '../../features/palette/presentation/shortcuts_dialog.dart';
import '../../features/settings/presentation/settings_dialog.dart';

/// Avatar in the top bar: account, notifications, Settings, shortcuts and
/// sign out. The look lives in Settings > Appearance (and the sun/moon button).
class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final session = ref.watch(authProvider).value;
    final name = session?.userName ?? '';
    final isSample = session?.isSample ?? true;
    final notificationsOn = ref.watch(notificationsProvider);
    final item = etherMenuItemStyle(c, t);

    Future<void> signOut() async {
      final ok = await confirmSignOut(context, sample: isSample);
      if (ok) ref.read(authProvider.notifier).signOut();
    }

    return MenuAnchor(
      style: etherMenuStyle(c),
      alignmentOffset: const Offset(-210, 8),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? 'Signed in' : name, style: t.label),
              const SizedBox(height: 3),
              Text(isSample ? 'Sample data' : 'Connected to Canvas', style: t.metaMuted),
            ],
          ),
        ),
        const EMenuDivider(),
        MenuItemButton(
          style: item,
          closeOnActivate: false,
          leadingIcon: Icon(notificationsOn ? EIcons.bell : EIcons.bellOff),
          trailingIcon: Text(notificationsOn ? 'On' : 'Off', style: t.metaMuted),
          onPressed: () {
            ref.read(notificationsProvider.notifier).toggle();
            ref.read(toastProvider.notifier).show(
                  notificationsOn ? 'Notifications off' : 'Notifications on',
                );
          },
          child: const Text('Notifications'),
        ),
        const EMenuDivider(),
        MenuItemButton(
          style: item,
          leadingIcon: const Icon(EIcons.settings),
          onPressed: () => showSettings(context),
          child: const Text('Settings'),
        ),
        MenuItemButton(
          style: item,
          leadingIcon: const Icon(EIcons.keyboard),
          onPressed: () => showShortcuts(context),
          child: const Text('Keyboard shortcuts'),
        ),
        const EMenuDivider(),
        MenuItemButton(
          style: etherMenuItemStyle(c, t, danger: true),
          leadingIcon: const Icon(EIcons.signOut),
          onPressed: signOut,
          child: const Text('Sign out…'),
        ),
      ],
      builder: (context, controller, _) => ETap(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        pressedScale: 0.94,
        builder: (context, s) => Tooltip(
          message: name.isEmpty ? 'Account' : name,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: s.hovered ? c.accent.withValues(alpha: 0.28) : c.accentSoft,
                  shape: BoxShape.circle,
                  boxShadow: focusRing(c, s.focused),
                ),
                child: Text(
                  initialsOf(name),
                  style: t.label.copyWith(color: c.accent, fontSize: t.handwritten ? 15 : 12.5),
                ),
              ),
              if (isSample)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.dueSoon,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.canvas, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
