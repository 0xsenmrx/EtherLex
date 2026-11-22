import 'dart:io';

import '../../../core/storage/app_dir.dart';
import '../../../core/storage/json_file.dart';
import '../domain/update_prefs.dart';

/// `%APPDATA%/EtherLex/updates.json`.
class UpdatePrefsStore {
  UpdatePrefsStore({File? file})
      : _json = JsonFile(file ?? File('${appDataPath()}${Platform.pathSeparator}updates.json'));

  final JsonFile _json;

  /// A missing or damaged file gives the defaults.
  Future<UpdatePrefs> read() async {
    try {
      return UpdatePrefs.fromJson(await _json.read());
    } catch (_) {
      return const UpdatePrefs();
    }
  }

  /// Writes run one after another.
  Future<void> write(UpdatePrefs prefs) => _json.write(prefs.toJson());
}
