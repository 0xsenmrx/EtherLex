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
Future<void> writeFileAtomically(File file, String contents) async {
  await file.parent.create(recursive: true);
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(contents, flush: true);
  await tmp.rename(file.path);
}
