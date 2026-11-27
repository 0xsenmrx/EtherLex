import 'dart:io';

import 'account_scope.dart';
import 'app_dir.dart';
import 'json_file.dart';

abstract interface class SettingsStore {
  Future<Set<int>> readDisabledCourses();
  Future<void> writeDisabledCourses(Set<int> ids);
  Future<Set<int>> readHiddenFolders();
  Future<void> writeHiddenFolders(Set<int> ids);
  Future<Set<int>> readHiddenFileCourses();
  Future<void> writeHiddenFileCourses(Set<int> ids);
  Future<bool> readNotificationsEnabled();
  Future<void> writeNotificationsEnabled(bool on);

  /// Keys of alerts already shown, so each one fires once.
  Future<Set<String>> readNotified();
  Future<void> writeNotified(Set<String> keys);

  /// Per-course grade planner data (weights, class stats, letter quotas),
  /// keyed by course id as text.
  Future<Map<String, dynamic>> readGradePlans();
  Future<void> writeGradePlans(Map<String, dynamic> plans);

  /// Names of the AI services this account agreed to send Canvas data to.
  Future<Set<String>> readAiConsent();
  Future<void> writeAiConsent(Set<String> providers);

  /// The offline limit in GB (null: never chosen).
  Future<int?> readOfflineLimitGb();
  Future<void> writeOfflineLimitGb(int gb);

  /// How long assistant conversations are kept (a ChatRetention name).
  Future<String?> readChatRetention();
  Future<void> writeChatRetention(String name);

  /// Where downloads go (DownloadPrefs as JSON).
  Future<Map<String, dynamic>> readDownloadPrefs();
  Future<void> writeDownloadPrefs(Map<String, dynamic> prefs);

  /// How each page was left (ViewPrefs as JSON).
  Future<Map<String, dynamic>> readViewPrefs();
  Future<void> writeViewPrefs(Map<String, dynamic> prefs);

  /// What has been looked at (SeenState as JSON), so what is new can be marked.
  Future<Map<String, dynamic>> readSeen();
  Future<void> writeSeen(Map<String, dynamic> seen);

  /// The tasks you added yourself (the raw list; see `parseCustomTasks`).
  Future<List<Object?>> readCustomTasks();
  Future<void> writeCustomTasks(List<Map<String, dynamic>> tasks);
}

/// Tiny JSON file in the user's app-data folder (not secret, so not in the
/// credential store).
class FileSettingsStore implements SettingsStore {
  FileSettingsStore({File? file}) : _json = JsonFile(file ?? _defaultFile());

  /// One settings file per account (`settings/<scope>.json`). The first
  /// account to open after the upgrade inherits the old shared `settings.json`.
  factory FileSettingsStore.forScope(String scope, {String? root}) {
    final sep = Platform.pathSeparator;
    final base = root ?? appDataPath();
    final clean = cleanScope(scope);
    final file = File('$base${sep}settings$sep$clean.json');
    try {
      final legacy = File('$base${sep}settings.json');
      if (!file.existsSync() && legacy.existsSync()) {
        file.parent.createSync(recursive: true);
        legacy.copySync(file.path);
        legacy.renameSync('${legacy.path}.migrated'); // only the first account inherits it
      }
    } catch (_) {}
    return FileSettingsStore(file: file);
  }

  final JsonFile _json;

  static File _defaultFile() => File('${appDataPath()}${Platform.pathSeparator}settings.json');

  // Each write is a read-modify-write of the whole file (see JsonFile.update).
  Future<void> _update(void Function(Map<String, dynamic> map) change) => _json.update(change);

  Future<Map<String, dynamic>> _readMap() => _json.readMap();

  @override
  Future<Set<int>> readDisabledCourses() async {
    final raw = (await _readMap())['disabledCourses'];
    if (raw is! List) return <int>{};
    return {for (final v in raw) if (v is num) v.toInt()};
  }

  @override
  Future<void> writeDisabledCourses(Set<int> ids) async {
    await _update((map) => map['disabledCourses'] = ids.toList()..sort());
  }

  @override
  Future<Set<int>> readHiddenFolders() async {
    final raw = (await _readMap())['hiddenFolders'];
    if (raw is! List) return <int>{};
    return {for (final v in raw) if (v is num) v.toInt()};
  }

  @override
  Future<void> writeHiddenFolders(Set<int> ids) async {
    await _update((map) => map['hiddenFolders'] = ids.toList()..sort());
  }

  @override
  Future<Set<int>> readHiddenFileCourses() async {
    final raw = (await _readMap())['hiddenFileCourses'];
    if (raw is! List) return <int>{};
    return {for (final v in raw) if (v is num) v.toInt()};
  }

  @override
  Future<void> writeHiddenFileCourses(Set<int> ids) async {
    await _update((map) => map['hiddenFileCourses'] = ids.toList()..sort());
  }

  @override
  Future<bool> readNotificationsEnabled() async {
    final raw = (await _readMap())['notificationsEnabled'];
    return raw is bool ? raw : true;
  }

  @override
  Future<void> writeNotificationsEnabled(bool on) async {
    await _update((map) => map['notificationsEnabled'] = on);
  }

  @override
  Future<Set<String>> readNotified() async {
    final raw = (await _readMap())['notified'];
    if (raw is! List) return <String>{};
    return {for (final v in raw) if (v is String) v};
  }

  @override
  Future<void> writeNotified(Set<String> keys) async {
    await _update((map) => map['notified'] = keys.toList());
  }

  @override
  Future<Map<String, dynamic>> readGradePlans() async {
    final raw = (await _readMap())['gradePlans'];
    return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  }

  @override
  Future<void> writeGradePlans(Map<String, dynamic> plans) async {
    await _update((map) => map['gradePlans'] = plans);
  }

  @override
  Future<Set<String>> readAiConsent() async {
    final raw = (await _readMap())['aiConsent'];
    if (raw is! List) return <String>{};
    return {for (final v in raw) if (v is String) v};
  }

  @override
  Future<void> writeAiConsent(Set<String> providers) async {
    await _update((map) => map['aiConsent'] = providers.toList()..sort());
  }

  @override
  Future<Map<String, dynamic>> readViewPrefs() async {
    final raw = (await _readMap())['viewPrefs'];
    return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  }

  @override
  Future<void> writeViewPrefs(Map<String, dynamic> prefs) async {
    await _update((map) => map['viewPrefs'] = prefs);
  }

  @override
  Future<Map<String, dynamic>> readSeen() async {
    final raw = (await _readMap())['seen'];
    return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  }

  @override
  Future<void> writeSeen(Map<String, dynamic> seen) async {
    await _update((map) => map['seen'] = seen);
  }

  @override
  Future<List<Object?>> readCustomTasks() async {
    final raw = (await _readMap())['customTasks'];
    return raw is List ? List<Object?>.of(raw) : <Object?>[];
  }

  @override
  Future<void> writeCustomTasks(List<Map<String, dynamic>> tasks) async {
    await _update((map) => map['customTasks'] = tasks);
  }

  @override
  Future<int?> readOfflineLimitGb() async {
    final raw = (await _readMap())['offlineLimitGb'];
    return raw is num ? raw.toInt() : null;
  }

  @override
  Future<void> writeOfflineLimitGb(int gb) async {
    await _update((map) => map['offlineLimitGb'] = gb);
  }

  @override
  Future<Map<String, dynamic>> readDownloadPrefs() async {
    final raw = (await _readMap())['downloads'];
    return raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  }

  @override
  Future<void> writeDownloadPrefs(Map<String, dynamic> prefs) async {
    await _update((map) => map['downloads'] = prefs);
  }

  @override
  Future<String?> readChatRetention() async {
    final raw = (await _readMap())['chatRetention'];
    return raw is String ? raw : null;
  }

  @override
  Future<void> writeChatRetention(String name) async {
    await _update((map) => map['chatRetention'] = name);
  }
}
