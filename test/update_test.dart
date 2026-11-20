import 'dart:io';

import 'package:etherlex/app/app_info.dart';
import 'package:etherlex/features/update/data/update_prefs_store.dart';
import 'package:etherlex/features/update/domain/release_notes.dart';
import 'package:etherlex/features/update/domain/update_info.dart';
import 'package:etherlex/features/update/domain/update_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

const _hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _base = 'https://github.com/$kUpdateRepo/releases/download/v0.2.2';

Map<String, Object?> _release({
  String tag = 'v0.2.2',
  Object? assets,
  bool draft = false,
  bool prerelease = false,
  String body = '- Fixed it',
}) =>
    {
      'tag_name': tag,
      'draft': draft,
      'prerelease': prerelease,
      'body': body,
      'html_url': 'https://github.com/$kUpdateRepo/releases/tag/$tag',
      'assets': assets ??
          [
            {
              'name': 'EtherLex-Setup-0.2.2.exe',
              'browser_download_url': '$_base/EtherLex-Setup-0.2.2.exe',
              'size': 1234,
              'digest': 'sha256:${_hash.toUpperCase()}',
            },
          ],
    };

void main() {
  group('AppVersion', () {
    test('parses plain, v-prefixed and build-suffixed versions', () {
      expect(AppVersion.tryParse('0.2.1'), const AppVersion(0, 2, 1));
      expect(AppVersion.tryParse('v1.10.0'), const AppVersion(1, 10, 0));
      expect(AppVersion.tryParse('0.2.1+3'), const AppVersion(0, 2, 1));
    });

    test('rejects what is not a release version', () {
      expect(AppVersion.tryParse('0.2'), isNull);
      expect(AppVersion.tryParse('v1.0.0-beta'), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
    });

    test('compares numbers, not text', () {
      expect(AppVersion.tryParse('0.10.0')! > AppVersion.tryParse('0.9.9')!, isTrue);
      expect(AppVersion.tryParse('1.0.0')! > AppVersion.tryParse('0.99.99')!, isTrue);
      expect(AppVersion.tryParse('0.2.1')! > AppVersion.tryParse('0.2.1')!, isFalse);
      expect(AppVersion.tryParse('v0.2.1'), AppVersion.tryParse('0.2.1'));
    });

    test('the version shown in the app matches pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec);
      expect(m, isNotNull);
      expect(kAppVersion, m![1]);
    });
  });

  group('parseRelease', () {
    test('reads a normal release', () {
      final info = parseRelease(_release())!;
      expect(info.version, const AppVersion(0, 2, 2));
      expect(info.installerName, 'EtherLex-Setup-0.2.2.exe');
      expect(info.installerUrl.toString(), '$_base/EtherLex-Setup-0.2.2.exe');
      expect(info.sha256, _hash);
      expect(info.size, 1234);
      expect(info.notes, '- Fixed it');
    });

    test('skips drafts, pre-releases and odd input', () {
      expect(parseRelease(_release(draft: true)), isNull);
      expect(parseRelease(_release(prerelease: true)), isNull);
      expect(parseRelease(_release(tag: 'nightly')), isNull);
      expect(parseRelease(null), isNull);
      expect(parseRelease('nonsense'), isNull);
    });

    test('a release without an installer is an error, not "up to date"', () {
      expect(() => parseRelease(_release(assets: <Object>[])), throwsFormatException);
    });

    test('refuses an installer hosted anywhere but this repository', () {
      for (final url in [
        'https://evil.example/EtherLex-Setup-0.2.2.exe',
        'http://github.com/$kUpdateRepo/releases/download/v0.2.2/EtherLex-Setup-0.2.2.exe',
        'https://github.com/someone/else/releases/download/v1/EtherLex-Setup-0.2.2.exe',
        'https://github.com.evil.example/$kUpdateRepo/releases/download/v1/EtherLex-Setup-0.2.2.exe',
      ]) {
        final release = _release(assets: [
          {'name': 'EtherLex-Setup-0.2.2.exe', 'browser_download_url': url, 'digest': 'sha256:$_hash'},
        ]);
        expect(() => parseRelease(release), throwsFormatException, reason: url);
      }
    });

    test('uses a .sha256 asset when GitHub gives no digest', () {
      final info = parseRelease(_release(assets: [
        {'name': 'EtherLex-Setup-0.2.2.exe', 'browser_download_url': '$_base/EtherLex-Setup-0.2.2.exe'},
        {'name': 'EtherLex-Setup-0.2.2.exe.sha256', 'browser_download_url': '$_base/EtherLex-Setup-0.2.2.exe.sha256'},
      ]))!;
      expect(info.sha256, isNull);
      expect(info.checksumUrl.toString(), '$_base/EtherLex-Setup-0.2.2.exe.sha256');
      expect(info.withSha256(_hash).sha256, _hash);
    });

    test('no digest and no checksum asset is refused', () {
      final release = _release(assets: [
        {'name': 'EtherLex-Setup-0.2.2.exe', 'browser_download_url': '$_base/EtherLex-Setup-0.2.2.exe'},
      ]);
      expect(() => parseRelease(release), throwsFormatException);
    });

    test('a malformed digest is ignored', () {
      final release = _release(assets: [
        {
          'name': 'EtherLex-Setup-0.2.2.exe',
          'browser_download_url': '$_base/EtherLex-Setup-0.2.2.exe',
          'digest': 'sha256:abc',
        },
      ]);
      expect(() => parseRelease(release), throwsFormatException);
    });
  });

  group('parseChecksumFile', () {
    test('finds the hash for the file, in sha256sum format', () {
      const text = '$_hash  EtherLex-Setup-0.2.2.exe\r\n';
      expect(parseChecksumFile(text, 'EtherLex-Setup-0.2.2.exe'), _hash);
      expect(parseChecksumFile('${_hash.toUpperCase()} *EtherLex-Setup-0.2.2.exe', 'EtherLex-Setup-0.2.2.exe'), _hash);
    });

    test('accepts a bare hash, rejects another file and garbage', () {
      expect(parseChecksumFile(_hash, 'EtherLex-Setup-0.2.2.exe'), _hash);
      expect(parseChecksumFile('$_hash  other.exe', 'EtherLex-Setup-0.2.2.exe'), isNull);
      expect(parseChecksumFile('not a hash', 'EtherLex-Setup-0.2.2.exe'), isNull);
      expect(parseChecksumFile('', 'x'), isNull);
    });
  });

  group('parseReleaseNotes', () {
    test('turns Markdown into plain lines', () {
      const body = '## 0.2.2\r\n\r\n### Fixed\r\n- **Scrolling** a PDF no longer freezes [the window](https://x.example).\r\n'
          '* Uses `Flutter` 3.47.8\r\n---\r\nThanks for testing.';
      expect(parseReleaseNotes(body), [
        const NoteLine(NoteKind.heading, '0.2.2'),
        const NoteLine(NoteKind.heading, 'Fixed'),
        const NoteLine(NoteKind.bullet, 'Scrolling a PDF no longer freezes the window.'),
        const NoteLine(NoteKind.bullet, 'Uses Flutter 3.47.8'),
        const NoteLine(NoteKind.text, 'Thanks for testing.'),
      ]);
    });

    test('empty body and the line limit', () {
      expect(parseReleaseNotes(''), isEmpty);
      expect(parseReleaseNotes('\n\n  \n'), isEmpty);
      final long = List.generate(100, (i) => '- item $i').join('\n');
      expect(parseReleaseNotes(long, maxLines: 10), hasLength(10));
    });
  });

  group('update prefs', () {
    final now = DateTime.utc(2026, 11, 20, 12);

    test('check on first run, then only every 12 hours, and never when off', () {
      expect(shouldAutoCheck(const UpdatePrefs(), now), isTrue);
      expect(shouldAutoCheck(UpdatePrefs(lastCheck: now.subtract(const Duration(hours: 1))), now), isFalse);
      expect(shouldAutoCheck(UpdatePrefs(lastCheck: now.subtract(const Duration(hours: 13))), now), isTrue);
      expect(shouldAutoCheck(UpdatePrefs(lastCheck: now.add(const Duration(days: 1))), now), isTrue);
      expect(shouldAutoCheck(const UpdatePrefs(autoCheck: false), now), isFalse);
    });

    test('offers only newer versions, and not a skipped one unless asked', () {
      final info = parseRelease(_release())!;
      const current = AppVersion(0, 2, 1);
      expect(shouldOffer(info, current, const UpdatePrefs()), isTrue);
      expect(shouldOffer(info, const AppVersion(0, 2, 2), const UpdatePrefs()), isFalse);
      expect(shouldOffer(info, const AppVersion(0, 3, 0), const UpdatePrefs()), isFalse);
      const skipped = UpdatePrefs(skippedVersion: '0.2.2');
      expect(shouldOffer(info, current, skipped), isFalse);
      expect(shouldOffer(info, current, skipped, ignoreSkip: true), isTrue);
    });

    test('json round-trip and broken input', () {
      final p = UpdatePrefs(autoCheck: false, skippedVersion: '0.2.2', lastCheck: now);
      expect(UpdatePrefs.fromJson(p.toJson()), p);
      expect(UpdatePrefs.fromJson('nonsense'), const UpdatePrefs());
      expect(UpdatePrefs.fromJson({'autoCheck': 'no', 'lastCheck': 5}), const UpdatePrefs());
    });

    test('store writes, reads back, and survives a corrupt file', () async {
      final dir = Directory.systemTemp.createTempSync('etherlex_update_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/sub/updates.json');
      final store = UpdatePrefsStore(file: file);
      expect(await store.read(), const UpdatePrefs());
      final p = UpdatePrefs(autoCheck: false, skippedVersion: '1.0.0', lastCheck: now);
      await store.write(p);
      expect(await store.read(), p);
      file.writeAsStringSync('{not json');
      expect(await store.read(), const UpdatePrefs());
    });
  });
}
