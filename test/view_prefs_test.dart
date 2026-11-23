import 'dart:io';

import 'package:etherlex/core/storage/settings_store.dart';
import 'package:etherlex/features/settings/domain/view_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults: All, folded groups, no filter, the course list', () {
    const p = ViewPrefs();
    expect(p.assignmentsStarredOnly, isFalse);
    expect(p.assignmentsShowDone, isFalse);
    expect(p.activityKind, isNull);
    expect(p.gradesShowUngraded, isFalse);
    expect(p.filesCourseId, isNull);
    expect(p.filesFolderPath, isEmpty);
  });

  test('json round-trip', () {
    const p = ViewPrefs(
      assignmentsStarredOnly: true,
      assignmentsShowDone: true,
      activityKind: 'grade',
      gradesShowUngraded: true,
      filesCourseId: 42,
      filesFolderPath: [7, 9],
    );
    expect(ViewPrefs.fromJson(p.toJson()), p);
  });

  test('broken values fall back to defaults', () {
    expect(ViewPrefs.fromJson(null), const ViewPrefs());
    expect(ViewPrefs.fromJson('x'), const ViewPrefs());
    final p = ViewPrefs.fromJson({
      'assignmentsStarredOnly': 'yes',
      'activityKind': 3,
      'filesCourseId': 'nine',
      'filesFolderPath': [1, 'two', 3.0],
    });
    expect(p.assignmentsStarredOnly, isFalse);
    expect(p.activityKind, isNull);
    expect(p.filesCourseId, isNull);
    expect(p.filesFolderPath, [1, 3]);
  });

  test('copyWith can clear the filter and the course', () {
    const p = ViewPrefs(activityKind: 'grade', filesCourseId: 1, filesFolderPath: [2]);
    final q = p.copyWith(activityKind: () => null, filesCourseId: () => null, filesFolderPath: const []);
    expect(q.activityKind, isNull);
    expect(q.filesCourseId, isNull);
    expect(q.filesFolderPath, isEmpty);
    expect(p.copyWith(), p);
  });

  test('kept in the account settings file next to the other settings', () async {
    final dir = Directory.systemTemp.createTempSync('etherlex_view_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold the file for a moment.
      }
    });
    final store = FileSettingsStore(file: File('${dir.path}/s.json'));
    await store.writeDisabledCourses({5});
    const p = ViewPrefs(assignmentsStarredOnly: true, filesCourseId: 3);
    await store.writeViewPrefs(Map<String, dynamic>.from(p.toJson()));
    expect(ViewPrefs.fromJson(await store.readViewPrefs()), p);
    expect(await store.readDisabledCourses(), {5});
  });
}
