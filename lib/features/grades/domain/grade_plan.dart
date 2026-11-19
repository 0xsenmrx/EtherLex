/// Letters offered in the curve editor, best first.
const List<String> kLetters = ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'F'];

/// What Canvas publishes about one assignment's scores (in points): the
/// lowest and highest score, mean and quartiles. Any may be missing.
class ClassStats {
  const ClassStats({this.mean, this.low, this.high, this.q1, this.median, this.q3});

  final double? mean;
  final double? low;
  final double? high;
  final double? q1;
  final double? median;
  final double? q3;

  static ClassStats? fromCanvas(Object? j) {
    if (j is! Map) return null;
    double? n(String k) => (j[k] as num?)?.toDouble();
    final s = ClassStats(
      mean: n('mean'),
      low: n('min'),
      high: n('max'),
      q1: n('lower_q'),
      median: n('median'),
      q3: n('upper_q'),
    );
    final any = [s.mean, s.low, s.high, s.q1, s.median, s.q3].any((v) => v != null);
    return any ? s : null;
  }
}

/// The user's own settings for one course: categories (their own, next to
/// Canvas's), which assignment sits in which category, the category weights
/// and the teacher's letter quotas ("10% of the class gets A+").
class GradePlan {
  const GradePlan({
    this.weights = const {},
    this.quotas = const {},
    this.customGroups = const {},
    this.moves = const {},
    this.totals = const {},
  });

  static const GradePlan empty = GradePlan();

  /// Category id -> percent of the course grade.
  final Map<int, double> weights;

  /// Letter -> percent of the class that gets it.
  final Map<String, double> quotas;

  /// Categories you made yourself. Ids are negative (-1 is "Other"), so they
  /// can never clash with Canvas's.
  final Map<int, String> customGroups;

  /// Assignment id -> the category you put it in (overrides Canvas's).
  final Map<int, int> moves;

  /// Category id -> how many assignments it will have in the end, when more
  /// are still to come than Canvas lists yet (6 quizzes, 2 released).
  final Map<int, int> totals;

  GradePlan _copy({
    Map<int, double>? weights,
    Map<String, double>? quotas,
    Map<int, String>? customGroups,
    Map<int, int>? moves,
    Map<int, int>? totals,
  }) =>
      GradePlan(
        weights: weights ?? this.weights,
        quotas: quotas ?? this.quotas,
        customGroups: customGroups ?? this.customGroups,
        moves: moves ?? this.moves,
        totals: totals ?? this.totals,
      );

  GradePlan withWeight(int group, double? v) {
    final next = {...weights};
    if (v == null) {
      next.remove(group);
    } else {
      next[group] = v;
    }
    return _copy(weights: next);
  }

  GradePlan withTotal(int group, int? v) {
    final next = {...totals};
    if (v == null || v <= 0) {
      next.remove(group);
    } else {
      next[group] = v;
    }
    return _copy(totals: next);
  }

  GradePlan withQuota(String letter, double? v) {
    final next = {...quotas};
    if (v == null) {
      next.remove(letter);
    } else {
      next[letter] = v;
    }
    return _copy(quotas: next);
  }

  /// A new category of your own; the id is returned through [onId].
  GradePlan withNewGroup(String name, {void Function(int id)? onId}) {
    var id = -2;
    while (customGroups.containsKey(id)) {
      id--;
    }
    onId?.call(id);
    return _copy(customGroups: {...customGroups, id: name});
  }

  GradePlan withRenamedGroup(int id, String name) =>
      customGroups.containsKey(id) ? _copy(customGroups: {...customGroups, id: name}) : this;

  /// Deletes one of your categories; its assignments go back to Canvas's.
  GradePlan withoutGroup(int id) => _copy(
        customGroups: {...customGroups}..remove(id),
        weights: {...weights}..remove(id),
        totals: {...totals}..remove(id),
        moves: {
          for (final e in moves.entries)
            if (e.value != id) e.key: e.value,
        },
      );

  /// Puts [assignment] in [group]; null puts it back where Canvas had it.
  GradePlan withMove(int assignment, int? group) {
    final next = {...moves};
    if (group == null) {
      next.remove(assignment);
    } else {
      next[assignment] = group;
    }
    return _copy(moves: next);
  }

  bool get isEmpty => weights.isEmpty && quotas.isEmpty && customGroups.isEmpty && moves.isEmpty && totals.isEmpty;

  Map<String, dynamic> toJson() => {
        'w': {for (final e in weights.entries) '${e.key}': e.value},
        'q': quotas,
        'cg': {for (final e in customGroups.entries) '${e.key}': e.value},
        'mv': {for (final e in moves.entries) '${e.key}': e.value},
        't': {for (final e in totals.entries) '${e.key}': e.value},
      };

  static GradePlan fromJson(Object? j) {
    if (j is! Map) return empty;
    Map<int, T> ints<T>(Object? m, T? Function(Object?) pick) => {
          if (m is Map)
            for (final e in m.entries)
              if (int.tryParse('${e.key}') != null) int.parse('${e.key}'): ?pick(e.value),
        };
    final q = j['q'];
    return GradePlan(
      weights: ints<double>(j['w'], (v) => v is num ? v.toDouble() : null),
      customGroups: ints<String>(j['cg'], (v) => v is String ? v : null),
      moves: ints<int>(j['mv'], (v) => v is num ? v.toInt() : null),
      totals: ints<int>(j['t'], (v) => v is num ? v.toInt() : null),
      quotas: {
        if (q is Map)
          for (final e in q.entries)
            if (e.key is String && e.value is num) e.key as String: (e.value as num).toDouble(),
      },
    );
  }
}

/// "12,5" and "12.5" both work; blank or junk = no value.
double? parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));
