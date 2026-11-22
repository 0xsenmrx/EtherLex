import 'dart:io';

import 'package:etherlex/core/network/canvas_client.dart';
import 'package:etherlex/core/utils/open_path.dart';
import 'package:etherlex/features/chat/data/openai_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = 'https://school.instructure.com';

  group('isSameOrigin (the token only goes to Canvas itself)', () {
    test('same host over https', () {
      expect(isSameOrigin(Uri.parse('https://school.instructure.com/api/v1/courses?page=2'), base), isTrue);
      expect(isSameOrigin(Uri.parse('https://SCHOOL.instructure.com/x'), base), isTrue);
    });

    test('plain http is never the same origin', () {
      expect(isSameOrigin(Uri.parse('http://school.instructure.com/api/v1/courses?page=2'), base), isFalse);
    });

    test('another host, a look-alike host or another port', () {
      expect(isSameOrigin(Uri.parse('https://evil.example/x'), base), isFalse);
      expect(isSameOrigin(Uri.parse('https://school.instructure.com.evil.example/x'), base), isFalse);
      expect(isSameOrigin(Uri.parse('https://school.instructure.com:8443/x'), base), isFalse);
    });

    test('a base with its own port', () {
      expect(isSameOrigin(Uri.parse('https://canvas.local:8443/x'), 'https://canvas.local:8443'), isTrue);
      expect(isSameOrigin(Uri.parse('https://canvas.local/x'), 'https://canvas.local:8443'), isFalse);
    });
  });

  group('redirectTarget', () {
    final from = Uri.parse('https://school.instructure.com/files/1/download');

    test('absolute and relative https locations', () {
      expect(redirectTarget(from, 'https://s3.amazonaws.com/b/f?sig=1').toString(), 'https://s3.amazonaws.com/b/f?sig=1');
      expect(redirectTarget(from, '/files/1/download?x=1').toString(), 'https://school.instructure.com/files/1/download?x=1');
    });

    test('http, other schemes and empty locations are refused', () {
      expect(redirectTarget(from, 'http://s3.amazonaws.com/f'), isNull);
      expect(redirectTarget(from, 'file:///C:/secret'), isNull);
      expect(redirectTarget(from, ''), isNull);
      expect(redirectTarget(from, null), isNull);
    });
  });

  group('isAllowedAiBaseUrl', () {
    test('https anywhere', () {
      expect(isAllowedAiBaseUrl('https://api.openai.com/v1'), isTrue);
      expect(isAllowedAiBaseUrl('https://models.example.org/v1'), isTrue);
    });

    test('http only on this computer', () {
      expect(isAllowedAiBaseUrl('http://localhost:11434/v1'), isTrue);
      expect(isAllowedAiBaseUrl('http://127.0.0.1:1234/v1'), isTrue);
      expect(isAllowedAiBaseUrl('http://192.168.1.20:11434/v1'), isFalse);
      expect(isAllowedAiBaseUrl('http://models.example.org/v1'), isFalse);
      expect(isAllowedAiBaseUrl('http://localhost.evil.example/v1'), isFalse);
    });

    test('junk', () {
      expect(isAllowedAiBaseUrl('ftp://x'), isFalse);
      expect(isAllowedAiBaseUrl(''), isFalse);
      expect(isAllowedAiBaseUrl('api.openai.com'), isFalse);
    });
  });

  test('more things that can run code are only revealed, never opened', () {
    for (final f in ['a.url', 'a.chm', 'a.docm', 'a.XLSM', 'a.iso', 'a.msix', 'a.psm1', 'a.scf']) {
      expect(isRiskyFile('C:/x/$f'), isTrue, reason: f);
    }
    for (final f in ['a.pdf', 'a.docx', 'a.xlsx', 'a.pptx', 'a.png', 'a.txt', 'a.zip']) {
      expect(isRiskyFile('C:/x/$f'), isFalse, reason: f);
    }
  });

  group('openSafetyOf', () {
    test('Windows launchers, ClickOnce and old add-ins are only revealed', () {
      for (final f in [
        'a.appref-ms', 'a.settingcontent-ms', 'a.diagcab', 'a.website', 'a.application', 'a.xbap',
        'a.ws', 'a.msh', 'a.mshxml', 'a.ade', 'a.adp', 'a.mde', 'a.accde', 'a.xla', 'a.xlsb',
        'a.cab', 'a.theme', 'a.ms-appinstaller', 'A.APPREF-MS',
      ]) {
        expect(openSafetyOf('C:\\Users\\x\\$f'), OpenSafety.revealOnly, reason: f);
      }
    });

    test('web pages ask first', () {
      for (final f in ['a.html', 'a.HTM', 'a.mht', 'a.mhtml', 'a.xhtml', 'a.svg', 'notes.pdf.html']) {
        expect(openSafetyOf('C:/x/$f'), OpenSafety.askFirst, reason: f);
      }
    });

    test('documents open', () {
      for (final f in ['a.pdf', 'report.html.pdf', 'a.docx', 'a.png', 'README', 'a.zip']) {
        expect(openSafetyOf('C:/x/$f'), OpenSafety.open, reason: f);
      }
    });

    test('the name decides, not a dot in a folder', () {
      expect(openSafetyOf('C:/my.exe/readme'), OpenSafety.open);
      expect(openSafetyOf('C:\\my.html\\notes.txt'), OpenSafety.open);
    });

    test('trailing dots and spaces and stream names do not hide a program', () {
      expect(openSafetyOf('C:/x/a.exe.'), OpenSafety.revealOnly);
      expect(openSafetyOf('C:/x/a.exe . '), OpenSafety.revealOnly);
      expect(openSafetyOf('C:/x/a.exe:stream'), OpenSafety.revealOnly);
      expect(openSafetyOf('C:/x/page.html.'), OpenSafety.askFirst);
    });
  });

  group('markFromInternet', () {
    test('writes zone 3', () {
      expect(kZoneIdentifier, contains('ZoneId=3'));
      expect(kZoneIdentifier, startsWith('[ZoneTransfer]'));
    });

    test('adds the Zone.Identifier stream on Windows', () async {
      final dir = await Directory.systemTemp.createTemp('etherlex_motw');
      try {
        final file = File('${dir.path}${Platform.pathSeparator}a.docx')..writeAsStringSync('x');
        await markFromInternet(file.path);
        final mark = File('${file.path}:Zone.Identifier');
        expect(await mark.readAsString(), kZoneIdentifier);
        expect(file.readAsStringSync(), 'x');
      } finally {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }, skip: Platform.isWindows ? false : 'NTFS streams exist only on Windows');
  });
}
