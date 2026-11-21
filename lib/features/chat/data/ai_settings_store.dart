import 'dart:convert';
import 'dart:io';

import '../../../core/storage/account_scope.dart';
import '../../../core/storage/app_dir.dart';
import '../domain/ai_settings.dart';

/// Provider, model names and server address of one account:
/// `%APPDATA%/EtherLex/ai/<scope>.json`. Without a [scope] (an account whose id
/// is not known yet) the old shared `ai.json` is used.
class AiSettingsStore {
  AiSettingsStore({File? file}) : _file = file ?? File('${appDataPath()}${Platform.pathSeparator}ai.json');

  /// The shared `ai.json` of an older version moves to the first account that
  /// opens this store ([adoptLegacy]); later accounts start with the defaults.
  factory AiSettingsStore.forScope(String? scope, {String? root, bool adoptLegacy = true}) {
    final sep = Platform.pathSeparator;
    final base = root ?? appDataPath();
    final legacy = File('$base${sep}ai.json');
    if (scope == null) return AiSettingsStore(file: legacy);
    final file = File('$base${sep}ai$sep${cleanScope(scope)}.json');
    try {
      if (adoptLegacy && !file.existsSync() && legacy.existsSync()) {
        file.parent.createSync(recursive: true);
        legacy.renameSync(file.path);
      }
    } catch (_) {}
    return AiSettingsStore(file: file);
  }

  final File _file;

  Future<AiSettings> read() async {
    try {
      if (!await _file.exists()) return const AiSettings();
      return AiSettings.fromJson(jsonDecode(await _file.readAsString()));
    } catch (_) {
      return const AiSettings();
    }
  }

  Future<void>? _pending;

  /// Writes run one after another, so quick changes cannot interleave.
  Future<void> write(AiSettings s) {
    final next = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => writeFileAtomically(_file, jsonEncode(s.toJson())));
    _pending = next;
    return next;
  }
}
