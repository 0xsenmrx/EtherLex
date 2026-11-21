import 'package:etherlex/features/chat/domain/proposed_courses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty block, {} or no "show" lists every course', () {
    expect(parseCourseList(''), CourseListFilter.all);
    expect(parseCourseList(' {} '), CourseListFilter.all);
    expect(parseCourseList('{"note":"x"}'), CourseListFilter.all);
  });

  test('show picks hidden or shown courses only', () {
    expect(parseCourseList('{"show":"hidden"}'), CourseListFilter.hidden);
    expect(parseCourseList('{"show":"shown"}'), CourseListFilter.shown);
    expect(parseCourseList('{"show":"all"}'), CourseListFilter.all);
  });

  test('anything else is not a card', () {
    expect(parseCourseList('{"show":"some"}'), isNull);
    expect(parseCourseList('[1]'), isNull);
    expect(parseCourseList('not json'), isNull);
  });
}
