import 'dart:io';

import 'package:etherlex/core/storage/settings_store.dart';
import 'package:etherlex/features/assignments/data/custom_task_list.dart';
import 'package:etherlex/features/assignments/data/mock_assignments_repository.dart';
import 'package:etherlex/features/assignments/data/with_custom_tasks_repository.dart';
import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/assignments/domain/custom_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('model', () {
    test('json round trip keeps everything', () {
      final t = CustomTask(
        id: -5,
        title: 'Read chapter 4',
        courseId: 7,
        dueAt: DateTime(2026, 12, 5, 18, 30),
        notes: 'pages 80-110',
        done: true,
        starred: true,
      );
      expect(CustomTask.fromJson(t.toJson()), t);
    });

    test('a task without a due date or course', () {
      final t = CustomTask.fromJson({'id': -1, 'title': ' Call the registrar '})!;
      expect(t.title, 'Call the registrar');
      expect(t.dueAt, isNull);
      expect(t.courseId, kPersonalCourseId);
      expect(t.done, isFalse);
    });

    test('untrusted entries are skipped, the rest stay', () {
      final list = parseCustomTasks([
        {'id': -1, 'title': 'ok'},
        {'id': 5, 'title': 'positive id would look like a Canvas assignment'},
        {'id': -2, 'title': '   '},
        {'id': -3},
        {'id': 'x', 'title': 'bad id'},
        'not a map',
        null,
        {'id': -1, 'title': 'same id again'},
        {'id': -4, 'title': 'fine', 'courseId': -9, 'dueAt': 'soon'},
      ]);
      expect(list.map((t) => t.id), [-1, -4]);
      expect(list.first.title, 'ok');
      expect(list.last.courseId, kPersonalCourseId);
      expect(list.last.dueAt, isNull);
      expect(parseCustomTasks('nope'), isEmpty);
      expect(parseCustomTasks(null), isEmpty);
    });

    test('very long text is cut', () {
      final t = CustomTask.fromJson({'id': -1, 'title': 'x' * 1000, 'notes': 'n' * 10000})!;
      expect(t.title.length, kMaxTaskTitle);
      expect(t.notes.length, kMaxTaskNotes);
    });

    test('it shows up as an assignment with a negative id', () {
      final a = CustomTask(id: -9, title: 'T', courseId: 2, dueAt: DateTime(2026, 1, 2), starred: true).toAssignment();
      expect(a.isPersonal, isTrue);
      expect(a.id, -9);
      expect(a.courseId, 2);
      expect(a.points, isNull);
      expect(a.starred, isTrue);
      expect(const Assignment(id: 101, courseId: 1, title: 'x', dueAt: null, points: null).isPersonal, isFalse);
    });

    test('new ids are negative and never repeat', () {
      final now = DateTime(2026, 11, 27, 12);
      final first = nextCustomTaskId(const [], now: now);
      expect(first, lessThan(0));
      final second = nextCustomTaskId([first], now: now);
      expect(second, isNot(first));
      expect(second, lessThan(0));
    });
  });

  group('due date', () {
    test('reads the three forms', () {
      expect(parseTaskDue('2026-12-05'), DateTime(2026, 12, 5, 23, 59));
      expect(parseTaskDue('2026-12-05 18:30'), DateTime(2026, 12, 5, 18, 30));
      expect(parseTaskDue('2026-12-05T08:05'), DateTime(2026, 12, 5, 8, 5));
      expect(parseTaskDue('5.12.2026'), DateTime(2026, 12, 5, 23, 59));
      expect(parseTaskDue('05.12.2026 18:30'), DateTime(2026, 12, 5, 18, 30));
      expect(parseTaskDue('  2026/1/2 9:00 '), DateTime(2026, 1, 2, 9, 0));
    });

    test('rejects what is not a real date and time', () {
      for (final bad in ['', 'tomorrow', '2026-02-31', '2026-13-01', '2026-12-05 24:00', '2026-12-05 18:75', '32.1.2026', '1999-1-1x', '12/05/2026']) {
        expect(parseTaskDue(bad), isNull, reason: bad);
      }
    });

    test('format reads back', () {
      final d = DateTime(2026, 3, 4, 5, 6);
      expect(formatTaskDue(d), '2026-03-04 05:06');
      expect(parseTaskDue(formatTaskDue(d)), d);
    });
  });

  group('stored with the account', () {
    late Directory dir;
    late File file;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('etherlex_tasks_');
      file = File('${dir.path}${Platform.pathSeparator}settings.json');
    });
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // a leftover temp folder is harmless
      }
    });

    test('tasks survive a restart; done and star are kept', () async {
      final a = CustomTaskList(FileSettingsStore(file: file));
      final t = await a.create(title: 'Essay outline', courseId: 3, dueAt: DateTime(2026, 12, 1, 12), notes: 'ask Prof.');
      await a.setDone(t.id, true);
      await a.setStarred(t.id, true);
      a.dispose();

      final b = CustomTaskList(FileSettingsStore(file: file));
      await b.create(title: 'Second');
      expect(b.tasks.length, 2);
      final back = b.tasks.firstWhere((x) => x.id == t.id);
      expect(back.title, 'Essay outline');
      expect(back.courseId, 3);
      expect(back.dueAt, DateTime(2026, 12, 1, 12));
      expect(back.notes, 'ask Prof.');
      expect(back.done, isTrue);
      expect(back.starred, isTrue);
      b.dispose();
    });

    test('edit and delete', () async {
      final list = CustomTaskList(FileSettingsStore(file: file));
      final t = await list.create(title: 'A', dueAt: DateTime(2026, 12, 1));
      await list.update(t.copyWith(title: 'B', clearDue: true));
      expect(list.tasks.single.title, 'B');
      expect(list.tasks.single.dueAt, isNull);
      await list.remove(t.id);
      expect(list.tasks, isEmpty);
      list.dispose();
      expect(parseCustomTasks(await FileSettingsStore(file: file).readCustomTasks()), isEmpty);
    });

    test('a task added at once after opening does not wipe the saved ones', () async {
      final first = CustomTaskList(FileSettingsStore(file: file));
      await first.create(title: 'Old one');
      first.dispose();
      final second = CustomTaskList(FileSettingsStore(file: file));
      await second.create(title: 'New one'); // not waiting for the first read by hand
      expect(second.tasks.map((t) => t.title), containsAll(['Old one', 'New one']));
      second.dispose();
    });

    test('merged with the Canvas list; done and star of a task stay out of Canvas data', () async {
      final tasks = CustomTaskList(FileSettingsStore(file: file));
      final repo = WithCustomTasksRepository(MockAssignmentsRepository(now: DateTime(2026, 11, 27, 12)), tasks);
      final t = await tasks.create(title: 'Mine', dueAt: DateTime(2026, 12, 2));

      var list = await repo.watch().first;
      expect(list.where((a) => a.isPersonal).map((a) => a.title), ['Mine']);
      expect(list.where((a) => !a.isPersonal), isNotEmpty);

      await repo.setDone(t.id, true); // routed to the task
      await repo.setStarred(101, true); // routed to the sample data
      list = await repo.watch().first;
      expect(list.firstWhere((a) => a.id == t.id).done, isTrue);
      expect(list.firstWhere((a) => a.id == 101).starred, isTrue);
      expect(list.firstWhere((a) => a.id == 102).done, isFalse);

      // A change shows up on a stream that is already open.
      final seen = <int>[];
      final sub = repo.watch().listen((l) => seen.add(l.where((a) => a.isPersonal).length));
      await Future<void>.delayed(Duration.zero);
      await tasks.create(title: 'Another');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(seen.last, 2);
      repo.dispose();
      tasks.dispose();
    });
  });
}
