import 'dart:convert';
import 'dart:io';

import '../../../core/storage/app_dir.dart';
import '../domain/ai_settings.dart';

/// `%APPDATA%/EtherLex/ai.json`: provider, model names, server address.
class AiSettingsStore {
  AiSettingsStore({File? file}) : _file = file ?? File('${appDataPath()}${Platform.pathSeparator}ai.json');

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
