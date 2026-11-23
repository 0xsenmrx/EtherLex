import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/open_path.dart';

const MethodChannel _window = MethodChannel('etherlex/window');

/// Where Windows keeps the user's Downloads (it may have been moved to
/// another drive or to OneDrive), asked from the runner. Falls back to
/// `%USERPROFILE%\Downloads` elsewhere or when Windows cannot say.
Future<String> windowsDownloadsFolder() async {
  if (Platform.isWindows) {
    try {
      final path = await _window.invokeMethod<String>('downloadsFolder');
      if (path != null && path.trim().isNotEmpty) return path;
    } on MissingPluginException {
      // Not in the EtherLex runner (tests).
    } on PlatformException {
      // The window is not ready.
    }
  }
  return downloadsDirPath();
}
