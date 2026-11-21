import '../../../core/appearance/appearance.dart';
import '../../courses/domain/course.dart';
import '../../grades/domain/plan_proposal.dart' show matchCourse;

enum SettingKind {
  /// Light, dark or follow the system.
  theme,

  /// Handwritten or clean.
  font,

  /// Deadline and grade notifications on or off.
  notifications,

  /// Show or hide a course everywhere in the app.
  course,

  /// Go to a page.
  open,
}

/// Pages the assistant may open, as the app's routes name them.
const List<String> kOpenPages = ['assignments', 'activity', 'calendar', 'grades', 'files', 'chat'];

/// What the assistant writes as the course when it cannot tell which one is
/// meant: the card then asks the student to choose.
const String kAskCourse = '?';

/// One change to the app's own settings, or a page to open.
class SettingChange {
  const SettingChange({required this.kind, this.text, this.flag});

  final SettingKind kind;

  /// theme / font / course name / page.
  final String? text;

  /// notifications on/off; course shown (true) or hidden (false).
  final bool? flag;
}

/// Reads one entry of the block's "settings" list; null if it is not valid.
SettingChange? parseSetting(Object? j) {
  if (j is! Map) return null;
  final kind = SettingKind.values.where((k) => k.name == j['type']).firstOrNull;
  final value = j['value'];
  switch (kind) {
    case SettingKind.theme:
      return ThemeChoice.values.any((t) => t.name == value) ? SettingChange(kind: kind!, text: value as String) : null;
    case SettingKind.font:
      return TypefaceChoice.values.any((t) => t.name == value) ? SettingChange(kind: kind!, text: value as String) : null;
    case SettingKind.notifications:
      return value is bool ? SettingChange(kind: kind!, flag: value) : null;
    case SettingKind.course:
      final name = j['course'];
      if (name is! String || name.trim().isEmpty || name.length > 120 || value is! bool) return null;
      return SettingChange(kind: kind!, text: name.trim(), flag: value);
    case SettingKind.open:
      final page = j['page'];
      return kOpenPages.contains(page) ? SettingChange(kind: kind!, text: page as String) : null;
    case null:
      return null;
  }
}

/// How the app is set now, to preview changes against.
class SettingsSnapshot {
  const SettingsSnapshot({
    required this.theme,
    required this.typeface,
    required this.notifications,
    required this.disabledCourses,
    required this.courses,
  });

  final ThemeChoice theme;
  final TypefaceChoice typeface;
  final bool notifications;
  final Set<int> disabledCourses;
  final List<Course> courses;
}

enum SettingEffect { change, same, unknown }

class SettingLine {
  const SettingLine({
    required this.kind,
    required this.label,
    required this.detail,
    required this.effect,
    this.text,
    this.flag,
    this.courseId,
    this.previousText,
    this.previousFlag,
    this.index = 0,
  });

  /// Its place in the proposal's settings list.
  final int index;

  final SettingKind kind;

  /// "Theme", "Course"...
  final String label;

  /// "Dark", "Hide PHYS101"...
  final String detail;
  final SettingEffect effect;
  final String? text;
  final bool? flag;
  final int? courseId;

  /// What it is now, for undoing.
  final String? previousText;
  final bool? previousFlag;
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// What applying [changes] would do, line by line. A course that is not found,
/// or that several courses fit, is "unknown": nothing is guessed. [courseChoices]
/// holds what the person picked for such a line (its place in [changes] -> course id).
List<SettingLine> previewSettings(List<SettingChange> changes, SettingsSnapshot now, {Map<int, int> courseChoices = const {}}) {
  final out = <SettingLine>[];
  for (var index = 0; index < changes.length; index++) {
    final c = changes[index];
    switch (c.kind) {
      case SettingKind.theme:
        final same = now.theme.name == c.text;
        out.add(SettingLine(
          kind: c.kind,
          label: 'Theme',
          detail: _cap(c.text!),
          effect: same ? SettingEffect.same : SettingEffect.change,
          text: c.text,
          previousText: now.theme.name,
        ));
      case SettingKind.font:
        final same = now.typeface.name == c.text;
        out.add(SettingLine(
          kind: c.kind,
          label: 'Font',
          detail: _cap(c.text!),
          effect: same ? SettingEffect.same : SettingEffect.change,
          text: c.text,
          previousText: now.typeface.name,
        ));
      case SettingKind.notifications:
        out.add(SettingLine(
          kind: c.kind,
          label: 'Notifications',
          detail: c.flag! ? 'Turn on' : 'Turn off',
          effect: now.notifications == c.flag ? SettingEffect.same : SettingEffect.change,
          flag: c.flag,
          previousFlag: now.notifications,
        ));
      case SettingKind.course:
        final chosen = courseChoices[index];
        final picked = chosen == null ? null : now.courses.where((x) => x.id == chosen).firstOrNull;
        final course = picked ?? (c.text == kAskCourse ? null : matchCourse(c.text, now.courses));
        if (course == null) {
          out.add(SettingLine(
            kind: c.kind,
            label: c.flag! ? 'Show course' : 'Hide course',
            detail: c.text == kAskCourse ? 'Which course?' : c.text!,
            text: c.text,
            index: index,
            effect: SettingEffect.unknown,
          ));
        } else {
          final shown = !now.disabledCourses.contains(course.id);
          out.add(SettingLine(
            kind: c.kind,
            label: c.flag! ? 'Show course' : 'Hide course',
            detail: course.shortLabel,
            effect: shown == c.flag ? SettingEffect.same : SettingEffect.change,
            flag: c.flag,
            courseId: course.id,
            previousFlag: shown,
          ));
        }
      case SettingKind.open:
        out.add(SettingLine(
          kind: c.kind,
          label: 'Open',
          detail: c.text == 'chat' ? 'Assistant' : _cap(c.text!),
          effect: SettingEffect.change,
          text: c.text,
        ));
    }
  }
  return out;
}

/// The app's own setters, so applying can be tested without the app.
abstract interface class SettingsTarget {
  void setTheme(String name);
  void setFont(String name);
  void setNotifications(bool on);
  void setCourseShown(int courseId, bool shown);
  void open(String page);
}

/// What to put back to undo: only what was changed. Opening a page is not undone.
class SettingsUndo {
  SettingsUndo({this.theme, this.font, this.notifications, Map<int, bool>? courses}) : courses = courses ?? {};

  String? theme;
  String? font;
  bool? notifications;
  final Map<int, bool> courses;

  bool get isEmpty => theme == null && font == null && notifications == null && courses.isEmpty;
}

/// An apply stopped half way; [done] is what had been changed so far.
class SettingsApplyFailed implements Exception {
  const SettingsApplyFailed(this.done, this.cause);

  final SettingsUndo done;
  final Object cause;
}

/// Applies the lines that change something and returns how to undo it.
SettingsUndo applySettings(List<SettingLine> lines, SettingsTarget target) {
  final undo = SettingsUndo();
  try {
    for (final l in lines) {
      if (l.effect != SettingEffect.change) continue;
      switch (l.kind) {
        case SettingKind.theme:
          target.setTheme(l.text!);
          undo.theme ??= l.previousText;
        case SettingKind.font:
          target.setFont(l.text!);
          undo.font ??= l.previousText;
        case SettingKind.notifications:
          target.setNotifications(l.flag!);
          undo.notifications ??= l.previousFlag;
        case SettingKind.course:
          target.setCourseShown(l.courseId!, l.flag!);
          undo.courses.putIfAbsent(l.courseId!, () => l.previousFlag!);
        case SettingKind.open:
          target.open(l.text!);
      }
    }
  } catch (e) {
    throw SettingsApplyFailed(undo, e);
  }
  return undo;
}

void undoSettings(SettingsUndo undo, SettingsTarget target) {
  if (undo.theme != null) target.setTheme(undo.theme!);
  if (undo.font != null) target.setFont(undo.font!);
  if (undo.notifications != null) target.setNotifications(undo.notifications!);
  for (final e in undo.courses.entries) {
    target.setCourseShown(e.key, e.value);
  }
}
