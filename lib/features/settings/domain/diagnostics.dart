import '../../update/domain/update_info.dart';

/// What "Copy diagnostics" puts on the clipboard and "Send feedback" prefills
/// in a GitHub issue. Only facts about the app and this computer: no token, no
/// API key, no name, no Canvas address, no course or file names.
class Diagnostics {
  const Diagnostics({
    required this.appVersion,
    required this.windows,
    required this.theme,
    required this.typeface,
    required this.sampleMode,
    required this.aiService,
    required this.notifications,
    required this.autoUpdateCheck,
    this.dart = '',
  });

  final String appVersion;

  /// `Platform.operatingSystemVersion`.
  final String windows;
  final String theme;
  final String typeface;
  final bool sampleMode;

  /// The chosen AI service's name, or null when it is not used. Never a key or model.
  final String? aiService;
  final bool notifications;
  final bool autoUpdateCheck;
  final String dart;

  String toText() {
    String yesNo(bool v) => v ? 'on' : 'off';
    return [
      'EtherLex $appVersion',
      'Windows: ${_oneLine(windows)}',
      if (dart.isNotEmpty) 'Dart: ${_oneLine(dart)}',
      'Mode: ${sampleMode ? 'sample data' : 'signed in to Canvas'}',
      'Look: $theme, $typeface font',
      'AI service chosen: ${aiService ?? 'not used'}',
      'Notifications: ${yesNo(notifications)}',
      'Automatic update check: ${yesNo(autoUpdateCheck)}',
    ].join('\n');
  }
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The new-issue page with a short template and [diagnostics] filled in, so the
/// student can read and edit everything before sending it.
Uri feedbackUri(Diagnostics diagnostics) => Uri.https('github.com', '/$kUpdateRepo/issues/new', {
      'body': [
        '**What happened, or what would you like?**',
        '',
        '',
        '**Steps to see it** (if it is a bug)',
        '',
        '',
        '<details><summary>Diagnostics</summary>',
        '',
        '```',
        diagnostics.toText(),
        '```',
        '',
        '</details>',
      ].join('\n'),
    });
