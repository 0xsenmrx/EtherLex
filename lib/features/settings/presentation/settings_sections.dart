import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../../../app/app_info.dart';
import '../../../core/appearance/appearance.dart';
import '../../../core/notify/toast.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/open_url.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dot_grid.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/option_cards.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../../auth/presentation/sign_out.dart';
import '../../chat/presentation/ai_providers.dart';
import '../../chat/presentation/ai_settings_section.dart';
import '../../files/data/file_cache.dart';
import '../../files/presentation/files_providers.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../palette/domain/shortcuts.dart';
import '../../update/data/update_service.dart';
import '../../update/presentation/update_dialog.dart';
import '../../update/presentation/update_providers.dart';
import '../domain/diagnostics.dart';
import '../domain/settings_search.dart';
import 'settings_widgets.dart';

/// One entry of the Settings dialog: what search reads, and how to draw it
/// ([build] gets the search text, to mark hits).
class SettingsItem {
  const SettingsItem(this.section, this.search, this.build, {this.searchable = true});

  final SettingsSection section;
  final SettingsSearchText search;
  final Widget Function(String query) build;

  /// Banners and notes are shown in their section but not in search results.
  final bool searchable;
}

/// What "Reset to defaults" does in a section, and what it says first.
class SettingsReset {
  const SettingsReset(this.message, this.run);
  final String message;
  final VoidCallback run;
}

SettingsItem _row(
  SettingsSection section,
  String title, {
  String? description,
  List<String> keywords = const [],
  Widget? trailing,
  Widget? leading,
}) =>
    SettingsItem(
      section,
      SettingsSearchText(title: title, description: description ?? '', keywords: keywords),
      (q) => SettingsRow(title: title, description: description, trailing: trailing, leading: leading, query: q),
    );

SettingsItem _block(
  SettingsSection section,
  String title, {
  String? description,
  List<String> keywords = const [],
  required Widget child,
}) =>
    SettingsItem(
      section,
      SettingsSearchText(title: title, description: description ?? '', keywords: keywords),
      (q) => SettingsBlock(title: title, description: description, query: q, child: child),
    );

SettingsItem _note(SettingsSection section, String text) =>
    SettingsItem(section, SettingsSearchText(title: text), (_) => SettingsBanner(text), searchable: false);

/// Every entry of the Settings dialog, in order. Built on each frame from the
/// providers it watches, so every control shows the current value.
List<SettingsItem> buildSettingsItems(BuildContext context, WidgetRef ref) {
  final c = context.colors;
  final session = ref.watch(authProvider).value;
  final sample = session == null || session.isSample;
  final host = Uri.tryParse(session?.baseUrl ?? '')?.host ?? '';
  final appearance = ref.watch(appearanceProvider);
  final looks = ref.read(appearanceProvider.notifier);
  final notificationsOn = ref.watch(notificationsProvider);
  final courses = [...?ref.watch(coursesProvider).value]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final disabled = ref.watch(disabledCoursesProvider);
  final disabledNotifier = ref.read(disabledCoursesProvider.notifier);
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

  // Named only when this account can use it (a key is saved), never the key or model.
  String? aiServiceInUse() {
    if (sample) return null;
    final provider = ref.read(aiSettingsProvider).provider;
    return ref.read(aiKeysProvider).contains(provider) ? provider.label : null;
  }

  Diagnostics diagnostics() => Diagnostics(
        appVersion: kAppVersion,
        windows: Platform.operatingSystemVersion,
        theme: appearance.theme.name,
        typeface: appearance.typeface.name,
        palette: appearance.palette.name,
        sampleMode: sample,
        aiService: aiServiceInUse(),
        notifications: notificationsOn,
        autoUpdateCheck: updatePrefs.autoCheck,
        dart: Platform.version.split(' ').first,
      );

  Future<void> copyDiagnostics() async {
    await Clipboard.setData(ClipboardData(text: diagnostics().toText()));
    ref.read(toastProvider.notifier).show('Diagnostics copied');
  }

  Future<void> signOut() async {
    final auth = ref.read(authProvider.notifier);
    final nav = Navigator.of(context);
    final ok = await confirmSignOut(context, sample: sample);
    if (!ok) return;
    nav.pop();
    auth.signOut();
  }

  const account = SettingsSection.account;
  const look = SettingsSection.appearance;
  const alerts = SettingsSection.notifications;
  const courseSection = SettingsSection.courses;
  const ai = SettingsSection.assistant;
  const files = SettingsSection.files;
  const updates = SettingsSection.updates;
  const keys = SettingsSection.shortcuts;
  const about = SettingsSection.about;

  return [
    // Account
    _row(
      account,
      session?.userName ?? 'Signed in',
      description: sample ? 'Sample data, nothing is sent to Canvas' : host,
      keywords: const ['account', 'sign out', 'log out', 'token', 'canvas'],
      trailing: EButton(label: 'Sign out', kind: EButtonKind.ghost, onTap: signOut),
    ),
    _note(account, 'Settings are saved on this computer, separately for each Canvas account. '
        'Your token is kept in the Windows credential store.'),

    // Appearance
    _block(
      look,
      'Theme',
      description: 'Light, dark, or whatever Windows uses',
      keywords: const ['dark', 'light', 'mode', 'windows', 'system', 'match'],
      child: EOptionCards(
        options: const [
          EOptionCard(label: 'Light', icon: EIcons.sun),
          EOptionCard(label: 'Dark', icon: EIcons.moon),
          EOptionCard(label: 'Match Windows', icon: EIcons.monitor),
        ],
        selected: switch (appearance.theme) {
          ThemeChoice.light => 0,
          ThemeChoice.dark => 1,
          ThemeChoice.system => 2,
        },
        onChanged: (i) => looks.setTheme(const [ThemeChoice.light, ThemeChoice.dark, ThemeChoice.system][i]),
      ),
    ),
    _row(
      look,
      'Accent colour',
      description: 'Buttons, links, selection and focus rings',
      keywords: [
        'colour', 'color', 'palette', 'accent',
        for (final p in PaletteChoice.values) p.label,
      ],
      trailing: EPalettePicker(
        colors: [for (final p in PaletteChoice.values) c.swatchOf(p)],
        labels: [for (final p in PaletteChoice.values) p.label],
        selected: appearance.palette.index,
        onChanged: (i) => looks.setPalette(PaletteChoice.values[i]),
      ),
    ),
    _block(
      look,
      'Font',
      description: 'Handwritten uses Ink Free, which comes with Windows',
      keywords: const ['handwritten', 'clean', 'typeface', 'ink free', 'inter'],
      child: EOptionCards(
        previewHeight: 48,
        options: const [
          EOptionCard(label: 'Handwritten', preview: _FontSample(handwritten: true)),
          EOptionCard(label: 'Clean', preview: _FontSample(handwritten: false)),
        ],
        selected: appearance.handwritten ? 0 : 1,
        onChanged: (i) => looks.setTypeface(i == 0 ? TypefaceChoice.handwritten : TypefaceChoice.clean),
      ),
    ),
    _block(
      look,
      'Background',
      description: 'What sits behind the lists',
      keywords: const ['pattern', 'dots', 'grid', 'plain', 'canvas', 'background'],
      child: EOptionCards(
        previewHeight: 48,
        options: [
          for (final p in BackgroundPattern.values) EOptionCard(label: p.label, preview: _PatternSample(p)),
        ],
        selected: appearance.background.index,
        onChanged: (i) => looks.setBackground(BackgroundPattern.values[i]),
      ),
    ),
    _note(look, 'The look is shared by every account on this computer.'),

    // Notifications
    _row(
      alerts,
      'Deadlines and new grades',
      description: 'Windows notifications for work due soon and grades just posted',
      keywords: const ['notifications', 'alerts', 'reminders', 'due', 'grade'],
      trailing: ESwitch(
        value: notificationsOn,
        onChanged: (on) => ref.read(notificationsProvider.notifier).set(on),
      ),
    ),

    // Courses
    _note(courseSection, 'Turned-off courses leave every list, count and notification. '
        'They stay in the sidebar under Disabled, and nothing is deleted.'),
    for (final course in courses)
      _row(
        courseSection,
        course.name,
        description: course.code.isEmpty || course.code == course.name ? null : course.code,
        keywords: const ['course', 'hide', 'disable', 'turn off'],
        leading: ESwatch(CoursePalette.colorFor(course.id), dim: disabled.contains(course.id)),
        trailing: ESwitch(
          value: !disabled.contains(course.id),
          onChanged: (on) => on ? disabledNotifier.enable(course.id) : disabledNotifier.disable(course.id),
        ),
      ),
    if (courses.isEmpty) _note(courseSection, 'Your courses appear here after the first sync.'),

    // Assistant
    SettingsItem(
      ai,
      const SettingsSearchText(
        title: 'AI service, API key and model',
        description: 'Your own key, kept in the Windows credential store',
        keywords: [
          'ai', 'assistant', 'key', 'api', 'model', 'server', 'address', 'url', 'anthropic', 'claude',
          'openai', 'deepseek', 'permission', 'consent', 'chat',
        ],
      ),
      (_) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.sunken,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line),
        ),
        child: const AiSettingsSection(),
      ),
    ),

    // Files & downloads
    SettingsItem(
      files,
      const SettingsSearchText(
        title: 'Offline files',
        description: 'Files you opened or saved offline, up to 3 GB',
        keywords: ['cache', 'storage', 'space', 'disk', 'clear', 'offline'],
      ),
      (q) => ValueListenableBuilder<int>(
        valueListenable: fileCacheRevision,
        builder: (context, _, _) {
          final bytes = ref.read(filesRepositoryProvider).offlineBytes();
          return SettingsRow(
            title: bytes == 0 ? 'Offline files: nothing saved' : 'Offline files: ${formatBytes(bytes)}',
            description: 'Files you opened or saved offline, up to 3 GB',
            query: q,
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
    ),
    _note(files, 'Downloads go to your Downloads folder and are marked as coming from the internet, '
        'so Office opens them in Protected View. Programs and scripts are only shown in their folder.'),

    // Updates
    if (UpdateService.supported) ...[
      _row(
        updates,
        'Check automatically',
        description: 'Asks GitHub for a new release about twice a day. Nothing about you is sent.',
        keywords: const ['update', 'version', 'release', 'github'],
        trailing: ESwitch(
          value: updatePrefs.autoCheck,
          onChanged: ref.read(updatePrefsProvider.notifier).setAutoCheck,
        ),
      ),
      _row(
        updates,
        updateTitle,
        description: updateSub,
        keywords: const ['update', 'check', 'version', "what's new"],
        trailing: EButton(
          label: updateState.status == UpdateStatus.available ? "See what's new" : 'Check now',
          kind: EButtonKind.ghost,
          loading: updateState.status == UpdateStatus.checking,
          onTap: updateState.status == UpdateStatus.downloading ? null : checkNow,
        ),
      ),
    ] else
      _note(updates, 'Updates are checked only in the installed Windows app.'),

    // Keyboard shortcuts
    for (final s in kShortcuts)
      _row(
        keys,
        s.description,
        description: s.group,
        keywords: ['shortcut', 'key', ...s.keys],
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < s.keys.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              EKeyCap(s.keys[i]),
            ],
          ],
        ),
      ),

    // Help & About
    _row(about, kAppName, description: 'Version $kAppVersion', keywords: const ['version', 'about']),
    _row(
      about,
      'Send feedback',
      description: 'Opens a new issue on GitHub. You read and edit it before sending.',
      keywords: const ['bug', 'report', 'issue', 'help', 'github'],
      trailing: EButton(
        label: 'Send feedback',
        kind: EButtonKind.ghost,
        onTap: () => openExternal(feedbackUri(diagnostics()).toString()),
      ),
    ),
    _row(
      about,
      'Copy diagnostics',
      description: 'Version, Windows and look only. No token, key, name or course.',
      keywords: const ['debug', 'support', 'info'],
      trailing: EButton(label: 'Copy', kind: EButtonKind.ghost, onTap: copyDiagnostics),
    ),
  ];
}

/// The sections that have a "Reset to defaults", and what each resets. Never
/// the token, API keys, permissions, grade plans, chats or offline files.
Map<SettingsSection, SettingsReset> settingsResets(WidgetRef ref) => {
      SettingsSection.appearance: SettingsReset(
        'Theme back to Match Windows, the handwritten font and violet.',
        () => ref.read(appearanceProvider.notifier).reset(),
      ),
      SettingsSection.notifications: SettingsReset(
        'Deadline and grade notifications back on.',
        () => ref.read(notificationsProvider.notifier).set(true),
      ),
      SettingsSection.courses: SettingsReset(
        'Every course turned back on. Nothing else changes.',
        () => ref.read(disabledCoursesProvider.notifier).enableAll(),
      ),
      SettingsSection.assistant: SettingsReset(
        'The service back to Anthropic and every model name back to its default. '
            'Your API keys, the server address and your permissions are kept.',
        () => ref.read(aiSettingsProvider.notifier).resetChoices(),
      ),
      if (UpdateService.supported)
        SettingsSection.updates: SettingsReset(
          'Automatic update checks back on.',
          () => ref.read(updatePrefsProvider.notifier).setAutoCheck(true),
        ),
    };

/// Two lines in the given font, for the Font cards.
class _FontSample extends StatelessWidget {
  const _FontSample({required this.handwritten});
  final bool handwritten;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = EtherText.build(c, handwritten: handwritten);
    return Container(
      color: c.canvas,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Problem Set 3', maxLines: 1, overflow: TextOverflow.ellipsis, style: s.label),
          Text('Due Friday 23:59', maxLines: 1, overflow: TextOverflow.ellipsis, style: s.meta),
        ],
      ),
    );
  }
}

/// A small piece of the canvas with [pattern], for the Background cards.
class _PatternSample extends StatelessWidget {
  const _PatternSample(this.pattern);
  final BackgroundPattern pattern;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return CustomPaint(
      painter: PatternPainter(c.canvas, c.dot, 12, MediaQuery.devicePixelRatioOf(context), pattern),
      child: const SizedBox.expand(),
    );
  }
}
