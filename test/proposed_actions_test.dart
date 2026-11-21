import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/chat/domain/proposed_actions.dart';
import 'package:etherlex/features/courses/domain/course.dart';
import 'package:flutter_test/flutter_test.dart';

const _courses = {1: Course(id: 1, name: 'Physics', code: 'PHYS101')};
const _known = [
  Assignment(id: 1, courseId: 1, title: 'Lab 1', dueAt: null, points: 10),
  Assignment(id: 2, courseId: 1, title: 'HW 1', dueAt: null, points: 5, starred: true),
  Assignment(id: 3, courseId: 1, title: 'HW 2', dueAt: null, points: 5, done: true),
];

void main() {
  group('parseActions', () {
    test('reads star and done actions, value defaults to true', () {
      final p = parseActions('{"actions":[{"type":"star","assignments":[1,2]},{"type":"done","assignments":[3],"value":false}],"note":" why "}')!;
      expect(p.actions.length, 2);
      expect(p.actions.first.kind, ActionKind.star);
      expect(p.actions.first.value, isTrue);
      expect(p.actions.first.caution, isFalse);
      expect(p.actions.last.value, isFalse);
      expect(p.actions.last.caution, isTrue);
      expect(p.note, 'why');
    });

    test('anything unusable, including unknown types, gives null', () {
      for (final bad in [
        'nope',
        '{}',
        '{"actions":[]}',
        '{"actions":[{"type":"submit","assignments":[1]}]}',
        '{"actions":[{"type":"star","assignments":[]}]}',
        '{"actions":[{"type":"star","assignments":["1"]}]}',
        '{"actions":[{"type":"star","assignments":[0]}]}',
        '{"actions":[{"type":"star","assignments":[1,1]}]}',
        '{"actions":[{"type":"star","assignments":[1],"value":"yes"}]}',
        '{"actions":[1]}',
      ]) {
        expect(parseActions(bad), isNull, reason: bad);
      }
      expect(parseActions('{"actions":[${List.filled(21, '{"type":"star","assignments":[1]}').join(',')}]}'), isNull);
    });
  });

  group('previewActions', () {
    test('marks what changes, what is already so, and what does not exist', () {
      final p = parseActions('{"actions":[{"type":"star","assignments":[1,2,99]},{"type":"done","assignments":[3]}]}')!;
      final lines = previewActions(p, _known, _courses);
      expect([for (final l in lines) l.effect], [ActionEffect.change, ActionEffect.same, ActionEffect.unknown, ActionEffect.same]);
      expect(lines.first.title, 'Lab 1');
      expect(lines.first.course, 'PHYS101');
      expect(lines.first.previous, isFalse);
    });

    test('later actions see the effect of earlier ones', () {
      final p = parseActions('{"actions":[{"type":"star","assignments":[1]},{"type":"star","assignments":[1],"value":false}]}')!;
      final lines = previewActions(p, _known, _courses);
      expect([for (final l in lines) l.effect], [ActionEffect.change, ActionEffect.change]);
      expect(lines.last.previous, isTrue);
    });
  });

  group('applyActions', () {
    test('changes only what differs and undo restores it', () async {
      final starred = {1: false, 2: true};
      final done = {3: true};
      Future<void> setStarred(int id, bool v) async => starred[id] = v;
      Future<void> setDone(int id, bool v) async => done[id] = v;
      final p = parseActions('{"actions":[{"type":"star","assignments":[1,2]},{"type":"done","assignments":[3],"value":false}]}')!;
      final calls = <String>[];
      final undo = await applyActions(
        previewActions(p, _known, _courses),
        setStarred: (id, v) async {
          calls.add('star $id $v');
          await setStarred(id, v);
        },
        setDone: (id, v) async {
          calls.add('done $id $v');
          await setDone(id, v);
        },
      );
      expect(calls, ['star 1 true', 'done 3 false']); // 2 is already starred: untouched
      expect(starred, {1: true, 2: true});
      expect(done, {3: false});
      await undoActions(undo, setStarred: setStarred, setDone: setDone);
      expect(starred, {1: false, 2: true});
      expect(done, {3: true});
    });

    test('a failure part way reports what was already changed', () async {
      final p = parseActions('{"actions":[{"type":"star","assignments":[1]},{"type":"done","assignments":[3],"value":false}]}')!;
      final calls = <int>[];
      await expectLater(
        applyActions(
          previewActions(p, _known, _courses),
          setStarred: (id, v) async => calls.add(id),
          setDone: (id, v) async => throw StateError('disk'),
        ),
        throwsA(isA<ApplyFailed>().having((e) => e.done[ActionKind.star], 'star', {1: false})),
      );
      expect(calls, [1]);
    });
  });
}
