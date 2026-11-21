import 'dart:convert';

import '../../assignments/domain/assignment.dart';
import '../../courses/domain/course.dart';
import 'proposed_settings.dart';

/// The word after the opening fence of the block the assistant writes when it
/// proposes changes to assignments (starring, marking done).
const String kActionsFence = 'etherlex-actions';

enum ActionKind {
  /// Star or unstar.
  star,

  /// Mark done or not done in EtherLex. This never submits anything to Canvas.
  done,
}

class ProposedAction {
  const ProposedAction({required this.kind, required this.assignments, this.value = true});

  final ActionKind kind;
  final List<int> assignments;

  /// true = star / mark done, false = unstar / mark not done.
  final bool value;

  /// Needs the student's extra care before it is applied.
  bool get caution => kind == ActionKind.done;
}

class ActionsProposal {
  const ActionsProposal({this.actions = const [], this.settings = const [], this.note});

  final List<ProposedAction> actions;

  /// Changes to the app's own settings, or pages to open.
  final List<SettingChange> settings;
  final String? note;
}

/// Reads and checks the JSON inside the block; null if it is not a usable
/// proposal (the chat then shows it as plain code). Unknown fields and action
/// types are rejected, not skipped: a proposal is all valid or not shown.
ActionsProposal? parseActions(String source) {
  final Object? j;
  try {
    j = jsonDecode(source);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final raw = j['actions'] ?? const [];
  if (raw is! List || raw.length > 20) return null;
  final rawSettings = j['settings'] ?? const [];
  if (rawSettings is! List || rawSettings.length > 10) return null;
  final settings = <SettingChange>[];
  for (final r in rawSettings) {
    final c = parseSetting(r);
    if (c == null) return null;
    settings.add(c);
  }
  final actions = <ProposedAction>[];
  var ids = 0;
  for (final a in raw) {
    if (a is! Map) return null;
    // A setting put in the "actions" list by mistake is still a setting; its
    // kind (theme, font...) cannot be mistaken for an assignment action.
    if (SettingKind.values.any((k) => k.name == a['type'])) {
      final c = parseSetting(a);
      if (c == null || settings.length >= 10) return null;
      settings.add(c);
      continue;
    }
    final kind = ActionKind.values.where((k) => k.name == a['type']).firstOrNull;
    final list = a['assignments'];
    final value = a['value'] ?? true;
    if (kind == null || value is! bool || list is! List || list.isEmpty || list.length > 100) return null;
    final seen = <int>{};
    for (final id in list) {
      if (id is! int || id <= 0 || !seen.add(id)) return null;
    }
    ids += list.length;
    if (ids > 200) return null;
    actions.add(ProposedAction(kind: kind, assignments: [for (final id in list) id as int], value: value));
  }
  if (actions.isEmpty && settings.isEmpty) return null;
  final note = j['note'];
  return ActionsProposal(
    actions: actions,
    settings: settings,
    note: note is String && note.trim().isNotEmpty && note.length <= 300 ? note.trim() : null,
  );
}

enum ActionEffect {
  /// It will be changed.
  change,

  /// It already is that way.
  same,

  /// No such assignment.
  unknown,
}

class ActionLine {
  const ActionLine({
    required this.kind,
    required this.value,
    required this.id,
    required this.effect,
    this.title,
    this.course,
    this.previous,
  });

  final ActionKind kind;
  final bool value;
  final int id;
  final ActionEffect effect;
  final String? title;
  final String? course;

  /// What it was before (for undoing); null when it will not change.
  final bool? previous;
}

/// What applying [p] would do to [known], line by line, in order. A line that
/// sets what is already set is "same"; an id nobody has is "unknown". Later
/// actions see the effect of earlier ones.
List<ActionLine> previewActions(ActionsProposal p, List<Assignment> known, Map<int, Course> courses) {
  final byId = {for (final a in known) a.id: a};
  final starred = {for (final a in known) a.id: a.starred};
  final done = {for (final a in known) a.id: a.done};
  final out = <ActionLine>[];
  for (final action in p.actions) {
    final state = action.kind == ActionKind.star ? starred : done;
    for (final id in action.assignments) {
      final a = byId[id];
      if (a == null) {
        out.add(ActionLine(kind: action.kind, value: action.value, id: id, effect: ActionEffect.unknown));
        continue;
      }
      final before = state[id]!;
      final change = before != action.value;
      state[id] = action.value;
      out.add(ActionLine(
        kind: action.kind,
        value: action.value,
        id: id,
        effect: change ? ActionEffect.change : ActionEffect.same,
        title: a.title,
        course: courses[a.courseId]?.shortLabel,
        previous: change ? before : null,
      ));
    }
  }
  return out;
}

/// What to put back to undo an apply: kind -> assignment -> the old value.
typedef ActionUndo = Map<ActionKind, Map<int, bool>>;

/// Applies the lines that change something, through [setStarred] and
/// [setDone], and returns how to undo it. Stops at the first failure and
/// throws [ApplyFailed], which carries what was already changed.
Future<ActionUndo> applyActions(
  List<ActionLine> lines, {
  required Future<void> Function(int id, bool value) setStarred,
  required Future<void> Function(int id, bool value) setDone,
}) async {
  final undo = <ActionKind, Map<int, bool>>{ActionKind.star: {}, ActionKind.done: {}};
  try {
    for (final l in lines) {
      if (l.effect != ActionEffect.change) continue;
      if (l.kind == ActionKind.star) {
        await setStarred(l.id, l.value);
      } else {
        await setDone(l.id, l.value);
      }
      // Keep the oldest value if the same one is set twice.
      undo[l.kind]!.putIfAbsent(l.id, () => l.previous!);
    }
  } catch (e) {
    throw ApplyFailed(undo, e);
  }
  return undo;
}

/// Puts back what [undo] recorded.
Future<void> undoActions(
  ActionUndo undo, {
  required Future<void> Function(int id, bool value) setStarred,
  required Future<void> Function(int id, bool value) setDone,
}) async {
  for (final e in undo[ActionKind.star]?.entries ?? const <MapEntry<int, bool>>[]) {
    await setStarred(e.key, e.value);
  }
  for (final e in undo[ActionKind.done]?.entries ?? const <MapEntry<int, bool>>[]) {
    await setDone(e.key, e.value);
  }
}

/// An apply stopped half way; [done] is what had been changed so far.
class ApplyFailed implements Exception {
  const ApplyFailed(this.done, this.cause);

  final ActionUndo done;
  final Object cause;
}
