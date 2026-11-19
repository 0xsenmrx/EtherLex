import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:etherlex/core/database/app_database.dart';
import 'package:etherlex/core/network/canvas_client.dart';
import 'package:etherlex/core/utils/date_format.dart';
import 'package:etherlex/core/utils/html_text.dart';
import 'package:etherlex/features/activity/data/activity_mapper.dart';
import 'package:etherlex/features/activity/data/cached_activity_repository.dart';
import 'package:etherlex/features/activity/domain/activity_feed.dart';
import 'package:etherlex/features/activity/domain/activity_item.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Object Function(String path) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(respond(options.path)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final now = DateTime(2026, 11, 13, 12);

  group('htmlToText links', () {
    test('keeps the url next to the link text', () {
      expect(
        htmlToText('<a href="https://x.org/a?b=1&amp;c=2">Read</a>', links: true),
        'Read (https://x.org/a?b=1&c=2)',
      );
      expect(htmlToText('<a href="https://x.org">https://x.org</a>', links: true), 'https://x.org');
      expect(
        htmlToText('<a href="/courses/1/pages/p">Page</a>', links: true, origin: 'https://c.edu'),
        'Page (https://c.edu/courses/1/pages/p)',
      );
    });

    test('file links and default mode stay plain', () {
      expect(htmlToText('<a href="https://c.edu/files/5/download">slides.pdf</a>', links: true), 'slides.pdf');
      expect(htmlToText('<a href="https://x.org">Read</a>'), 'Read');
    });
  });

  group('htmlToText', () {
    test('strips tags, keeps paragraphs, decodes entities', () {
      expect(
        htmlToText('<p>Hello&nbsp;<b>world</b> &amp; all</p><p>Second</p>'),
        'Hello world & all\nSecond',
      );
    });
    test('drops script/style and truncates', () {
      expect(htmlToText('<style>p{}</style>Hi<script>x()</script>'), 'Hi');
      expect(htmlToText('a' * 50, maxLength: 10), '${'a' * 10}…');
    });
  });

  group('formatAgo', () {
    test('labels', () {
      expect(formatAgo(DateTime(2026, 11, 13, 11, 55), now), '5m ago');
      expect(formatAgo(DateTime(2026, 11, 13, 9), now), '3h ago');
      expect(formatAgo(DateTime(2026, 11, 12, 17), now), 'Yesterday 17:00');
      expect(formatAgo(DateTime(2026, 11, 10, 9), now), 'Tue 09:00');
      expect(formatAgo(DateTime(2026, 11, 1, 9), now), '1 Nov');
    });
  });

  group('parseActivity', () {
    test('announcement', () {
      final a = parseActivity({
        'id': 5,
        'type': 'Announcement',
        'title': 'Room change',
        'message': '<p>Now in Hall B</p>',
        'updated_at': '2026-11-13T01:00:00Z',
        'course_id': 7,
        'html_url': 'https://s.instructure.com/courses/7/discussion_topics/5',
      })!;
      expect(a.kind, ActivityKind.announcement);
      expect(a.body, 'Now in Hall B');
      expect(a.courseId, 7);
      expect(a.id, 'Announcement-5');
    });

    test('grade builds a readable body and falls back to the assignment name', () {
      final a = parseActivity({
        'id': 9,
        'type': 'Submission',
        'created_at': '2026-11-12T10:00:00Z',
        'grade': 'A-',
        'score': 38,
        'assignment': {'name': 'PS5', 'points_possible': 40},
      })!;
      expect(a.kind, ActivityKind.grade);
      expect(a.title, 'PS5');
      expect(a.body, 'Grade: A- · Score: 38 / 40');
    });

    test('unknown types become other; missing id or date is skipped', () {
      expect(parseActivity({'id': 1, 'type': 'Mystery', 'created_at': '2026-11-12T10:00:00Z'})!.kind,
          ActivityKind.other);
      expect(parseActivity({'type': 'Announcement', 'created_at': '2026-11-12T10:00:00Z'}), isNull);
      expect(parseActivity({'id': 1, 'type': 'Announcement'}), isNull);
    });
  });

  group('buildActivityFeed', () {
    test('groups newest first with headers', () {
      ActivityItem it(String id, DateTime t) =>
          ActivityItem(id: id, kind: ActivityKind.other, title: id, body: '', createdAt: t);
      final feed = buildActivityFeed([
        it('old', DateTime(2026, 10, 1)),
        it('a', DateTime(2026, 11, 13, 9)),
        it('b', DateTime(2026, 11, 13, 11)),
        it('y', DateTime(2026, 11, 12, 8)),
      ], now);
      expect((feed[0] as ActivityHeader).bucket, ActivityBucket.today);
      expect((feed[1] as ActivityRowEntry).item.id, 'b');
      expect((feed[2] as ActivityRowEntry).item.id, 'a');
      expect((feed[3] as ActivityHeader).bucket, ActivityBucket.yesterday);
      expect((feed.last as ActivityRowEntry).item.id, 'old');
    });
  });

  group('CachedActivityRepository', () {
    late AppDatabase db;
    late List<Map<String, dynamic>> remote;
    late CachedActivityRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      remote = [
        {'id': 1, 'type': 'Announcement', 'title': 'A', 'message': '<p>x</p>', 'updated_at': '2026-11-13T01:00:00Z'},
        {'id': 2, 'type': 'Submission', 'created_at': '2026-11-12T01:00:00Z', 'grade': '90', 'assignment': {'name': 'HW'}},
      ];
      repo = CachedActivityRepository(
        CanvasClient(
          baseUrl: 'https://school.instructure.com',
          token: 't',
          dio: Dio()..httpClientAdapter = _Adapter((p) {
            // The extra endpoints fail, so the stream items must be kept.
            if (p.contains('graded_submissions')) throw StateError('unavailable');
            return remote;
          }),
        ),
        db,
      );
    });

    tearDown(() => db.close());

    test('refresh stores items newest first and mirrors removals', () async {
      await repo.refresh();
      expect((await repo.watch().first).map((i) => i.id), ['Announcement-1', 'Submission-2']);
      expect(await repo.lastSyncedAt(), isNotNull);
      remote = [remote.first];
      await repo.refresh();
      expect((await repo.watch().first).map((i) => i.id), ['Announcement-1']);
    });
  });
}
