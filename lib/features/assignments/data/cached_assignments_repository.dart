import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/canvas_client.dart';
import '../../../core/network/canvas_exception.dart';
import '../../courses/domain/course.dart';
import '../domain/assignment.dart';
import '../domain/assignments_repository.dart';
import 'canvas_mappers.dart';

/// UI reads only from the local database; refresh() copies Canvas into it.
/// Stars and manual "done" live in their own table and survive refreshes.
class CachedAssignmentsRepository implements AssignmentsRepository {
  CachedAssignmentsRepository(this._client, this._db);

  final CanvasClient _client;
  final AppDatabase _db; // owned by the session, closed elsewhere

  static const _kLastSynced = 'lastSyncedAt';

  @override
  Stream<List<Course>> watchCourses() {
    return _db.select(_db.cachedCourses).watch().map(
          (rows) => [for (final r in rows) Course(id: r.id, name: r.name, code: r.code)],
        );
  }

  @override
  Stream<List<Assignment>> watch() {
    final query = _db.select(_db.cachedAssignments).join([
      leftOuterJoin(
        _db.assignmentUserStates,
        _db.assignmentUserStates.assignmentId.equalsExp(_db.cachedAssignments.id),
      ),
    ]);
    return query.watch().map(
          (rows) => [
            for (final r in rows)
              _toDomain(
                r.readTable(_db.cachedAssignments),
                r.readTableOrNull(_db.assignmentUserStates),
              ),
          ],
        );
  }

  Assignment _toDomain(CachedAssignment row, AssignmentUserState? state) {
    return Assignment(
      id: row.id,
      courseId: row.courseId,
      title: row.title,
      dueAt: row.dueAt,
      points: row.points,
      done: state?.doneOverride ?? row.submitted,
      starred: state?.starred ?? false,
    );
  }

  @override
  Future<DateTime?> lastSyncedAt() async {
    final row = await (_db.select(_db.keyValues)..where((t) => t.settingKey.equals(_kLastSynced)))
        .getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.settingValue)?.toLocal();
  }

  Future<List<Assignment>?> _loadCourse(Course course, void Function(CanvasException) onError) async {
    try {
      final json = await _client.fetchAssignmentsJson(course.id);
      return [for (final j in json) ?parseAssignment(j, courseId: course.id)];
    } on CanvasException catch (e) {
      onError(e);
      return null;
    }
  }

  Future<void> _upsert(List<Course> courses, List<Assignment> items) {
    return _db.batch((b) {
      b.insertAllOnConflictUpdate(_db.cachedCourses, [
        for (final c in courses)
          CachedCoursesCompanion.insert(id: Value(c.id), name: c.name, code: Value(c.code)),
      ]);
      b.insertAllOnConflictUpdate(_db.cachedAssignments, [
        for (final a in items)
          CachedAssignmentsCompanion.insert(
            id: Value(a.id),
            courseId: a.courseId,
            title: a.title,
            dueAt: Value(a.dueAt),
            points: Value(a.points),
            submitted: Value(a.done),
          ),
      ]);
    });
  }

  @override
  Future<void> refresh() async {
    final courseJson = await _client.fetchCoursesJson();
    final courses = [for (final j in courseJson) ?parseCourse(j)];

    final fetched = <Assignment>[];
    final loadedCourseIds = <int>[];
    var failures = 0;
    CanvasException? firstError;
    void onError(CanvasException e) {
      failures++;
      firstError ??= e;
    }

    // Show the courses straight away, then each batch of assignments as soon
    // as it arrives, so the list fills in while the rest is still loading.
    await _upsert(courses, const []);
    // Six courses at a time stays well inside Canvas's rate limit.
    for (var i = 0; i < courses.length; i += 6) {
      final chunk = courses.skip(i).take(6).toList();
      final results = await Future.wait(chunk.map((c) => _loadCourse(c, onError)));
      final got = <Assignment>[];
      for (var k = 0; k < chunk.length; k++) {
        final r = results[k];
        if (r != null) {
          got.addAll(r);
          loadedCourseIds.add(chunk[k].id);
        }
      }
      fetched.addAll(got);
      await _upsert(const [], got);
    }
    if (courses.isNotEmpty && failures == courses.length) {
      throw firstError ??
          const CanvasException(CanvasErrorKind.unexpected, 'Could not load assignments.');
    }

    final courseIds = [for (final c in courses) c.id];
    final fetchedIds = [for (final a in fetched) a.id];

    // Everything fetched is already saved (batch by batch above); what is
    // left is dropping what Canvas no longer reports, in one transaction so
    // the list updates once.
    await _db.transaction(() async {
      // Drop what Canvas no longer reports. Courses that failed to load keep
      // their previously cached assignments.
      await (_db.delete(_db.cachedCourses)..where((t) => t.id.isNotIn(courseIds))).go();
      await (_db.delete(_db.cachedAssignments)
            ..where(
              (t) =>
                  t.courseId.isNotIn(courseIds) |
                  (t.courseId.isIn(loadedCourseIds) & t.id.isNotIn(fetchedIds)),
            ))
          .go();
      await _db.into(_db.keyValues).insertOnConflictUpdate(
            KeyValuesCompanion.insert(
              settingKey: _kLastSynced,
              settingValue: DateTime.now().toUtc().toIso8601String(),
            ),
          );
    });
  }

  @override
  Future<void> setStarred(int id, bool value) async {
    await _db.into(_db.assignmentUserStates).insert(
          AssignmentUserStatesCompanion.insert(assignmentId: Value(id), starred: Value(value)),
          onConflict: DoUpdate((old) => AssignmentUserStatesCompanion(starred: Value(value))),
        );
  }

  @override
  Future<void> setDone(int id, bool value) async {
    final row = await (_db.select(_db.cachedAssignments)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    // If the choice matches what Canvas says, just follow Canvas.
    final override = (row != null && row.submitted == value) ? null : value;
    await _db.into(_db.assignmentUserStates).insert(
          AssignmentUserStatesCompanion.insert(
            assignmentId: Value(id),
            doneOverride: Value(override),
          ),
          onConflict: DoUpdate((old) => AssignmentUserStatesCompanion(doneOverride: Value(override))),
        );
  }

  @override
  void dispose() {}
}
