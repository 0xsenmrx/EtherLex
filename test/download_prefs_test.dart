import 'package:etherlex/features/files/domain/download_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const windows = r'D:\Users\arsen\Downloads';

  test('defaults: the Windows Downloads folder, no dialog, no course folders', () {
    const p = DownloadPrefs();
    expect(downloadDirectory(p, windowsDownloads: windows), windows);
    expect(p.askEachTime, isFalse);
    expect(p.folderPerCourse, isFalse);
  });

  test('a chosen folder wins; trailing separators are dropped', () {
    const p = DownloadPrefs(folder: r'E:\Uni\');
    expect(downloadDirectory(p, windowsDownloads: windows), r'E:\Uni');
  });

  test('a subfolder per course, with a safe name', () {
    const p = DownloadPrefs(folderPerCourse: true);
    expect(downloadDirectory(p, windowsDownloads: windows, courseName: 'Linear Algebra: Fall 2026'),
        r'D:\Users\arsen\Downloads\Linear Algebra_ Fall 2026');
    expect(downloadDirectory(p, windowsDownloads: windows), windows, reason: 'no course: no subfolder');
    expect(downloadDirectory(p, windowsDownloads: windows, courseName: '  '), windows);
  });

  test('json round-trip and broken values', () {
    const p = DownloadPrefs(folder: r'E:\Uni', askEachTime: true, folderPerCourse: true);
    expect(DownloadPrefs.fromJson(p.toJson()), p);
    expect(DownloadPrefs.fromJson(null), const DownloadPrefs());
    expect(DownloadPrefs.fromJson({'folder': '', 'askEachTime': 'yes'}), const DownloadPrefs());
    expect(p.copyWith(folder: () => null).folder, isNull);
  });

  group('isAllowedDownloadDir', () {
    const appData = r'C:\Users\arsen\AppData\Roaming\EtherLex';

    test('normal folders are fine', () {
      expect(isAllowedDownloadDir(windows, appData: appData), isTrue);
      expect(isAllowedDownloadDir(r'C:\Users\arsen\AppData\Roaming\EtherLexOther', appData: appData), isTrue);
    });

    test("EtherLex's own data folder and anything inside it are refused, whatever the case or slashes", () {
      expect(isAllowedDownloadDir(appData, appData: appData), isFalse);
      expect(isAllowedDownloadDir('$appData\\files', appData: appData), isFalse);
      expect(isAllowedDownloadDir(r'c:/users/arsen/appdata/roaming/etherlex/settings/', appData: appData), isFalse);
    });

    test('empty is refused', () {
      expect(isAllowedDownloadDir('  ', appData: appData), isFalse);
    });
  });
}
