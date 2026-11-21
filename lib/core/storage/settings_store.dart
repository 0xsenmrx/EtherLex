import 'dart:convert';
import 'dart:io';

import 'app_dir.dart';

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
}

/// Tiny JSON file in the user's app-data folder (not secret, so not in the
/// credential store). Will move into the Drift database with the cache step.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore({File? file}) : _file = file ?? _defaultFile();

  /// One settings file per account (`settings/<scope>.json`). The first
  /// account to open after the upgrade inherits the old shared `settings.json`.
  factory FileSettingsStore.forScope(String scope, {String? root}) {
    final sep = Platform.pathSeparator;
    final base = root ?? appDataPath();
    final clean = scope.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
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

  final File _file;

  static File _defaultFile() => File('${appDataPath()}${Platform.pathSeparator}settings.json');

  // Each write is a read-modify-write of the whole file. Writes run one at a
  // time (two at once would each drop the other's change) and replace the
  // file in one step (a crash mid-write must not wipe every setting).
  static final Map<String, Future<void>> _queues = {};

  Future<void> _update(void Function(Map<String, dynamic> map) change) {
    final key = _file.path;
    final next = (_queues[key] ?? Future<void>.value()).catchError((Object _) {}).then((_) async {
      final map = await _readMap();
      change(map);
      await writeFileAtomically(_file, jsonEncode(map));
    });
    _queues[key] = next;
    return next;
  }

  Future<Map<String, dynamic>> _readMap() async {
    try {
      if (!await _file.exists()) return <String, dynamic>{};
      final decoded = jsonDecode(await _file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

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
}
