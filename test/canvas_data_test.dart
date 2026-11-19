import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:etherlex/core/network/canvas_client.dart';
import 'package:etherlex/features/assignments/data/canvas_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final List<Uri> requested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {String? link}) => ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (link != null) 'link': [link],
      },
    );

void main() {
  group('parseNextLink', () {
    test('finds rel=next among several links', () {
      const h = '<https://s.instructure.com/api/v1/courses?page=1>; rel="current", '
          '<https://s.instructure.com/api/v1/courses?page=2>; rel="next", '
          '<https://s.instructure.com/api/v1/courses?page=9>; rel="last"';
      expect(parseNextLink(h), 'https://s.instructure.com/api/v1/courses?page=2');
    });
    test('null when there is no next page', () {
      expect(parseNextLink('<https://x.com/a?page=1>; rel="current"'), isNull);
      expect(parseNextLink(null), isNull);
    });
  });

  group('getPaged', () {
    test('follows next links and stops on the last page', () async {
      final adapter = _Adapter((o) {
        if (o.uri.queryParameters['page'] == '2') return _json('[{"id": 3}]');
        return _json(
          '[{"id": 1}, {"id": 2}]',
          link: '<https://school.instructure.com/api/v1/courses?page=2&per_page=100>; rel="next"',
        );
      });
      final client = CanvasClient(
        baseUrl: 'https://school.instructure.com',
        token: 't',
        dio: Dio()..httpClientAdapter = adapter,
      );
      final items = await client.getPaged('/api/v1/courses');
      expect(items.map((e) => e['id']), [1, 2, 3]);
      expect(adapter.requested.length, 2);
    });

    test('does not follow a next link to another host', () async {
      final adapter = _Adapter(
        (o) => _json('[{"id": 1}]', link: '<https://evil.example.com/x?page=2>; rel="next"'),
      );
      final client = CanvasClient(
        baseUrl: 'https://school.instructure.com',
        token: 't',
        dio: Dio()..httpClientAdapter = adapter,
      );
      await client.getPaged('/api/v1/courses');
      expect(adapter.requested.length, 1);
    });

    test('sends include[]=submission for assignments', () async {
      final adapter = _Adapter((o) => _json('[]'));
      final client = CanvasClient(
        baseUrl: 'https://school.instructure.com',
        token: 't',
        dio: Dio()..httpClientAdapter = adapter,
      );
      await client.fetchAssignmentsJson(7);
      final uri = adapter.requested.single;
      expect(uri.path, '/api/v1/courses/7/assignments');
      expect(uri.queryParametersAll['include[]'], ['submission']);
    });
  });

  group('mappers', () {
    test('parseCourse skips courses without a name', () {
      expect(parseCourse({'id': 1, 'course_code': 'X'}), isNull);
      final c = parseCourse({'id': 1, 'name': 'Physics', 'course_code': 'PHYS 1'})!;
      expect(c.label, 'PHYS 1 · Physics');
    });

    test('parseAssignment: due date, points, submission state', () {
      final a = parseAssignment({
        'id': 9,
        'name': 'HW',
        'due_at': '2026-11-20T15:59:00Z',
        'points_possible': 10.0,
        'submission': {'workflow_state': 'submitted', 'submitted_at': '2026-11-19T10:00:00Z'},
      }, courseId: 4)!;
      expect(a.courseId, 4);
      expect(a.points, 10);
      expect(a.done, isTrue);
      expect(a.dueAt!.toUtc(), DateTime.utc(2026, 11, 20, 15, 59));
    });

    test('unsubmitted and missing dates', () {
      final a = parseAssignment({
        'id': 9,
        'name': 'HW',
        'due_at': null,
        'submission': {'workflow_state': 'unsubmitted', 'submitted_at': null},
      }, courseId: 4)!;
      expect(a.done, isFalse);
      expect(a.dueAt, isNull);
    });
  });
}
