import 'dart:io';

import 'package:etherlex/core/storage/account_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the scope is host plus user id, the bare host without an id', () {
    expect(accountScope('https://canvas.school.edu', 12), 'canvas.school.edu_u12');
    expect(accountScope('https://canvas.school.edu', 13), isNot(accountScope('https://canvas.school.edu', 12)));
    expect(accountScope('https://canvas.school.edu', null), 'canvas.school.edu');
  });

  group('adoptLegacyAccountData', () {
    late Directory dir;
    late String sep;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('etherlex_scope_');
      sep = Platform.pathSeparator;
    });
    tearDown(() {
      // Windows can still hold a just-written file for a moment; a leftover temp folder is harmless.
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // ignore
      }
    });

    File at(String rel) => File('${dir.path}$sep${rel.replaceAll('/', sep)}');

    void seed(String host) {
      final stem = databaseStem(host);
      for (final rel in [
        'settings/$host.json',
        'chats/$host.json',
        'files/$host/1_2_a.txt',
        'file_index/$host/1.json',
        'cache_$stem.sqlite',
        'cache_$stem.sqlite-wal',
      ]) {
        at(rel)
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('old');
      }
    }

    test('moves every part of the old host data to the account', () {
      seed('canvas.school.edu');
      adoptLegacyAccountData(host: 'canvas.school.edu', scope: 'canvas.school.edu_u12', root: dir.path);
      for (final rel in [
        'settings/canvas.school.edu_u12.json',
        'chats/canvas.school.edu_u12.json',
        'files/canvas.school.edu_u12/1_2_a.txt',
        'file_index/canvas.school.edu_u12/1.json',
        'cache_canvas_school_edu_u12.sqlite',
        'cache_canvas_school_edu_u12.sqlite-wal',
      ]) {
        expect(at(rel).readAsStringSync(), 'old', reason: rel);
      }
      expect(at('settings/canvas.school.edu.json').existsSync(), isFalse);
      expect(at('cache_canvas_school_edu.sqlite').existsSync(), isFalse);
    });

    test('only the first account adopts; a second one on the same host starts empty', () {
      seed('canvas.school.edu');
      adoptLegacyAccountData(host: 'canvas.school.edu', scope: 'canvas.school.edu_u12', root: dir.path);
      adoptLegacyAccountData(host: 'canvas.school.edu', scope: 'canvas.school.edu_u13', root: dir.path);
      expect(at('settings/canvas.school.edu_u12.json').existsSync(), isTrue);
      expect(at('settings/canvas.school.edu_u13.json').existsSync(), isFalse);
      expect(at('files/canvas.school.edu_u13').existsSync(), isFalse);
    });

    test('never overwrites data the account already has', () {
      seed('canvas.school.edu');
      at('settings/canvas.school.edu_u12.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('mine');
      adoptLegacyAccountData(host: 'canvas.school.edu', scope: 'canvas.school.edu_u12', root: dir.path);
      expect(at('settings/canvas.school.edu_u12.json').readAsStringSync(), 'mine');
      expect(at('settings/canvas.school.edu.json').readAsStringSync(), 'old');
    });

    test('does nothing without old data, without an id, or for another host', () {
      adoptLegacyAccountData(host: 'canvas.school.edu', scope: 'canvas.school.edu_u12', root: dir.path);
      expect(dir.listSync(), isEmpty);
      seed('canvas.school.edu');
      adoptLegacyAccountData(host: 'canvas.school.edu', scope: 'canvas.school.edu', root: dir.path);
      adoptLegacyAccountData(host: 'other.edu', scope: 'other.edu_u1', root: dir.path);
      expect(at('settings/canvas.school.edu.json').existsSync(), isTrue);
    });
  });
}
