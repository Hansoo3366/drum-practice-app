// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    parentId,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final String id;
  final String name;

  /// ARGB color value for folder chips / accents.
  final int color;
  final String? parentId;
  final int sortOrder;
  final DateTime createdAt;
  const Folder({
    required this.id,
    required this.name,
    required this.color,
    this.parentId,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'parentId': serializer.toJson<String?>(parentId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Folder copyWith({
    String? id,
    String? name,
    int? color,
    Value<String?> parentId = const Value.absent(),
    int? sortOrder,
    DateTime? createdAt,
  }) => Folder(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    parentId: parentId.present ? parentId.value : this.parentId,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, color, parentId, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.parentId == this.parentId &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<String?> parentId;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String name,
    required int color,
    this.parentId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       color = Value(color),
       createdAt = Value(createdAt);
  static Insertable<Folder> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<String>? parentId,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (parentId != null) 'parent_id': parentId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? color,
    Value<String?>? parentId,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('parentId: $parentId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LabelsTable extends Labels with TableInfo<$LabelsTable, Label> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Label> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  Label map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Label(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LabelsTable createAlias(String alias) {
    return $LabelsTable(attachedDatabase, alias);
  }
}

class Label extends DataClass implements Insertable<Label> {
  final String id;

  /// Normalized hashtag body (no leading `#`, lowercased).
  final String name;
  final DateTime createdAt;
  const Label({required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LabelsCompanion toCompanion(bool nullToAbsent) {
    return LabelsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory Label.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Label(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Label copyWith({String? id, String? name, DateTime? createdAt}) => Label(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
  );
  Label copyWithCompanion(LabelsCompanion data) {
    return Label(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Label(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Label &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class LabelsCompanion extends UpdateCompanion<Label> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LabelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LabelsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Label> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LabelsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LabelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LabelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SongsTable extends Songs with TableInfo<$SongsTable, Song> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultTempoMeta = const VerificationMeta(
    'defaultTempo',
  );
  @override
  late final GeneratedColumn<int> defaultTempo = GeneratedColumn<int>(
    'default_tempo',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetBpmMeta = const VerificationMeta(
    'targetBpm',
  );
  @override
  late final GeneratedColumn<int> targetBpm = GeneratedColumn<int>(
    'target_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreTypeMeta = const VerificationMeta(
    'scoreType',
  );
  @override
  late final GeneratedColumn<String> scoreType = GeneratedColumn<String>(
    'score_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pdf'),
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceProviderMeta = const VerificationMeta(
    'sourceProvider',
  );
  @override
  late final GeneratedColumn<String> sourceProvider = GeneratedColumn<String>(
    'source_provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _remoteUriMeta = const VerificationMeta(
    'remoteUri',
  );
  @override
  late final GeneratedColumn<String> remoteUri = GeneratedColumn<String>(
    'remote_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteModifiedAtMeta = const VerificationMeta(
    'remoteModifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> remoteModifiedAt =
      GeneratedColumn<DateTime>(
        'remote_modified_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _remoteSizeMeta = const VerificationMeta(
    'remoteSize',
  );
  @override
  late final GeneratedColumn<int> remoteSize = GeneratedColumn<int>(
    'remote_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offlineAvailableMeta = const VerificationMeta(
    'offlineAvailable',
  );
  @override
  late final GeneratedColumn<bool> offlineAvailable = GeneratedColumn<bool>(
    'offline_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("offline_available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioNameMeta = const VerificationMeta(
    'audioName',
  );
  @override
  late final GeneratedColumn<String> audioName = GeneratedColumn<String>(
    'audio_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE SET NULL',
    ),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    artist,
    defaultTempo,
    targetBpm,
    scoreType,
    sourcePath,
    sourceProvider,
    remoteUri,
    remoteModifiedAt,
    remoteSize,
    syncStatus,
    offlineAvailable,
    isFavorite,
    note,
    audioPath,
    audioName,
    folderId,
    createdAt,
    updatedAt,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Song> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('default_tempo')) {
      context.handle(
        _defaultTempoMeta,
        defaultTempo.isAcceptableOrUnknown(
          data['default_tempo']!,
          _defaultTempoMeta,
        ),
      );
    }
    if (data.containsKey('target_bpm')) {
      context.handle(
        _targetBpmMeta,
        targetBpm.isAcceptableOrUnknown(data['target_bpm']!, _targetBpmMeta),
      );
    }
    if (data.containsKey('score_type')) {
      context.handle(
        _scoreTypeMeta,
        scoreType.isAcceptableOrUnknown(data['score_type']!, _scoreTypeMeta),
      );
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('source_provider')) {
      context.handle(
        _sourceProviderMeta,
        sourceProvider.isAcceptableOrUnknown(
          data['source_provider']!,
          _sourceProviderMeta,
        ),
      );
    }
    if (data.containsKey('remote_uri')) {
      context.handle(
        _remoteUriMeta,
        remoteUri.isAcceptableOrUnknown(data['remote_uri']!, _remoteUriMeta),
      );
    }
    if (data.containsKey('remote_modified_at')) {
      context.handle(
        _remoteModifiedAtMeta,
        remoteModifiedAt.isAcceptableOrUnknown(
          data['remote_modified_at']!,
          _remoteModifiedAtMeta,
        ),
      );
    }
    if (data.containsKey('remote_size')) {
      context.handle(
        _remoteSizeMeta,
        remoteSize.isAcceptableOrUnknown(data['remote_size']!, _remoteSizeMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('offline_available')) {
      context.handle(
        _offlineAvailableMeta,
        offlineAvailable.isAcceptableOrUnknown(
          data['offline_available']!,
          _offlineAvailableMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('audio_name')) {
      context.handle(
        _audioNameMeta,
        audioName.isAcceptableOrUnknown(data['audio_name']!, _audioNameMeta),
      );
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Song map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Song(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      defaultTempo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_tempo'],
      ),
      targetBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_bpm'],
      ),
      scoreType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}score_type'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      sourceProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_provider'],
      )!,
      remoteUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_uri'],
      ),
      remoteModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}remote_modified_at'],
      ),
      remoteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_size'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      ),
      offlineAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}offline_available'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      audioName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_name'],
      ),
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class Song extends DataClass implements Insertable<Song> {
  final String id;
  final String title;
  final String? artist;
  final int? defaultTempo;
  final int? targetBpm;
  final String scoreType;
  final String sourcePath;
  final String sourceProvider;
  final String? remoteUri;
  final DateTime? remoteModifiedAt;
  final int? remoteSize;
  final String? syncStatus;
  final bool offlineAvailable;
  final bool isFavorite;
  final String? note;
  final String? audioPath;
  final String? audioName;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;
  const Song({
    required this.id,
    required this.title,
    this.artist,
    this.defaultTempo,
    this.targetBpm,
    required this.scoreType,
    required this.sourcePath,
    required this.sourceProvider,
    this.remoteUri,
    this.remoteModifiedAt,
    this.remoteSize,
    this.syncStatus,
    required this.offlineAvailable,
    required this.isFavorite,
    this.note,
    this.audioPath,
    this.audioName,
    this.folderId,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || defaultTempo != null) {
      map['default_tempo'] = Variable<int>(defaultTempo);
    }
    if (!nullToAbsent || targetBpm != null) {
      map['target_bpm'] = Variable<int>(targetBpm);
    }
    map['score_type'] = Variable<String>(scoreType);
    map['source_path'] = Variable<String>(sourcePath);
    map['source_provider'] = Variable<String>(sourceProvider);
    if (!nullToAbsent || remoteUri != null) {
      map['remote_uri'] = Variable<String>(remoteUri);
    }
    if (!nullToAbsent || remoteModifiedAt != null) {
      map['remote_modified_at'] = Variable<DateTime>(remoteModifiedAt);
    }
    if (!nullToAbsent || remoteSize != null) {
      map['remote_size'] = Variable<int>(remoteSize);
    }
    if (!nullToAbsent || syncStatus != null) {
      map['sync_status'] = Variable<String>(syncStatus);
    }
    map['offline_available'] = Variable<bool>(offlineAvailable);
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || audioName != null) {
      map['audio_name'] = Variable<String>(audioName);
    }
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      defaultTempo: defaultTempo == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultTempo),
      targetBpm: targetBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(targetBpm),
      scoreType: Value(scoreType),
      sourcePath: Value(sourcePath),
      sourceProvider: Value(sourceProvider),
      remoteUri: remoteUri == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteUri),
      remoteModifiedAt: remoteModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteModifiedAt),
      remoteSize: remoteSize == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteSize),
      syncStatus: syncStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(syncStatus),
      offlineAvailable: Value(offlineAvailable),
      isFavorite: Value(isFavorite),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      audioName: audioName == null && nullToAbsent
          ? const Value.absent()
          : Value(audioName),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
    );
  }

  factory Song.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Song(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      defaultTempo: serializer.fromJson<int?>(json['defaultTempo']),
      targetBpm: serializer.fromJson<int?>(json['targetBpm']),
      scoreType: serializer.fromJson<String>(json['scoreType']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      sourceProvider: serializer.fromJson<String>(json['sourceProvider']),
      remoteUri: serializer.fromJson<String?>(json['remoteUri']),
      remoteModifiedAt: serializer.fromJson<DateTime?>(
        json['remoteModifiedAt'],
      ),
      remoteSize: serializer.fromJson<int?>(json['remoteSize']),
      syncStatus: serializer.fromJson<String?>(json['syncStatus']),
      offlineAvailable: serializer.fromJson<bool>(json['offlineAvailable']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      note: serializer.fromJson<String?>(json['note']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      audioName: serializer.fromJson<String?>(json['audioName']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'defaultTempo': serializer.toJson<int?>(defaultTempo),
      'targetBpm': serializer.toJson<int?>(targetBpm),
      'scoreType': serializer.toJson<String>(scoreType),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'sourceProvider': serializer.toJson<String>(sourceProvider),
      'remoteUri': serializer.toJson<String?>(remoteUri),
      'remoteModifiedAt': serializer.toJson<DateTime?>(remoteModifiedAt),
      'remoteSize': serializer.toJson<int?>(remoteSize),
      'syncStatus': serializer.toJson<String?>(syncStatus),
      'offlineAvailable': serializer.toJson<bool>(offlineAvailable),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'note': serializer.toJson<String?>(note),
      'audioPath': serializer.toJson<String?>(audioPath),
      'audioName': serializer.toJson<String?>(audioName),
      'folderId': serializer.toJson<String?>(folderId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
    };
  }

  Song copyWith({
    String? id,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<int?> defaultTempo = const Value.absent(),
    Value<int?> targetBpm = const Value.absent(),
    String? scoreType,
    String? sourcePath,
    String? sourceProvider,
    Value<String?> remoteUri = const Value.absent(),
    Value<DateTime?> remoteModifiedAt = const Value.absent(),
    Value<int?> remoteSize = const Value.absent(),
    Value<String?> syncStatus = const Value.absent(),
    bool? offlineAvailable,
    bool? isFavorite,
    Value<String?> note = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    Value<String?> audioName = const Value.absent(),
    Value<String?> folderId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
  }) => Song(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    defaultTempo: defaultTempo.present ? defaultTempo.value : this.defaultTempo,
    targetBpm: targetBpm.present ? targetBpm.value : this.targetBpm,
    scoreType: scoreType ?? this.scoreType,
    sourcePath: sourcePath ?? this.sourcePath,
    sourceProvider: sourceProvider ?? this.sourceProvider,
    remoteUri: remoteUri.present ? remoteUri.value : this.remoteUri,
    remoteModifiedAt: remoteModifiedAt.present
        ? remoteModifiedAt.value
        : this.remoteModifiedAt,
    remoteSize: remoteSize.present ? remoteSize.value : this.remoteSize,
    syncStatus: syncStatus.present ? syncStatus.value : this.syncStatus,
    offlineAvailable: offlineAvailable ?? this.offlineAvailable,
    isFavorite: isFavorite ?? this.isFavorite,
    note: note.present ? note.value : this.note,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    audioName: audioName.present ? audioName.value : this.audioName,
    folderId: folderId.present ? folderId.value : this.folderId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  Song copyWithCompanion(SongsCompanion data) {
    return Song(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      defaultTempo: data.defaultTempo.present
          ? data.defaultTempo.value
          : this.defaultTempo,
      targetBpm: data.targetBpm.present ? data.targetBpm.value : this.targetBpm,
      scoreType: data.scoreType.present ? data.scoreType.value : this.scoreType,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      sourceProvider: data.sourceProvider.present
          ? data.sourceProvider.value
          : this.sourceProvider,
      remoteUri: data.remoteUri.present ? data.remoteUri.value : this.remoteUri,
      remoteModifiedAt: data.remoteModifiedAt.present
          ? data.remoteModifiedAt.value
          : this.remoteModifiedAt,
      remoteSize: data.remoteSize.present
          ? data.remoteSize.value
          : this.remoteSize,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      offlineAvailable: data.offlineAvailable.present
          ? data.offlineAvailable.value
          : this.offlineAvailable,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      note: data.note.present ? data.note.value : this.note,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      audioName: data.audioName.present ? data.audioName.value : this.audioName,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Song(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('defaultTempo: $defaultTempo, ')
          ..write('targetBpm: $targetBpm, ')
          ..write('scoreType: $scoreType, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sourceProvider: $sourceProvider, ')
          ..write('remoteUri: $remoteUri, ')
          ..write('remoteModifiedAt: $remoteModifiedAt, ')
          ..write('remoteSize: $remoteSize, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('offlineAvailable: $offlineAvailable, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('note: $note, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioName: $audioName, ')
          ..write('folderId: $folderId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    artist,
    defaultTempo,
    targetBpm,
    scoreType,
    sourcePath,
    sourceProvider,
    remoteUri,
    remoteModifiedAt,
    remoteSize,
    syncStatus,
    offlineAvailable,
    isFavorite,
    note,
    audioPath,
    audioName,
    folderId,
    createdAt,
    updatedAt,
    lastOpenedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Song &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.defaultTempo == this.defaultTempo &&
          other.targetBpm == this.targetBpm &&
          other.scoreType == this.scoreType &&
          other.sourcePath == this.sourcePath &&
          other.sourceProvider == this.sourceProvider &&
          other.remoteUri == this.remoteUri &&
          other.remoteModifiedAt == this.remoteModifiedAt &&
          other.remoteSize == this.remoteSize &&
          other.syncStatus == this.syncStatus &&
          other.offlineAvailable == this.offlineAvailable &&
          other.isFavorite == this.isFavorite &&
          other.note == this.note &&
          other.audioPath == this.audioPath &&
          other.audioName == this.audioName &&
          other.folderId == this.folderId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class SongsCompanion extends UpdateCompanion<Song> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> artist;
  final Value<int?> defaultTempo;
  final Value<int?> targetBpm;
  final Value<String> scoreType;
  final Value<String> sourcePath;
  final Value<String> sourceProvider;
  final Value<String?> remoteUri;
  final Value<DateTime?> remoteModifiedAt;
  final Value<int?> remoteSize;
  final Value<String?> syncStatus;
  final Value<bool> offlineAvailable;
  final Value<bool> isFavorite;
  final Value<String?> note;
  final Value<String?> audioPath;
  final Value<String?> audioName;
  final Value<String?> folderId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> rowid;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.defaultTempo = const Value.absent(),
    this.targetBpm = const Value.absent(),
    this.scoreType = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.sourceProvider = const Value.absent(),
    this.remoteUri = const Value.absent(),
    this.remoteModifiedAt = const Value.absent(),
    this.remoteSize = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.offlineAvailable = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.note = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioName = const Value.absent(),
    this.folderId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsCompanion.insert({
    required String id,
    required String title,
    this.artist = const Value.absent(),
    this.defaultTempo = const Value.absent(),
    this.targetBpm = const Value.absent(),
    this.scoreType = const Value.absent(),
    required String sourcePath,
    this.sourceProvider = const Value.absent(),
    this.remoteUri = const Value.absent(),
    this.remoteModifiedAt = const Value.absent(),
    this.remoteSize = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.offlineAvailable = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.note = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.audioName = const Value.absent(),
    this.folderId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       sourcePath = Value(sourcePath),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Song> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<int>? defaultTempo,
    Expression<int>? targetBpm,
    Expression<String>? scoreType,
    Expression<String>? sourcePath,
    Expression<String>? sourceProvider,
    Expression<String>? remoteUri,
    Expression<DateTime>? remoteModifiedAt,
    Expression<int>? remoteSize,
    Expression<String>? syncStatus,
    Expression<bool>? offlineAvailable,
    Expression<bool>? isFavorite,
    Expression<String>? note,
    Expression<String>? audioPath,
    Expression<String>? audioName,
    Expression<String>? folderId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (defaultTempo != null) 'default_tempo': defaultTempo,
      if (targetBpm != null) 'target_bpm': targetBpm,
      if (scoreType != null) 'score_type': scoreType,
      if (sourcePath != null) 'source_path': sourcePath,
      if (sourceProvider != null) 'source_provider': sourceProvider,
      if (remoteUri != null) 'remote_uri': remoteUri,
      if (remoteModifiedAt != null) 'remote_modified_at': remoteModifiedAt,
      if (remoteSize != null) 'remote_size': remoteSize,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (offlineAvailable != null) 'offline_available': offlineAvailable,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (note != null) 'note': note,
      if (audioPath != null) 'audio_path': audioPath,
      if (audioName != null) 'audio_name': audioName,
      if (folderId != null) 'folder_id': folderId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? artist,
    Value<int?>? defaultTempo,
    Value<int?>? targetBpm,
    Value<String>? scoreType,
    Value<String>? sourcePath,
    Value<String>? sourceProvider,
    Value<String?>? remoteUri,
    Value<DateTime?>? remoteModifiedAt,
    Value<int?>? remoteSize,
    Value<String?>? syncStatus,
    Value<bool>? offlineAvailable,
    Value<bool>? isFavorite,
    Value<String?>? note,
    Value<String?>? audioPath,
    Value<String?>? audioName,
    Value<String?>? folderId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return SongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      defaultTempo: defaultTempo ?? this.defaultTempo,
      targetBpm: targetBpm ?? this.targetBpm,
      scoreType: scoreType ?? this.scoreType,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceProvider: sourceProvider ?? this.sourceProvider,
      remoteUri: remoteUri ?? this.remoteUri,
      remoteModifiedAt: remoteModifiedAt ?? this.remoteModifiedAt,
      remoteSize: remoteSize ?? this.remoteSize,
      syncStatus: syncStatus ?? this.syncStatus,
      offlineAvailable: offlineAvailable ?? this.offlineAvailable,
      isFavorite: isFavorite ?? this.isFavorite,
      note: note ?? this.note,
      audioPath: audioPath ?? this.audioPath,
      audioName: audioName ?? this.audioName,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (defaultTempo.present) {
      map['default_tempo'] = Variable<int>(defaultTempo.value);
    }
    if (targetBpm.present) {
      map['target_bpm'] = Variable<int>(targetBpm.value);
    }
    if (scoreType.present) {
      map['score_type'] = Variable<String>(scoreType.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (sourceProvider.present) {
      map['source_provider'] = Variable<String>(sourceProvider.value);
    }
    if (remoteUri.present) {
      map['remote_uri'] = Variable<String>(remoteUri.value);
    }
    if (remoteModifiedAt.present) {
      map['remote_modified_at'] = Variable<DateTime>(remoteModifiedAt.value);
    }
    if (remoteSize.present) {
      map['remote_size'] = Variable<int>(remoteSize.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (offlineAvailable.present) {
      map['offline_available'] = Variable<bool>(offlineAvailable.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (audioName.present) {
      map['audio_name'] = Variable<String>(audioName.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('defaultTempo: $defaultTempo, ')
          ..write('targetBpm: $targetBpm, ')
          ..write('scoreType: $scoreType, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('sourceProvider: $sourceProvider, ')
          ..write('remoteUri: $remoteUri, ')
          ..write('remoteModifiedAt: $remoteModifiedAt, ')
          ..write('remoteSize: $remoteSize, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('offlineAvailable: $offlineAvailable, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('note: $note, ')
          ..write('audioPath: $audioPath, ')
          ..write('audioName: $audioName, ')
          ..write('folderId: $folderId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SongLabelsTable extends SongLabels
    with TableInfo<$SongLabelsTable, SongLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelIdMeta = const VerificationMeta(
    'labelId',
  );
  @override
  late final GeneratedColumn<String> labelId = GeneratedColumn<String>(
    'label_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES labels (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [songId, labelId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'song_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<SongLabel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('label_id')) {
      context.handle(
        _labelIdMeta,
        labelId.isAcceptableOrUnknown(data['label_id']!, _labelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_labelIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {songId, labelId};
  @override
  SongLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongLabel(
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      labelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_id'],
      )!,
    );
  }

  @override
  $SongLabelsTable createAlias(String alias) {
    return $SongLabelsTable(attachedDatabase, alias);
  }
}

class SongLabel extends DataClass implements Insertable<SongLabel> {
  final String songId;
  final String labelId;
  const SongLabel({required this.songId, required this.labelId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['song_id'] = Variable<String>(songId);
    map['label_id'] = Variable<String>(labelId);
    return map;
  }

  SongLabelsCompanion toCompanion(bool nullToAbsent) {
    return SongLabelsCompanion(songId: Value(songId), labelId: Value(labelId));
  }

  factory SongLabel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongLabel(
      songId: serializer.fromJson<String>(json['songId']),
      labelId: serializer.fromJson<String>(json['labelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'songId': serializer.toJson<String>(songId),
      'labelId': serializer.toJson<String>(labelId),
    };
  }

  SongLabel copyWith({String? songId, String? labelId}) => SongLabel(
    songId: songId ?? this.songId,
    labelId: labelId ?? this.labelId,
  );
  SongLabel copyWithCompanion(SongLabelsCompanion data) {
    return SongLabel(
      songId: data.songId.present ? data.songId.value : this.songId,
      labelId: data.labelId.present ? data.labelId.value : this.labelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongLabel(')
          ..write('songId: $songId, ')
          ..write('labelId: $labelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(songId, labelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongLabel &&
          other.songId == this.songId &&
          other.labelId == this.labelId);
}

class SongLabelsCompanion extends UpdateCompanion<SongLabel> {
  final Value<String> songId;
  final Value<String> labelId;
  final Value<int> rowid;
  const SongLabelsCompanion({
    this.songId = const Value.absent(),
    this.labelId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongLabelsCompanion.insert({
    required String songId,
    required String labelId,
    this.rowid = const Value.absent(),
  }) : songId = Value(songId),
       labelId = Value(labelId);
  static Insertable<SongLabel> custom({
    Expression<String>? songId,
    Expression<String>? labelId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (songId != null) 'song_id': songId,
      if (labelId != null) 'label_id': labelId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongLabelsCompanion copyWith({
    Value<String>? songId,
    Value<String>? labelId,
    Value<int>? rowid,
  }) {
    return SongLabelsCompanion(
      songId: songId ?? this.songId,
      labelId: labelId ?? this.labelId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (labelId.present) {
      map['label_id'] = Variable<String>(labelId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongLabelsCompanion(')
          ..write('songId: $songId, ')
          ..write('labelId: $labelId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetlistsTable extends Setlists with TableInfo<$SetlistsTable, Setlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetlistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SetlistsTable createAlias(String alias) {
    return $SetlistsTable(attachedDatabase, alias);
  }
}

class Setlist extends DataClass implements Insertable<Setlist> {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Setlist({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SetlistsCompanion toCompanion(bool nullToAbsent) {
    return SetlistsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Setlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setlist(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Setlist copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Setlist(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Setlist copyWithCompanion(SetlistsCompanion data) {
    return Setlist(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setlist(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setlist &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SetlistsCompanion extends UpdateCompanion<Setlist> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SetlistsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetlistsCompanion.insert({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Setlist> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetlistsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SetlistsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetlistsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetlistEntriesTable extends SetlistEntries
    with TableInfo<$SetlistEntriesTable, SetlistEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetlistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setlistIdMeta = const VerificationMeta(
    'setlistId',
  );
  @override
  late final GeneratedColumn<String> setlistId = GeneratedColumn<String>(
    'setlist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES setlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tempoOverrideMeta = const VerificationMeta(
    'tempoOverride',
  );
  @override
  late final GeneratedColumn<int> tempoOverride = GeneratedColumn<int>(
    'tempo_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metronomeJsonMeta = const VerificationMeta(
    'metronomeJson',
  );
  @override
  late final GeneratedColumn<String> metronomeJson = GeneratedColumn<String>(
    'metronome_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setlistId,
    songId,
    position,
    tempoOverride,
    metronomeJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setlist_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetlistEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('setlist_id')) {
      context.handle(
        _setlistIdMeta,
        setlistId.isAcceptableOrUnknown(data['setlist_id']!, _setlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setlistIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('tempo_override')) {
      context.handle(
        _tempoOverrideMeta,
        tempoOverride.isAcceptableOrUnknown(
          data['tempo_override']!,
          _tempoOverrideMeta,
        ),
      );
    }
    if (data.containsKey('metronome_json')) {
      context.handle(
        _metronomeJsonMeta,
        metronomeJson.isAcceptableOrUnknown(
          data['metronome_json']!,
          _metronomeJsonMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {setlistId, position},
  ];
  @override
  SetlistEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetlistEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      setlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setlist_id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      tempoOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tempo_override'],
      ),
      metronomeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metronome_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SetlistEntriesTable createAlias(String alias) {
    return $SetlistEntriesTable(attachedDatabase, alias);
  }
}

class SetlistEntry extends DataClass implements Insertable<SetlistEntry> {
  final String id;
  final String setlistId;
  final String songId;
  final int position;
  final int? tempoOverride;

  /// JSON-encoded per-entry metronome profile. Kept nullable so existing
  /// setlists continue to use the song BPM and global metronome defaults.
  final String? metronomeJson;
  final DateTime createdAt;
  const SetlistEntry({
    required this.id,
    required this.setlistId,
    required this.songId,
    required this.position,
    this.tempoOverride,
    this.metronomeJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['setlist_id'] = Variable<String>(setlistId);
    map['song_id'] = Variable<String>(songId);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || tempoOverride != null) {
      map['tempo_override'] = Variable<int>(tempoOverride);
    }
    if (!nullToAbsent || metronomeJson != null) {
      map['metronome_json'] = Variable<String>(metronomeJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SetlistEntriesCompanion toCompanion(bool nullToAbsent) {
    return SetlistEntriesCompanion(
      id: Value(id),
      setlistId: Value(setlistId),
      songId: Value(songId),
      position: Value(position),
      tempoOverride: tempoOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(tempoOverride),
      metronomeJson: metronomeJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metronomeJson),
      createdAt: Value(createdAt),
    );
  }

  factory SetlistEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetlistEntry(
      id: serializer.fromJson<String>(json['id']),
      setlistId: serializer.fromJson<String>(json['setlistId']),
      songId: serializer.fromJson<String>(json['songId']),
      position: serializer.fromJson<int>(json['position']),
      tempoOverride: serializer.fromJson<int?>(json['tempoOverride']),
      metronomeJson: serializer.fromJson<String?>(json['metronomeJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'setlistId': serializer.toJson<String>(setlistId),
      'songId': serializer.toJson<String>(songId),
      'position': serializer.toJson<int>(position),
      'tempoOverride': serializer.toJson<int?>(tempoOverride),
      'metronomeJson': serializer.toJson<String?>(metronomeJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SetlistEntry copyWith({
    String? id,
    String? setlistId,
    String? songId,
    int? position,
    Value<int?> tempoOverride = const Value.absent(),
    Value<String?> metronomeJson = const Value.absent(),
    DateTime? createdAt,
  }) => SetlistEntry(
    id: id ?? this.id,
    setlistId: setlistId ?? this.setlistId,
    songId: songId ?? this.songId,
    position: position ?? this.position,
    tempoOverride: tempoOverride.present
        ? tempoOverride.value
        : this.tempoOverride,
    metronomeJson: metronomeJson.present
        ? metronomeJson.value
        : this.metronomeJson,
    createdAt: createdAt ?? this.createdAt,
  );
  SetlistEntry copyWithCompanion(SetlistEntriesCompanion data) {
    return SetlistEntry(
      id: data.id.present ? data.id.value : this.id,
      setlistId: data.setlistId.present ? data.setlistId.value : this.setlistId,
      songId: data.songId.present ? data.songId.value : this.songId,
      position: data.position.present ? data.position.value : this.position,
      tempoOverride: data.tempoOverride.present
          ? data.tempoOverride.value
          : this.tempoOverride,
      metronomeJson: data.metronomeJson.present
          ? data.metronomeJson.value
          : this.metronomeJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetlistEntry(')
          ..write('id: $id, ')
          ..write('setlistId: $setlistId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('tempoOverride: $tempoOverride, ')
          ..write('metronomeJson: $metronomeJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    setlistId,
    songId,
    position,
    tempoOverride,
    metronomeJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetlistEntry &&
          other.id == this.id &&
          other.setlistId == this.setlistId &&
          other.songId == this.songId &&
          other.position == this.position &&
          other.tempoOverride == this.tempoOverride &&
          other.metronomeJson == this.metronomeJson &&
          other.createdAt == this.createdAt);
}

class SetlistEntriesCompanion extends UpdateCompanion<SetlistEntry> {
  final Value<String> id;
  final Value<String> setlistId;
  final Value<String> songId;
  final Value<int> position;
  final Value<int?> tempoOverride;
  final Value<String?> metronomeJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SetlistEntriesCompanion({
    this.id = const Value.absent(),
    this.setlistId = const Value.absent(),
    this.songId = const Value.absent(),
    this.position = const Value.absent(),
    this.tempoOverride = const Value.absent(),
    this.metronomeJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetlistEntriesCompanion.insert({
    required String id,
    required String setlistId,
    required String songId,
    required int position,
    this.tempoOverride = const Value.absent(),
    this.metronomeJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       setlistId = Value(setlistId),
       songId = Value(songId),
       position = Value(position),
       createdAt = Value(createdAt);
  static Insertable<SetlistEntry> custom({
    Expression<String>? id,
    Expression<String>? setlistId,
    Expression<String>? songId,
    Expression<int>? position,
    Expression<int>? tempoOverride,
    Expression<String>? metronomeJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setlistId != null) 'setlist_id': setlistId,
      if (songId != null) 'song_id': songId,
      if (position != null) 'position': position,
      if (tempoOverride != null) 'tempo_override': tempoOverride,
      if (metronomeJson != null) 'metronome_json': metronomeJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetlistEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? setlistId,
    Value<String>? songId,
    Value<int>? position,
    Value<int?>? tempoOverride,
    Value<String?>? metronomeJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SetlistEntriesCompanion(
      id: id ?? this.id,
      setlistId: setlistId ?? this.setlistId,
      songId: songId ?? this.songId,
      position: position ?? this.position,
      tempoOverride: tempoOverride ?? this.tempoOverride,
      metronomeJson: metronomeJson ?? this.metronomeJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (setlistId.present) {
      map['setlist_id'] = Variable<String>(setlistId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (tempoOverride.present) {
      map['tempo_override'] = Variable<int>(tempoOverride.value);
    }
    if (metronomeJson.present) {
      map['metronome_json'] = Variable<String>(metronomeJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetlistEntriesCompanion(')
          ..write('id: $id, ')
          ..write('setlistId: $setlistId, ')
          ..write('songId: $songId, ')
          ..write('position: $position, ')
          ..write('tempoOverride: $tempoOverride, ')
          ..write('metronomeJson: $metronomeJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeasuresTable extends Measures with TableInfo<$MeasuresTable, Measure> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeasuresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _xMeta = const VerificationMeta('x');
  @override
  late final GeneratedColumn<double> x = GeneratedColumn<double>(
    'x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yMeta = const VerificationMeta('y');
  @override
  late final GeneratedColumn<double> y = GeneratedColumn<double>(
    'y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<double> width = GeneratedColumn<double>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDifficultMeta = const VerificationMeta(
    'isDifficult',
  );
  @override
  late final GeneratedColumn<bool> isDifficult = GeneratedColumn<bool>(
    'is_difficult',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_difficult" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    number,
    page,
    x,
    y,
    width,
    height,
    section,
    isDifficult,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'measures';
  @override
  VerificationContext validateIntegrity(
    Insertable<Measure> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('x')) {
      context.handle(_xMeta, x.isAcceptableOrUnknown(data['x']!, _xMeta));
    } else if (isInserting) {
      context.missing(_xMeta);
    }
    if (data.containsKey('y')) {
      context.handle(_yMeta, y.isAcceptableOrUnknown(data['y']!, _yMeta));
    } else if (isInserting) {
      context.missing(_yMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    }
    if (data.containsKey('is_difficult')) {
      context.handle(
        _isDifficultMeta,
        isDifficult.isAcceptableOrUnknown(
          data['is_difficult']!,
          _isDifficultMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {songId, number},
  ];
  @override
  Measure map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Measure(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      x: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}x'],
      )!,
      y: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}y'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      ),
      isDifficult: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_difficult'],
      )!,
    );
  }

  @override
  $MeasuresTable createAlias(String alias) {
    return $MeasuresTable(attachedDatabase, alias);
  }
}

class Measure extends DataClass implements Insertable<Measure> {
  final String id;
  final String songId;
  final int number;
  final int page;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? section;
  final bool isDifficult;
  const Measure({
    required this.id,
    required this.songId,
    required this.number,
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.section,
    required this.isDifficult,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    map['number'] = Variable<int>(number);
    map['page'] = Variable<int>(page);
    map['x'] = Variable<double>(x);
    map['y'] = Variable<double>(y);
    map['width'] = Variable<double>(width);
    map['height'] = Variable<double>(height);
    if (!nullToAbsent || section != null) {
      map['section'] = Variable<String>(section);
    }
    map['is_difficult'] = Variable<bool>(isDifficult);
    return map;
  }

  MeasuresCompanion toCompanion(bool nullToAbsent) {
    return MeasuresCompanion(
      id: Value(id),
      songId: Value(songId),
      number: Value(number),
      page: Value(page),
      x: Value(x),
      y: Value(y),
      width: Value(width),
      height: Value(height),
      section: section == null && nullToAbsent
          ? const Value.absent()
          : Value(section),
      isDifficult: Value(isDifficult),
    );
  }

  factory Measure.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Measure(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      number: serializer.fromJson<int>(json['number']),
      page: serializer.fromJson<int>(json['page']),
      x: serializer.fromJson<double>(json['x']),
      y: serializer.fromJson<double>(json['y']),
      width: serializer.fromJson<double>(json['width']),
      height: serializer.fromJson<double>(json['height']),
      section: serializer.fromJson<String?>(json['section']),
      isDifficult: serializer.fromJson<bool>(json['isDifficult']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'number': serializer.toJson<int>(number),
      'page': serializer.toJson<int>(page),
      'x': serializer.toJson<double>(x),
      'y': serializer.toJson<double>(y),
      'width': serializer.toJson<double>(width),
      'height': serializer.toJson<double>(height),
      'section': serializer.toJson<String?>(section),
      'isDifficult': serializer.toJson<bool>(isDifficult),
    };
  }

  Measure copyWith({
    String? id,
    String? songId,
    int? number,
    int? page,
    double? x,
    double? y,
    double? width,
    double? height,
    Value<String?> section = const Value.absent(),
    bool? isDifficult,
  }) => Measure(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    number: number ?? this.number,
    page: page ?? this.page,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    section: section.present ? section.value : this.section,
    isDifficult: isDifficult ?? this.isDifficult,
  );
  Measure copyWithCompanion(MeasuresCompanion data) {
    return Measure(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      number: data.number.present ? data.number.value : this.number,
      page: data.page.present ? data.page.value : this.page,
      x: data.x.present ? data.x.value : this.x,
      y: data.y.present ? data.y.value : this.y,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      section: data.section.present ? data.section.value : this.section,
      isDifficult: data.isDifficult.present
          ? data.isDifficult.value
          : this.isDifficult,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Measure(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('number: $number, ')
          ..write('page: $page, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('section: $section, ')
          ..write('isDifficult: $isDifficult')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    songId,
    number,
    page,
    x,
    y,
    width,
    height,
    section,
    isDifficult,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Measure &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.number == this.number &&
          other.page == this.page &&
          other.x == this.x &&
          other.y == this.y &&
          other.width == this.width &&
          other.height == this.height &&
          other.section == this.section &&
          other.isDifficult == this.isDifficult);
}

class MeasuresCompanion extends UpdateCompanion<Measure> {
  final Value<String> id;
  final Value<String> songId;
  final Value<int> number;
  final Value<int> page;
  final Value<double> x;
  final Value<double> y;
  final Value<double> width;
  final Value<double> height;
  final Value<String?> section;
  final Value<bool> isDifficult;
  final Value<int> rowid;
  const MeasuresCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.number = const Value.absent(),
    this.page = const Value.absent(),
    this.x = const Value.absent(),
    this.y = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.section = const Value.absent(),
    this.isDifficult = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeasuresCompanion.insert({
    required String id,
    required String songId,
    required int number,
    required int page,
    required double x,
    required double y,
    required double width,
    required double height,
    this.section = const Value.absent(),
    this.isDifficult = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       songId = Value(songId),
       number = Value(number),
       page = Value(page),
       x = Value(x),
       y = Value(y),
       width = Value(width),
       height = Value(height);
  static Insertable<Measure> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<int>? number,
    Expression<int>? page,
    Expression<double>? x,
    Expression<double>? y,
    Expression<double>? width,
    Expression<double>? height,
    Expression<String>? section,
    Expression<bool>? isDifficult,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (number != null) 'number': number,
      if (page != null) 'page': page,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (section != null) 'section': section,
      if (isDifficult != null) 'is_difficult': isDifficult,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeasuresCompanion copyWith({
    Value<String>? id,
    Value<String>? songId,
    Value<int>? number,
    Value<int>? page,
    Value<double>? x,
    Value<double>? y,
    Value<double>? width,
    Value<double>? height,
    Value<String?>? section,
    Value<bool>? isDifficult,
    Value<int>? rowid,
  }) {
    return MeasuresCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      number: number ?? this.number,
      page: page ?? this.page,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      section: section ?? this.section,
      isDifficult: isDifficult ?? this.isDifficult,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (x.present) {
      map['x'] = Variable<double>(x.value);
    }
    if (y.present) {
      map['y'] = Variable<double>(y.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (isDifficult.present) {
      map['is_difficult'] = Variable<bool>(isDifficult.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeasuresCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('number: $number, ')
          ..write('page: $page, ')
          ..write('x: $x, ')
          ..write('y: $y, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('section: $section, ')
          ..write('isDifficult: $isDifficult, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TempoMapsTable extends TempoMaps
    with TableInfo<$TempoMapsTable, TempoMap> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TempoMapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startMeasureMeta = const VerificationMeta(
    'startMeasure',
  );
  @override
  late final GeneratedColumn<int> startMeasure = GeneratedColumn<int>(
    'start_measure',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMeasureMeta = const VerificationMeta(
    'endMeasure',
  );
  @override
  late final GeneratedColumn<int> endMeasure = GeneratedColumn<int>(
    'end_measure',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startBpmMeta = const VerificationMeta(
    'startBpm',
  );
  @override
  late final GeneratedColumn<int> startBpm = GeneratedColumn<int>(
    'start_bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endBpmMeta = const VerificationMeta('endBpm');
  @override
  late final GeneratedColumn<int> endBpm = GeneratedColumn<int>(
    'end_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    startMeasure,
    endMeasure,
    mode,
    startBpm,
    endBpm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tempo_maps';
  @override
  VerificationContext validateIntegrity(
    Insertable<TempoMap> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('start_measure')) {
      context.handle(
        _startMeasureMeta,
        startMeasure.isAcceptableOrUnknown(
          data['start_measure']!,
          _startMeasureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMeasureMeta);
    }
    if (data.containsKey('end_measure')) {
      context.handle(
        _endMeasureMeta,
        endMeasure.isAcceptableOrUnknown(data['end_measure']!, _endMeasureMeta),
      );
    } else if (isInserting) {
      context.missing(_endMeasureMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('start_bpm')) {
      context.handle(
        _startBpmMeta,
        startBpm.isAcceptableOrUnknown(data['start_bpm']!, _startBpmMeta),
      );
    } else if (isInserting) {
      context.missing(_startBpmMeta);
    }
    if (data.containsKey('end_bpm')) {
      context.handle(
        _endBpmMeta,
        endBpm.isAcceptableOrUnknown(data['end_bpm']!, _endBpmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {songId, startMeasure},
  ];
  @override
  TempoMap map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TempoMap(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      startMeasure: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_measure'],
      )!,
      endMeasure: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_measure'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      startBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_bpm'],
      )!,
      endBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_bpm'],
      ),
    );
  }

  @override
  $TempoMapsTable createAlias(String alias) {
    return $TempoMapsTable(attachedDatabase, alias);
  }
}

class TempoMap extends DataClass implements Insertable<TempoMap> {
  final String id;
  final String songId;
  final int startMeasure;
  final int endMeasure;
  final String mode;
  final int startBpm;
  final int? endBpm;
  const TempoMap({
    required this.id,
    required this.songId,
    required this.startMeasure,
    required this.endMeasure,
    required this.mode,
    required this.startBpm,
    this.endBpm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    map['start_measure'] = Variable<int>(startMeasure);
    map['end_measure'] = Variable<int>(endMeasure);
    map['mode'] = Variable<String>(mode);
    map['start_bpm'] = Variable<int>(startBpm);
    if (!nullToAbsent || endBpm != null) {
      map['end_bpm'] = Variable<int>(endBpm);
    }
    return map;
  }

  TempoMapsCompanion toCompanion(bool nullToAbsent) {
    return TempoMapsCompanion(
      id: Value(id),
      songId: Value(songId),
      startMeasure: Value(startMeasure),
      endMeasure: Value(endMeasure),
      mode: Value(mode),
      startBpm: Value(startBpm),
      endBpm: endBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(endBpm),
    );
  }

  factory TempoMap.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TempoMap(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      startMeasure: serializer.fromJson<int>(json['startMeasure']),
      endMeasure: serializer.fromJson<int>(json['endMeasure']),
      mode: serializer.fromJson<String>(json['mode']),
      startBpm: serializer.fromJson<int>(json['startBpm']),
      endBpm: serializer.fromJson<int?>(json['endBpm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'startMeasure': serializer.toJson<int>(startMeasure),
      'endMeasure': serializer.toJson<int>(endMeasure),
      'mode': serializer.toJson<String>(mode),
      'startBpm': serializer.toJson<int>(startBpm),
      'endBpm': serializer.toJson<int?>(endBpm),
    };
  }

  TempoMap copyWith({
    String? id,
    String? songId,
    int? startMeasure,
    int? endMeasure,
    String? mode,
    int? startBpm,
    Value<int?> endBpm = const Value.absent(),
  }) => TempoMap(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    startMeasure: startMeasure ?? this.startMeasure,
    endMeasure: endMeasure ?? this.endMeasure,
    mode: mode ?? this.mode,
    startBpm: startBpm ?? this.startBpm,
    endBpm: endBpm.present ? endBpm.value : this.endBpm,
  );
  TempoMap copyWithCompanion(TempoMapsCompanion data) {
    return TempoMap(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      startMeasure: data.startMeasure.present
          ? data.startMeasure.value
          : this.startMeasure,
      endMeasure: data.endMeasure.present
          ? data.endMeasure.value
          : this.endMeasure,
      mode: data.mode.present ? data.mode.value : this.mode,
      startBpm: data.startBpm.present ? data.startBpm.value : this.startBpm,
      endBpm: data.endBpm.present ? data.endBpm.value : this.endBpm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TempoMap(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('startMeasure: $startMeasure, ')
          ..write('endMeasure: $endMeasure, ')
          ..write('mode: $mode, ')
          ..write('startBpm: $startBpm, ')
          ..write('endBpm: $endBpm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, songId, startMeasure, endMeasure, mode, startBpm, endBpm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TempoMap &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.startMeasure == this.startMeasure &&
          other.endMeasure == this.endMeasure &&
          other.mode == this.mode &&
          other.startBpm == this.startBpm &&
          other.endBpm == this.endBpm);
}

class TempoMapsCompanion extends UpdateCompanion<TempoMap> {
  final Value<String> id;
  final Value<String> songId;
  final Value<int> startMeasure;
  final Value<int> endMeasure;
  final Value<String> mode;
  final Value<int> startBpm;
  final Value<int?> endBpm;
  final Value<int> rowid;
  const TempoMapsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.startMeasure = const Value.absent(),
    this.endMeasure = const Value.absent(),
    this.mode = const Value.absent(),
    this.startBpm = const Value.absent(),
    this.endBpm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TempoMapsCompanion.insert({
    required String id,
    required String songId,
    required int startMeasure,
    required int endMeasure,
    required String mode,
    required int startBpm,
    this.endBpm = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       songId = Value(songId),
       startMeasure = Value(startMeasure),
       endMeasure = Value(endMeasure),
       mode = Value(mode),
       startBpm = Value(startBpm);
  static Insertable<TempoMap> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<int>? startMeasure,
    Expression<int>? endMeasure,
    Expression<String>? mode,
    Expression<int>? startBpm,
    Expression<int>? endBpm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (startMeasure != null) 'start_measure': startMeasure,
      if (endMeasure != null) 'end_measure': endMeasure,
      if (mode != null) 'mode': mode,
      if (startBpm != null) 'start_bpm': startBpm,
      if (endBpm != null) 'end_bpm': endBpm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TempoMapsCompanion copyWith({
    Value<String>? id,
    Value<String>? songId,
    Value<int>? startMeasure,
    Value<int>? endMeasure,
    Value<String>? mode,
    Value<int>? startBpm,
    Value<int?>? endBpm,
    Value<int>? rowid,
  }) {
    return TempoMapsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      startMeasure: startMeasure ?? this.startMeasure,
      endMeasure: endMeasure ?? this.endMeasure,
      mode: mode ?? this.mode,
      startBpm: startBpm ?? this.startBpm,
      endBpm: endBpm ?? this.endBpm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (startMeasure.present) {
      map['start_measure'] = Variable<int>(startMeasure.value);
    }
    if (endMeasure.present) {
      map['end_measure'] = Variable<int>(endMeasure.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (startBpm.present) {
      map['start_bpm'] = Variable<int>(startBpm.value);
    }
    if (endBpm.present) {
      map['end_bpm'] = Variable<int>(endBpm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TempoMapsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('startMeasure: $startMeasure, ')
          ..write('endMeasure: $endMeasure, ')
          ..write('mode: $mode, ')
          ..write('startBpm: $startBpm, ')
          ..write('endBpm: $endBpm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TimeSignatureMapsTable extends TimeSignatureMaps
    with TableInfo<$TimeSignatureMapsTable, TimeSignatureMap> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimeSignatureMapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startMeasureMeta = const VerificationMeta(
    'startMeasure',
  );
  @override
  late final GeneratedColumn<int> startMeasure = GeneratedColumn<int>(
    'start_measure',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMeasureMeta = const VerificationMeta(
    'endMeasure',
  );
  @override
  late final GeneratedColumn<int> endMeasure = GeneratedColumn<int>(
    'end_measure',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numeratorMeta = const VerificationMeta(
    'numerator',
  );
  @override
  late final GeneratedColumn<int> numerator = GeneratedColumn<int>(
    'numerator',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _denominatorMeta = const VerificationMeta(
    'denominator',
  );
  @override
  late final GeneratedColumn<int> denominator = GeneratedColumn<int>(
    'denominator',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    startMeasure,
    endMeasure,
    numerator,
    denominator,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'time_signature_maps';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimeSignatureMap> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('start_measure')) {
      context.handle(
        _startMeasureMeta,
        startMeasure.isAcceptableOrUnknown(
          data['start_measure']!,
          _startMeasureMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMeasureMeta);
    }
    if (data.containsKey('end_measure')) {
      context.handle(
        _endMeasureMeta,
        endMeasure.isAcceptableOrUnknown(data['end_measure']!, _endMeasureMeta),
      );
    } else if (isInserting) {
      context.missing(_endMeasureMeta);
    }
    if (data.containsKey('numerator')) {
      context.handle(
        _numeratorMeta,
        numerator.isAcceptableOrUnknown(data['numerator']!, _numeratorMeta),
      );
    } else if (isInserting) {
      context.missing(_numeratorMeta);
    }
    if (data.containsKey('denominator')) {
      context.handle(
        _denominatorMeta,
        denominator.isAcceptableOrUnknown(
          data['denominator']!,
          _denominatorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_denominatorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {songId, startMeasure},
  ];
  @override
  TimeSignatureMap map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimeSignatureMap(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      startMeasure: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_measure'],
      )!,
      endMeasure: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_measure'],
      )!,
      numerator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numerator'],
      )!,
      denominator: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}denominator'],
      )!,
    );
  }

  @override
  $TimeSignatureMapsTable createAlias(String alias) {
    return $TimeSignatureMapsTable(attachedDatabase, alias);
  }
}

class TimeSignatureMap extends DataClass
    implements Insertable<TimeSignatureMap> {
  final String id;
  final String songId;
  final int startMeasure;
  final int endMeasure;
  final int numerator;
  final int denominator;
  const TimeSignatureMap({
    required this.id,
    required this.songId,
    required this.startMeasure,
    required this.endMeasure,
    required this.numerator,
    required this.denominator,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    map['start_measure'] = Variable<int>(startMeasure);
    map['end_measure'] = Variable<int>(endMeasure);
    map['numerator'] = Variable<int>(numerator);
    map['denominator'] = Variable<int>(denominator);
    return map;
  }

  TimeSignatureMapsCompanion toCompanion(bool nullToAbsent) {
    return TimeSignatureMapsCompanion(
      id: Value(id),
      songId: Value(songId),
      startMeasure: Value(startMeasure),
      endMeasure: Value(endMeasure),
      numerator: Value(numerator),
      denominator: Value(denominator),
    );
  }

  factory TimeSignatureMap.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimeSignatureMap(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      startMeasure: serializer.fromJson<int>(json['startMeasure']),
      endMeasure: serializer.fromJson<int>(json['endMeasure']),
      numerator: serializer.fromJson<int>(json['numerator']),
      denominator: serializer.fromJson<int>(json['denominator']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'startMeasure': serializer.toJson<int>(startMeasure),
      'endMeasure': serializer.toJson<int>(endMeasure),
      'numerator': serializer.toJson<int>(numerator),
      'denominator': serializer.toJson<int>(denominator),
    };
  }

  TimeSignatureMap copyWith({
    String? id,
    String? songId,
    int? startMeasure,
    int? endMeasure,
    int? numerator,
    int? denominator,
  }) => TimeSignatureMap(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    startMeasure: startMeasure ?? this.startMeasure,
    endMeasure: endMeasure ?? this.endMeasure,
    numerator: numerator ?? this.numerator,
    denominator: denominator ?? this.denominator,
  );
  TimeSignatureMap copyWithCompanion(TimeSignatureMapsCompanion data) {
    return TimeSignatureMap(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      startMeasure: data.startMeasure.present
          ? data.startMeasure.value
          : this.startMeasure,
      endMeasure: data.endMeasure.present
          ? data.endMeasure.value
          : this.endMeasure,
      numerator: data.numerator.present ? data.numerator.value : this.numerator,
      denominator: data.denominator.present
          ? data.denominator.value
          : this.denominator,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimeSignatureMap(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('startMeasure: $startMeasure, ')
          ..write('endMeasure: $endMeasure, ')
          ..write('numerator: $numerator, ')
          ..write('denominator: $denominator')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, songId, startMeasure, endMeasure, numerator, denominator);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimeSignatureMap &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.startMeasure == this.startMeasure &&
          other.endMeasure == this.endMeasure &&
          other.numerator == this.numerator &&
          other.denominator == this.denominator);
}

class TimeSignatureMapsCompanion extends UpdateCompanion<TimeSignatureMap> {
  final Value<String> id;
  final Value<String> songId;
  final Value<int> startMeasure;
  final Value<int> endMeasure;
  final Value<int> numerator;
  final Value<int> denominator;
  final Value<int> rowid;
  const TimeSignatureMapsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.startMeasure = const Value.absent(),
    this.endMeasure = const Value.absent(),
    this.numerator = const Value.absent(),
    this.denominator = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TimeSignatureMapsCompanion.insert({
    required String id,
    required String songId,
    required int startMeasure,
    required int endMeasure,
    required int numerator,
    required int denominator,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       songId = Value(songId),
       startMeasure = Value(startMeasure),
       endMeasure = Value(endMeasure),
       numerator = Value(numerator),
       denominator = Value(denominator);
  static Insertable<TimeSignatureMap> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<int>? startMeasure,
    Expression<int>? endMeasure,
    Expression<int>? numerator,
    Expression<int>? denominator,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (startMeasure != null) 'start_measure': startMeasure,
      if (endMeasure != null) 'end_measure': endMeasure,
      if (numerator != null) 'numerator': numerator,
      if (denominator != null) 'denominator': denominator,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TimeSignatureMapsCompanion copyWith({
    Value<String>? id,
    Value<String>? songId,
    Value<int>? startMeasure,
    Value<int>? endMeasure,
    Value<int>? numerator,
    Value<int>? denominator,
    Value<int>? rowid,
  }) {
    return TimeSignatureMapsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      startMeasure: startMeasure ?? this.startMeasure,
      endMeasure: endMeasure ?? this.endMeasure,
      numerator: numerator ?? this.numerator,
      denominator: denominator ?? this.denominator,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (startMeasure.present) {
      map['start_measure'] = Variable<int>(startMeasure.value);
    }
    if (endMeasure.present) {
      map['end_measure'] = Variable<int>(endMeasure.value);
    }
    if (numerator.present) {
      map['numerator'] = Variable<int>(numerator.value);
    }
    if (denominator.present) {
      map['denominator'] = Variable<int>(denominator.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimeSignatureMapsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('startMeasure: $startMeasure, ')
          ..write('endMeasure: $endMeasure, ')
          ..write('numerator: $numerator, ')
          ..write('denominator: $denominator, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioAnchorsTable extends AudioAnchors
    with TableInfo<$AudioAnchorsTable, AudioAnchor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioAnchorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _measureNumberMeta = const VerificationMeta(
    'measureNumber',
  );
  @override
  late final GeneratedColumn<int> measureNumber = GeneratedColumn<int>(
    'measure_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioTimeMeta = const VerificationMeta(
    'audioTime',
  );
  @override
  late final GeneratedColumn<double> audioTime = GeneratedColumn<double>(
    'audio_time',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, songId, measureNumber, audioTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_anchors';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioAnchor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('measure_number')) {
      context.handle(
        _measureNumberMeta,
        measureNumber.isAcceptableOrUnknown(
          data['measure_number']!,
          _measureNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_measureNumberMeta);
    }
    if (data.containsKey('audio_time')) {
      context.handle(
        _audioTimeMeta,
        audioTime.isAcceptableOrUnknown(data['audio_time']!, _audioTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_audioTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {songId, measureNumber},
  ];
  @override
  AudioAnchor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioAnchor(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      measureNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}measure_number'],
      )!,
      audioTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}audio_time'],
      )!,
    );
  }

  @override
  $AudioAnchorsTable createAlias(String alias) {
    return $AudioAnchorsTable(attachedDatabase, alias);
  }
}

class AudioAnchor extends DataClass implements Insertable<AudioAnchor> {
  final String id;
  final String songId;
  final int measureNumber;
  final double audioTime;
  const AudioAnchor({
    required this.id,
    required this.songId,
    required this.measureNumber,
    required this.audioTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    map['measure_number'] = Variable<int>(measureNumber);
    map['audio_time'] = Variable<double>(audioTime);
    return map;
  }

  AudioAnchorsCompanion toCompanion(bool nullToAbsent) {
    return AudioAnchorsCompanion(
      id: Value(id),
      songId: Value(songId),
      measureNumber: Value(measureNumber),
      audioTime: Value(audioTime),
    );
  }

  factory AudioAnchor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioAnchor(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      measureNumber: serializer.fromJson<int>(json['measureNumber']),
      audioTime: serializer.fromJson<double>(json['audioTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'measureNumber': serializer.toJson<int>(measureNumber),
      'audioTime': serializer.toJson<double>(audioTime),
    };
  }

  AudioAnchor copyWith({
    String? id,
    String? songId,
    int? measureNumber,
    double? audioTime,
  }) => AudioAnchor(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    measureNumber: measureNumber ?? this.measureNumber,
    audioTime: audioTime ?? this.audioTime,
  );
  AudioAnchor copyWithCompanion(AudioAnchorsCompanion data) {
    return AudioAnchor(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      measureNumber: data.measureNumber.present
          ? data.measureNumber.value
          : this.measureNumber,
      audioTime: data.audioTime.present ? data.audioTime.value : this.audioTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioAnchor(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('measureNumber: $measureNumber, ')
          ..write('audioTime: $audioTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, songId, measureNumber, audioTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioAnchor &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.measureNumber == this.measureNumber &&
          other.audioTime == this.audioTime);
}

class AudioAnchorsCompanion extends UpdateCompanion<AudioAnchor> {
  final Value<String> id;
  final Value<String> songId;
  final Value<int> measureNumber;
  final Value<double> audioTime;
  final Value<int> rowid;
  const AudioAnchorsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.measureNumber = const Value.absent(),
    this.audioTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioAnchorsCompanion.insert({
    required String id,
    required String songId,
    required int measureNumber,
    required double audioTime,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       songId = Value(songId),
       measureNumber = Value(measureNumber),
       audioTime = Value(audioTime);
  static Insertable<AudioAnchor> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<int>? measureNumber,
    Expression<double>? audioTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (measureNumber != null) 'measure_number': measureNumber,
      if (audioTime != null) 'audio_time': audioTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioAnchorsCompanion copyWith({
    Value<String>? id,
    Value<String>? songId,
    Value<int>? measureNumber,
    Value<double>? audioTime,
    Value<int>? rowid,
  }) {
    return AudioAnchorsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      measureNumber: measureNumber ?? this.measureNumber,
      audioTime: audioTime ?? this.audioTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (measureNumber.present) {
      map['measure_number'] = Variable<int>(measureNumber.value);
    }
    if (audioTime.present) {
      map['audio_time'] = Variable<double>(audioTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioAnchorsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('measureNumber: $measureNumber, ')
          ..write('audioTime: $audioTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CuesTable extends Cues with TableInfo<$CuesTable, Cue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _measureNumberMeta = const VerificationMeta(
    'measureNumber',
  );
  @override
  late final GeneratedColumn<int> measureNumber = GeneratedColumn<int>(
    'measure_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, songId, measureNumber, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cues';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('measure_number')) {
      context.handle(
        _measureNumberMeta,
        measureNumber.isAcceptableOrUnknown(
          data['measure_number']!,
          _measureNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_measureNumberMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {songId, measureNumber},
  ];
  @override
  Cue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cue(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      measureNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}measure_number'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
    );
  }

  @override
  $CuesTable createAlias(String alias) {
    return $CuesTable(attachedDatabase, alias);
  }
}

class Cue extends DataClass implements Insertable<Cue> {
  final String id;
  final String songId;
  final int measureNumber;
  final String label;
  const Cue({
    required this.id,
    required this.songId,
    required this.measureNumber,
    required this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    map['measure_number'] = Variable<int>(measureNumber);
    map['label'] = Variable<String>(label);
    return map;
  }

  CuesCompanion toCompanion(bool nullToAbsent) {
    return CuesCompanion(
      id: Value(id),
      songId: Value(songId),
      measureNumber: Value(measureNumber),
      label: Value(label),
    );
  }

  factory Cue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cue(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      measureNumber: serializer.fromJson<int>(json['measureNumber']),
      label: serializer.fromJson<String>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'measureNumber': serializer.toJson<int>(measureNumber),
      'label': serializer.toJson<String>(label),
    };
  }

  Cue copyWith({
    String? id,
    String? songId,
    int? measureNumber,
    String? label,
  }) => Cue(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    measureNumber: measureNumber ?? this.measureNumber,
    label: label ?? this.label,
  );
  Cue copyWithCompanion(CuesCompanion data) {
    return Cue(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      measureNumber: data.measureNumber.present
          ? data.measureNumber.value
          : this.measureNumber,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cue(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('measureNumber: $measureNumber, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, songId, measureNumber, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cue &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.measureNumber == this.measureNumber &&
          other.label == this.label);
}

class CuesCompanion extends UpdateCompanion<Cue> {
  final Value<String> id;
  final Value<String> songId;
  final Value<int> measureNumber;
  final Value<String> label;
  final Value<int> rowid;
  const CuesCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.measureNumber = const Value.absent(),
    this.label = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CuesCompanion.insert({
    required String id,
    required String songId,
    required int measureNumber,
    required String label,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       songId = Value(songId),
       measureNumber = Value(measureNumber),
       label = Value(label);
  static Insertable<Cue> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<int>? measureNumber,
    Expression<String>? label,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (measureNumber != null) 'measure_number': measureNumber,
      if (label != null) 'label': label,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CuesCompanion copyWith({
    Value<String>? id,
    Value<String>? songId,
    Value<int>? measureNumber,
    Value<String>? label,
    Value<int>? rowid,
  }) {
    return CuesCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      measureNumber: measureNumber ?? this.measureNumber,
      label: label ?? this.label,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (measureNumber.present) {
      map['measure_number'] = Variable<int>(measureNumber.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CuesCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('measureNumber: $measureNumber, ')
          ..write('label: $label, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeSessionsTable extends PracticeSessions
    with TableInfo<$PracticeSessionsTable, PracticeSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
    'song_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES songs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    songId,
    startedAt,
    endedAt,
    durationSeconds,
    bpm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(
        _songIdMeta,
        songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta),
      );
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    } else if (isInserting) {
      context.missing(_bpmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      songId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}song_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      )!,
    );
  }

  @override
  $PracticeSessionsTable createAlias(String alias) {
    return $PracticeSessionsTable(attachedDatabase, alias);
  }
}

class PracticeSession extends DataClass implements Insertable<PracticeSession> {
  final String id;
  final String songId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int bpm;
  const PracticeSession({
    required this.id,
    required this.songId,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.bpm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['bpm'] = Variable<int>(bpm);
    return map;
  }

  PracticeSessionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeSessionsCompanion(
      id: Value(id),
      songId: Value(songId),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      durationSeconds: Value(durationSeconds),
      bpm: Value(bpm),
    );
  }

  factory PracticeSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSession(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      bpm: serializer.fromJson<int>(json['bpm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'bpm': serializer.toJson<int>(bpm),
    };
  }

  PracticeSession copyWith({
    String? id,
    String? songId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    int? bpm,
  }) => PracticeSession(
    id: id ?? this.id,
    songId: songId ?? this.songId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    bpm: bpm ?? this.bpm,
  );
  PracticeSession copyWithCompanion(PracticeSessionsCompanion data) {
    return PracticeSession(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSession(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('bpm: $bpm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, songId, startedAt, endedAt, durationSeconds, bpm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSession &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.bpm == this.bpm);
}

class PracticeSessionsCompanion extends UpdateCompanion<PracticeSession> {
  final Value<String> id;
  final Value<String> songId;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<int> durationSeconds;
  final Value<int> bpm;
  final Value<int> rowid;
  const PracticeSessionsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.bpm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeSessionsCompanion.insert({
    required String id,
    required String songId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required int bpm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       songId = Value(songId),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       durationSeconds = Value(durationSeconds),
       bpm = Value(bpm);
  static Insertable<PracticeSession> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationSeconds,
    Expression<int>? bpm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (bpm != null) 'bpm': bpm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? songId,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<int>? durationSeconds,
    Value<int>? bpm,
    Value<int>? rowid,
  }) {
    return PracticeSessionsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      bpm: bpm ?? this.bpm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSessionsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('bpm: $bpm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $LabelsTable labels = $LabelsTable(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $SongLabelsTable songLabels = $SongLabelsTable(this);
  late final $SetlistsTable setlists = $SetlistsTable(this);
  late final $SetlistEntriesTable setlistEntries = $SetlistEntriesTable(this);
  late final $MeasuresTable measures = $MeasuresTable(this);
  late final $TempoMapsTable tempoMaps = $TempoMapsTable(this);
  late final $TimeSignatureMapsTable timeSignatureMaps =
      $TimeSignatureMapsTable(this);
  late final $AudioAnchorsTable audioAnchors = $AudioAnchorsTable(this);
  late final $CuesTable cues = $CuesTable(this);
  late final $PracticeSessionsTable practiceSessions = $PracticeSessionsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    labels,
    songs,
    songLabels,
    setlists,
    setlistEntries,
    measures,
    tempoMaps,
    timeSignatureMaps,
    audioAnchors,
    cues,
    practiceSessions,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('folders', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('songs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('song_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'labels',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('song_labels', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'setlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('setlist_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('setlist_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('measures', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tempo_maps', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('time_signature_maps', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('audio_anchors', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cues', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'songs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_sessions', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FoldersTableCreateCompanionBuilder =
    FoldersCompanion Function({
      required String id,
      required String name,
      required int color,
      Value<String?> parentId,
      Value<int> sortOrder,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FoldersTableUpdateCompanionBuilder =
    FoldersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> color,
      Value<String?> parentId,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FoldersTableReferences
    extends BaseReferences<_$AppDatabase, $FoldersTable, Folder> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _parentIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.folders.parentId, db.folders.id));

  $$FoldersTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SongsTable, List<Song>> _songsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.songs,
    aliasName: $_aliasNameGenerator(db.folders.id, db.songs.folderId),
  );

  $$SongsTableProcessedTableManager get songsRefs {
    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_songsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FoldersTableFilterComposer get parentId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> songsRefs(
    Expression<bool> Function($$SongsTableFilterComposer f) f,
  ) {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoldersTableOrderingComposer get parentId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FoldersTableAnnotationComposer get parentId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> songsRefs<T extends Object>(
    Expression<T> Function($$SongsTableAnnotationComposer a) f,
  ) {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, $$FoldersTableReferences),
          Folder,
          PrefetchHooks Function({bool parentId, bool songsRefs})
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                color: color,
                parentId: parentId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int color,
                Value<String?> parentId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                color: color,
                parentId: parentId,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({parentId = false, songsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (songsRefs) db.songs],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (parentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.parentId,
                                referencedTable: $$FoldersTableReferences
                                    ._parentIdTable(db),
                                referencedColumn: $$FoldersTableReferences
                                    ._parentIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (songsRefs)
                    await $_getPrefetchedData<Folder, $FoldersTable, Song>(
                      currentTable: table,
                      referencedTable: $$FoldersTableReferences._songsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$FoldersTableReferences(db, table, p0).songsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, $$FoldersTableReferences),
      Folder,
      PrefetchHooks Function({bool parentId, bool songsRefs})
    >;
typedef $$LabelsTableCreateCompanionBuilder =
    LabelsCompanion Function({
      required String id,
      required String name,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LabelsTableUpdateCompanionBuilder =
    LabelsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$LabelsTableReferences
    extends BaseReferences<_$AppDatabase, $LabelsTable, Label> {
  $$LabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SongLabelsTable, List<SongLabel>>
  _songLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.songLabels,
    aliasName: $_aliasNameGenerator(db.labels.id, db.songLabels.labelId),
  );

  $$SongLabelsTableProcessedTableManager get songLabelsRefs {
    final manager = $$SongLabelsTableTableManager(
      $_db,
      $_db.songLabels,
    ).filter((f) => f.labelId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_songLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LabelsTableFilterComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> songLabelsRefs(
    Expression<bool> Function($$SongLabelsTableFilterComposer f) f,
  ) {
    final $$SongLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songLabels,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongLabelsTableFilterComposer(
            $db: $db,
            $table: $db.songLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LabelsTable> {
  $$LabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> songLabelsRefs<T extends Object>(
    Expression<T> Function($$SongLabelsTableAnnotationComposer a) f,
  ) {
    final $$SongLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songLabels,
      getReferencedColumn: (t) => t.labelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.songLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LabelsTable,
          Label,
          $$LabelsTableFilterComposer,
          $$LabelsTableOrderingComposer,
          $$LabelsTableAnnotationComposer,
          $$LabelsTableCreateCompanionBuilder,
          $$LabelsTableUpdateCompanionBuilder,
          (Label, $$LabelsTableReferences),
          Label,
          PrefetchHooks Function({bool songLabelsRefs})
        > {
  $$LabelsTableTableManager(_$AppDatabase db, $LabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LabelsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LabelsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$LabelsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({songLabelsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (songLabelsRefs) db.songLabels],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (songLabelsRefs)
                    await $_getPrefetchedData<Label, $LabelsTable, SongLabel>(
                      currentTable: table,
                      referencedTable: $$LabelsTableReferences
                          ._songLabelsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LabelsTableReferences(db, table, p0).songLabelsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.labelId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LabelsTable,
      Label,
      $$LabelsTableFilterComposer,
      $$LabelsTableOrderingComposer,
      $$LabelsTableAnnotationComposer,
      $$LabelsTableCreateCompanionBuilder,
      $$LabelsTableUpdateCompanionBuilder,
      (Label, $$LabelsTableReferences),
      Label,
      PrefetchHooks Function({bool songLabelsRefs})
    >;
typedef $$SongsTableCreateCompanionBuilder =
    SongsCompanion Function({
      required String id,
      required String title,
      Value<String?> artist,
      Value<int?> defaultTempo,
      Value<int?> targetBpm,
      Value<String> scoreType,
      required String sourcePath,
      Value<String> sourceProvider,
      Value<String?> remoteUri,
      Value<DateTime?> remoteModifiedAt,
      Value<int?> remoteSize,
      Value<String?> syncStatus,
      Value<bool> offlineAvailable,
      Value<bool> isFavorite,
      Value<String?> note,
      Value<String?> audioPath,
      Value<String?> audioName,
      Value<String?> folderId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$SongsTableUpdateCompanionBuilder =
    SongsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> artist,
      Value<int?> defaultTempo,
      Value<int?> targetBpm,
      Value<String> scoreType,
      Value<String> sourcePath,
      Value<String> sourceProvider,
      Value<String?> remoteUri,
      Value<DateTime?> remoteModifiedAt,
      Value<int?> remoteSize,
      Value<String?> syncStatus,
      Value<bool> offlineAvailable,
      Value<bool> isFavorite,
      Value<String?> note,
      Value<String?> audioPath,
      Value<String?> audioName,
      Value<String?> folderId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });

final class $$SongsTableReferences
    extends BaseReferences<_$AppDatabase, $SongsTable, Song> {
  $$SongsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _folderIdTable(_$AppDatabase db) => db.folders
      .createAlias($_aliasNameGenerator(db.songs.folderId, db.folders.id));

  $$FoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SongLabelsTable, List<SongLabel>>
  _songLabelsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.songLabels,
    aliasName: $_aliasNameGenerator(db.songs.id, db.songLabels.songId),
  );

  $$SongLabelsTableProcessedTableManager get songLabelsRefs {
    final manager = $$SongLabelsTableTableManager(
      $_db,
      $_db.songLabels,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_songLabelsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SetlistEntriesTable, List<SetlistEntry>>
  _setlistEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setlistEntries,
    aliasName: $_aliasNameGenerator(db.songs.id, db.setlistEntries.songId),
  );

  $$SetlistEntriesTableProcessedTableManager get setlistEntriesRefs {
    final manager = $$SetlistEntriesTableTableManager(
      $_db,
      $_db.setlistEntries,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setlistEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MeasuresTable, List<Measure>> _measuresRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.measures,
    aliasName: $_aliasNameGenerator(db.songs.id, db.measures.songId),
  );

  $$MeasuresTableProcessedTableManager get measuresRefs {
    final manager = $$MeasuresTableTableManager(
      $_db,
      $_db.measures,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_measuresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TempoMapsTable, List<TempoMap>>
  _tempoMapsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tempoMaps,
    aliasName: $_aliasNameGenerator(db.songs.id, db.tempoMaps.songId),
  );

  $$TempoMapsTableProcessedTableManager get tempoMapsRefs {
    final manager = $$TempoMapsTableTableManager(
      $_db,
      $_db.tempoMaps,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tempoMapsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TimeSignatureMapsTable, List<TimeSignatureMap>>
  _timeSignatureMapsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.timeSignatureMaps,
        aliasName: $_aliasNameGenerator(
          db.songs.id,
          db.timeSignatureMaps.songId,
        ),
      );

  $$TimeSignatureMapsTableProcessedTableManager get timeSignatureMapsRefs {
    final manager = $$TimeSignatureMapsTableTableManager(
      $_db,
      $_db.timeSignatureMaps,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _timeSignatureMapsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AudioAnchorsTable, List<AudioAnchor>>
  _audioAnchorsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.audioAnchors,
    aliasName: $_aliasNameGenerator(db.songs.id, db.audioAnchors.songId),
  );

  $$AudioAnchorsTableProcessedTableManager get audioAnchorsRefs {
    final manager = $$AudioAnchorsTableTableManager(
      $_db,
      $_db.audioAnchors,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_audioAnchorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CuesTable, List<Cue>> _cuesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cues,
    aliasName: $_aliasNameGenerator(db.songs.id, db.cues.songId),
  );

  $$CuesTableProcessedTableManager get cuesRefs {
    final manager = $$CuesTableTableManager(
      $_db,
      $_db.cues,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cuesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PracticeSessionsTable, List<PracticeSession>>
  _practiceSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.practiceSessions,
    aliasName: $_aliasNameGenerator(db.songs.id, db.practiceSessions.songId),
  );

  $$PracticeSessionsTableProcessedTableManager get practiceSessionsRefs {
    final manager = $$PracticeSessionsTableTableManager(
      $_db,
      $_db.practiceSessions,
    ).filter((f) => f.songId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _practiceSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultTempo => $composableBuilder(
    column: $table.defaultTempo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetBpm => $composableBuilder(
    column: $table.targetBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoreType => $composableBuilder(
    column: $table.scoreType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceProvider => $composableBuilder(
    column: $table.sourceProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUri => $composableBuilder(
    column: $table.remoteUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get remoteModifiedAt => $composableBuilder(
    column: $table.remoteModifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteSize => $composableBuilder(
    column: $table.remoteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get offlineAvailable => $composableBuilder(
    column: $table.offlineAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioName => $composableBuilder(
    column: $table.audioName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> songLabelsRefs(
    Expression<bool> Function($$SongLabelsTableFilterComposer f) f,
  ) {
    final $$SongLabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songLabels,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongLabelsTableFilterComposer(
            $db: $db,
            $table: $db.songLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> setlistEntriesRefs(
    Expression<bool> Function($$SetlistEntriesTableFilterComposer f) f,
  ) {
    final $$SetlistEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setlistEntries,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistEntriesTableFilterComposer(
            $db: $db,
            $table: $db.setlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> measuresRefs(
    Expression<bool> Function($$MeasuresTableFilterComposer f) f,
  ) {
    final $$MeasuresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.measures,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeasuresTableFilterComposer(
            $db: $db,
            $table: $db.measures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tempoMapsRefs(
    Expression<bool> Function($$TempoMapsTableFilterComposer f) f,
  ) {
    final $$TempoMapsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tempoMaps,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TempoMapsTableFilterComposer(
            $db: $db,
            $table: $db.tempoMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> timeSignatureMapsRefs(
    Expression<bool> Function($$TimeSignatureMapsTableFilterComposer f) f,
  ) {
    final $$TimeSignatureMapsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeSignatureMaps,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeSignatureMapsTableFilterComposer(
            $db: $db,
            $table: $db.timeSignatureMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> audioAnchorsRefs(
    Expression<bool> Function($$AudioAnchorsTableFilterComposer f) f,
  ) {
    final $$AudioAnchorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioAnchors,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioAnchorsTableFilterComposer(
            $db: $db,
            $table: $db.audioAnchors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cuesRefs(
    Expression<bool> Function($$CuesTableFilterComposer f) f,
  ) {
    final $$CuesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cues,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuesTableFilterComposer(
            $db: $db,
            $table: $db.cues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> practiceSessionsRefs(
    Expression<bool> Function($$PracticeSessionsTableFilterComposer f) f,
  ) {
    final $$PracticeSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableFilterComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultTempo => $composableBuilder(
    column: $table.defaultTempo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetBpm => $composableBuilder(
    column: $table.targetBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoreType => $composableBuilder(
    column: $table.scoreType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceProvider => $composableBuilder(
    column: $table.sourceProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUri => $composableBuilder(
    column: $table.remoteUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get remoteModifiedAt => $composableBuilder(
    column: $table.remoteModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteSize => $composableBuilder(
    column: $table.remoteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get offlineAvailable => $composableBuilder(
    column: $table.offlineAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioName => $composableBuilder(
    column: $table.audioName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<int> get defaultTempo => $composableBuilder(
    column: $table.defaultTempo,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetBpm =>
      $composableBuilder(column: $table.targetBpm, builder: (column) => column);

  GeneratedColumn<String> get scoreType =>
      $composableBuilder(column: $table.scoreType, builder: (column) => column);

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceProvider => $composableBuilder(
    column: $table.sourceProvider,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteUri =>
      $composableBuilder(column: $table.remoteUri, builder: (column) => column);

  GeneratedColumn<DateTime> get remoteModifiedAt => $composableBuilder(
    column: $table.remoteModifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remoteSize => $composableBuilder(
    column: $table.remoteSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get offlineAvailable => $composableBuilder(
    column: $table.offlineAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get audioName =>
      $composableBuilder(column: $table.audioName, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> songLabelsRefs<T extends Object>(
    Expression<T> Function($$SongLabelsTableAnnotationComposer a) f,
  ) {
    final $$SongLabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.songLabels,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongLabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.songLabels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> setlistEntriesRefs<T extends Object>(
    Expression<T> Function($$SetlistEntriesTableAnnotationComposer a) f,
  ) {
    final $$SetlistEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setlistEntries,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.setlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> measuresRefs<T extends Object>(
    Expression<T> Function($$MeasuresTableAnnotationComposer a) f,
  ) {
    final $$MeasuresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.measures,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MeasuresTableAnnotationComposer(
            $db: $db,
            $table: $db.measures,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tempoMapsRefs<T extends Object>(
    Expression<T> Function($$TempoMapsTableAnnotationComposer a) f,
  ) {
    final $$TempoMapsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tempoMaps,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TempoMapsTableAnnotationComposer(
            $db: $db,
            $table: $db.tempoMaps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> timeSignatureMapsRefs<T extends Object>(
    Expression<T> Function($$TimeSignatureMapsTableAnnotationComposer a) f,
  ) {
    final $$TimeSignatureMapsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.timeSignatureMaps,
          getReferencedColumn: (t) => t.songId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TimeSignatureMapsTableAnnotationComposer(
                $db: $db,
                $table: $db.timeSignatureMaps,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> audioAnchorsRefs<T extends Object>(
    Expression<T> Function($$AudioAnchorsTableAnnotationComposer a) f,
  ) {
    final $$AudioAnchorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.audioAnchors,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AudioAnchorsTableAnnotationComposer(
            $db: $db,
            $table: $db.audioAnchors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cuesRefs<T extends Object>(
    Expression<T> Function($$CuesTableAnnotationComposer a) f,
  ) {
    final $$CuesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cues,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CuesTableAnnotationComposer(
            $db: $db,
            $table: $db.cues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> practiceSessionsRefs<T extends Object>(
    Expression<T> Function($$PracticeSessionsTableAnnotationComposer a) f,
  ) {
    final $$PracticeSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.songId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SongsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongsTable,
          Song,
          $$SongsTableFilterComposer,
          $$SongsTableOrderingComposer,
          $$SongsTableAnnotationComposer,
          $$SongsTableCreateCompanionBuilder,
          $$SongsTableUpdateCompanionBuilder,
          (Song, $$SongsTableReferences),
          Song,
          PrefetchHooks Function({
            bool folderId,
            bool songLabelsRefs,
            bool setlistEntriesRefs,
            bool measuresRefs,
            bool tempoMapsRefs,
            bool timeSignatureMapsRefs,
            bool audioAnchorsRefs,
            bool cuesRefs,
            bool practiceSessionsRefs,
          })
        > {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<int?> defaultTempo = const Value.absent(),
                Value<int?> targetBpm = const Value.absent(),
                Value<String> scoreType = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String> sourceProvider = const Value.absent(),
                Value<String?> remoteUri = const Value.absent(),
                Value<DateTime?> remoteModifiedAt = const Value.absent(),
                Value<int?> remoteSize = const Value.absent(),
                Value<String?> syncStatus = const Value.absent(),
                Value<bool> offlineAvailable = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> audioName = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion(
                id: id,
                title: title,
                artist: artist,
                defaultTempo: defaultTempo,
                targetBpm: targetBpm,
                scoreType: scoreType,
                sourcePath: sourcePath,
                sourceProvider: sourceProvider,
                remoteUri: remoteUri,
                remoteModifiedAt: remoteModifiedAt,
                remoteSize: remoteSize,
                syncStatus: syncStatus,
                offlineAvailable: offlineAvailable,
                isFavorite: isFavorite,
                note: note,
                audioPath: audioPath,
                audioName: audioName,
                folderId: folderId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<int?> defaultTempo = const Value.absent(),
                Value<int?> targetBpm = const Value.absent(),
                Value<String> scoreType = const Value.absent(),
                required String sourcePath,
                Value<String> sourceProvider = const Value.absent(),
                Value<String?> remoteUri = const Value.absent(),
                Value<DateTime?> remoteModifiedAt = const Value.absent(),
                Value<int?> remoteSize = const Value.absent(),
                Value<String?> syncStatus = const Value.absent(),
                Value<bool> offlineAvailable = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> audioName = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongsCompanion.insert(
                id: id,
                title: title,
                artist: artist,
                defaultTempo: defaultTempo,
                targetBpm: targetBpm,
                scoreType: scoreType,
                sourcePath: sourcePath,
                sourceProvider: sourceProvider,
                remoteUri: remoteUri,
                remoteModifiedAt: remoteModifiedAt,
                remoteSize: remoteSize,
                syncStatus: syncStatus,
                offlineAvailable: offlineAvailable,
                isFavorite: isFavorite,
                note: note,
                audioPath: audioPath,
                audioName: audioName,
                folderId: folderId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SongsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                folderId = false,
                songLabelsRefs = false,
                setlistEntriesRefs = false,
                measuresRefs = false,
                tempoMapsRefs = false,
                timeSignatureMapsRefs = false,
                audioAnchorsRefs = false,
                cuesRefs = false,
                practiceSessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (songLabelsRefs) db.songLabels,
                    if (setlistEntriesRefs) db.setlistEntries,
                    if (measuresRefs) db.measures,
                    if (tempoMapsRefs) db.tempoMaps,
                    if (timeSignatureMapsRefs) db.timeSignatureMaps,
                    if (audioAnchorsRefs) db.audioAnchors,
                    if (cuesRefs) db.cues,
                    if (practiceSessionsRefs) db.practiceSessions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (folderId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.folderId,
                                    referencedTable: $$SongsTableReferences
                                        ._folderIdTable(db),
                                    referencedColumn: $$SongsTableReferences
                                        ._folderIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (songLabelsRefs)
                        await $_getPrefetchedData<Song, $SongsTable, SongLabel>(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._songLabelsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).songLabelsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (setlistEntriesRefs)
                        await $_getPrefetchedData<
                          Song,
                          $SongsTable,
                          SetlistEntry
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._setlistEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).setlistEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (measuresRefs)
                        await $_getPrefetchedData<Song, $SongsTable, Measure>(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._measuresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).measuresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tempoMapsRefs)
                        await $_getPrefetchedData<Song, $SongsTable, TempoMap>(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._tempoMapsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).tempoMapsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (timeSignatureMapsRefs)
                        await $_getPrefetchedData<
                          Song,
                          $SongsTable,
                          TimeSignatureMap
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._timeSignatureMapsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).timeSignatureMapsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (audioAnchorsRefs)
                        await $_getPrefetchedData<
                          Song,
                          $SongsTable,
                          AudioAnchor
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._audioAnchorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).audioAnchorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cuesRefs)
                        await $_getPrefetchedData<Song, $SongsTable, Cue>(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._cuesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(db, table, p0).cuesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (practiceSessionsRefs)
                        await $_getPrefetchedData<
                          Song,
                          $SongsTable,
                          PracticeSession
                        >(
                          currentTable: table,
                          referencedTable: $$SongsTableReferences
                              ._practiceSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SongsTableReferences(
                                db,
                                table,
                                p0,
                              ).practiceSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.songId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SongsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongsTable,
      Song,
      $$SongsTableFilterComposer,
      $$SongsTableOrderingComposer,
      $$SongsTableAnnotationComposer,
      $$SongsTableCreateCompanionBuilder,
      $$SongsTableUpdateCompanionBuilder,
      (Song, $$SongsTableReferences),
      Song,
      PrefetchHooks Function({
        bool folderId,
        bool songLabelsRefs,
        bool setlistEntriesRefs,
        bool measuresRefs,
        bool tempoMapsRefs,
        bool timeSignatureMapsRefs,
        bool audioAnchorsRefs,
        bool cuesRefs,
        bool practiceSessionsRefs,
      })
    >;
typedef $$SongLabelsTableCreateCompanionBuilder =
    SongLabelsCompanion Function({
      required String songId,
      required String labelId,
      Value<int> rowid,
    });
typedef $$SongLabelsTableUpdateCompanionBuilder =
    SongLabelsCompanion Function({
      Value<String> songId,
      Value<String> labelId,
      Value<int> rowid,
    });

final class $$SongLabelsTableReferences
    extends BaseReferences<_$AppDatabase, $SongLabelsTable, SongLabel> {
  $$SongLabelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.songLabels.songId, db.songs.id),
  );

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LabelsTable _labelIdTable(_$AppDatabase db) => db.labels.createAlias(
    $_aliasNameGenerator(db.songLabels.labelId, db.labels.id),
  );

  $$LabelsTableProcessedTableManager get labelId {
    final $_column = $_itemColumn<String>('label_id')!;

    final manager = $$LabelsTableTableManager(
      $_db,
      $_db.labels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_labelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SongLabelsTableFilterComposer
    extends Composer<_$AppDatabase, $SongLabelsTable> {
  $$SongLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableFilterComposer get labelId {
    final $$LabelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableFilterComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongLabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongLabelsTable> {
  $$SongLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableOrderingComposer get labelId {
    final $$LabelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableOrderingComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongLabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongLabelsTable> {
  $$SongLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LabelsTableAnnotationComposer get labelId {
    final $$LabelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.labelId,
      referencedTable: $db.labels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LabelsTableAnnotationComposer(
            $db: $db,
            $table: $db.labels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SongLabelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SongLabelsTable,
          SongLabel,
          $$SongLabelsTableFilterComposer,
          $$SongLabelsTableOrderingComposer,
          $$SongLabelsTableAnnotationComposer,
          $$SongLabelsTableCreateCompanionBuilder,
          $$SongLabelsTableUpdateCompanionBuilder,
          (SongLabel, $$SongLabelsTableReferences),
          SongLabel,
          PrefetchHooks Function({bool songId, bool labelId})
        > {
  $$SongLabelsTableTableManager(_$AppDatabase db, $SongLabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongLabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongLabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongLabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> songId = const Value.absent(),
                Value<String> labelId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SongLabelsCompanion(
                songId: songId,
                labelId: labelId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String songId,
                required String labelId,
                Value<int> rowid = const Value.absent(),
              }) => SongLabelsCompanion.insert(
                songId: songId,
                labelId: labelId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SongLabelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false, labelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$SongLabelsTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$SongLabelsTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (labelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.labelId,
                                referencedTable: $$SongLabelsTableReferences
                                    ._labelIdTable(db),
                                referencedColumn: $$SongLabelsTableReferences
                                    ._labelIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SongLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SongLabelsTable,
      SongLabel,
      $$SongLabelsTableFilterComposer,
      $$SongLabelsTableOrderingComposer,
      $$SongLabelsTableAnnotationComposer,
      $$SongLabelsTableCreateCompanionBuilder,
      $$SongLabelsTableUpdateCompanionBuilder,
      (SongLabel, $$SongLabelsTableReferences),
      SongLabel,
      PrefetchHooks Function({bool songId, bool labelId})
    >;
typedef $$SetlistsTableCreateCompanionBuilder =
    SetlistsCompanion Function({
      required String id,
      required String title,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SetlistsTableUpdateCompanionBuilder =
    SetlistsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$SetlistsTableReferences
    extends BaseReferences<_$AppDatabase, $SetlistsTable, Setlist> {
  $$SetlistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SetlistEntriesTable, List<SetlistEntry>>
  _setlistEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.setlistEntries,
    aliasName: $_aliasNameGenerator(
      db.setlists.id,
      db.setlistEntries.setlistId,
    ),
  );

  $$SetlistEntriesTableProcessedTableManager get setlistEntriesRefs {
    final manager = $$SetlistEntriesTableTableManager(
      $_db,
      $_db.setlistEntries,
    ).filter((f) => f.setlistId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_setlistEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SetlistsTableFilterComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> setlistEntriesRefs(
    Expression<bool> Function($$SetlistEntriesTableFilterComposer f) f,
  ) {
    final $$SetlistEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setlistEntries,
      getReferencedColumn: (t) => t.setlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistEntriesTableFilterComposer(
            $db: $db,
            $table: $db.setlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SetlistsTableOrderingComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SetlistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> setlistEntriesRefs<T extends Object>(
    Expression<T> Function($$SetlistEntriesTableAnnotationComposer a) f,
  ) {
    final $$SetlistEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setlistEntries,
      getReferencedColumn: (t) => t.setlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.setlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SetlistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetlistsTable,
          Setlist,
          $$SetlistsTableFilterComposer,
          $$SetlistsTableOrderingComposer,
          $$SetlistsTableAnnotationComposer,
          $$SetlistsTableCreateCompanionBuilder,
          $$SetlistsTableUpdateCompanionBuilder,
          (Setlist, $$SetlistsTableReferences),
          Setlist,
          PrefetchHooks Function({bool setlistEntriesRefs})
        > {
  $$SetlistsTableTableManager(_$AppDatabase db, $SetlistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetlistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetlistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetlistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetlistsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SetlistsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetlistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setlistEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (setlistEntriesRefs) db.setlistEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (setlistEntriesRefs)
                    await $_getPrefetchedData<
                      Setlist,
                      $SetlistsTable,
                      SetlistEntry
                    >(
                      currentTable: table,
                      referencedTable: $$SetlistsTableReferences
                          ._setlistEntriesRefsTable(db),
                      managerFromTypedResult: (p0) => $$SetlistsTableReferences(
                        db,
                        table,
                        p0,
                      ).setlistEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.setlistId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SetlistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetlistsTable,
      Setlist,
      $$SetlistsTableFilterComposer,
      $$SetlistsTableOrderingComposer,
      $$SetlistsTableAnnotationComposer,
      $$SetlistsTableCreateCompanionBuilder,
      $$SetlistsTableUpdateCompanionBuilder,
      (Setlist, $$SetlistsTableReferences),
      Setlist,
      PrefetchHooks Function({bool setlistEntriesRefs})
    >;
typedef $$SetlistEntriesTableCreateCompanionBuilder =
    SetlistEntriesCompanion Function({
      required String id,
      required String setlistId,
      required String songId,
      required int position,
      Value<int?> tempoOverride,
      Value<String?> metronomeJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SetlistEntriesTableUpdateCompanionBuilder =
    SetlistEntriesCompanion Function({
      Value<String> id,
      Value<String> setlistId,
      Value<String> songId,
      Value<int> position,
      Value<int?> tempoOverride,
      Value<String?> metronomeJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SetlistEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $SetlistEntriesTable, SetlistEntry> {
  $$SetlistEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SetlistsTable _setlistIdTable(_$AppDatabase db) =>
      db.setlists.createAlias(
        $_aliasNameGenerator(db.setlistEntries.setlistId, db.setlists.id),
      );

  $$SetlistsTableProcessedTableManager get setlistId {
    final $_column = $_itemColumn<String>('setlist_id')!;

    final manager = $$SetlistsTableTableManager(
      $_db,
      $_db.setlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_setlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.setlistEntries.songId, db.songs.id),
  );

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetlistEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SetlistEntriesTable> {
  $$SetlistEntriesTableFilterComposer({
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

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tempoOverride => $composableBuilder(
    column: $table.tempoOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metronomeJson => $composableBuilder(
    column: $table.metronomeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SetlistsTableFilterComposer get setlistId {
    final $$SetlistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setlistId,
      referencedTable: $db.setlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistsTableFilterComposer(
            $db: $db,
            $table: $db.setlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetlistEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SetlistEntriesTable> {
  $$SetlistEntriesTableOrderingComposer({
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

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tempoOverride => $composableBuilder(
    column: $table.tempoOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metronomeJson => $composableBuilder(
    column: $table.metronomeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SetlistsTableOrderingComposer get setlistId {
    final $$SetlistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setlistId,
      referencedTable: $db.setlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistsTableOrderingComposer(
            $db: $db,
            $table: $db.setlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetlistEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetlistEntriesTable> {
  $$SetlistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get tempoOverride => $composableBuilder(
    column: $table.tempoOverride,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metronomeJson => $composableBuilder(
    column: $table.metronomeJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SetlistsTableAnnotationComposer get setlistId {
    final $$SetlistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.setlistId,
      referencedTable: $db.setlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetlistsTableAnnotationComposer(
            $db: $db,
            $table: $db.setlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetlistEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetlistEntriesTable,
          SetlistEntry,
          $$SetlistEntriesTableFilterComposer,
          $$SetlistEntriesTableOrderingComposer,
          $$SetlistEntriesTableAnnotationComposer,
          $$SetlistEntriesTableCreateCompanionBuilder,
          $$SetlistEntriesTableUpdateCompanionBuilder,
          (SetlistEntry, $$SetlistEntriesTableReferences),
          SetlistEntry,
          PrefetchHooks Function({bool setlistId, bool songId})
        > {
  $$SetlistEntriesTableTableManager(
    _$AppDatabase db,
    $SetlistEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetlistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetlistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetlistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> setlistId = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> tempoOverride = const Value.absent(),
                Value<String?> metronomeJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetlistEntriesCompanion(
                id: id,
                setlistId: setlistId,
                songId: songId,
                position: position,
                tempoOverride: tempoOverride,
                metronomeJson: metronomeJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String setlistId,
                required String songId,
                required int position,
                Value<int?> tempoOverride = const Value.absent(),
                Value<String?> metronomeJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SetlistEntriesCompanion.insert(
                id: id,
                setlistId: setlistId,
                songId: songId,
                position: position,
                tempoOverride: tempoOverride,
                metronomeJson: metronomeJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetlistEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setlistId = false, songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (setlistId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.setlistId,
                                referencedTable: $$SetlistEntriesTableReferences
                                    ._setlistIdTable(db),
                                referencedColumn:
                                    $$SetlistEntriesTableReferences
                                        ._setlistIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$SetlistEntriesTableReferences
                                    ._songIdTable(db),
                                referencedColumn:
                                    $$SetlistEntriesTableReferences
                                        ._songIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SetlistEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetlistEntriesTable,
      SetlistEntry,
      $$SetlistEntriesTableFilterComposer,
      $$SetlistEntriesTableOrderingComposer,
      $$SetlistEntriesTableAnnotationComposer,
      $$SetlistEntriesTableCreateCompanionBuilder,
      $$SetlistEntriesTableUpdateCompanionBuilder,
      (SetlistEntry, $$SetlistEntriesTableReferences),
      SetlistEntry,
      PrefetchHooks Function({bool setlistId, bool songId})
    >;
typedef $$MeasuresTableCreateCompanionBuilder =
    MeasuresCompanion Function({
      required String id,
      required String songId,
      required int number,
      required int page,
      required double x,
      required double y,
      required double width,
      required double height,
      Value<String?> section,
      Value<bool> isDifficult,
      Value<int> rowid,
    });
typedef $$MeasuresTableUpdateCompanionBuilder =
    MeasuresCompanion Function({
      Value<String> id,
      Value<String> songId,
      Value<int> number,
      Value<int> page,
      Value<double> x,
      Value<double> y,
      Value<double> width,
      Value<double> height,
      Value<String?> section,
      Value<bool> isDifficult,
      Value<int> rowid,
    });

final class $$MeasuresTableReferences
    extends BaseReferences<_$AppDatabase, $MeasuresTable, Measure> {
  $$MeasuresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.measures.songId, db.songs.id),
  );

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MeasuresTableFilterComposer
    extends Composer<_$AppDatabase, $MeasuresTable> {
  $$MeasuresTableFilterComposer({
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

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDifficult => $composableBuilder(
    column: $table.isDifficult,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeasuresTableOrderingComposer
    extends Composer<_$AppDatabase, $MeasuresTable> {
  $$MeasuresTableOrderingComposer({
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

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get x => $composableBuilder(
    column: $table.x,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get y => $composableBuilder(
    column: $table.y,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDifficult => $composableBuilder(
    column: $table.isDifficult,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeasuresTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeasuresTable> {
  $$MeasuresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<double> get x =>
      $composableBuilder(column: $table.x, builder: (column) => column);

  GeneratedColumn<double> get y =>
      $composableBuilder(column: $table.y, builder: (column) => column);

  GeneratedColumn<double> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<bool> get isDifficult => $composableBuilder(
    column: $table.isDifficult,
    builder: (column) => column,
  );

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MeasuresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeasuresTable,
          Measure,
          $$MeasuresTableFilterComposer,
          $$MeasuresTableOrderingComposer,
          $$MeasuresTableAnnotationComposer,
          $$MeasuresTableCreateCompanionBuilder,
          $$MeasuresTableUpdateCompanionBuilder,
          (Measure, $$MeasuresTableReferences),
          Measure,
          PrefetchHooks Function({bool songId})
        > {
  $$MeasuresTableTableManager(_$AppDatabase db, $MeasuresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeasuresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeasuresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeasuresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<double> x = const Value.absent(),
                Value<double> y = const Value.absent(),
                Value<double> width = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<String?> section = const Value.absent(),
                Value<bool> isDifficult = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeasuresCompanion(
                id: id,
                songId: songId,
                number: number,
                page: page,
                x: x,
                y: y,
                width: width,
                height: height,
                section: section,
                isDifficult: isDifficult,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String songId,
                required int number,
                required int page,
                required double x,
                required double y,
                required double width,
                required double height,
                Value<String?> section = const Value.absent(),
                Value<bool> isDifficult = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeasuresCompanion.insert(
                id: id,
                songId: songId,
                number: number,
                page: page,
                x: x,
                y: y,
                width: width,
                height: height,
                section: section,
                isDifficult: isDifficult,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MeasuresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$MeasuresTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$MeasuresTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MeasuresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeasuresTable,
      Measure,
      $$MeasuresTableFilterComposer,
      $$MeasuresTableOrderingComposer,
      $$MeasuresTableAnnotationComposer,
      $$MeasuresTableCreateCompanionBuilder,
      $$MeasuresTableUpdateCompanionBuilder,
      (Measure, $$MeasuresTableReferences),
      Measure,
      PrefetchHooks Function({bool songId})
    >;
typedef $$TempoMapsTableCreateCompanionBuilder =
    TempoMapsCompanion Function({
      required String id,
      required String songId,
      required int startMeasure,
      required int endMeasure,
      required String mode,
      required int startBpm,
      Value<int?> endBpm,
      Value<int> rowid,
    });
typedef $$TempoMapsTableUpdateCompanionBuilder =
    TempoMapsCompanion Function({
      Value<String> id,
      Value<String> songId,
      Value<int> startMeasure,
      Value<int> endMeasure,
      Value<String> mode,
      Value<int> startBpm,
      Value<int?> endBpm,
      Value<int> rowid,
    });

final class $$TempoMapsTableReferences
    extends BaseReferences<_$AppDatabase, $TempoMapsTable, TempoMap> {
  $$TempoMapsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.tempoMaps.songId, db.songs.id),
  );

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TempoMapsTableFilterComposer
    extends Composer<_$AppDatabase, $TempoMapsTable> {
  $$TempoMapsTableFilterComposer({
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

  ColumnFilters<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startBpm => $composableBuilder(
    column: $table.startBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endBpm => $composableBuilder(
    column: $table.endBpm,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TempoMapsTableOrderingComposer
    extends Composer<_$AppDatabase, $TempoMapsTable> {
  $$TempoMapsTableOrderingComposer({
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

  ColumnOrderings<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startBpm => $composableBuilder(
    column: $table.startBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endBpm => $composableBuilder(
    column: $table.endBpm,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TempoMapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TempoMapsTable> {
  $$TempoMapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get startBpm =>
      $composableBuilder(column: $table.startBpm, builder: (column) => column);

  GeneratedColumn<int> get endBpm =>
      $composableBuilder(column: $table.endBpm, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TempoMapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TempoMapsTable,
          TempoMap,
          $$TempoMapsTableFilterComposer,
          $$TempoMapsTableOrderingComposer,
          $$TempoMapsTableAnnotationComposer,
          $$TempoMapsTableCreateCompanionBuilder,
          $$TempoMapsTableUpdateCompanionBuilder,
          (TempoMap, $$TempoMapsTableReferences),
          TempoMap,
          PrefetchHooks Function({bool songId})
        > {
  $$TempoMapsTableTableManager(_$AppDatabase db, $TempoMapsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TempoMapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TempoMapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TempoMapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> startMeasure = const Value.absent(),
                Value<int> endMeasure = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> startBpm = const Value.absent(),
                Value<int?> endBpm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TempoMapsCompanion(
                id: id,
                songId: songId,
                startMeasure: startMeasure,
                endMeasure: endMeasure,
                mode: mode,
                startBpm: startBpm,
                endBpm: endBpm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String songId,
                required int startMeasure,
                required int endMeasure,
                required String mode,
                required int startBpm,
                Value<int?> endBpm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TempoMapsCompanion.insert(
                id: id,
                songId: songId,
                startMeasure: startMeasure,
                endMeasure: endMeasure,
                mode: mode,
                startBpm: startBpm,
                endBpm: endBpm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TempoMapsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$TempoMapsTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$TempoMapsTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TempoMapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TempoMapsTable,
      TempoMap,
      $$TempoMapsTableFilterComposer,
      $$TempoMapsTableOrderingComposer,
      $$TempoMapsTableAnnotationComposer,
      $$TempoMapsTableCreateCompanionBuilder,
      $$TempoMapsTableUpdateCompanionBuilder,
      (TempoMap, $$TempoMapsTableReferences),
      TempoMap,
      PrefetchHooks Function({bool songId})
    >;
typedef $$TimeSignatureMapsTableCreateCompanionBuilder =
    TimeSignatureMapsCompanion Function({
      required String id,
      required String songId,
      required int startMeasure,
      required int endMeasure,
      required int numerator,
      required int denominator,
      Value<int> rowid,
    });
typedef $$TimeSignatureMapsTableUpdateCompanionBuilder =
    TimeSignatureMapsCompanion Function({
      Value<String> id,
      Value<String> songId,
      Value<int> startMeasure,
      Value<int> endMeasure,
      Value<int> numerator,
      Value<int> denominator,
      Value<int> rowid,
    });

final class $$TimeSignatureMapsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TimeSignatureMapsTable,
          TimeSignatureMap
        > {
  $$TimeSignatureMapsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.timeSignatureMaps.songId, db.songs.id),
  );

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimeSignatureMapsTableFilterComposer
    extends Composer<_$AppDatabase, $TimeSignatureMapsTable> {
  $$TimeSignatureMapsTableFilterComposer({
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

  ColumnFilters<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numerator => $composableBuilder(
    column: $table.numerator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get denominator => $composableBuilder(
    column: $table.denominator,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeSignatureMapsTableOrderingComposer
    extends Composer<_$AppDatabase, $TimeSignatureMapsTable> {
  $$TimeSignatureMapsTableOrderingComposer({
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

  ColumnOrderings<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numerator => $composableBuilder(
    column: $table.numerator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get denominator => $composableBuilder(
    column: $table.denominator,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeSignatureMapsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimeSignatureMapsTable> {
  $$TimeSignatureMapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startMeasure => $composableBuilder(
    column: $table.startMeasure,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMeasure => $composableBuilder(
    column: $table.endMeasure,
    builder: (column) => column,
  );

  GeneratedColumn<int> get numerator =>
      $composableBuilder(column: $table.numerator, builder: (column) => column);

  GeneratedColumn<int> get denominator => $composableBuilder(
    column: $table.denominator,
    builder: (column) => column,
  );

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeSignatureMapsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimeSignatureMapsTable,
          TimeSignatureMap,
          $$TimeSignatureMapsTableFilterComposer,
          $$TimeSignatureMapsTableOrderingComposer,
          $$TimeSignatureMapsTableAnnotationComposer,
          $$TimeSignatureMapsTableCreateCompanionBuilder,
          $$TimeSignatureMapsTableUpdateCompanionBuilder,
          (TimeSignatureMap, $$TimeSignatureMapsTableReferences),
          TimeSignatureMap,
          PrefetchHooks Function({bool songId})
        > {
  $$TimeSignatureMapsTableTableManager(
    _$AppDatabase db,
    $TimeSignatureMapsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimeSignatureMapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimeSignatureMapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimeSignatureMapsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> startMeasure = const Value.absent(),
                Value<int> endMeasure = const Value.absent(),
                Value<int> numerator = const Value.absent(),
                Value<int> denominator = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TimeSignatureMapsCompanion(
                id: id,
                songId: songId,
                startMeasure: startMeasure,
                endMeasure: endMeasure,
                numerator: numerator,
                denominator: denominator,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String songId,
                required int startMeasure,
                required int endMeasure,
                required int numerator,
                required int denominator,
                Value<int> rowid = const Value.absent(),
              }) => TimeSignatureMapsCompanion.insert(
                id: id,
                songId: songId,
                startMeasure: startMeasure,
                endMeasure: endMeasure,
                numerator: numerator,
                denominator: denominator,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TimeSignatureMapsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable:
                                    $$TimeSignatureMapsTableReferences
                                        ._songIdTable(db),
                                referencedColumn:
                                    $$TimeSignatureMapsTableReferences
                                        ._songIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TimeSignatureMapsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimeSignatureMapsTable,
      TimeSignatureMap,
      $$TimeSignatureMapsTableFilterComposer,
      $$TimeSignatureMapsTableOrderingComposer,
      $$TimeSignatureMapsTableAnnotationComposer,
      $$TimeSignatureMapsTableCreateCompanionBuilder,
      $$TimeSignatureMapsTableUpdateCompanionBuilder,
      (TimeSignatureMap, $$TimeSignatureMapsTableReferences),
      TimeSignatureMap,
      PrefetchHooks Function({bool songId})
    >;
typedef $$AudioAnchorsTableCreateCompanionBuilder =
    AudioAnchorsCompanion Function({
      required String id,
      required String songId,
      required int measureNumber,
      required double audioTime,
      Value<int> rowid,
    });
typedef $$AudioAnchorsTableUpdateCompanionBuilder =
    AudioAnchorsCompanion Function({
      Value<String> id,
      Value<String> songId,
      Value<int> measureNumber,
      Value<double> audioTime,
      Value<int> rowid,
    });

final class $$AudioAnchorsTableReferences
    extends BaseReferences<_$AppDatabase, $AudioAnchorsTable, AudioAnchor> {
  $$AudioAnchorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.audioAnchors.songId, db.songs.id),
  );

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AudioAnchorsTableFilterComposer
    extends Composer<_$AppDatabase, $AudioAnchorsTable> {
  $$AudioAnchorsTableFilterComposer({
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

  ColumnFilters<int> get measureNumber => $composableBuilder(
    column: $table.measureNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get audioTime => $composableBuilder(
    column: $table.audioTime,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioAnchorsTableOrderingComposer
    extends Composer<_$AppDatabase, $AudioAnchorsTable> {
  $$AudioAnchorsTableOrderingComposer({
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

  ColumnOrderings<int> get measureNumber => $composableBuilder(
    column: $table.measureNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get audioTime => $composableBuilder(
    column: $table.audioTime,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioAnchorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AudioAnchorsTable> {
  $$AudioAnchorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get measureNumber => $composableBuilder(
    column: $table.measureNumber,
    builder: (column) => column,
  );

  GeneratedColumn<double> get audioTime =>
      $composableBuilder(column: $table.audioTime, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AudioAnchorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AudioAnchorsTable,
          AudioAnchor,
          $$AudioAnchorsTableFilterComposer,
          $$AudioAnchorsTableOrderingComposer,
          $$AudioAnchorsTableAnnotationComposer,
          $$AudioAnchorsTableCreateCompanionBuilder,
          $$AudioAnchorsTableUpdateCompanionBuilder,
          (AudioAnchor, $$AudioAnchorsTableReferences),
          AudioAnchor,
          PrefetchHooks Function({bool songId})
        > {
  $$AudioAnchorsTableTableManager(_$AppDatabase db, $AudioAnchorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioAnchorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioAnchorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioAnchorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> measureNumber = const Value.absent(),
                Value<double> audioTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioAnchorsCompanion(
                id: id,
                songId: songId,
                measureNumber: measureNumber,
                audioTime: audioTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String songId,
                required int measureNumber,
                required double audioTime,
                Value<int> rowid = const Value.absent(),
              }) => AudioAnchorsCompanion.insert(
                id: id,
                songId: songId,
                measureNumber: measureNumber,
                audioTime: audioTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AudioAnchorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$AudioAnchorsTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$AudioAnchorsTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AudioAnchorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AudioAnchorsTable,
      AudioAnchor,
      $$AudioAnchorsTableFilterComposer,
      $$AudioAnchorsTableOrderingComposer,
      $$AudioAnchorsTableAnnotationComposer,
      $$AudioAnchorsTableCreateCompanionBuilder,
      $$AudioAnchorsTableUpdateCompanionBuilder,
      (AudioAnchor, $$AudioAnchorsTableReferences),
      AudioAnchor,
      PrefetchHooks Function({bool songId})
    >;
typedef $$CuesTableCreateCompanionBuilder =
    CuesCompanion Function({
      required String id,
      required String songId,
      required int measureNumber,
      required String label,
      Value<int> rowid,
    });
typedef $$CuesTableUpdateCompanionBuilder =
    CuesCompanion Function({
      Value<String> id,
      Value<String> songId,
      Value<int> measureNumber,
      Value<String> label,
      Value<int> rowid,
    });

final class $$CuesTableReferences
    extends BaseReferences<_$AppDatabase, $CuesTable, Cue> {
  $$CuesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SongsTable _songIdTable(_$AppDatabase db) =>
      db.songs.createAlias($_aliasNameGenerator(db.cues.songId, db.songs.id));

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CuesTableFilterComposer extends Composer<_$AppDatabase, $CuesTable> {
  $$CuesTableFilterComposer({
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

  ColumnFilters<int> get measureNumber => $composableBuilder(
    column: $table.measureNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CuesTableOrderingComposer extends Composer<_$AppDatabase, $CuesTable> {
  $$CuesTableOrderingComposer({
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

  ColumnOrderings<int> get measureNumber => $composableBuilder(
    column: $table.measureNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CuesTable> {
  $$CuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get measureNumber => $composableBuilder(
    column: $table.measureNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CuesTable,
          Cue,
          $$CuesTableFilterComposer,
          $$CuesTableOrderingComposer,
          $$CuesTableAnnotationComposer,
          $$CuesTableCreateCompanionBuilder,
          $$CuesTableUpdateCompanionBuilder,
          (Cue, $$CuesTableReferences),
          Cue,
          PrefetchHooks Function({bool songId})
        > {
  $$CuesTableTableManager(_$AppDatabase db, $CuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<int> measureNumber = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CuesCompanion(
                id: id,
                songId: songId,
                measureNumber: measureNumber,
                label: label,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String songId,
                required int measureNumber,
                required String label,
                Value<int> rowid = const Value.absent(),
              }) => CuesCompanion.insert(
                id: id,
                songId: songId,
                measureNumber: measureNumber,
                label: label,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CuesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable: $$CuesTableReferences
                                    ._songIdTable(db),
                                referencedColumn: $$CuesTableReferences
                                    ._songIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CuesTable,
      Cue,
      $$CuesTableFilterComposer,
      $$CuesTableOrderingComposer,
      $$CuesTableAnnotationComposer,
      $$CuesTableCreateCompanionBuilder,
      $$CuesTableUpdateCompanionBuilder,
      (Cue, $$CuesTableReferences),
      Cue,
      PrefetchHooks Function({bool songId})
    >;
typedef $$PracticeSessionsTableCreateCompanionBuilder =
    PracticeSessionsCompanion Function({
      required String id,
      required String songId,
      required DateTime startedAt,
      required DateTime endedAt,
      required int durationSeconds,
      required int bpm,
      Value<int> rowid,
    });
typedef $$PracticeSessionsTableUpdateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<String> id,
      Value<String> songId,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<int> durationSeconds,
      Value<int> bpm,
      Value<int> rowid,
    });

final class $$PracticeSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PracticeSessionsTable, PracticeSession> {
  $$PracticeSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SongsTable _songIdTable(_$AppDatabase db) => db.songs.createAlias(
    $_aliasNameGenerator(db.practiceSessions.songId, db.songs.id),
  );

  $$SongsTableProcessedTableManager get songId {
    final $_column = $_itemColumn<String>('song_id')!;

    final manager = $$SongsTableTableManager(
      $_db,
      $_db.songs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_songIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PracticeSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableFilterComposer({
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  $$SongsTableFilterComposer get songId {
    final $$SongsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableFilterComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticeSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  $$SongsTableOrderingComposer get songId {
    final $$SongsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableOrderingComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticeSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  $$SongsTableAnnotationComposer get songId {
    final $$SongsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.songId,
      referencedTable: $db.songs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SongsTableAnnotationComposer(
            $db: $db,
            $table: $db.songs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticeSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeSessionsTable,
          PracticeSession,
          $$PracticeSessionsTableFilterComposer,
          $$PracticeSessionsTableOrderingComposer,
          $$PracticeSessionsTableAnnotationComposer,
          $$PracticeSessionsTableCreateCompanionBuilder,
          $$PracticeSessionsTableUpdateCompanionBuilder,
          (PracticeSession, $$PracticeSessionsTableReferences),
          PracticeSession,
          PrefetchHooks Function({bool songId})
        > {
  $$PracticeSessionsTableTableManager(
    _$AppDatabase db,
    $PracticeSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> songId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> bpm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSessionsCompanion(
                id: id,
                songId: songId,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                bpm: bpm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String songId,
                required DateTime startedAt,
                required DateTime endedAt,
                required int durationSeconds,
                required int bpm,
                Value<int> rowid = const Value.absent(),
              }) => PracticeSessionsCompanion.insert(
                id: id,
                songId: songId,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                bpm: bpm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PracticeSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({songId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (songId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.songId,
                                referencedTable:
                                    $$PracticeSessionsTableReferences
                                        ._songIdTable(db),
                                referencedColumn:
                                    $$PracticeSessionsTableReferences
                                        ._songIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PracticeSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeSessionsTable,
      PracticeSession,
      $$PracticeSessionsTableFilterComposer,
      $$PracticeSessionsTableOrderingComposer,
      $$PracticeSessionsTableAnnotationComposer,
      $$PracticeSessionsTableCreateCompanionBuilder,
      $$PracticeSessionsTableUpdateCompanionBuilder,
      (PracticeSession, $$PracticeSessionsTableReferences),
      PracticeSession,
      PrefetchHooks Function({bool songId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$LabelsTableTableManager get labels =>
      $$LabelsTableTableManager(_db, _db.labels);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$SongLabelsTableTableManager get songLabels =>
      $$SongLabelsTableTableManager(_db, _db.songLabels);
  $$SetlistsTableTableManager get setlists =>
      $$SetlistsTableTableManager(_db, _db.setlists);
  $$SetlistEntriesTableTableManager get setlistEntries =>
      $$SetlistEntriesTableTableManager(_db, _db.setlistEntries);
  $$MeasuresTableTableManager get measures =>
      $$MeasuresTableTableManager(_db, _db.measures);
  $$TempoMapsTableTableManager get tempoMaps =>
      $$TempoMapsTableTableManager(_db, _db.tempoMaps);
  $$TimeSignatureMapsTableTableManager get timeSignatureMaps =>
      $$TimeSignatureMapsTableTableManager(_db, _db.timeSignatureMaps);
  $$AudioAnchorsTableTableManager get audioAnchors =>
      $$AudioAnchorsTableTableManager(_db, _db.audioAnchors);
  $$CuesTableTableManager get cues => $$CuesTableTableManager(_db, _db.cues);
  $$PracticeSessionsTableTableManager get practiceSessions =>
      $$PracticeSessionsTableTableManager(_db, _db.practiceSessions);
}
