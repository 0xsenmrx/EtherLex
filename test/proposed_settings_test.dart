import 'package:etherlex/core/appearance/appearance.dart';
import 'package:etherlex/features/chat/domain/proposed_settings.dart';
import 'package:etherlex/features/courses/domain/course.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements SettingsTarget {
  String theme = 'system';
  String font = 'handwritten';
  bool notifications = true;
  final shown = <int, bool>{};
  final opened = <String>[];

  @override
  void setTheme(String name) => theme = name;
  @override
  void setFont(String name) => font = name;
  @override
  void setNotifications(bool on) => notifications = on;
  @override
  void setCourseShown(int courseId, bool value) => shown[courseId] = value;
  @override
  void open(String page) => opened.add(page);
}

const _courses = [
  Course(id: 1, name: 'Physics II', code: 'PHYS2'),
  Course(id: 2, name: 'Physics Lab', code: 'PHYS2L'),
  Course(id: 3, name: 'Electronic Circuits', code: 'ECE3110J'),
];

SettingsSnapshot _now({Set<int> disabled = const {}}) => SettingsSnapshot(
      theme: ThemeChoice.system,
      typeface: TypefaceChoice.handwritten,
      notifications: true,
      disabledCourses: disabled,
      courses: _courses,
    );

void main() {
  group('parseSetting', () {
    test('reads each kind', () {
      expect(parseSetting({'type': 'theme', 'value': 'dark'})!.text, 'dark');
      expect(parseSetting({'type': 'font', 'value': 'clean'})!.text, 'clean');
      expect(parseSetting({'type': 'notifications', 'value': false})!.flag, isFalse);
      final c = parseSetting({'type': 'course', 'course': ' Circuits ', 'value': false})!;
      expect(c.text, 'Circuits');
      expect(c.flag, isFalse);
      expect(parseSetting({'type': 'open', 'page': 'grades'})!.text, 'grades');
    });

    test('anything else is refused', () {
      for (final bad in <Object?>[
        null,
        'x',
        {'type': 'theme', 'value': 'purple'},
        {'type': 'font', 'value': 1},
        {'type': 'notifications', 'value': 'off'},
        {'type': 'course', 'course': '', 'value': true},
        {'type': 'course', 'course': 'Physics'},
        {'type': 'open', 'page': 'login'},
        {'type': 'open', 'page': 'settings'},
        {'type': 'sign_out'},
        {'type': 'api_key', 'value': 'sk-123'},
      ]) {
        expect(parseSetting(bad), isNull, reason: '$bad');
      }
    });
  });

  group('previewSettings', () {
    test('marks changes and what is already so', () {
      final lines = previewSettings(const [
        SettingChange(kind: SettingKind.theme, text: 'dark'),
        SettingChange(kind: SettingKind.font, text: 'handwritten'),
        SettingChange(kind: SettingKind.notifications, flag: true),
        SettingChange(kind: SettingKind.open, text: 'chat'),
      ], _now());
      expect([for (final l in lines) l.effect], [SettingEffect.change, SettingEffect.same, SettingEffect.same, SettingEffect.change]);
      expect(lines.first.previousText, 'system');
      expect(lines.last.detail, 'Assistant');
    });

    test('a course must be found, and only one may fit', () {
      final lines = previewSettings(const [
        SettingChange(kind: SettingKind.course, text: 'electronic circuits', flag: false),
        SettingChange(kind: SettingKind.course, text: 'Physics', flag: false),
        SettingChange(kind: SettingKind.course, text: 'Chemistry', flag: false),
      ], _now());
      expect(lines[0].effect, SettingEffect.change);
      expect(lines[0].courseId, 3);
      expect(lines[0].detail, 'ECE3110J');
      expect(lines[1].effect, SettingEffect.unknown); // two Physics courses: nothing guessed
      expect(lines[2].effect, SettingEffect.unknown);
    });

    test('a course the person picked stands in for a name that matched nothing', () {
      const change = SettingChange(kind: SettingKind.course, text: 'Physics', flag: false);
      final without = previewSettings(const [change], _now());
      expect(without.single.effect, SettingEffect.unknown);
      expect(without.single.text, 'Physics'); // so the card can offer "Choose course"
      final picked = previewSettings(const [change], _now(), courseChoices: {'Physics': 2});
      expect(picked.single.effect, SettingEffect.change);
      expect(picked.single.courseId, 2);
      // a pick for another name changes nothing
      expect(previewSettings(const [change], _now(), courseChoices: {'Chemistry': 2}).single.effect, SettingEffect.unknown);
    });

    test('hiding a hidden course is no change; showing it is', () {
      final lines = previewSettings(const [
        SettingChange(kind: SettingKind.course, text: 'ECE3110J', flag: false),
        SettingChange(kind: SettingKind.course, text: 'ECE3110J', flag: true),
      ], _now(disabled: {3}));
      expect([for (final l in lines) l.effect], [SettingEffect.same, SettingEffect.change]);
    });
  });

  group('applySettings', () {
    test('changes only what differs, opens pages, and undo restores the rest', () {
      final target = _Fake();
      final lines = previewSettings(const [
        SettingChange(kind: SettingKind.theme, text: 'dark'),
        SettingChange(kind: SettingKind.font, text: 'clean'),
        SettingChange(kind: SettingKind.notifications, flag: false),
        SettingChange(kind: SettingKind.course, text: 'ECE3110J', flag: false),
        SettingChange(kind: SettingKind.open, text: 'grades'),
      ], _now());
      final undo = applySettings(lines, target);
      expect(target.theme, 'dark');
      expect(target.font, 'clean');
      expect(target.notifications, isFalse);
      expect(target.shown, {3: false});
      expect(target.opened, ['grades']);
      undoSettings(undo, target);
      expect(target.theme, 'system');
      expect(target.font, 'handwritten');
      expect(target.notifications, isTrue);
      expect(target.shown, {3: true});
      expect(target.opened, ['grades']); // opening is not undone
    });

    test('a failure reports what was already changed', () {
      final target = _FailsOnFont();
      final lines = previewSettings(const [
        SettingChange(kind: SettingKind.theme, text: 'dark'),
        SettingChange(kind: SettingKind.font, text: 'clean'),
      ], _now());
      expect(
        () => applySettings(lines, target),
        throwsA(isA<SettingsApplyFailed>().having((e) => e.done.theme, 'theme', 'system')),
      );
    });
  });
}

class _FailsOnFont extends _Fake {
  @override
  void setFont(String name) => throw StateError('disk');
}
