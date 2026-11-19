import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../storage/app_dir.dart';

part 'app_database.g.dart';

/// What Canvas last told us.
class CachedCourses extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get code => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedAssignments extends Table {
  IntColumn get id => integer()();
  IntColumn get courseId => integer()();
  TextColumn get title => text()();
  DateTimeColumn get dueAt => dateTime().nullable()();
  RealColumn get points => real().nullable()();
  BoolColumn get submitted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// What the user decided locally. Kept apart from the Canvas data so a
/// refresh can never overwrite it.
class AssignmentUserStates extends Table {
  IntColumn get assignmentId => integer()();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();

  /// null = follow Canvas; true/false = the user's manual override.
  BoolColumn get doneOverride => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {assignmentId};
}

/// Mirror of Canvas's activity stream (announcements, grades, replies...).
class CachedActivityItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  IntColumn get courseId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get url => text().nullable()();

  /// Image references found in the text, one per line ("file:123" or "url:https://...").
  TextColumn get images => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

class KeyValues extends Table {
  TextColumn get settingKey => text()();
  TextColumn get settingValue => text()();

  @override
  Set<Column> get primaryKey => {settingKey};
}

@DriftDatabase(tables: [CachedCourses, CachedAssignments, AssignmentUserStates, CachedActivityItems, KeyValues])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(cachedActivityItems);
          if (from == 2) await m.addColumn(cachedActivityItems, cachedActivityItems.images);
        },
      );

  /// One database file per Canvas site, so accounts never mix.
  static AppDatabase forAccount(String baseUrl) {
    final host = Uri.parse(baseUrl).host.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final dir = Directory(appDataPath())..createSync(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}cache_$host.sqlite');
    return AppDatabase(NativeDatabase.createInBackground(file));
  }
}
