import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/canvas_client.dart';
import '../domain/activity_item.dart';
import '../domain/activity_repository.dart';
import 'activity_mapper.dart';

class CachedActivityRepository implements ActivityRepository {
  CachedActivityRepository(this._client, this._db);

  final CanvasClient _client;
  final AppDatabase _db; // owned by the session, closed elsewhere

  static const _kLastSynced = 'activityLastSyncedAt';

  @override
  Stream<List<ActivityItem>> watch() {
    final query = _db.select(_db.cachedActivityItems)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map(
          (rows) => [
            for (final r in rows)
              ActivityItem(
                id: r.id,
                kind: ActivityKind.values.firstWhere(
                  (k) => k.name == r.kind,
                  orElse: () => ActivityKind.other,
                ),
                title: r.title,
                body: r.body,
                courseId: r.courseId,
                createdAt: r.createdAt,
                url: r.url,
                images: r.images.isEmpty ? const [] : r.images.split('\n'),
              ),
          ],
        );
  }

  @override
  Future<DateTime?> lastSyncedAt() async {
    final row = await (_db.select(_db.keyValues)..where((t) => t.settingKey.equals(_kLastSynced)))
        .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.settingValue)?.toLocal();
  }

  Future<List<Map<String, dynamic>>?> _try(Future<List<Map<String, dynamic>>> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> refresh() async {
    final courseIds = [for (final c in await _db.select(_db.cachedCourses).get()) c.id];
    final host = Uri.tryParse(_client.baseUrl)?.host;

    // The stream is the base; announcements and grades are also asked for
    // directly because the stream only keeps a short, partial window of them.
    final results = await Future.wait([
      _client.fetchActivityJson(),
      _try(_client.fetchGradedJson()),
      courseIds.isEmpty
          ? Future<List<Map<String, dynamic>>?>.value(null)
          : _try(_client.fetchAnnouncementsJson(courseIds)),
    ]);
    final stream = [for (final j in results[0]!) ?_orSkip(() => parseActivity(j, host: host))];
    final graded = results[1];
    final announcements = results[2];

    final items = <ActivityItem>[
      for (final i in stream)
        if (!(i.kind == ActivityKind.grade && graded != null) &&
            !(i.kind == ActivityKind.announcement && announcements != null))
          i,
      if (graded != null) for (final j in graded) ?_orSkip(() => parseGraded(j, baseUrl: _client.baseUrl)),
      if (announcements != null) for (final j in announcements) ?_orSkip(() => parseAnnouncement(j, host: host)),
    ];

    await _db.transaction(() async {
      await _db.delete(_db.cachedActivityItems).go(); // mirror Canvas's current window
      await _db.batch((b) {
        b.insertAll(
          _db.cachedActivityItems,
          [
            for (final i in items)
              CachedActivityItemsCompanion.insert(
                id: i.id,
                kind: i.kind.name,
                title: i.title,
                body: Value(i.body),
                courseId: Value(i.courseId),
                createdAt: i.createdAt,
                url: Value(i.url),
                images: Value(i.images.join('\n')),
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );
      });
      await _db.into(_db.keyValues).insertOnConflictUpdate(
            KeyValuesCompanion.insert(
              settingKey: _kLastSynced,
              settingValue: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    });
  }

  @override
  void dispose() {}
}

/// One odd item from Canvas (anyone can write a discussion post or send a
/// message) must not stop the whole feed from updating: it is left out.
T? _orSkip<T>(T? Function() parse) {
  try {
    return parse();
  } catch (_) {
    return null;
  }
}
