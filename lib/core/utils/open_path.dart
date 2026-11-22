import 'dart:io';

String downloadsDirPath() {
  final env = Platform.environment;
  final home = env['USERPROFILE'] ?? env['HOME'] ?? Directory.systemTemp.path;
  return '$home${Platform.pathSeparator}Downloads';
}

const _reserved = {
  'con', 'prn', 'aux', 'nul', 'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7',
  'com8', 'com9', 'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9',
};

/// Safe file name for any OS: no path separators or reserved characters.
String sanitizeFileName(String name) {
  var s = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
  s = s.replaceAll(RegExp(r'[. ]+$'), '');
  if (s.isEmpty) s = 'file';
  if (s.length > 150) {
    final dot = s.lastIndexOf('.');
    final ext = dot > 0 && s.length - dot <= 10 ? s.substring(dot) : '';
    s = s.substring(0, 150 - ext.length) + ext;
  }
  final base = s.split('.').first.toLowerCase();
  if (_reserved.contains(base)) s = '_$s';
  return s;
}

/// "report.pdf" -> "report (1).pdf" when the name is taken.
String uniquePath(String dir, String fileName) {
  final sep = Platform.pathSeparator;
  var candidate = '$dir$sep$fileName';
  if (!File(candidate).existsSync()) return candidate;
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '';
  for (var i = 1; i < 1000; i++) {
    candidate = '$dir$sep$stem ($i)$ext';
    if (!File(candidate).existsSync()) return candidate;
  }
  return '$dir$sep$stem (${DateTime.now().millisecondsSinceEpoch})$ext';
}

const _risky = {
  'exe', 'bat', 'cmd', 'com', 'msi', 'ps1', 'vbs', 'vbe', 'js', 'jse', 'wsf', 'jar',
  'scr', 'lnk', 'reg', 'hta', 'pif', 'cpl', 'dll', 'sh', 'app', 'command', 'appimage',
  // Shortcuts, installers, packages, macro documents and other things that can run code.
  'url', 'chm', 'msp', 'msix', 'msixbundle', 'appx', 'appxbundle', 'psm1', 'ps1xml', 'psc1',
  'msc', 'wsh', 'wsc', 'vb', 'inf', 'ins', 'isp', 'gadget', 'scf', 'iso', 'img', 'vhd', 'vhdx',
  'docm', 'dotm', 'xlsm', 'xltm', 'xlam', 'xll', 'pptm', 'potm', 'ppam', 'ppsm', 'sldm',
  'jnlp', 'library-ms', 'searchconnector-ms', 'pyw', 'py', 'rb', 'pl',
};

bool isRiskyFile(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 && _risky.contains(path.substring(dot + 1).toLowerCase());
}

/// Opens a downloaded file with its default app. Programs and scripts are
/// only revealed in the folder, never run.
Future<void> openDownloaded(String path) async {
  try {
    if (isRiskyFile(path)) {
      await revealInFolder(path);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else {
      await Process.run('xdg-open', [path]);
    }
  } catch (_) {}
}

Future<void> revealInFolder(String path) async {
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,$path']);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else {
      await Process.run('xdg-open', [File(path).parent.path]);
    }
  } catch (_) {}
}
