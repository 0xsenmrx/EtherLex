import '../../../core/utils/open_path.dart' show sanitizeFileName;

/// Where downloads go, per account (Settings > Files & downloads).
class DownloadPrefs {
  const DownloadPrefs({this.folder, this.askEachTime = false, this.folderPerCourse = false});

  /// A folder the student chose; null means the Windows Downloads folder.
  final String? folder;

  /// Show a Save dialog for every download.
  final bool askEachTime;

  /// Put each course's downloads in a subfolder named after the course.
  final bool folderPerCourse;

  DownloadPrefs copyWith({String? Function()? folder, bool? askEachTime, bool? folderPerCourse}) => DownloadPrefs(
        folder: folder == null ? this.folder : folder(),
        askEachTime: askEachTime ?? this.askEachTime,
        folderPerCourse: folderPerCourse ?? this.folderPerCourse,
      );

  Map<String, Object?> toJson() => {'folder': folder, 'askEachTime': askEachTime, 'folderPerCourse': folderPerCourse};

  static DownloadPrefs fromJson(Object? json) {
    if (json is! Map) return const DownloadPrefs();
    final folder = json['folder'];
    return DownloadPrefs(
      folder: folder is String && folder.trim().isNotEmpty ? folder : null,
      askEachTime: json['askEachTime'] == true,
      folderPerCourse: json['folderPerCourse'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DownloadPrefs &&
      other.folder == folder &&
      other.askEachTime == askEachTime &&
      other.folderPerCourse == folderPerCourse;

  @override
  int get hashCode => Object.hash(folder, askEachTime, folderPerCourse);
}

/// The folder a download goes to: the chosen one or [windowsDownloads],
/// plus a subfolder named after [courseName] when [DownloadPrefs.folderPerCourse].
String downloadDirectory(DownloadPrefs p, {required String windowsDownloads, String? courseName, String sep = r'\'}) {
  var dir = (p.folder ?? windowsDownloads).replaceAll(RegExp(r'[\\/]+$'), '');
  if (p.folderPerCourse && courseName != null && courseName.trim().isNotEmpty) {
    dir = '$dir$sep${sanitizeFileName(courseName.trim())}';
  }
  return dir;
}

String _norm(String path) => path.replaceAll('/', r'\').replaceAll(RegExp(r'\\+$'), '').toLowerCase();

/// False for a folder EtherLex must not save into: empty, or inside its own
/// data folder ([appData]), where downloads would mix with settings and the
/// offline cache.
bool isAllowedDownloadDir(String dir, {required String appData}) {
  if (dir.trim().isEmpty) return false;
  final d = _norm(dir);
  final a = _norm(appData);
  return d != a && !d.startsWith('$a\\');
}
