import 'package:etherlex/features/activity/data/activity_mapper.dart';
import 'package:etherlex/features/activity/domain/activity_item.dart';
import 'package:etherlex/core/network/canvas_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseImages finds Canvas files and external https images', () {
    const html = '''
<p><img src="https://school.instructure.com/courses/5/files/77/preview?verifier=x" data-api-endpoint="https://school.instructure.com/api/v1/courses/5/files/77" alt="a"></p>
<img src="https://cdn.example.com/pic.png?a=1&amp;b=2">
<img src="http://insecure.example.com/x.png">
<img src="/equation_images/x%5E2">
<img src="https://school.instructure.com/courses/5/files/77/preview">''';
    expect(parseImages(html, host: 'school.instructure.com'), [
      'file:77',
      'url:https://cdn.example.com/pic.png?a=1&b=2',
    ]);
  });

  test('parseAnnouncement keeps the full text, course and images', () {
    final a = parseAnnouncement({
      'id': 9,
      'title': 'Exam moved',
      'message': '<p>See <img src="https://cdn.example.com/p.png"></p>',
      'posted_at': '2026-11-10T08:00:00Z',
      'context_code': 'course_42',
      'html_url': 'https://school.instructure.com/courses/42/discussion_topics/9',
    })!;
    expect(a.kind, ActivityKind.announcement);
    expect(a.id, 'Announcement-9');
    expect(a.courseId, 42);
    expect(a.images, ['url:https://cdn.example.com/p.png']);
  });

  test('parseGraded builds score text and an assignment link', () {
    final g = parseGraded({
      'id': 5,
      'score': 8.5,
      'grade': '8.5',
      'graded_at': '2026-11-11T08:00:00Z',
      'assignment_id': 3,
      'assignment': {'name': 'HW 1', 'points_possible': 10, 'course_id': 42},
    }, baseUrl: 'https://school.instructure.com')!;
    expect(g.kind, ActivityKind.grade);
    expect(g.title, 'HW 1');
    expect(g.body, 'Grade: 8.5 · Score: 8.5 / 10');
    expect(g.courseId, 42);
    expect(g.url, 'https://school.instructure.com/courses/42/assignments/3');
  });

  test('parseLastPage reads a numeric rel="last"', () {
    const header =
        '<https://x/api/v1/a?page=2&per_page=100>; rel="next", <https://x/api/v1/a?page=7&per_page=100>; rel="last"';
    expect(parseLastPage(header), 7);
    expect(parseLastPage('<https://x/a?page=bookmark:abc>; rel="last"'), isNull);
    expect(parseLastPage(null), isNull);
  });
}
