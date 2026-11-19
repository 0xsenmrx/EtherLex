import 'dart:math' as math;

import 'grade_plan.dart';
import 'grades.dart';

/// The course as the user has arranged it: their own categories added, and
/// their moves applied over Canvas's grouping.
CourseWork applyPlan(CourseWork work, GradePlan plan) {
  if (plan.customGroups.isEmpty && plan.moves.isEmpty) return work;
  final groups = [
    ...work.groups,
    for (final e in plan.customGroups.entries)
      AssignmentGroup(id: e.key, name: e.value, position: 100000 - e.key),
  ];
  final valid = {for (final g in groups) g.id};
  return CourseWork(
    groups: groups,
    items: [
      for (final i in work.items)
        if (plan.moves[i.id] case final g? when valid.contains(g)) i.withGroup(g) else i,
    ],
  );
}

/// Quick start for courses with no categories in Canvas: assignments whose
/// names start with the same word ("Quiz 1", "Quiz 2"; "HW1", "HW2") become
/// one category each. Already-moved assignments and existing categories with
/// the same name are respected.
GradePlan suggestFromNames(GradePlan plan, CourseWork work) {
  final applied = applyPlan(work, plan);
  final byKey = <String, List<GradedItem>>{};
  final label = <String, String>{};
  for (final i in work.items) {
    if (plan.moves.containsKey(i.id)) continue;
    final m = RegExp(r'^[A-Za-z]{2,}').firstMatch(i.title.trim());
    if (m == null) continue;
    final word = m.group(0)!;
    final key = word.toLowerCase();
    (byKey[key] ??= []).add(i);
    label.putIfAbsent(key, () => word[0].toUpperCase() + word.substring(1).toLowerCase());
  }
  var next = plan;
  for (final e in byKey.entries) {
    if (e.value.length < 2) continue;
    final name = label[e.key]!;
    final existing = applied.groups.where((g) => g.name.toLowerCase() == name.toLowerCase());
    int? id = existing.isEmpty ? null : existing.first.id;
    if (id == null) {
      next = next.withNewGroup(name, onId: (v) => id = v);
    }
    for (final i in e.value) {
      next = next.withMove(i.id, id);
    }
  }
  return next;
}

/// Weights to use: the user's own, else Canvas's if the course sets any.
Map<int, double> effectiveWeights(List<AssignmentGroup> groups, Map<int, double> custom) {
  final out = <int, double>{};
  for (final g in groups) {
    final w = custom[g.id] ?? (g.weight > 0 ? g.weight : null);
    if (w != null) out[g.id] = w;
  }
  final other = custom[-1];
  if (other != null) out[-1] = other;
  return out;
}

class CategoryResult {
  const CategoryResult({
    required this.group,
    required this.weight,
    required this.count,
    required this.total,
    required this.earned,
    required this.possibleGraded,
    required this.possibleAll,
  });

  final AssignmentGroup group;
  final double? weight;

  /// Assignments Canvas lists that carry points (excused ones do not count).
  final int count;

  /// How many the category will have in the end (never less than [count]).
  final int total;
  final double earned;
  final double possibleGraded;

  /// Points of everything in the category, including assignments that are
  /// still to come (valued like the average one you have).
  final double possibleAll;

  /// 0..1 over the graded work in this category.
  double? get fraction => possibleGraded > 0 ? earned / possibleGraded : null;

  /// How much of the course each assignment is worth, if split evenly.
  double? get eachWeight => weight != null && total > 0 ? weight! / total : null;
}

class WeightedGrade {
  const WeightedGrade({
    required this.categories,
    this.current,
    this.worst,
    this.half,
    this.steady,
    this.best,
  });

  final List<CategoryResult> categories;

  /// Percent over graded work only.
  final double? current;

  /// The final grade if everything still to do scores 0, half marks, the same
  /// share as the graded work so far (in each category), or full marks.
  final double? worst;
  final double? half;
  final double? steady;
  final double? best;
}

WeightedGrade computeWeighted(
  List<GradedItem> items,
  List<AssignmentGroup> groups,
  Map<int, double> weights, {
  Map<int, int> totals = const {},
}) {
  final known = {for (final g in groups) g.id: g};
  const other = AssignmentGroup(id: -1, name: 'Other');
  final byGroup = <int, List<GradedItem>>{};
  for (final i in items) {
    if (i.state == GradeState.excused) continue;
    final p = i.points;
    if (p == null || p <= 0) continue;
    final id = i.groupId != null && known.containsKey(i.groupId) ? i.groupId! : -1;
    (byGroup[id] ??= []).add(i);
  }

  final cats = <CategoryResult>[];
  final ordered = [
    ...groups,
    if (byGroup.containsKey(-1)) other,
  ];
  for (final g in ordered) {
    final list = byGroup[g.id] ?? const <GradedItem>[];
    double earned = 0, possGraded = 0, possAll = 0;
    for (final i in list) {
      possAll += i.points!;
      if (i.state == GradeState.graded && i.score != null) {
        earned += i.score!;
        possGraded += i.points!;
      }
    }
    final total = (totals[g.id] ?? 0) > list.length ? totals[g.id]! : list.length;
    if (list.isNotEmpty && total > list.length) {
      possAll += (total - list.length) * (possAll / list.length);
    } else if (list.isEmpty && total > 0) {
      // Nothing released yet (a final exam): only its share of the category
      // matters, so any equal points per assignment will do.
      possAll = total.toDouble();
    }
    cats.add(CategoryResult(
      group: g,
      weight: weights[g.id],
      count: list.length,
      total: total,
      earned: earned,
      possibleGraded: possGraded,
      possibleAll: possAll,
    ));
  }

  // Current: only the graded work, scaled to the categories that have any.
  double sumCur = 0, wCur = 0;
  for (final c in cats) {
    final w = c.weight;
    if (w == null || w <= 0 || c.possibleGraded <= 0) continue;
    sumCur += w * c.earned / c.possibleGraded;
    wCur += w;
  }
  final current = wCur > 0 ? 100 * sumCur / wCur : null;

  // What the rest of the work scores: a share r of the points still open.
  double? scenario(double? Function(CategoryResult) share) {
    double sum = 0, wAll = 0;
    for (final c in cats) {
      final w = c.weight;
      if (w == null || w <= 0 || c.possibleAll <= 0) continue;
      final r = share(c);
      if (r == null) return null;
      final open = c.possibleAll - c.possibleGraded;
      sum += w * (c.earned + r * open) / c.possibleAll;
      wAll += w;
    }
    return wAll > 0 ? 100 * sum / wAll : null;
  }

  final overall = current == null ? null : current / 100;
  return WeightedGrade(
    categories: cats,
    current: current,
    worst: scenario((_) => 0),
    half: scenario((_) => 0.5),
    steady: scenario((c) => c.fraction ?? overall),
    best: scenario((_) => 1),
  );
}

// ---------------------------------------------------------------- the curve

double _erf(double x) {
  final sign = x < 0 ? -1.0 : 1.0;
  final a = x.abs();
  const a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741, a4 = -1.453152027, a5 = 1.061405429;
  const p = 0.3275911;
  final t = 1 / (1 + p * a);
  final y = 1 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-a * a);
  return sign * y;
}

double normalCdf(double z) => 0.5 * (1 + _erf(z / math.sqrt2));

extension ClassStatsModel on ClassStats {
  bool get hasQuartiles {
    final v = [low, q1, median, q3, high];
    if (v.any((e) => e == null)) return false;
    final d = v.cast<double>();
    for (var i = 0; i < 4; i++) {
      if (d[i] > d[i + 1]) return false;
    }
    return d[0] < d[4];
  }

  bool get _hasNormal => mean != null && low != null && high != null && high! > low! && mean! > low! && mean! < high!;

  /// Enough numbers to model the class.
  bool get usable => hasQuartiles || _hasNormal;

  /// Share of the class scoring at or below [x] (0..1). Quartiles give a
  /// piecewise-linear fit through low/Q1/median/Q3/high; without them the
  /// mean and range give a truncated bell curve (spread = range / 4).
  double? cdf(double x) {
    if (!usable) return null;
    if (hasQuartiles) {
      final xs = [low!, q1!, median!, q3!, high!];
      if (x <= xs.first) return 0;
      if (x >= xs.last) return 1;
      for (var i = 0; i < 4; i++) {
        if (x < xs[i + 1] && xs[i + 1] > xs[i]) {
          return 0.25 * i + 0.25 * (x - xs[i]) / (xs[i + 1] - xs[i]);
        }
      }
      return 1;
    }
    final sd = (high! - low!) / 4;
    double f(double v) => normalCdf((v - mean!) / sd);
    final lo = f(low!);
    final hi = f(high!);
    if (x <= low!) return 0;
    if (x >= high!) return 1;
    return ((f(x) - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  /// Where [x] sits in the class, 0 (bottom) .. 1 (top). Like [cdf], but a
  /// score shared by many students lands in the middle of their block instead
  /// of at its top.
  double? rank(double x) {
    if (!usable) return null;
    if (hasQuartiles) {
      final xs = [low!, q1!, median!, q3!, high!];
      if (x < xs.first) return 0;
      if (x > xs.last) return 1;
      final first = xs.indexOf(x);
      if (first >= 0) return 0.25 * (first + xs.lastIndexOf(x)) / 2;
    }
    return cdf(x);
  }
}

/// Where you stand across the assignments that have class statistics.
class Standing {
  const Standing({
    required this.rank,
    required this.assignments,
    required this.graded,
    required this.yourPercent,
    required this.classPercent,
  });

  /// 0 (bottom) .. 1 (top): the average of your rank on each assignment,
  /// weighted by what each assignment is worth in the course.
  final double rank;

  /// Assignments with statistics, out of [graded] that you have a score for.
  final int assignments;
  final int graded;

  /// Your and the class's average on those same assignments, in percent.
  final double? yourPercent;
  final double? classPercent;

  double get topPercent => (1 - rank) * 100;
}

/// Averages your rank over every graded assignment that shows class
/// statistics. With category weights set, each assignment counts for what it
/// is worth in the course; otherwise by its points.
Standing? estimateStanding(
  List<GradedItem> items,
  List<AssignmentGroup> groups,
  Map<int, double> weights, {
  Map<int, int> totals = const {},
}) {
  final known = {for (final g in groups) g.id};
  final possible = <int, double>{};
  final counts = <int, int>{};
  for (final i in items) {
    final p = i.points;
    if (i.state == GradeState.excused || p == null || p <= 0) continue;
    final id = i.groupId != null && known.contains(i.groupId) ? i.groupId! : -1;
    possible[id] = (possible[id] ?? 0) + p;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  // Assignments still to come are worth what the average one here is.
  for (final id in possible.keys.toList()) {
    final extra = (totals[id] ?? 0) - counts[id]!;
    if (extra > 0) possible[id] = possible[id]! + extra * possible[id]! / counts[id]!;
  }
  final hasWeights = weights.values.any((w) => w > 0);

  double weightOf(GradedItem i) {
    final id = i.groupId != null && known.contains(i.groupId) ? i.groupId! : -1;
    if (!hasWeights) return i.points!;
    final w = weights[id] ?? 0;
    return w * i.points! / possible[id]!;
  }

  var graded = 0, used = 0;
  double sumW = 0, sumRank = 0, sumYou = 0, sumClass = 0;
  for (final i in items) {
    final p = i.points;
    if (i.state != GradeState.graded || i.score == null || p == null || p <= 0) continue;
    final w = weightOf(i);
    if (w <= 0) continue;
    graded++;
    final st = i.stats;
    final r = st?.rank(i.score!);
    if (st == null || r == null) continue;
    used++;
    sumW += w;
    sumRank += w * r;
    sumYou += w * i.score! / p;
    if (st.mean != null) sumClass += w * st.mean! / p;
  }
  if (used == 0 || sumW <= 0) return null;
  return Standing(
    rank: sumRank / sumW,
    assignments: used,
    graded: graded,
    yourPercent: 100 * sumYou / sumW,
    classPercent: sumClass > 0 ? 100 * sumClass / sumW : null,
  );
}

class LetterEstimate {
  const LetterEstimate({required this.letter, required this.topPercent, this.nextLetter, this.nextTopPercent});
  final String letter;

  /// Share of the class estimated to be above you.
  final double topPercent;
  final String? nextLetter;

  /// The "top X%" line you would have to cross for [nextLetter].
  final double? nextTopPercent;
}

/// The letter for being in the top [topPercent]% when the teacher hands out
/// letters by fixed shares of the class (e.g. 10% A+, 20% A).
LetterEstimate? letterForTop(double topPercent, Map<String, double> quotas) {
  final rows = [
    for (final l in kLetters)
      if ((quotas[l] ?? 0) > 0) (letter: l, quota: quotas[l]!),
  ];
  if (rows.isEmpty) return null;
  final total = rows.fold<double>(0, (s, r) => s + r.quota);
  final cums = <double>[];
  var cum = 0.0;
  for (final r in rows) {
    cum += r.quota / total * 100;
    cums.add(cum);
  }
  var idx = rows.length - 1;
  for (var i = 0; i < rows.length; i++) {
    if (topPercent <= cums[i] + 1e-9) {
      idx = i;
      break;
    }
  }
  return LetterEstimate(
    letter: rows[idx].letter,
    topPercent: topPercent,
    nextLetter: idx > 0 ? rows[idx - 1].letter : null,
    nextTopPercent: idx > 0 ? cums[idx - 1] : null,
  );
}
