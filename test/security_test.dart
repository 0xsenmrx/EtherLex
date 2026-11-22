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
}
