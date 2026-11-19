import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:etherlex/core/database/app_database.dart';
import 'package:etherlex/core/network/canvas_client.dart';
import 'package:etherlex/features/assignments/data/cached_assignments_repository.dart';
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

Map<String, dynamic> _a(int id, {bool submitted = false}) => {
      'id': id,
      'name': 'HW$id',
      'due_at': '2026-11-20T10:00:00Z',
      'points_possible': 10,
      'submission': {'workflow_state': submitted ? 'submitted' : 'unsubmitted'},
    };

void main() {
  late AppDatabase db;
  late List<Map<String, dynamic>> remote;
  late CachedAssignmentsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = [_a(10), _a(11)];
    final adapter = _Adapter((path) {
      if (path == '/api/v1/courses') {
        return [
          {'id': 1, 'name': 'Physics', 'course_code': 'PHYS 1'},
        ];
      }
      return remote;
    });
    repo = CachedAssignmentsRepository(
      CanvasClient(
        baseUrl: 'https://school.instructure.com',
        token: 't',
        dio: Dio()..httpClientAdapter = adapter,
      ),
      db,
    );
  });

  tearDown(() => db.close());

  test('refresh fills the cache and stamps the sync time', () async {
    expect(await repo.lastSyncedAt(), isNull);
    await repo.refresh();
    final items = await repo.watch().first;
    expect(items.map((a) => a.id).toSet(), {10, 11});
    expect((await repo.watchCourses().first).single.name, 'Physics');
    expect(await repo.lastSyncedAt(), isNotNull);
  });

  test('stars and manual done survive a refresh', () async {
    await repo.refresh();
    await repo.setStarred(10, true);
    await repo.setDone(11, true);
    await repo.refresh();
    final byId = {for (final a in await repo.watch().first) a.id: a};
    expect(byId[10]!.starred, isTrue);
    expect(byId[10]!.done, isFalse);
    expect(byId[11]!.done, isTrue);
  });

  test('a manual choice that matches Canvas follows Canvas afterwards', () async {
    await repo.refresh();
    await repo.setDone(10, true); // override: done
    await repo.setDone(10, false); // matches Canvas (unsubmitted) -> override cleared
    remote = [_a(10, submitted: true), _a(11)];
    await repo.refresh();
    final byId = {for (final a in await repo.watch().first) a.id: a};
    expect(byId[10]!.done, isTrue); // Canvas now says submitted
  });

  test('assignments removed from Canvas disappear', () async {
    await repo.refresh();
    remote = [_a(10)];
    await repo.refresh();
    expect((await repo.watch().first).map((a) => a.id), [10]);
  });
}
