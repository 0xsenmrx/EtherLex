import 'dart:convert';

import '../../courses/domain/course.dart';
import 'grade_plan.dart';
import 'grades.dart';

/// The word after the opening fence of the block the assistant writes when it
/// proposes a grade plan.
const String kPlanFence = 'etherlex-plan';

class ProposedCategory {
  const ProposedCategory({required this.name, required this.weight, this.count});

  final String name;

  /// Percent of the course grade.
  final double weight;

  /// How many assignments the course will have in this category, if the
  /// syllabus says so.
  final int? count;
}

/// Puts one assignment into a category, by the category's name.
class ProposedMove {
  const ProposedMove({required this.assignment, required this.category});

  final int assignment;
  final String category;
}

/// A grade plan the assistant read out of a syllabus. It changes nothing by
/// itself: the student sees it as a card and presses Apply.
class PlanProposal {
  const PlanProposal({this.course, this.categories = const [], this.curve = const {}, this.moves = const [], this.note});

  /// The course as the assistant named it; matched to a real course later.
  final String? course;
  final List<ProposedCategory> categories;

  /// Letter -> percent of the class that gets it.
  final Map<String, double> curve;

  /// Assignments to put in a category, when Canvas groups them differently.
  final List<ProposedMove> moves;
  final String? note;

  double get weightTotal => categories.fold(0, (a, c) => a + c.weight);
}

/// Reads and checks the JSON inside the block. Null when it is not a usable
/// plan (so the chat shows it as plain code instead). Nothing is trusted:
/// names, numbers and letters are all checked, and extra fields are ignored.
PlanProposal? parseProposal(String source) {
  final Object? j;
  try {
    j = jsonDecode(source);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;

  String? text(Object? v, int max) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty || t.length > max ? null : t;
  }

  final categories = <ProposedCategory>[];
  final raw = j['categories'];
  if (raw != null) {
    if (raw is! List || raw.length > 30) return null;
    final seen = <String>{};
    for (final c in raw) {
      if (c is! Map) return null;
      final name = text(c['name'], 60);
      final weight = c['weight'];
      if (name == null || weight is! num || weight < 0 || weight > 100) return null;
      if (!seen.add(normalizeName(name))) return null;
      final count = c['count'];
      if (count != null && (count is! int || count < 1 || count > 500)) return null;
      categories.add(ProposedCategory(name: name, weight: weight.toDouble(), count: count as int?));
    }
  }

  final curve = <String, double>{};
  final rawCurve = j['curve'];
  if (rawCurve != null) {
    if (rawCurve is! Map) return null;
    for (final e in rawCurve.entries) {
      final v = e.value;
      if (!kLetters.contains(e.key) || v is! num || v < 0 || v > 100) return null;
      curve['${e.key}'] = v.toDouble();
    }
    if (curve.values.fold<double>(0, (a, b) => a + b) > 100.0001) return null;
  }

  final moves = <ProposedMove>[];
  final rawMoves = j['moves'];
  if (rawMoves != null) {
    if (rawMoves is! List || rawMoves.length > 200) return null;
    final seen = <int>{};
    for (final m in rawMoves) {
      if (m is! Map) return null;
      final id = m['assignment'];
      final category = text(m['category'], 60);
      if (id is! int || id <= 0 || category == null || !seen.add(id)) return null;
      moves.add(ProposedMove(assignment: id, category: category));
    }
  }

  if (categories.isEmpty && curve.isEmpty && moves.isEmpty) return null;
  return PlanProposal(
    course: text(j['course'], 120),
    categories: categories,
    curve: curve,
    moves: moves,
    note: text(j['note'], 300),
  );
}

/// "Quizzes", "quiz", "QUIZ (best 5)" all compare alike: lower case, letters
/// and digits only, and a plural s dropped.
String normalizeName(String s) {
  final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0080-￿]'), '');
  return t.length > 3 && t.endsWith('s') ? t.substring(0, t.length - 1) : t;
}

T? _only<T>(Iterable<T> found) => found.length == 1 ? found.first : null;

/// The category in [pool] (id -> name) that [name] means, skipping the ids in
/// [skip]: an exact match, else the only one whose name contains it or is
/// contained by it. Null when none or several fit.
int? matchCategory(String name, Map<int, String> pool, [Set<int> skip = const {}]) {
  final n = normalizeName(name);
  final free = {for (final e in pool.entries) if (!skip.contains(e.key)) e.key: normalizeName(e.value)};
  final exact = _only(free.entries.where((e) => e.value == n));
  if (exact != null) return exact.key;
  return _only(free.entries.where((e) => e.value.length >= 4 && n.length >= 4 && (e.value.contains(n) || n.contains(e.value))))?.key;
}

/// The real course the proposal means, or null when none or several fit.
Course? matchCourse(String? name, List<Course> courses) {
  if (name == null) return null;
  final n = normalizeName(name);
  if (n.isEmpty) return null;
  final exact = _only(courses.where((c) => normalizeName(c.name) == n || (c.code.isNotEmpty && normalizeName(c.code) == n)));
  if (exact != null) return exact;
  return _only(courses.where((c) {
    final a = normalizeName(c.name);
    final b = normalizeName(c.code);
    return (a.length >= 4 && (a.contains(n) || n.contains(a))) || (b.length >= 4 && (b.contains(n) || n.contains(b)));
  }));
}

/// One line of what Apply will do.
class PlanRow {
  const PlanRow({required this.name, required this.weight, this.count, required this.kind, this.groupId});

  final String name;
  final double weight;
  final int? count;
  final PlanRowKind kind;

  /// The category it lands in (null for one that will be created).
  final int? groupId;
}

enum PlanRowKind {
  /// Matches a category Canvas has.
  canvas,

  /// Matches a category the student made earlier.
  own,

  /// Will be created.
  created,

  /// A Canvas category the plan does not mention; it is set to 0%.
  dropped,
}

enum MoveStatus {
  /// Will be moved.
  ok,

  /// No assignment with that id in this course.
  unknownAssignment,

  /// No category with that name (and the plan does not create it).
  unknownCategory,
}

/// One assignment the plan puts in another category.
class MoveRow {
  const MoveRow({required this.assignment, required this.category, required this.status, this.groupId});

  final int assignment;
  final String category;
  final MoveStatus status;
  final int? groupId;
}

/// Matches the proposal's categories to [groups] (Canvas's) and to the
/// student's own categories in [old], and gives the plan after applying.
({GradePlan plan, List<PlanRow> rows, List<MoveRow> moves}) applyProposal(
  GradePlan old,
  PlanProposal p,
  List<AssignmentGroup> groups, {
  Set<int>? knownAssignments,
}) {
  var plan = old;
  final rows = <PlanRow>[];
  final used = <int>{};

  int? find(String name, Map<int, String> pool) => matchCategory(name, pool, used);

  final canvas = {for (final g in groups) g.id: g.name};
  for (final c in p.categories) {
    var kind = PlanRowKind.canvas;
    var id = find(c.name, canvas);
    if (id == null) {
      kind = PlanRowKind.own;
      id = find(c.name, old.customGroups);
    }
    if (id == null) {
      kind = PlanRowKind.created;
      plan = plan.withNewGroup(c.name, onId: (v) => id = v);
    }
    final gid = id!;
    used.add(gid);
    plan = plan.withWeight(gid, c.weight);
    if (c.count != null) plan = plan.withTotal(gid, c.count);
    rows.add(PlanRow(
      name: c.name,
      weight: c.weight,
      count: c.count,
      kind: kind,
      groupId: gid,
    ));
  }

  if (p.categories.isNotEmpty) {
    for (final g in groups) {
      if (used.contains(g.id)) continue;
      plan = plan.withWeight(g.id, 0);
      rows.add(PlanRow(name: g.name, weight: 0, kind: PlanRowKind.dropped, groupId: g.id));
    }
  }

  for (final e in p.curve.entries) {
    plan = plan.withQuota(e.key, e.value);
  }

  final pool = {...canvas, ...plan.customGroups};
  final moves = <MoveRow>[];
  for (final m in p.moves) {
    if (knownAssignments != null && !knownAssignments.contains(m.assignment)) {
      moves.add(MoveRow(assignment: m.assignment, category: m.category, status: MoveStatus.unknownAssignment));
      continue;
    }
    final gid = matchCategory(m.category, pool);
    if (gid == null) {
      moves.add(MoveRow(assignment: m.assignment, category: m.category, status: MoveStatus.unknownCategory));
      continue;
    }
    plan = plan.withMove(m.assignment, gid);
    moves.add(MoveRow(assignment: m.assignment, category: m.category, status: MoveStatus.ok, groupId: gid));
  }
  return (plan: plan, rows: rows, moves: moves);
}
