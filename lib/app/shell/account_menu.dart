import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/appearance/appearance.dart';
import '../../core/notify/toast.dart';
import '../../core/utils/initials.dart';
import '../../design_system/ether/dialog.dart';
import '../../design_system/ether/icons.dart';
import '../../design_system/ether/menu.dart';
import '../../design_system/ether/tap.dart';
import '../../design_system/theme/ether_theme.dart';
import '../../features/auth/domain/auth_provider.dart';
import '../../features/notifications/presentation/notifications_providers.dart';
import '../../features/palette/presentation/shortcuts_dialog.dart';
import '../../features/settings/presentation/settings_dialog.dart';

/// Avatar in the top bar. Holds account, notifications, theme and sign out
/// until the Settings window exists.
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
    final appearance = ref.watch(appearanceProvider);
    final looks = ref.read(appearanceProvider.notifier);
    final item = etherMenuItemStyle(c, t);

    Widget themeItem(ThemeChoice choice, String label, IconData icon) => MenuItemButton(
          style: item,
          closeOnActivate: false,
          leadingIcon: Icon(icon),
          trailingIcon: appearance.theme == choice
              ? Icon(EIcons.check, size: 15, color: c.accent)
              : null,
          onPressed: () => looks.setTheme(choice),
          child: Text(label),
        );

    Future<void> signOut() async {
      final ok = await confirmAction(
        context,
        title: 'Sign out?',
        message: isSample
            ? 'You will leave sample mode.'
            : 'Your token is removed from this computer. Your settings for this account stay.',
        confirmLabel: 'Sign out',
        destructive: true,
      );
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
        const EMenuCaption('Theme'),
        themeItem(ThemeChoice.system, 'Match Windows', EIcons.monitor),
        themeItem(ThemeChoice.light, 'Light', EIcons.sun),
        themeItem(ThemeChoice.dark, 'Dark', EIcons.moon),
        MenuItemButton(
          style: item,
          closeOnActivate: false,
          leadingIcon: const Icon(EIcons.pen),
          trailingIcon: Text(appearance.handwritten ? 'On' : 'Off', style: t.metaMuted),
          onPressed: () => looks.setTypeface(
            appearance.handwritten ? TypefaceChoice.clean : TypefaceChoice.handwritten,
          ),
          child: const Text('Handwritten font'),
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
