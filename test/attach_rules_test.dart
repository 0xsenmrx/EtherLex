import 'package:etherlex/features/assignments/domain/assignment.dart';
import 'package:etherlex/features/chat/domain/attach_rules.dart';
import 'package:etherlex/features/courses/domain/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('readable kinds and sizes are accepted without downloading', () {
    expect(attachProblemFor('syllabus.pdf', 3 * 1024 * 1024), isNull);
    expect(attachProblemFor('notes.md', 10), isNull);
    expect(attachProblemFor('slides.pptx', 20 * 1024 * 1024), isNull);
    expect(attachProblemFor('plot.png', kMaxImageBytes), isNull);
  });

  test('unreadable kinds and too big files say why', () {
    expect(attachProblemFor('data.xlsx', 10), 'Cannot be read yet');
    expect(attachProblemFor('video.mp4', 10), 'Cannot be read yet');
    expect(attachProblemFor('scan.bmp', 10), contains('PNG, JPEG'));
    expect(attachProblemFor('plot.png', 10, readsImages: false), contains('cannot read pictures'));
    expect(attachProblemFor('notes.md', 10, readsImages: false), isNull);
    expect(attachProblemFor('big.png', kMaxImageBytes + 1), startsWith('Too big: '));
    expect(attachProblemFor('big.pdf', kMaxDocumentBytes + 1), startsWith('Too big: '));
  });

  test('search needs every word, ignoring case and order', () {
    expect(nameMatches('Week 3 Lecture Notes.pdf', 'lecture 3'), isTrue);
    expect(nameMatches('Week 3 Lecture Notes.pdf', 'exam'), isFalse);
    expect(nameMatches('anything', '  '), isTrue);
  });

  group('assignmentsWithFiles', () {
    Assignment a(int id, String title, {int course = 1, DateTime? due, bool done = false}) =>
        Assignment(id: id, courseId: course, title: title, dueAt: due, points: 10, done: done);
    final courses = {
      1: const Course(id: 1, name: 'Electronic Circuits', code: 'ECE3110J'),
      2: const Course(id: 2, name: 'Ethics', code: 'ENGR4960J'),
    };
    final d1 = DateTime(2026, 12, 1), d2 = DateTime(2026, 12, 5);

    test('open first by due date, no date last, then done ones', () {
      final out = assignmentsWithFiles(
        [a(1, 'late', due: d2), a(2, 'undated'), a(3, 'finished', due: d1, done: true), a(4, 'soon', due: d1)],
        courses,
      );
      expect(out.map((e) => e.id), [4, 1, 2, 3]);
    });

    test('your own tasks and hidden courses are left out', () {
      final out = assignmentsWithFiles([a(-1, 'my task'), a(5, 'hw'), a(6, 'essay', course: 2)], courses, disabled: {2});
      expect(out.map((e) => e.id), [5]);
    });

    test('the search looks at the title and the course', () {
      final all = [a(1, 'Homework 3'), a(2, 'Essay', course: 2)];
      expect(assignmentsWithFiles(all, courses, query: 'home 3').map((e) => e.id), isEmpty);
      expect(assignmentsWithFiles(all, courses, query: 'homework 3').map((e) => e.id), [1]);
      expect(assignmentsWithFiles(all, courses, query: 'ethics').map((e) => e.id), [2]);
    });
  });
}
