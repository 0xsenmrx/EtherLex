import 'dart:io';

/// Per-user folder for EtherLex's own files (settings, cache databases).
String appDataPath() {
  final env = Platform.environment;
  final sep = Platform.pathSeparator;
  final base = env['APPDATA'] ??
      env['XDG_CONFIG_HOME'] ??
      (env['HOME'] != null ? '${env['HOME']}$sep.config' : Directory.systemTemp.path);
  return '$base${sep}EtherLex';
}

/// Replaces [file] with [contents] in one step: the text goes to a temporary
/// file first, which is then renamed over the original. A crash or power
/// loss leaves either the old file or the new one, never half of one.
///
/// Windows refuses to replace a file that another program has open for a
/// moment (a virus scanner, the search indexer, a reader). The rename is
/// tried again for up to about a second before the write gives up, so a
/// passing reader does not make a save get lost.
Future<void> writeFileAtomically(File file, String contents) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(contents, flush: true);
  for (var attempt = 1;; attempt++) {
    try {
      await tmp.rename(file.path);
      return;
    } on FileSystemException {
      if (attempt >= 10) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 20 * attempt));
    }
  }
}
