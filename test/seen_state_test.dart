import 'package:etherlex/features/activity/domain/activity_item.dart';
import 'package:etherlex/features/grades/domain/grades.dart';
import 'package:etherlex/features/seen/domain/seen_state.dart';
import 'package:flutter_test/flutter_test.dart';

ActivityItem item(String id, DateTime at) => ActivityItem(id: id, kind: ActivityKind.announcement, title: id, body: '', createdAt: at);

void main() {
  final t0 = DateTime(2026, 11, 1, 12);
  final old = item('old', t0.subtract(const Duration(days: 2)));
  final base = item('base', t0);
  final fresh = item('fresh', t0.add(const Duration(hours: 3)));

  group('activity', () {
    test('nothing is new before the first look', () {
      expect(const SeenState().isActivityNew(fresh), isFalse);
      expect(const SeenState().baselineActivity(const []).activityBaseline, isNull);
    });

    test('the first list is the baseline: only later items are new', () {
      final s = const SeenState().baselineActivity([old, base]);
      expect(s.activityBaseline, t0);
      expect(s.isActivityNew(old), isFalse);
      expect(s.isActivityNew(base), isFalse);
      expect(s.isActivityNew(fresh), isTrue);
      expect(s.baselineActivity([fresh]).activityBaseline, t0, reason: 'the baseline is set once');
    });

    test('opening an item, or all of them, marks it seen', () {
      final s = const SeenState().baselineActivity([base]);
      final a = fresh, b = item('fresh2', t0.add(const Duration(hours: 4)));
      expect(s.newActivityCount([a, b]), 2);
      final one = s.markActivity('fresh');
      expect(one.newActivityCount([a, b]), 1);
      expect(identical(one.markActivity('fresh'), one), isTrue);
      expect(s.markAllActivity([a, b]).newActivityCount([a, b]), 0);
      expect(identical(s.markAllActivity([base]), s), isTrue);
    });

    test('only the latest ids are kept', () {
      var s = const SeenState().baselineActivity([base]);
      for (var i = 0; i < kMaxSeenActivity + 20; i++) {
        s = s.markActivity('id$i');
      }
      expect(s.activityIds.length, kMaxSeenActivity);
      expect(s.activityIds.contains('id0'), isFalse);
      expect(s.activityIds.contains('id${kMaxSeenActivity + 19}'), isTrue);
    });
  });

  group('marking unseen', () {
    test('an old item can be marked new again, and opening clears it', () {
      final s = const SeenState().baselineActivity([old, base]);
      expect(s.isActivityNew(old), isFalse);
      final u = s.markActivityUnseen('old');
      expect(u.isActivityNew(old), isTrue);
      expect(u.newActivityCount([old, base]), 1);
      expect(identical(u.markActivityUnseen('old'), u), isTrue);
      expect(u.markActivity('old').isActivityNew(old), isFalse);
    });

    test('a new item opened and marked unseen is new again', () {
      final s = const SeenState().baselineActivity([base]).markActivity('fresh');
      expect(s.isActivityNew(fresh), isFalse);
      expect(s.markActivityUnseen('fresh').isActivityNew(fresh), isTrue);
    });

    test('mark all clears the hand-marked ones too', () {
      final s = const SeenState().baselineActivity([old, base]).markActivityUnseen('old');
      expect(s.markAllActivity([old, base]).isActivityNew(old), isFalse);
    });

    test('a course can be marked as having news again', () {
      const g = CourseGrade(courseId: 1, currentScore: 90);
      final s = const SeenState().baselineGrades({1: g}, t0);
      final u = s.markCourseUnseen(1);
      expect(u.courseUpdated(g), isTrue);
      expect(u.markCourse(1, g, t0).courseUpdated(g), isFalse);
      expect(u.markAllCourses({1: g}, t0).courseUpdated(g), isFalse);
    });

    test('it is saved', () {
      final s = const SeenState().baselineActivity([base]).markActivityUnseen('a').markCourseUnseen(3);
      final back = SeenState.fromJson(s.toJson());
      expect(back.activityUnseen, {'a'});
      expect(back.courseUnseen, {3});
    });
  });

  group('grades', () {
    const a1 = CourseGrade(courseId: 1, currentScore: 90, currentGrade: 'A-');
    const a1Changed = CourseGrade(courseId: 1, currentScore: 85, currentGrade: 'B');
    const none = CourseGrade(courseId: 2);

    test('nothing is updated before the first look; the first look is the baseline', () {
      expect(const SeenState().courseUpdated(a1), isFalse);
      final s = const SeenState().baselineGrades({1: a1, 2: none}, t0);
      expect(s.courseUpdated(a1), isFalse);
      expect(s.courseUpdated(none), isFalse);
      expect(s.courseUpdated(a1Changed), isTrue);
      expect(identical(s.baselineGrades({1: a1Changed}, t0), s), isTrue);
    });

    test('a course that gets its first grade is updated; opening it clears that', () {
      final s = const SeenState().baselineGrades({1: a1, 2: none}, t0);
      const graded = CourseGrade(courseId: 2, currentScore: 70);
      expect(s.courseUpdated(graded), isTrue);
      expect(s.updatedCourseCount([a1, graded]), 1);
      final opened = s.markCourse(2, graded, t0.add(const Duration(hours: 1)));
      expect(opened.courseUpdated(graded), isFalse);
      expect(opened.sinceFor(2), t0.add(const Duration(hours: 1)));
      expect(opened.sinceFor(1), t0, reason: 'a course never opened counts from the baseline');
    });

    test('mark all clears every course', () {
      final s = const SeenState().baselineGrades({1: a1}, t0);
      final all = s.markAllCourses({1: a1Changed}, t0.add(const Duration(hours: 2)));
      expect(all.courseUpdated(a1Changed), isFalse);
    });

    test('only graded or excused items after the last visit are new', () {
      GradedItem g(GradeState st, DateTime? when) => GradedItem(id: 1, title: 'x', state: st, when: when);
      final after = t0.add(const Duration(days: 1));
      expect(SeenState.itemIsNew(g(GradeState.graded, after), t0), isTrue);
      expect(SeenState.itemIsNew(g(GradeState.excused, after), t0), isTrue);
      expect(SeenState.itemIsNew(g(GradeState.graded, t0.subtract(const Duration(days: 1))), t0), isFalse);
      expect(SeenState.itemIsNew(g(GradeState.submitted, after), t0), isFalse);
      expect(SeenState.itemIsNew(g(GradeState.missing, after), t0), isFalse);
      expect(SeenState.itemIsNew(g(GradeState.graded, null), t0), isFalse);
      expect(SeenState.itemIsNew(g(GradeState.graded, after), null), isFalse);
    });
  });

  group('saving', () {
    test('it round-trips', () {
      var s = const SeenState().baselineActivity([base]).markActivity('x').baselineGrades({1: const CourseGrade(courseId: 1, currentScore: 90)}, t0);
      s = s.markCourse(1, const CourseGrade(courseId: 1, currentScore: 91), t0.add(const Duration(hours: 1)));
      final back = SeenState.fromJson(s.toJson());
      expect(back.activityBaseline, s.activityBaseline);
      expect(back.activityIds, {'x'});
      expect(back.courseGrades, s.courseGrades);
      expect(back.gradesBaselineAt, s.gradesBaselineAt);
      expect(back.courseSeenAt, s.courseSeenAt);
    });

    test('a damaged file gives an empty state, and bad entries are skipped', () {
      expect(SeenState.fromJson('nope').activityBaseline, isNull);
      expect(SeenState.fromJson(null).courseGrades, isNull);
      final s = SeenState.fromJson({
        'activityBaseline': 'not a date',
        'activityIds': ['ok', 5, '', null],
        'courseGrades': {'1': '90', 'x': '80', '2': 7},
        'courseSeenAt': {'1': '2026-11-01T00:00:00Z', '2': 'bad'},
      });
      expect(s.activityBaseline, isNull);
      expect(s.activityIds, {'ok'});
      expect(s.courseGrades, {1: '90'});
      expect(s.courseSeenAt.keys, [1]);
    });
  });
}
