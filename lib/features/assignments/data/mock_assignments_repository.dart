import 'dart:async';

import '../../courses/domain/course.dart';
import '../domain/assignment.dart';
import '../domain/assignments_repository.dart';

class MockAssignmentsRepository implements AssignmentsRepository {
  MockAssignmentsRepository({DateTime? now}) {
    _items = _seed(now ?? DateTime.now());
  }

  late List<Assignment> _items;
  final StreamController<List<Assignment>> _changes =
      StreamController<List<Assignment>>.broadcast();

  final List<Course> courses = const [
    Course(id: 1, name: 'Electromagnetism', code: 'PHYS 201'),
    Course(id: 2, name: 'Algorithms', code: 'CS 301'),
    Course(id: 3, name: 'Probability', code: 'MATH 240'),
    Course(id: 4, name: 'Microeconomics', code: 'ECON 101'),
    Course(id: 5, name: 'Writing Seminar', code: 'WRIT 110'),
  ];

  static DateTime _at(DateTime now, int days, int hour, [int minute = 0]) =>
      DateTime(now.year, now.month, now.day + days, hour, minute);

  static List<Assignment> _seed(DateTime now) => [
        Assignment(id: 101, courseId: 2, title: 'Problem Set 6: Dynamic Programming', dueAt: _at(now, -2, 23, 59), points: 100),
        Assignment(id: 102, courseId: 4, title: 'Reading Response: Market Failures', dueAt: _at(now, -1, 17), points: 20, starred: true),
        Assignment(id: 103, courseId: 3, title: 'Homework 7: Conditional Expectation', dueAt: _at(now, 0, 23, 59), points: 50),
        Assignment(id: 104, courseId: 1, title: 'Lab Report 4: RC Circuits', dueAt: _at(now, 1, 10), points: 80, starred: true),
        Assignment(id: 105, courseId: 5, title: 'Draft 2: Argument Essay', dueAt: _at(now, 1, 23, 59), points: 100),
        Assignment(id: 106, courseId: 2, title: 'Programming Assignment: Graph Search', dueAt: _at(now, 3, 12), points: 120),
        Assignment(id: 107, courseId: 1, title: 'Problem Set 8: Maxwell Equations', dueAt: _at(now, 4, 18), points: 60),
        Assignment(id: 108, courseId: 3, title: 'Quiz 3', dueAt: _at(now, 6, 9, 30), points: 30),
        Assignment(id: 109, courseId: 4, title: 'Problem Set 5: Consumer Theory', dueAt: _at(now, 9, 23, 59), points: 40),
        Assignment(id: 110, courseId: 2, title: 'Midterm Project Proposal', dueAt: _at(now, 12, 23, 59), points: 50),
        Assignment(id: 111, courseId: 5, title: 'Final Portfolio', dueAt: _at(now, 24, 23, 59), points: 200),
        Assignment(id: 112, courseId: 1, title: 'Optional: Extra Practice Set', dueAt: null, points: null),
        Assignment(id: 113, courseId: 3, title: 'Homework 6: Variance and Covariance', dueAt: _at(now, -6, 23, 59), points: 50, done: true),
        Assignment(id: 114, courseId: 4, title: 'Discussion Post 4', dueAt: _at(now, -4, 12), points: 10, done: true),
      ];

  void _replace(int id, Assignment Function(Assignment) f) {
    _items = [for (final a in _items) a.id == id ? f(a) : a];
    _changes.add(List<Assignment>.unmodifiable(_items));
  }

  @override
  Stream<List<Course>> watchCourses() => Stream<List<Course>>.value(courses);

  @override
  Future<DateTime?> lastSyncedAt() async => null;

  @override
  Future<void> refresh() => Future<void>.delayed(const Duration(milliseconds: 500));

  @override
  Stream<List<Assignment>> watch() {
    return Stream<List<Assignment>>.multi((controller) {
      controller.add(List<Assignment>.unmodifiable(_items));
      final sub = _changes.stream.listen(controller.add);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> setStarred(int id, bool value) async =>
      _replace(id, (a) => a.copyWith(starred: value));

  @override
  Future<void> setDone(int id, bool value) async =>
      _replace(id, (a) => a.copyWith(done: value));

  @override
  void dispose() => _changes.close();
}
