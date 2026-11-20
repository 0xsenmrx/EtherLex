import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_info.dart';
import '../../../core/appearance/appearance.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../../files/data/file_cache.dart';
import '../../chat/presentation/ai_settings_section.dart';
import '../../files/presentation/files_providers.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../update/data/update_service.dart';
import '../../update/presentation/update_dialog.dart';
import '../../update/presentation/update_providers.dart';

/// Ctrl+,: account, look, notifications, courses, offline storage.
Future<void> showSettings(BuildContext context) =>
    showEtherDialog<void>(context, (_) => const SettingsDialog(), maxWidth: 620);

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final session = ref.watch(authProvider).value;
    final appearance = ref.watch(appearanceProvider);
    final looks = ref.read(appearanceProvider.notifier);
    final notificationsOn = ref.watch(notificationsProvider);
    final courses = [...?ref.watch(coursesProvider).value]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final disabled = ref.watch(disabledCoursesProvider);
    final disabledNotifier = ref.read(disabledCoursesProvider.notifier);
    final host = Uri.tryParse(session?.baseUrl ?? '')?.host ?? '';
    final updateState = ref.watch(updateProvider);
    final updatePrefs = ref.watch(updatePrefsProvider);
    final (String updateTitle, String? updateSub) = switch (updateState.status) {
      UpdateStatus.checking => ('Checking for updates...', null),
      UpdateStatus.downloading => ('Downloading the update...', null),
      UpdateStatus.available => ('Version ${updateState.info?.version} is available', 'You have $kAppVersion'),
      UpdateStatus.upToDate => ("You're up to date", 'Version $kAppVersion'),
      UpdateStatus.failed => ('Could not check for updates', updateState.message),
      UpdateStatus.idle => ('Updates', 'Version $kAppVersion'),
    };

    Future<void> checkNow() async {
      final updates = ref.read(updateProvider.notifier);
      if (ref.read(updateProvider).status != UpdateStatus.available) await updates.check(manual: true);
      if (!context.mounted) return;
      if (ref.read(updateProvider).status == UpdateStatus.available) await showUpdateDialog(context);
    }

    Future<void> signOut() async {
      final auth = ref.read(authProvider.notifier);
      final nav = Navigator.of(context);
      final ok = await confirmAction(
        context,
        title: 'Sign out?',
        message: 'Your token is removed from this computer. Your settings for this account stay.',
        confirmLabel: 'Sign out',
        destructive: true,
      );
      if (!ok) return;
      nav.pop();
      auth.signOut();
    }

    return EDialog(
      title: 'Settings',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Section('Account'),
          _Row(
            title: session?.userName ?? 'Signed in',
            subtitle: session == null || session.isSample ? 'Sample data, nothing is sent to Canvas' : host,
            trailing: EButton(label: 'Sign out', kind: EButtonKind.ghost, onTap: signOut),
          ),
          const _Section('Appearance'),
          _Row(
            title: 'Theme',
            trailing: ESegmented(
              labels: const ['Windows', 'Light', 'Dark'],
              selected: switch (appearance.theme) {
                ThemeChoice.system => 0,
                ThemeChoice.light => 1,
                ThemeChoice.dark => 2,
              },
              onChanged: (i) => looks.setTheme(ThemeChoice.values[i]),
            ),
          ),
          _Row(
            title: 'Font',
            subtitle: 'Handwritten uses Ink Free, which comes with Windows',
            trailing: ESegmented(
              labels: const ['Handwritten', 'Clean'],
              selected: appearance.handwritten ? 0 : 1,
              onChanged: (i) => looks.setTypeface(i == 0 ? TypefaceChoice.handwritten : TypefaceChoice.clean),
            ),
          ),
          const _Section('Notifications'),
          _Row(
            title: 'Deadlines and new grades',
            subtitle: 'Windows notifications for work due soon and grades just posted',
            trailing: ESwitch(
              value: notificationsOn,
              onChanged: (_) => ref.read(notificationsProvider.notifier).toggle(),
            ),
          ),
          const AiSettingsSection(),
          if (courses.isNotEmpty) ...[
            const _Section('Courses', hint: 'Turned-off courses leave every list and count'),
            for (final course in courses)
              _Row(
                leading: ESwatch(CoursePalette.colorFor(course.id), dim: disabled.contains(course.id)),
                title: course.name,
                trailing: ESwitch(
                  value: !disabled.contains(course.id),
                  onChanged: (on) =>
                      on ? disabledNotifier.enable(course.id) : disabledNotifier.disable(course.id),
                ),
              ),
          ],
          const _Section('Offline files'),
          ValueListenableBuilder<int>(
            valueListenable: fileCacheRevision,
            builder: (context, _, _) {
              final bytes = ref.read(filesRepositoryProvider).offlineBytes();
              return _Row(
                title: bytes == 0 ? 'Nothing saved' : '${formatBytes(bytes)} saved on this computer',
                subtitle: 'Files you opened or saved offline, up to 3 GB',
                trailing: bytes == 0
                    ? null
                    : EButton(
                        label: 'Clear',
                        kind: EButtonKind.ghost,
                        onTap: () => ref.read(filesRepositoryProvider).clearOffline(),
                      ),
              );
            },
          ),
          if (UpdateService.supported) ...[
            const _Section('Updates'),
            _Row(
              title: 'Check automatically',
              subtitle: 'Asks GitHub for a new release about twice a day. Nothing about you is sent.',
              trailing: ESwitch(
                value: updatePrefs.autoCheck,
                onChanged: ref.read(updatePrefsProvider.notifier).setAutoCheck,
              ),
            ),
            _Row(
              title: updateTitle,
              subtitle: updateSub,
              trailing: EButton(
                label: updateState.status == UpdateStatus.available ? "See what's new" : 'Check now',
                kind: EButtonKind.ghost,
                loading: updateState.status == UpdateStatus.checking,
                onTap: updateState.status == UpdateStatus.downloading ? null : checkNow,
              ),
            ),
          ],
          const _Section('About'),
          _Row(title: kAppName, subtitle: 'Version $kAppVersion'),
          const SizedBox(height: 4),
          Text(
            'Settings are saved on this computer, separately for each Canvas account.',
            style: t.metaMuted.copyWith(color: c.textTertiary),
          ),
        ],
      ),
      actions: [
        EButton(label: 'Done', kind: EButtonKind.primary, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label, {this.hint});
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) => ESectionLabel(label, trailing: hint);
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.trailing, this.leading});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final sub = subtitle;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(sub, style: t.metaMuted),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing!],
        ],
      ),
    );
  }
}
