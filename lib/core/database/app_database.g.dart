// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedCoursesTable extends CachedCourses
    with TableInfo<$CachedCoursesTable, CachedCourse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, code];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_courses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCourse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCourse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCourse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
    );
  }

  @override
  $CachedCoursesTable createAlias(String alias) {
    return $CachedCoursesTable(attachedDatabase, alias);
  }
}

class CachedCourse extends DataClass implements Insertable<CachedCourse> {
  final int id;
  final String name;
  final String code;
  const CachedCourse({
    required this.id,
    required this.name,
    required this.code,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['code'] = Variable<String>(code);
    return map;
  }

  CachedCoursesCompanion toCompanion(bool nullToAbsent) {
    return CachedCoursesCompanion(
      id: Value(id),
      name: Value(name),
      code: Value(code),
    );
  }

  factory CachedCourse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCourse(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      code: serializer.fromJson<String>(json['code']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'code': serializer.toJson<String>(code),
    };
  }

  CachedCourse copyWith({int? id, String? name, String? code}) => CachedCourse(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
  );
  CachedCourse copyWithCompanion(CachedCoursesCompanion data) {
    return CachedCourse(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      code: data.code.present ? data.code.value : this.code,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCourse(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, code);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCourse &&
          other.id == this.id &&
          other.name == this.name &&
          other.code == this.code);
}

class CachedCoursesCompanion extends UpdateCompanion<CachedCourse> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> code;
  const CachedCoursesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.code = const Value.absent(),
  });
  CachedCoursesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.code = const Value.absent(),
  }) : name = Value(name);
  static Insertable<CachedCourse> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? code,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
    });
  }

  CachedCoursesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? code,
  }) {
    return CachedCoursesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCoursesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('code: $code')
          ..write(')'))
        .toString();
  }
}

class $CachedAssignmentsTable extends CachedAssignments
    with TableInfo<$CachedAssignmentsTable, CachedAssignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<double> points = GeneratedColumn<double>(
    'points',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _submittedMeta = const VerificationMeta(
    'submitted',
  );
  @override
  late final GeneratedColumn<bool> submitted = GeneratedColumn<bool>(
    'submitted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("submitted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    courseId,
    title,
    dueAt,
    points,
    submitted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('points')) {
      context.handle(
        _pointsMeta,
        points.isAcceptableOrUnknown(data['points']!, _pointsMeta),
      );
    }
    if (data.containsKey('submitted')) {
      context.handle(
        _submittedMeta,
        submitted.isAcceptableOrUnknown(data['submitted']!, _submittedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedAssignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAssignment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      points: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}points'],
      ),
      submitted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}submitted'],
      )!,
    );
  }

  @override
  $CachedAssignmentsTable createAlias(String alias) {
    return $CachedAssignmentsTable(attachedDatabase, alias);
  }
}

class CachedAssignment extends DataClass
    implements Insertable<CachedAssignment> {
  final int id;
  final int courseId;
  final String title;
  final DateTime? dueAt;
  final double? points;
  final bool submitted;
  const CachedAssignment({
    required this.id,
    required this.courseId,
    required this.title,
    this.dueAt,
    this.points,
    required this.submitted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['course_id'] = Variable<int>(courseId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    if (!nullToAbsent || points != null) {
      map['points'] = Variable<double>(points);
    }
    map['submitted'] = Variable<bool>(submitted);
    return map;
  }

  CachedAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return CachedAssignmentsCompanion(
      id: Value(id),
      courseId: Value(courseId),
      title: Value(title),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      points: points == null && nullToAbsent
          ? const Value.absent()
          : Value(points),
      submitted: Value(submitted),
    );
  }

  factory CachedAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAssignment(
      id: serializer.fromJson<int>(json['id']),
      courseId: serializer.fromJson<int>(json['courseId']),
      title: serializer.fromJson<String>(json['title']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      points: serializer.fromJson<double?>(json['points']),
      submitted: serializer.fromJson<bool>(json['submitted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'courseId': serializer.toJson<int>(courseId),
      'title': serializer.toJson<String>(title),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'points': serializer.toJson<double?>(points),
      'submitted': serializer.toJson<bool>(submitted),
    };
  }

  CachedAssignment copyWith({
    int? id,
    int? courseId,
    String? title,
    Value<DateTime?> dueAt = const Value.absent(),
    Value<double?> points = const Value.absent(),
    bool? submitted,
  }) => CachedAssignment(
    id: id ?? this.id,
    courseId: courseId ?? this.courseId,
    title: title ?? this.title,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    points: points.present ? points.value : this.points,
    submitted: submitted ?? this.submitted,
  );
  CachedAssignment copyWithCompanion(CachedAssignmentsCompanion data) {
    return CachedAssignment(
      id: data.id.present ? data.id.value : this.id,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      title: data.title.present ? data.title.value : this.title,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      points: data.points.present ? data.points.value : this.points,
      submitted: data.submitted.present ? data.submitted.value : this.submitted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAssignment(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('title: $title, ')
          ..write('dueAt: $dueAt, ')
          ..write('points: $points, ')
          ..write('submitted: $submitted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, courseId, title, dueAt, points, submitted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAssignment &&
          other.id == this.id &&
          other.courseId == this.courseId &&
          other.title == this.title &&
          other.dueAt == this.dueAt &&
          other.points == this.points &&
          other.submitted == this.submitted);
}

class CachedAssignmentsCompanion extends UpdateCompanion<CachedAssignment> {
  final Value<int> id;
  final Value<int> courseId;
  final Value<String> title;
  final Value<DateTime?> dueAt;
  final Value<double?> points;
  final Value<bool> submitted;
  const CachedAssignmentsCompanion({
    this.id = const Value.absent(),
    this.courseId = const Value.absent(),
    this.title = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.points = const Value.absent(),
    this.submitted = const Value.absent(),
  });
  CachedAssignmentsCompanion.insert({
    this.id = const Value.absent(),
    required int courseId,
    required String title,
    this.dueAt = const Value.absent(),
    this.points = const Value.absent(),
    this.submitted = const Value.absent(),
  }) : courseId = Value(courseId),
       title = Value(title);
  static Insertable<CachedAssignment> custom({
    Expression<int>? id,
    Expression<int>? courseId,
    Expression<String>? title,
    Expression<DateTime>? dueAt,
    Expression<double>? points,
    Expression<bool>? submitted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (courseId != null) 'course_id': courseId,
      if (title != null) 'title': title,
      if (dueAt != null) 'due_at': dueAt,
      if (points != null) 'points': points,
      if (submitted != null) 'submitted': submitted,
    });
  }

  CachedAssignmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? courseId,
    Value<String>? title,
    Value<DateTime?>? dueAt,
    Value<double?>? points,
    Value<bool>? submitted,
  }) {
    return CachedAssignmentsCompanion(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      dueAt: dueAt ?? this.dueAt,
      points: points ?? this.points,
      submitted: submitted ?? this.submitted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (points.present) {
      map['points'] = Variable<double>(points.value);
    }
    if (submitted.present) {
      map['submitted'] = Variable<bool>(submitted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedAssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('courseId: $courseId, ')
          ..write('title: $title, ')
          ..write('dueAt: $dueAt, ')
          ..write('points: $points, ')
          ..write('submitted: $submitted')
          ..write(')'))
        .toString();
  }
}

class $AssignmentUserStatesTable extends AssignmentUserStates
    with TableInfo<$AssignmentUserStatesTable, AssignmentUserState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssignmentUserStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assignmentIdMeta = const VerificationMeta(
    'assignmentId',
  );
  @override
  late final GeneratedColumn<int> assignmentId = GeneratedColumn<int>(
    'assignment_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _starredMeta = const VerificationMeta(
    'starred',
  );
  @override
  late final GeneratedColumn<bool> starred = GeneratedColumn<bool>(
    'starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("starred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _doneOverrideMeta = const VerificationMeta(
    'doneOverride',
  );
  @override
  late final GeneratedColumn<bool> doneOverride = GeneratedColumn<bool>(
    'done_override',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done_override" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [assignmentId, starred, doneOverride];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assignment_user_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssignmentUserState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('assignment_id')) {
      context.handle(
        _assignmentIdMeta,
        assignmentId.isAcceptableOrUnknown(
          data['assignment_id']!,
          _assignmentIdMeta,
        ),
      );
    }
    if (data.containsKey('starred')) {
      context.handle(
        _starredMeta,
        starred.isAcceptableOrUnknown(data['starred']!, _starredMeta),
      );
    }
    if (data.containsKey('done_override')) {
      context.handle(
        _doneOverrideMeta,
        doneOverride.isAcceptableOrUnknown(
          data['done_override']!,
          _doneOverrideMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assignmentId};
  @override
  AssignmentUserState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssignmentUserState(
      assignmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}assignment_id'],
      )!,
      starred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}starred'],
      )!,
      doneOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done_override'],
      ),
    );
  }

  @override
  $AssignmentUserStatesTable createAlias(String alias) {
    return $AssignmentUserStatesTable(attachedDatabase, alias);
  }
}

class AssignmentUserState extends DataClass
    implements Insertable<AssignmentUserState> {
  final int assignmentId;
  final bool starred;

  /// null = follow Canvas; true/false = the user's manual override.
  final bool? doneOverride;
  const AssignmentUserState({
    required this.assignmentId,
    required this.starred,
    this.doneOverride,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['assignment_id'] = Variable<int>(assignmentId);
    map['starred'] = Variable<bool>(starred);
    if (!nullToAbsent || doneOverride != null) {
      map['done_override'] = Variable<bool>(doneOverride);
    }
    return map;
  }

  AssignmentUserStatesCompanion toCompanion(bool nullToAbsent) {
    return AssignmentUserStatesCompanion(
      assignmentId: Value(assignmentId),
      starred: Value(starred),
      doneOverride: doneOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(doneOverride),
    );
  }

  factory AssignmentUserState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssignmentUserState(
      assignmentId: serializer.fromJson<int>(json['assignmentId']),
      starred: serializer.fromJson<bool>(json['starred']),
      doneOverride: serializer.fromJson<bool?>(json['doneOverride']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assignmentId': serializer.toJson<int>(assignmentId),
      'starred': serializer.toJson<bool>(starred),
      'doneOverride': serializer.toJson<bool?>(doneOverride),
    };
  }

  AssignmentUserState copyWith({
    int? assignmentId,
    bool? starred,
    Value<bool?> doneOverride = const Value.absent(),
  }) => AssignmentUserState(
    assignmentId: assignmentId ?? this.assignmentId,
    starred: starred ?? this.starred,
    doneOverride: doneOverride.present ? doneOverride.value : this.doneOverride,
  );
  AssignmentUserState copyWithCompanion(AssignmentUserStatesCompanion data) {
    return AssignmentUserState(
      assignmentId: data.assignmentId.present
          ? data.assignmentId.value
          : this.assignmentId,
      starred: data.starred.present ? data.starred.value : this.starred,
      doneOverride: data.doneOverride.present
          ? data.doneOverride.value
          : this.doneOverride,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssignmentUserState(')
          ..write('assignmentId: $assignmentId, ')
          ..write('starred: $starred, ')
          ..write('doneOverride: $doneOverride')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assignmentId, starred, doneOverride);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssignmentUserState &&
          other.assignmentId == this.assignmentId &&
          other.starred == this.starred &&
          other.doneOverride == this.doneOverride);
}

class AssignmentUserStatesCompanion
    extends UpdateCompanion<AssignmentUserState> {
  final Value<int> assignmentId;
  final Value<bool> starred;
  final Value<bool?> doneOverride;
  const AssignmentUserStatesCompanion({
    this.assignmentId = const Value.absent(),
    this.starred = const Value.absent(),
    this.doneOverride = const Value.absent(),
  });
  AssignmentUserStatesCompanion.insert({
    this.assignmentId = const Value.absent(),
    this.starred = const Value.absent(),
    this.doneOverride = const Value.absent(),
  });
  static Insertable<AssignmentUserState> custom({
    Expression<int>? assignmentId,
    Expression<bool>? starred,
    Expression<bool>? doneOverride,
  }) {
    return RawValuesInsertable({
      if (assignmentId != null) 'assignment_id': assignmentId,
      if (starred != null) 'starred': starred,
      if (doneOverride != null) 'done_override': doneOverride,
    });
  }

  AssignmentUserStatesCompanion copyWith({
    Value<int>? assignmentId,
    Value<bool>? starred,
    Value<bool?>? doneOverride,
  }) {
    return AssignmentUserStatesCompanion(
      assignmentId: assignmentId ?? this.assignmentId,
      starred: starred ?? this.starred,
      doneOverride: doneOverride ?? this.doneOverride,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assignmentId.present) {
      map['assignment_id'] = Variable<int>(assignmentId.value);
    }
    if (starred.present) {
      map['starred'] = Variable<bool>(starred.value);
    }
    if (doneOverride.present) {
      map['done_override'] = Variable<bool>(doneOverride.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssignmentUserStatesCompanion(')
          ..write('assignmentId: $assignmentId, ')
          ..write('starred: $starred, ')
          ..write('doneOverride: $doneOverride')
          ..write(')'))
        .toString();
  }
}

class $CachedActivityItemsTable extends CachedActivityItems
    with TableInfo<$CachedActivityItemsTable, CachedActivityItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedActivityItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
    'course_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  @override
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
    'images',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    title,
    body,
    courseId,
    createdAt,
    url,
    images,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_activity_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedActivityItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    if (data.containsKey('images')) {
      context.handle(
        _imagesMeta,
        images.isAcceptableOrUnknown(data['images']!, _imagesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedActivityItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedActivityItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}course_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      ),
      images: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}images'],
      )!,
    );
  }

  @override
  $CachedActivityItemsTable createAlias(String alias) {
    return $CachedActivityItemsTable(attachedDatabase, alias);
  }
}

class CachedActivityItem extends DataClass
    implements Insertable<CachedActivityItem> {
  final String id;
  final String kind;
  final String title;
  final String body;
  final int? courseId;
  final DateTime createdAt;
  final String? url;

  /// Image references found in the text, one per line ("file:123" or "url:https://...").
  final String images;
  const CachedActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.courseId,
    required this.createdAt,
    this.url,
    required this.images,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || courseId != null) {
      map['course_id'] = Variable<int>(courseId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || url != null) {
      map['url'] = Variable<String>(url);
    }
    map['images'] = Variable<String>(images);
    return map;
  }

  CachedActivityItemsCompanion toCompanion(bool nullToAbsent) {
    return CachedActivityItemsCompanion(
      id: Value(id),
      kind: Value(kind),
      title: Value(title),
      body: Value(body),
      courseId: courseId == null && nullToAbsent
          ? const Value.absent()
          : Value(courseId),
      createdAt: Value(createdAt),
      url: url == null && nullToAbsent ? const Value.absent() : Value(url),
      images: Value(images),
    );
  }

  factory CachedActivityItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedActivityItem(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      courseId: serializer.fromJson<int?>(json['courseId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      url: serializer.fromJson<String?>(json['url']),
      images: serializer.fromJson<String>(json['images']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'courseId': serializer.toJson<int?>(courseId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'url': serializer.toJson<String?>(url),
      'images': serializer.toJson<String>(images),
    };
  }

  CachedActivityItem copyWith({
    String? id,
    String? kind,
    String? title,
    String? body,
    Value<int?> courseId = const Value.absent(),
    DateTime? createdAt,
    Value<String?> url = const Value.absent(),
    String? images,
  }) => CachedActivityItem(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    body: body ?? this.body,
    courseId: courseId.present ? courseId.value : this.courseId,
    createdAt: createdAt ?? this.createdAt,
    url: url.present ? url.value : this.url,
    images: images ?? this.images,
  );
  CachedActivityItem copyWithCompanion(CachedActivityItemsCompanion data) {
    return CachedActivityItem(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      url: data.url.present ? data.url.value : this.url,
      images: data.images.present ? data.images.value : this.images,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedActivityItem(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('courseId: $courseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('url: $url, ')
          ..write('images: $images')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, title, body, courseId, createdAt, url, images);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedActivityItem &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.body == this.body &&
          other.courseId == this.courseId &&
          other.createdAt == this.createdAt &&
          other.url == this.url &&
          other.images == this.images);
}

class CachedActivityItemsCompanion extends UpdateCompanion<CachedActivityItem> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> title;
  final Value<String> body;
  final Value<int?> courseId;
  final Value<DateTime> createdAt;
  final Value<String?> url;
  final Value<String> images;
  final Value<int> rowid;
  const CachedActivityItemsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.courseId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.url = const Value.absent(),
    this.images = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedActivityItemsCompanion.insert({
    required String id,
    required String kind,
    required String title,
    this.body = const Value.absent(),
    this.courseId = const Value.absent(),
    required DateTime createdAt,
    this.url = const Value.absent(),
    this.images = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<CachedActivityItem> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? courseId,
    Expression<DateTime>? createdAt,
    Expression<String>? url,
    Expression<String>? images,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (courseId != null) 'course_id': courseId,
      if (createdAt != null) 'created_at': createdAt,
      if (url != null) 'url': url,
      if (images != null) 'images': images,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedActivityItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? title,
    Value<String>? body,
    Value<int?>? courseId,
    Value<DateTime>? createdAt,
    Value<String?>? url,
    Value<String>? images,
    Value<int>? rowid,
  }) {
    return CachedActivityItemsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      courseId: courseId ?? this.courseId,
      createdAt: createdAt ?? this.createdAt,
      url: url ?? this.url,
      images: images ?? this.images,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedActivityItemsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('courseId: $courseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('url: $url, ')
          ..write('images: $images, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _settingKeyMeta = const VerificationMeta(
    'settingKey',
  );
  @override
  late final GeneratedColumn<String> settingKey = GeneratedColumn<String>(
    'setting_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingValueMeta = const VerificationMeta(
    'settingValue',
  );
  @override
  late final GeneratedColumn<String> settingValue = GeneratedColumn<String>(
    'setting_value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [settingKey, settingValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('setting_key')) {
      context.handle(
        _settingKeyMeta,
        settingKey.isAcceptableOrUnknown(data['setting_key']!, _settingKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_settingKeyMeta);
    }
    if (data.containsKey('setting_value')) {
      context.handle(
        _settingValueMeta,
        settingValue.isAcceptableOrUnknown(
          data['setting_value']!,
          _settingValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_settingValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {settingKey};
  @override
  KeyValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValue(
      settingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_key'],
      )!,
      settingValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValue extends DataClass implements Insertable<KeyValue> {
  final String settingKey;
  final String settingValue;
  const KeyValue({required this.settingKey, required this.settingValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['setting_key'] = Variable<String>(settingKey);
    map['setting_value'] = Variable<String>(settingValue);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(
      settingKey: Value(settingKey),
      settingValue: Value(settingValue),
    );
  }

  factory KeyValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValue(
      settingKey: serializer.fromJson<String>(json['settingKey']),
      settingValue: serializer.fromJson<String>(json['settingValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'settingKey': serializer.toJson<String>(settingKey),
      'settingValue': serializer.toJson<String>(settingValue),
    };
  }

  KeyValue copyWith({String? settingKey, String? settingValue}) => KeyValue(
    settingKey: settingKey ?? this.settingKey,
    settingValue: settingValue ?? this.settingValue,
  );
  KeyValue copyWithCompanion(KeyValuesCompanion data) {
    return KeyValue(
      settingKey: data.settingKey.present
          ? data.settingKey.value
          : this.settingKey,
      settingValue: data.settingValue.present
          ? data.settingValue.value
          : this.settingValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValue(')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(settingKey, settingValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValue &&
          other.settingKey == this.settingKey &&
          other.settingValue == this.settingValue);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValue> {
  final Value<String> settingKey;
  final Value<String> settingValue;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.settingKey = const Value.absent(),
    this.settingValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String settingKey,
    required String settingValue,
    this.rowid = const Value.absent(),
  }) : settingKey = Value(settingKey),
       settingValue = Value(settingValue);
  static Insertable<KeyValue> custom({
    Expression<String>? settingKey,
    Expression<String>? settingValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (settingKey != null) 'setting_key': settingKey,
      if (settingValue != null) 'setting_value': settingValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? settingKey,
    Value<String>? settingValue,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (settingKey.present) {
      map['setting_key'] = Variable<String>(settingKey.value);
    }
    if (settingValue.present) {
      map['setting_value'] = Variable<String>(settingValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedCoursesTable cachedCourses = $CachedCoursesTable(this);
  late final $CachedAssignmentsTable cachedAssignments =
      $CachedAssignmentsTable(this);
  late final $AssignmentUserStatesTable assignmentUserStates =
      $AssignmentUserStatesTable(this);
  late final $CachedActivityItemsTable cachedActivityItems =
      $CachedActivityItemsTable(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedCourses,
    cachedAssignments,
    assignmentUserStates,
    cachedActivityItems,
    keyValues,
  ];
}

typedef $$CachedCoursesTableCreateCompanionBuilder =
    CachedCoursesCompanion Function({
      Value<int> id,
      required String name,
      Value<String> code,
    });
typedef $$CachedCoursesTableUpdateCompanionBuilder =
    CachedCoursesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> code,
    });

class $$CachedCoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCoursesTable> {
  $$CachedCoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCoursesTable> {
  $$CachedCoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCoursesTable> {
  $$CachedCoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);
}

class $$CachedCoursesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCoursesTable,
          CachedCourse,
          $$CachedCoursesTableFilterComposer,
          $$CachedCoursesTableOrderingComposer,
          $$CachedCoursesTableAnnotationComposer,
          $$CachedCoursesTableCreateCompanionBuilder,
          $$CachedCoursesTableUpdateCompanionBuilder,
          (
            CachedCourse,
            BaseReferences<_$AppDatabase, $CachedCoursesTable, CachedCourse>,
          ),
          CachedCourse,
          PrefetchHooks Function()
        > {
  $$CachedCoursesTableTableManager(_$AppDatabase db, $CachedCoursesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> code = const Value.absent(),
          }) => CachedCoursesCompanion(id: id, name: name, code: code),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> code = const Value.absent(),
          }) => CachedCoursesCompanion.insert(id: id, name: name, code: code),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedCoursesTable, CachedCourse>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedCoursesTable,
                    CachedCourse
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCoursesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCoursesTable,
      CachedCourse,
      $$CachedCoursesTableFilterComposer,
      $$CachedCoursesTableOrderingComposer,
      $$CachedCoursesTableAnnotationComposer,
      $$CachedCoursesTableCreateCompanionBuilder,
      $$CachedCoursesTableUpdateCompanionBuilder,
      (
        CachedCourse,
        BaseReferences<_$AppDatabase, $CachedCoursesTable, CachedCourse>,
      ),
      CachedCourse,
      PrefetchHooks Function()
    >;
typedef $$CachedAssignmentsTableCreateCompanionBuilder =
    CachedAssignmentsCompanion Function({
      Value<int> id,
      required int courseId,
      required String title,
      Value<DateTime?> dueAt,
      Value<double?> points,
      Value<bool> submitted,
    });
typedef $$CachedAssignmentsTableUpdateCompanionBuilder =
    CachedAssignmentsCompanion Function({
      Value<int> id,
      Value<int> courseId,
      Value<String> title,
      Value<DateTime?> dueAt,
      Value<double?> points,
      Value<bool> submitted,
    });

class $$CachedAssignmentsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedAssignmentsTable> {
  $$CachedAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedAssignmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedAssignmentsTable> {
  $$CachedAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get points => $composableBuilder(
    column: $table.points,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get submitted => $composableBuilder(
    column: $table.submitted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedAssignmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedAssignmentsTable> {
  $$CachedAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<double> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<bool> get submitted =>
      $composableBuilder(column: $table.submitted, builder: (column) => column);
}

class $$CachedAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedAssignmentsTable,
          CachedAssignment,
          $$CachedAssignmentsTableFilterComposer,
          $$CachedAssignmentsTableOrderingComposer,
          $$CachedAssignmentsTableAnnotationComposer,
          $$CachedAssignmentsTableCreateCompanionBuilder,
          $$CachedAssignmentsTableUpdateCompanionBuilder,
          (
            CachedAssignment,
            BaseReferences<
              _$AppDatabase,
              $CachedAssignmentsTable,
              CachedAssignment
            >,
          ),
          CachedAssignment,
          PrefetchHooks Function()
        > {
  $$CachedAssignmentsTableTableManager(
    _$AppDatabase db,
    $CachedAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAssignmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAssignmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> courseId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<double?> points = const Value.absent(),
                Value<bool> submitted = const Value.absent(),
              }) => CachedAssignmentsCompanion(
                id: id,
                courseId: courseId,
                title: title,
                dueAt: dueAt,
                points: points,
                submitted: submitted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int courseId,
                required String title,
                Value<DateTime?> dueAt = const Value.absent(),
                Value<double?> points = const Value.absent(),
                Value<bool> submitted = const Value.absent(),
              }) => CachedAssignmentsCompanion.insert(
                id: id,
                courseId: courseId,
                title: title,
                dueAt: dueAt,
                points: points,
                submitted: submitted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedAssignmentsTable, CachedAssignment>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedAssignmentsTable,
                    CachedAssignment
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedAssignmentsTable,
      CachedAssignment,
      $$CachedAssignmentsTableFilterComposer,
      $$CachedAssignmentsTableOrderingComposer,
      $$CachedAssignmentsTableAnnotationComposer,
      $$CachedAssignmentsTableCreateCompanionBuilder,
      $$CachedAssignmentsTableUpdateCompanionBuilder,
      (
        CachedAssignment,
        BaseReferences<
          _$AppDatabase,
          $CachedAssignmentsTable,
          CachedAssignment
        >,
      ),
      CachedAssignment,
      PrefetchHooks Function()
    >;
typedef $$AssignmentUserStatesTableCreateCompanionBuilder =
    AssignmentUserStatesCompanion Function({
      Value<int> assignmentId,
      Value<bool> starred,
      Value<bool?> doneOverride,
    });
typedef $$AssignmentUserStatesTableUpdateCompanionBuilder =
    AssignmentUserStatesCompanion Function({
      Value<int> assignmentId,
      Value<bool> starred,
      Value<bool?> doneOverride,
    });

class $$AssignmentUserStatesTableFilterComposer
    extends Composer<_$AppDatabase, $AssignmentUserStatesTable> {
  $$AssignmentUserStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get assignmentId => $composableBuilder(
    column: $table.assignmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get doneOverride => $composableBuilder(
    column: $table.doneOverride,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AssignmentUserStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $AssignmentUserStatesTable> {
  $$AssignmentUserStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get assignmentId => $composableBuilder(
    column: $table.assignmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get starred => $composableBuilder(
    column: $table.starred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get doneOverride => $composableBuilder(
    column: $table.doneOverride,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssignmentUserStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssignmentUserStatesTable> {
  $$AssignmentUserStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get assignmentId => $composableBuilder(
    column: $table.assignmentId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get starred =>
      $composableBuilder(column: $table.starred, builder: (column) => column);

  GeneratedColumn<bool> get doneOverride => $composableBuilder(
    column: $table.doneOverride,
    builder: (column) => column,
  );
}

class $$AssignmentUserStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssignmentUserStatesTable,
          AssignmentUserState,
          $$AssignmentUserStatesTableFilterComposer,
          $$AssignmentUserStatesTableOrderingComposer,
          $$AssignmentUserStatesTableAnnotationComposer,
          $$AssignmentUserStatesTableCreateCompanionBuilder,
          $$AssignmentUserStatesTableUpdateCompanionBuilder,
          (
            AssignmentUserState,
            BaseReferences<
              _$AppDatabase,
              $AssignmentUserStatesTable,
              AssignmentUserState
            >,
          ),
          AssignmentUserState,
          PrefetchHooks Function()
        > {
  $$AssignmentUserStatesTableTableManager(
    _$AppDatabase db,
    $AssignmentUserStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssignmentUserStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssignmentUserStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AssignmentUserStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> assignmentId = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool?> doneOverride = const Value.absent(),
              }) => AssignmentUserStatesCompanion(
                assignmentId: assignmentId,
                starred: starred,
                doneOverride: doneOverride,
              ),
          createCompanionCallback:
              ({
                Value<int> assignmentId = const Value.absent(),
                Value<bool> starred = const Value.absent(),
                Value<bool?> doneOverride = const Value.absent(),
              }) => AssignmentUserStatesCompanion.insert(
                assignmentId: assignmentId,
                starred: starred,
                doneOverride: doneOverride,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AssignmentUserStatesTable, AssignmentUserState>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $AssignmentUserStatesTable,
                    AssignmentUserState
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AssignmentUserStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssignmentUserStatesTable,
      AssignmentUserState,
      $$AssignmentUserStatesTableFilterComposer,
      $$AssignmentUserStatesTableOrderingComposer,
      $$AssignmentUserStatesTableAnnotationComposer,
      $$AssignmentUserStatesTableCreateCompanionBuilder,
      $$AssignmentUserStatesTableUpdateCompanionBuilder,
      (
        AssignmentUserState,
        BaseReferences<
          _$AppDatabase,
          $AssignmentUserStatesTable,
          AssignmentUserState
        >,
      ),
      AssignmentUserState,
      PrefetchHooks Function()
    >;
typedef $$CachedActivityItemsTableCreateCompanionBuilder =
    CachedActivityItemsCompanion Function({
      required String id,
      required String kind,
      required String title,
      Value<String> body,
      Value<int?> courseId,
      required DateTime createdAt,
      Value<String?> url,
      Value<String> images,
      Value<int> rowid,
    });
typedef $$CachedActivityItemsTableUpdateCompanionBuilder =
    CachedActivityItemsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> title,
      Value<String> body,
      Value<int?> courseId,
      Value<DateTime> createdAt,
      Value<String?> url,
      Value<String> images,
      Value<int> rowid,
    });

class $$CachedActivityItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedActivityItemsTable> {
  $$CachedActivityItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get images => $composableBuilder(
    column: $table.images,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedActivityItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedActivityItemsTable> {
  $$CachedActivityItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get images => $composableBuilder(
    column: $table.images,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedActivityItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedActivityItemsTable> {
  $$CachedActivityItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<int> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => column);
}

class $$CachedActivityItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedActivityItemsTable,
          CachedActivityItem,
          $$CachedActivityItemsTableFilterComposer,
          $$CachedActivityItemsTableOrderingComposer,
          $$CachedActivityItemsTableAnnotationComposer,
          $$CachedActivityItemsTableCreateCompanionBuilder,
          $$CachedActivityItemsTableUpdateCompanionBuilder,
          (
            CachedActivityItem,
            BaseReferences<
              _$AppDatabase,
              $CachedActivityItemsTable,
              CachedActivityItem
            >,
          ),
          CachedActivityItem,
          PrefetchHooks Function()
        > {
  $$CachedActivityItemsTableTableManager(
    _$AppDatabase db,
    $CachedActivityItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedActivityItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedActivityItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedActivityItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int?> courseId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> url = const Value.absent(),
                Value<String> images = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedActivityItemsCompanion(
                id: id,
                kind: kind,
                title: title,
                body: body,
                courseId: courseId,
                createdAt: createdAt,
                url: url,
                images: images,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String title,
                Value<String> body = const Value.absent(),
                Value<int?> courseId = const Value.absent(),
                required DateTime createdAt,
                Value<String?> url = const Value.absent(),
                Value<String> images = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedActivityItemsCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                body: body,
                courseId: courseId,
                createdAt: createdAt,
                url: url,
                images: images,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedActivityItemsTable, CachedActivityItem>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedActivityItemsTable,
                    CachedActivityItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedActivityItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedActivityItemsTable,
      CachedActivityItem,
      $$CachedActivityItemsTableFilterComposer,
      $$CachedActivityItemsTableOrderingComposer,
      $$CachedActivityItemsTableAnnotationComposer,
      $$CachedActivityItemsTableCreateCompanionBuilder,
      $$CachedActivityItemsTableUpdateCompanionBuilder,
      (
        CachedActivityItem,
        BaseReferences<
          _$AppDatabase,
          $CachedActivityItemsTable,
          CachedActivityItem
        >,
      ),
      CachedActivityItem,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder = KeyValuesCompanion Function({
  required String settingKey,
  required String settingValue,
  Value<int> rowid,
});
typedef $$KeyValuesTableUpdateCompanionBuilder = KeyValuesCompanion Function({
  Value<String> settingKey,
  Value<String> settingValue,
  Value<int> rowid,
});

class $$KeyValuesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => column,
  );
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValuesTable,
          KeyValue,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
          KeyValue,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$AppDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> settingKey = const Value.absent(),
                Value<String> settingValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion(
                settingKey: settingKey,
                settingValue: settingValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String settingKey,
                required String settingValue,
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion.insert(
                settingKey: settingKey,
                settingValue: settingValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValue>(table),
                  BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValuesTable,
      KeyValue,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
      KeyValue,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedCoursesTableTableManager get cachedCourses =>
      $$CachedCoursesTableTableManager(_db, _db.cachedCourses);
  $$CachedAssignmentsTableTableManager get cachedAssignments =>
      $$CachedAssignmentsTableTableManager(_db, _db.cachedAssignments);
  $$AssignmentUserStatesTableTableManager get assignmentUserStates =>
      $$AssignmentUserStatesTableTableManager(_db, _db.assignmentUserStates);
  $$CachedActivityItemsTableTableManager get cachedActivityItems =>
      $$CachedActivityItemsTableTableManager(_db, _db.cachedActivityItems);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
}
