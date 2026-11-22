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
  // Windows launchers and ClickOnce, PowerShell's old shells, Access projects, old add-ins.
  'appref-ms', 'settingcontent-ms', 'diagcab', 'website', 'application', 'xbap', 'ws',
  'msh', 'msh1', 'msh2', 'mshxml', 'msh1xml', 'msh2xml', 'ade', 'adp', 'mde', 'accde', 'mda',
  'xla', 'xlsb', 'cab', 'theme', 'themepack', 'desktopthemepack', 'ms-appinstaller',
};

/// Web pages run their scripts when a browser opens them from disk.
const _web = {'html', 'htm', 'shtml', 'xhtml', 'xht', 'mht', 'mhtml', 'svg', 'svgz'};

/// How EtherLex may open a file that came from Canvas.
enum OpenSafety {
  /// Documents, pictures, archives: open with the default app.
  open,

  /// Web pages: open only after the student says yes.
  askFirst,

  /// Programs, scripts, launchers, macro documents: only shown in the folder.
  revealOnly,
}

/// The extension Windows would act on: the text after the last dot of the
/// file name, ignoring trailing dots and spaces (Windows drops them, so
/// `a.exe.` runs as `a.exe`) and NTFS stream names (`a.exe:x`).
String _launchExtension(String path) {
  var name = path.split(RegExp(r'[\\/]')).last;
  final colon = name.indexOf(':');
  if (colon >= 0) name = name.substring(0, colon);
  name = name.replaceAll(RegExp(r'[. ]+$'), '');
  final dot = name.lastIndexOf('.');
  return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
}

OpenSafety openSafetyOf(String path) {
  final ext = _launchExtension(path);
  if (_risky.contains(ext)) return OpenSafety.revealOnly;
  if (_web.contains(ext)) return OpenSafety.askFirst;
  return OpenSafety.open;
}

bool isRiskyFile(String path) => openSafetyOf(path) == OpenSafety.revealOnly;

/// What Windows writes next to a file downloaded from the internet. With it,
/// Office opens the file in Protected View and SmartScreen checks programs.
const String kZoneIdentifier = '[ZoneTransfer]\r\nZoneId=3\r\nHostUrl=about:internet\r\n';

/// Marks [path] as downloaded from the internet (Windows and NTFS only;
/// quietly does nothing elsewhere or when the disk cannot hold the mark).
Future<void> markFromInternet(String path) async {
  if (!Platform.isWindows) return;
  try {
    await File('$path:Zone.Identifier').writeAsString(kZoneIdentifier, flush: true);
  } catch (_) {}
}

/// Opens a downloaded file with its default app, marked as coming from the
/// internet. Programs and scripts are only revealed in the folder, never run;
/// web pages are revealed too (use `openWithCare` where the student can be
/// asked first).
Future<void> openDownloaded(String path) async {
  try {
    if (openSafetyOf(path) != OpenSafety.open) {
      await revealInFolder(path);
      return;
    }
    await launchMarked(path);
  } catch (_) {}
}

/// Marks [path] as coming from the internet and opens it with its default
/// app, without any other check. Callers decide with [openSafetyOf] first.
Future<void> launchMarked(String path) async {
  await markFromInternet(path);
  if (Platform.isWindows) {
    await Process.run('explorer', [path]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [path]);
  } else {
    await Process.run('xdg-open', [path]);
  }
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
