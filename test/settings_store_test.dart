import 'dart:io';

import 'package:etherlex/core/storage/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('disabled courses round-trip', () async {
    final store = FileSettingsStore(file: File('${dir.path}/sub/settings.json'));
    expect(await store.readDisabledCourses(), isEmpty);
    await store.writeDisabledCourses({5, 2, 9});
    expect(await store.readDisabledCourses(), {2, 5, 9});
    await store.writeDisabledCourses({});
    expect(await store.readDisabledCourses(), isEmpty);
  });

  test('corrupt file is treated as empty', () async {
    final f = File('${dir.path}/settings.json')..writeAsStringSync('{not json');
    expect(await FileSettingsStore(file: f).readDisabledCourses(), isEmpty);
  });

  test('hidden folders round-trip independently of disabled courses', () async {
    final store = FileSettingsStore(file: File('${dir.path}/settings.json'));
    await store.writeDisabledCourses({1});
    await store.writeHiddenFolders({30, 10});
    expect(await store.readHiddenFolders(), {10, 30});
    expect(await store.readDisabledCourses(), {1});
  });

  test('notification settings round-trip', () async {
    final store = FileSettingsStore(file: File('${dir.path}/settings.json'));
    expect(await store.readNotificationsEnabled(), isTrue);
    await store.writeNotificationsEnabled(false);
    expect(await store.readNotificationsEnabled(), isFalse);
    await store.writeNotified({'a', 'b'});
    expect(await store.readNotified(), {'a', 'b'});
  });

  test('grade plans round-trip', () async {
    final store = FileSettingsStore(file: File('${dir.path}/settings.json'));
    expect(await store.readGradePlans(), isEmpty);
    await store.writeGradePlans({'4': {'w': {'1': 20}}});
    expect((await store.readGradePlans())['4'], isNotNull);
  });

  test('each account has its own file; the first one inherits the old shared file', () async {
    File('${dir.path}/settings.json').writeAsStringSync('{"disabledCourses":[7]}');
    final a = FileSettingsStore.forScope('a.example.com', root: dir.path);
    final b = FileSettingsStore.forScope('b.example.com', root: dir.path);
    expect(await a.readDisabledCourses(), {7});
    expect(await b.readDisabledCourses(), isEmpty);
    await b.writeDisabledCourses({1});
    expect(await a.readDisabledCourses(), {7});
    expect(await FileSettingsStore.forScope('b.example.com', root: dir.path).readDisabledCourses(), {1});
  });

  test('writes started together keep every change', () async {
    final store = FileSettingsStore(file: File('${dir.path}/settings.json'));
    await Future.wait([
      store.writeDisabledCourses({1}),
      store.writeHiddenFolders({2}),
      store.writeHiddenFileCourses({3}),
      store.writeNotificationsEnabled(false),
    ]);
    expect(await store.readDisabledCourses(), {1});
    expect(await store.readHiddenFolders(), {2});
    expect(await store.readHiddenFileCourses(), {3});
    expect(await store.readNotificationsEnabled(), isFalse);
    expect(File('${dir.path}/settings.json.tmp').existsSync(), isFalse);
  });
}
