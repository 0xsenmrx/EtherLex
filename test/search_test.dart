import 'package:etherlex/features/activity/domain/activity_item.dart';
import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/courses/domain/course.dart';
import 'package:etherlex/features/search/domain/search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 18);
  const courses = {
    1: Course(id: 1, name: 'Linear Algebra', code: 'MATH2140J'),
    2: Course(id: 2, name: 'Electronic Circuits', code: 'ECE3110J'),
  };
  final assignments = [
    Assignment(id: 1, courseId: 1, title: 'Project proposal', dueAt: now.add(const Duration(days: 2)), points: null),
    Assignment(id: 2, courseId: 2, title: 'Midterm review', dueAt: now.add(const Duration(days: 5)), points: null),
  ];
  final activity = [
    ActivityItem(
      id: 'a',
      kind: ActivityKind.announcement,
      title: 'Room change',
      body: 'The midterm moves to room 204',
      courseId: 2,
      createdAt: now,
    ),
  ];

  List<SearchHit> run(String q, {Set<int> excluded = const {}}) => searchAll(q,
      assignments: assignments, activity: activity, courses: courses, excludedCourses: excluded, now: now);

  test('empty query gives nothing', () => expect(run('  '), isEmpty));

  test('title match ranks above body match', () {
    final hits = run('midterm');
    expect(hits.first.kind, HitKind.assignment);
    expect(hits.length, 2);
  });

  test('all words must match, course label counts', () {
    expect(run('algebra proposal').length, 1);
    expect(run('algebra circuits'), isEmpty);
  });

  test('disabled courses are excluded', () {
    expect(run('midterm', excluded: {2}), isEmpty);
  });
}
