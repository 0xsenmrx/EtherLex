import 'dart:io';

/// Opens [url] in the default browser. Only https links are allowed.
Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
  try {
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', uri.toString()]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [uri.toString()]);
    } else {
      await Process.run('xdg-open', [uri.toString()]);
    }
  } catch (_) {}
}
