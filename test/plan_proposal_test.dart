import 'package:etherlex/features/courses/domain/course.dart';
import 'package:etherlex/features/grades/domain/grade_plan.dart';
import 'package:etherlex/features/grades/domain/grades.dart';
import 'package:etherlex/features/grades/domain/plan_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

const _ok = '''
{"course":"Physics II","categories":[
  {"name":"Homework","weight":20,"count":10},
  {"name":"Midterm","weight":30},
  {"name":"Final exam","weight":50}],
 "curve":{"A":20,"B":40},"note":"From the syllabus, page 2"}''';

void main() {
  group('parseProposal', () {
    test('reads a good plan', () {
      final p = parseProposal(_ok)!;
      expect(p.course, 'Physics II');
      expect(p.categories.map((c) => c.name), ['Homework', 'Midterm', 'Final exam']);
      expect(p.categories.first.count, 10);
      expect(p.categories[1].count, isNull);
      expect(p.weightTotal, 100);
      expect(p.curve, {'A': 20, 'B': 40});
      expect(p.note, contains('syllabus'));
    });

    test('a curve alone is a plan, and extra fields are ignored', () {
      final p = parseProposal('{"curve":{"A+":10},"anything":1}')!;
      expect(p.categories, isEmpty);
      expect(p.curve, {'A+': 10});
    });

    test('anything unusable gives null', () {
      for (final bad in [
        'not json',
        '[]',
        '{}',
        '{"categories":[]}',
        '{"categories":[{"name":"A","weight":-1}]}',
        '{"categories":[{"name":"A","weight":101}]}',
        '{"categories":[{"name":"A","weight":"20"}]}',
        '{"categories":[{"name":"","weight":20}]}',
        '{"categories":[{"name":"A","weight":20,"count":0}]}',
        '{"categories":[{"name":"A","weight":20,"count":1.5}]}',
        '{"categories":[{"name":"Quiz","weight":10},{"name":"QUIZ!","weight":10}]}',
        '{"curve":{"Z":10}}',
        '{"curve":{"A":60,"B":60}}',
      ]) {
        expect(parseProposal(bad), isNull, reason: bad);
      }
    });
  });

  group('guessed parts', () {
    test('curve and counts may be flagged as estimates; nothing else counts', () {
      final p = parseProposal('{"curve":{"A":10},"guessed":["curve","weights","counts",3]}')!;
      expect(p.guessed, {'curve', 'counts'});
      expect(parseProposal('{"curve":{"A":10}}')!.guessed, isEmpty);
      expect(parseProposal('{"curve":{"A":10},"guessed":"curve"}')!.guessed, isEmpty);
    });

    test('weights, categories and moves are not guessable', () {
      expect(kGuessable, {'curve', 'counts'});
    });
  });

  group('matchCourse', () {
    const courses = [
      Course(id: 1, name: 'Physics II', code: 'PHYS2'),
      Course(id: 2, name: 'Physics Lab', code: 'PHYS2L'),
      Course(id: 3, name: 'Electronic Circuits', code: 'ECE3110J'),
    ];
    test('matches by name or code, ignoring case and punctuation', () {
      expect(matchCourse('physics ii', courses)?.id, 1);
      expect(matchCourse('ECE-3110J', courses)?.id, 3);
      expect(matchCourse('Electronic Circuits (Fall 2026)', courses)?.id, 3);
    });
    test('null when nothing or several fit', () {
      expect(matchCourse('Chemistry', courses), isNull);
      expect(matchCourse('Physics', courses), isNull);
      expect(matchCourse(null, courses), isNull);
    });
  });

  group('applyProposal', () {
    const groups = [
      AssignmentGroup(id: 10, name: 'Homework'),
      AssignmentGroup(id: 11, name: 'Exams'),
      AssignmentGroup(id: 12, name: 'Participation', weight: 5),
    ];

    test('matches Canvas categories, creates the rest, and zeroes what is not mentioned', () {
      final r = applyProposal(GradePlan.empty, parseProposal(_ok)!, groups);
      expect(r.plan.weights[10], 20);
      expect(r.plan.totals[10], 10);
      expect(r.plan.weights[12], 0);
      expect(r.plan.quotas, {'A': 20, 'B': 40});
      expect(r.plan.customGroups.values, ['Midterm']);
      final kinds = {for (final x in r.rows) x.name: x.kind};
      expect(kinds['Homework'], PlanRowKind.canvas);
      expect(kinds['Final exam'], PlanRowKind.canvas); // matches the Canvas category "Exams"
      expect(r.plan.weights[11], 50);
      expect(kinds['Midterm'], PlanRowKind.created);
      expect(kinds['Participation'], PlanRowKind.dropped);
      final created = r.rows.where((x) => x.kind == PlanRowKind.created).single.groupId!;
      expect(created, lessThan(0));
      expect(r.plan.weights[created], 30);
    });

    test('reuses a category the student made before, and applying twice changes nothing more', () {
      final first = applyProposal(GradePlan.empty, parseProposal(_ok)!, groups);
      final again = applyProposal(first.plan, parseProposal(_ok)!, groups);
      expect(again.plan.customGroups.length, first.plan.customGroups.length);
      expect(again.rows.where((x) => x.kind == PlanRowKind.created), isEmpty);
      expect(again.plan.toJson(), first.plan.toJson());
    });

    test('a curve-only plan leaves weights and categories alone', () {
      final old = GradePlan.empty.withWeight(10, 40);
      final r = applyProposal(old, parseProposal('{"curve":{"A":10}}')!, groups);
      expect(r.plan.weights, {10: 40});
      expect(r.plan.quotas, {'A': 10});
      expect(r.rows, isEmpty);
    });

    test('the old plan is not changed (so Undo can restore it)', () {
      final old = GradePlan.empty.withWeight(10, 40);
      applyProposal(old, parseProposal(_ok)!, groups);
      expect(old.weights, {10: 40});
      expect(old.quotas, isEmpty);
    });

    test('moves put assignments in a category by name, and skip what cannot be placed', () {
      final p = parseProposal(
        '{"moves":[{"assignment":1,"category":"homework"},{"assignment":2,"category":"Nope"},{"assignment":99,"category":"Exams"}]}',
      )!;
      final r = applyProposal(GradePlan.empty, p, groups, knownAssignments: {1, 2});
      expect(r.plan.moves, {1: 10});
      expect([for (final m in r.moves) m.status], [MoveStatus.ok, MoveStatus.unknownCategory, MoveStatus.unknownAssignment]);
    });

    test('a move can target a category the same plan creates', () {
      final p = parseProposal(
        '{"categories":[{"name":"Lab","weight":15}],"moves":[{"assignment":5,"category":"Lab"}]}',
      )!;
      final r = applyProposal(GradePlan.empty, p, groups);
      final lab = r.plan.customGroups.entries.single.key;
      expect(r.plan.moves, {5: lab});
    });
  });

  group('moves in a proposal', () {
    test('are read and checked', () {
      final p = parseProposal('{"moves":[{"assignment":3,"category":"Lab"}]}')!;
      expect(p.moves.single.assignment, 3);
      for (final bad in [
        '{"moves":[{"assignment":"3","category":"Lab"}]}',
        '{"moves":[{"assignment":0,"category":"Lab"}]}',
        '{"moves":[{"assignment":3,"category":""}]}',
        '{"moves":[{"assignment":3,"category":"A"},{"assignment":3,"category":"B"}]}',
        '{"moves":"x"}',
      ]) {
        expect(parseProposal(bad), isNull, reason: bad);
      }
    });
  });
}
