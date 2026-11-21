import 'dart:io';

import 'app_dir.dart';

/// The name under which one account's data is kept on disk: the Canvas host
/// plus the user id, so two people on the same site never share anything.
/// Without an id (a sign-in whose id is not known yet) it is the host alone,
/// which is where all data lived before accounts were told apart.
String accountScope(String baseUrl, int? userId) {
  final host = Uri.tryParse(baseUrl)?.host ?? '';
  return userId == null ? host : '${host}_u$userId';
}

/// [name] with everything but letters, digits, '.', '_' and '-' replaced, as
/// the settings, chat and file stores name their files.
String cleanScope(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// The database file name stem for [scope]: letters and digits only.
String databaseStem(String scope) => scope.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

/// Moves the data kept under the old, host-only name to [scope], so the first
/// account that opens a site after the upgrade keeps what it already had.
/// Nothing is deleted or overwritten: a part is only renamed when the old one
/// exists and the new one does not, so a second account on the same host
/// starts empty. Call before anything opens the account's files.
void adoptLegacyAccountData({required String host, required String scope, String? root}) {
  if (host.isEmpty || host == scope) return;
  final sep = Platform.pathSeparator;
  final base = root ?? appDataPath();

  void move(String from, String to) {
    try {
      final type = FileSystemEntity.typeSync(from);
      if (type == FileSystemEntityType.notFound) return;
      if (FileSystemEntity.typeSync(to) != FileSystemEntityType.notFound) return;
      Directory(to).parent.createSync(recursive: true);
      if (type == FileSystemEntityType.directory) {
        Directory(from).renameSync(to);
      } else {
        File(from).renameSync(to);
      }
    } catch (_) {
      // Left where it is; the account then starts empty instead of failing.
    }
  }

  final oldName = cleanScope(host);
  final newName = cleanScope(scope);
  move('$base${sep}settings$sep$oldName.json', '$base${sep}settings$sep$newName.json');
  move('$base${sep}chats$sep$oldName.json', '$base${sep}chats$sep$newName.json');
  move('$base${sep}files$sep$oldName', '$base${sep}files$sep$newName');
  move('$base${sep}file_index$sep$oldName', '$base${sep}file_index$sep$newName');
  for (final end in const ['.sqlite', '.sqlite-wal', '.sqlite-shm', '.sqlite-journal']) {
    move('$base${sep}cache_${databaseStem(host)}$end', '$base${sep}cache_${databaseStem(scope)}$end');
  }
}
