import 'package:etherlex/features/grades/domain/grade_calc.dart';
import 'package:etherlex/features/grades/domain/grade_plan.dart';
import 'package:etherlex/features/grades/domain/grades.dart';
import 'package:flutter_test/flutter_test.dart';

GradedItem item(int id, int group, double points, {double? score, GradeState? state}) => GradedItem(
      id: id,
      title: 'I$id',
      state: state ?? (score != null ? GradeState.graded : GradeState.open),
      points: points,
      score: score,
      groupId: group,
    );

void main() {
  const groups = [
    AssignmentGroup(id: 1, name: 'Homework'),
    AssignmentGroup(id: 2, name: 'Quizzes', weight: 10),
  ];

  test('own weights give current, floor and best', () {
    final items = [
      item(1, 2, 1, score: 1),
      item(2, 2, 1), // open quiz
      item(3, 1, 10, score: 8),
    ];
    final w = effectiveWeights(groups, {1: 90});
    expect(w, {1: 90, 2: 10}); // quizzes fall back to Canvas's 10
    final g = computeWeighted(items, groups, w);
    expect(g.current, closeTo(82, 1e-9)); // 10*1 + 90*.8
    expect(g.worst, closeTo(77, 1e-9)); // 10*.5 + 90*.8
    expect(g.best, closeTo(82, 1e-9)); // 10*1 + 90*.8
    final quizzes = g.categories.firstWhere((c) => c.group.id == 2);
    expect(quizzes.count, 2);
    expect(quizzes.eachWeight, closeTo(5, 1e-9));
  });

  test('no weights, no grade; unknown group becomes Other; excused ignored', () {
    final items = [
      item(1, 99, 10, score: 5),
      item(2, 1, 10, state: GradeState.excused),
    ];
    final none = computeWeighted(items, groups, const {});
    expect(none.current, isNull);
    expect(none.categories.where((c) => c.count > 0).single.group.name, 'Other');
    final g = computeWeighted(items, groups, {-1: 50});
    expect(g.current, closeTo(50, 1e-9));
  });

  test('quartile model: cdf, rank and ties', () {
    const s = ClassStats(low: 40, q1: 60, median: 70, q3: 80, high: 95);
    expect(s.usable, isTrue);
    expect(s.cdf(70), closeTo(0.5, 1e-9));
    expect(s.cdf(75), closeTo(0.625, 1e-9));
    expect(s.rank(70), closeTo(0.5, 1e-9));
    expect(s.rank(10), 0);
    expect(s.rank(99), 1);
    // Half the class scored the maximum: you are in the middle of that block.
    const tie = ClassStats(low: 5, q1: 10, median: 10, q3: 10, high: 10);
    expect(tie.rank(10), closeTo(0.625, 1e-9));
  });

  test('letters from the top share and the teacher quotas', () {
    const quotas = {'A+': 10.0, 'A': 20.0, 'A-': 20.0, 'B': 50.0};
    final e = letterForTop(16.67, quotas)!;
    expect(e.letter, 'A');
    expect(e.nextLetter, 'A+');
    expect(e.nextTopPercent, closeTo(10, 1e-9));
    expect(letterForTop(0, quotas)!.letter, 'A+');
    expect(letterForTop(100, quotas)!.letter, 'B');
    expect(letterForTop(5, const {}), isNull);
  });

  test('standing averages your rank over assignments with statistics', () {
    const st = ClassStats(low: 4, q1: 6, median: 7, q3: 8, high: 10, mean: 7);
    GradedItem g(int id, double score, {ClassStats? stats}) => GradedItem(
          id: id,
          title: 'G$id',
          state: GradeState.graded,
          points: 10,
          score: score,
          groupId: 1,
          stats: stats,
        );
    final items = [g(1, 9, stats: st), g(2, 5, stats: st), g(3, 10)]; // 3 has no statistics
    final s = estimateStanding(items, groups, {1: 100})!;
    expect(s.assignments, 2);
    expect(s.graded, 3);
    expect(s.rank, closeTo(0.5, 1e-9)); // (0.875 + 0.125) / 2
    expect(s.topPercent, closeTo(50, 1e-9));
    expect(s.yourPercent, closeTo(70, 1e-9));
    expect(s.classPercent, closeTo(70, 1e-9));
    expect(estimateStanding([g(4, 9)], groups, {1: 100}), isNull);
  });

  test('Canvas score statistics are read from the assignment', () {
    final items = parseWorkItems([
      {
        'id': 1,
        'name': 'HW',
        'points_possible': 10,
        'submission': {'score': 9, 'workflow_state': 'graded'},
        'score_statistics': {'min': 4, 'max': 10, 'mean': 7, 'upper_q': 8, 'median': 7, 'lower_q': 6},
      },
      {
        'id': 2,
        'name': 'No stats',
        'points_possible': 10,
        'submission': {'score': 9, 'workflow_state': 'graded'},
      },
    ]);
    final st = items.firstWhere((i) => i.id == 1).stats!;
    expect(st.high, 10);
    expect(st.q3, 8);
    expect(st.q1, 6);
    expect(items.firstWhere((i) => i.id == 2).stats, isNull);
  });

  test('mean and range only: bell-curve fit', () {
    const s = ClassStats(mean: 70, low: 40, high: 100);
    expect(s.usable, isTrue);
    expect(s.cdf(70)!, closeTo(0.5, 0.01));
    expect(s.cdf(85)!, greaterThan(0.75));
    expect(const ClassStats(mean: 70).usable, isFalse);
    expect(const ClassStats(low: 1, high: 2).usable, isFalse);
  });

  test('plan json round-trip', () {
    final plan = GradePlan.empty.withWeight(3, 25).withQuota('A', 15);
    final back = GradePlan.fromJson(plan.toJson());
    expect(back.weights, {3: 25});
    expect(back.quotas, {'A': 15});
    expect(GradePlan.fromJson('junk').isEmpty, isTrue);
    expect(parseNumber('12,5'), 12.5);
    expect(parseNumber(''), isNull);
  });

  test('own categories and moves override Canvas grouping', () {
    final work = CourseWork(
      groups: const [AssignmentGroup(id: 1, name: 'Assignments')],
      items: [
        item(1, 1, 1, score: 1),
        item(2, 1, 1, score: 0),
        item(3, 1, 10, score: 9),
      ],
    );
    var quizId = 0;
    var plan = GradePlan.empty.withNewGroup('Quizzes', onId: (v) => quizId = v);
    expect(quizId, -2);
    plan = plan.withMove(1, quizId).withMove(2, quizId).withWeight(quizId, 20).withWeight(1, 80);
    final applied = applyPlan(work, plan);
    expect(applied.groups.map((g) => g.name), ['Assignments', 'Quizzes']);
    expect(applied.items.where((i) => i.groupId == quizId).length, 2);
    final g = computeWeighted(applied.items, applied.groups, effectiveWeights(applied.groups, plan.weights));
    expect(g.current, closeTo(20 * 0.5 + 80 * 0.9, 1e-9)); // 82
    // Deleting the category sends its assignments back.
    final back = applyPlan(work, plan.withoutGroup(quizId));
    expect(back.items.every((i) => i.groupId == 1), isTrue);
    expect(plan.withoutGroup(quizId).weights.containsKey(quizId), isFalse);
    // A second new category gets another id; the plan survives JSON.
    final two = plan.withNewGroup('Exams');
    expect(two.customGroups.keys.toSet(), {-2, -3});
    final round = GradePlan.fromJson(two.toJson());
    expect(round.customGroups, two.customGroups);
    expect(round.moves, {1: -2, 2: -2});
    expect(round.weights[-2], 20);
  });

  test('suggest categories from assignment names', () {
    final work = CourseWork(
      groups: const [AssignmentGroup(id: 1, name: 'Assignments')],
      items: [
        for (final (id, title) in [(1, 'Quiz 1'), (2, 'Quiz 2'), (3, 'HW1'), (4, 'HW2'), (5, 'HW3'), (6, 'Midterm')])
          GradedItem(id: id, title: title, state: GradeState.graded, points: 10, score: 8, groupId: 1),
      ],
    );
    final plan = suggestFromNames(GradePlan.empty, work);
    expect(plan.customGroups.values.toSet(), {'Quiz', 'Hw'});
    final applied = applyPlan(work, plan);
    final quiz = plan.customGroups.entries.firstWhere((e) => e.value == 'Quiz').key;
    expect(applied.items.where((i) => i.groupId == quiz).map((i) => i.id), [1, 2]);
    expect(applied.items.firstWhere((i) => i.id == 6).groupId, 1); // single item stays
    // Running it again changes nothing.
    final again = suggestFromNames(plan, work);
    expect(again.customGroups.length, 2);
  });

  test('assignments still to come count: 2 of 6 quizzes released', () {
    final items = [item(1, 2, 1, score: 1), item(2, 2, 1, score: 0.5)];
    const only = [AssignmentGroup(id: 2, name: 'Quizzes')];
    final g = computeWeighted(items, only, {2: 10}, totals: {2: 6});
    final q = g.categories.single;
    expect(q.count, 2);
    expect(q.total, 6);
    expect(q.eachWeight, closeTo(10 / 6, 1e-9));
    expect(g.current, closeTo(75, 1e-9)); // 1.5 of 2 so far
    expect(g.worst, closeTo(25, 1e-9)); // 1.5 / 6
    expect(g.half, closeTo(100 * 3.5 / 6, 1e-9));
    expect(g.steady, closeTo(75, 1e-9)); // the rest at the same 75%
    expect(g.best, closeTo(100 * 5.5 / 6, 1e-9));
    // A total below what Canvas lists is ignored.
    expect(computeWeighted(items, only, {2: 10}, totals: {2: 1}).categories.single.total, 2);
  });

  test('totals survive JSON and deleting a category', () {
    var id = 0;
    final plan = GradePlan.empty.withNewGroup('Q', onId: (v) => id = v).withTotal(id, 6).withTotal(1, 4);
    expect(GradePlan.fromJson(plan.toJson()).totals, {-2: 6, 1: 4});
    expect(plan.withoutGroup(id).totals, {1: 4});
    expect(plan.withTotal(1, null).totals, {-2: 6});
  });

  test('standing counts unreleased assignments in each one\'s weight', () {
    const st = ClassStats(low: 4, q1: 6, median: 7, q3: 8, high: 10, mean: 7);
    final items = [
      GradedItem(id: 1, title: 'A', state: GradeState.graded, points: 10, score: 9, groupId: 1, stats: st),
      GradedItem(id: 2, title: 'B', state: GradeState.graded, points: 10, score: 5, groupId: 1, stats: st),
    ];
    // Only the ranks of the two graded ones matter; the result is the same
    // because both lose the same share of weight.
    final s = estimateStanding(items, groups, {1: 100}, totals: {1: 5})!;
    expect(s.rank, closeTo(0.5, 1e-9));
  });

  test('a category with no assignments yet still counts when you give its size', () {
    const two = [AssignmentGroup(id: 1, name: 'Homework'), AssignmentGroup(id: 2, name: 'Final')];
    final items = [item(1, 1, 10, score: 9)];
    final g = computeWeighted(items, two, {1: 60, 2: 40}, totals: {2: 1});
    expect(g.current, closeTo(90, 1e-9));
    expect(g.worst, closeTo(54, 1e-9)); // the final scores zero
    expect(g.best, closeTo(94, 1e-9)); // 54 + a perfect final
    expect(g.steady, closeTo(90, 1e-9)); // the final at your 90%
    // Without a size the empty category cannot be valued, so it is left out.
    expect(computeWeighted(items, two, {1: 60, 2: 40}).worst, closeTo(90 * 0 + 90, 1e-9));
  });
}
