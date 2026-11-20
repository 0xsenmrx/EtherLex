import 'dart:convert';
import 'dart:io';

import '../../../core/storage/app_dir.dart';
import '../domain/update_prefs.dart';

/// `%APPDATA%/EtherLex/updates.json`.
class UpdatePrefsStore {
  UpdatePrefsStore({File? file})
      : _file = file ?? File('${appDataPath()}${Platform.pathSeparator}updates.json');

  final File _file;

  Future<UpdatePrefs> read() async {
    try {
      if (!await _file.exists()) return const UpdatePrefs();
      return UpdatePrefs.fromJson(jsonDecode(await _file.readAsString()));
    } catch (_) {
      return const UpdatePrefs();
    }
  }

  Future<void>? _pending;

  /// Writes run one after another.
  Future<void> write(UpdatePrefs prefs) {
    final next = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => writeFileAtomically(_file, jsonEncode(prefs.toJson())));
    _pending = next;
    return next;
  }
}
