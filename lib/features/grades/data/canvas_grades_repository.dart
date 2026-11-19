import '../../../core/database/app_database.dart';
import '../../../core/network/canvas_client.dart';
import '../domain/grades.dart';
import '../domain/grades_repository.dart';

class CanvasGradesRepository implements GradesRepository {
  CanvasGradesRepository(this._client, this._db);
  final CanvasClient _client;
  final AppDatabase _db;

  static const _key = 'courseGrades';

  @override
  Future<List<CourseGrade>> cached() async {
    final row = await (_db.select(_db.keyValues)..where((t) => t.settingKey.equals(_key))).getSingleOrNull();
    return row == null ? const [] : decodeGrades(row.settingValue);
  }

  @override
  Future<List<CourseGrade>> refresh() async {
    final grades = parseEnrollmentGrades(await _client.fetchEnrollmentsJson());
    await _db.into(_db.keyValues).insertOnConflictUpdate(
          KeyValuesCompanion.insert(settingKey: _key, settingValue: encodeGrades(grades)),
        );
    return grades;
  }

  @override
  Future<CourseWork> work(int courseId) async {
    final results = await Future.wait([
      _client.fetchAssignmentsJson(courseId, withStats: true),
      // Category names are a nicety: if this fails the work still shows.
      _client.fetchAssignmentGroupsJson(courseId).catchError((Object _) => <Map<String, dynamic>>[]),
    ]);
    return CourseWork(items: parseWorkItems(results[0]), groups: parseGroups(results[1]));
  }
}
