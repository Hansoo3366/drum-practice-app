import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Folders extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// ARGB color value for folder chips / accents.
  IntColumn get color => integer()();

  TextColumn get parentId =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Labels extends Table {
  TextColumn get id => text()();

  /// Normalized hashtag body (no leading `#`, lowercased).
  TextColumn get name => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {name},
  ];
}

class SongLabels extends Table {
  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  TextColumn get labelId =>
      text().references(Labels, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {songId, labelId};
}

class Songs extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get artist => text().nullable()();

  IntColumn get defaultTempo => integer().nullable()();

  IntColumn get targetBpm => integer().nullable()();

  TextColumn get scoreType => text().withDefault(const Constant('pdf'))();

  TextColumn get sourcePath => text()();

  TextColumn get sourceProvider =>
      text().withDefault(const Constant('local'))();

  TextColumn get remoteUri => text().nullable()();

  DateTimeColumn get remoteModifiedAt => dateTime().nullable()();

  IntColumn get remoteSize => integer().nullable()();

  TextColumn get syncStatus => text().nullable()();

  BoolColumn get offlineAvailable =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  TextColumn get note => text().nullable()();

  TextColumn get audioPath => text().nullable()();

  TextColumn get audioName => text().nullable()();

  TextColumn get folderId =>
      text().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Setlists extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SetlistEntries extends Table {
  TextColumn get id => text()();

  TextColumn get setlistId =>
      text().references(Setlists, #id, onDelete: KeyAction.cascade)();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get position => integer()();

  IntColumn get tempoOverride => integer().nullable()();

  /// JSON-encoded per-entry metronome profile. Kept nullable so existing
  /// setlists continue to use the song BPM and global metronome defaults.
  TextColumn get metronomeJson => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {setlistId, position},
  ];
}

class Measures extends Table {
  TextColumn get id => text()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get number => integer()();

  IntColumn get page => integer()();

  RealColumn get x => real()();

  RealColumn get y => real()();

  RealColumn get width => real()();

  RealColumn get height => real()();

  TextColumn get section => text().nullable()();

  BoolColumn get isDifficult => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {songId, number},
  ];
}

class TempoMaps extends Table {
  TextColumn get id => text()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get startMeasure => integer()();

  IntColumn get endMeasure => integer()();

  TextColumn get mode => text()();

  IntColumn get startBpm => integer()();

  IntColumn get endBpm => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {songId, startMeasure},
  ];
}

class TimeSignatureMaps extends Table {
  TextColumn get id => text()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get startMeasure => integer()();

  IntColumn get endMeasure => integer()();

  IntColumn get numerator => integer()();

  IntColumn get denominator => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {songId, startMeasure},
  ];
}

class AudioAnchors extends Table {
  TextColumn get id => text()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get measureNumber => integer()();

  RealColumn get audioTime => real()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {songId, measureNumber},
  ];
}

class Cues extends Table {
  TextColumn get id => text()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  IntColumn get measureNumber => integer()();

  TextColumn get label => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {songId, measureNumber},
  ];
}

class PracticeSessions extends Table {
  TextColumn get id => text()();

  TextColumn get songId =>
      text().references(Songs, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get startedAt => dateTime()();

  DateTimeColumn get endedAt => dateTime()();

  IntColumn get durationSeconds => integer()();

  IntColumn get bpm => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Folders,
    Labels,
    Songs,
    SongLabels,
    Setlists,
    SetlistEntries,
    Measures,
    TempoMaps,
    TimeSignatureMaps,
    AudioAnchors,
    Cues,
    PracticeSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'page_a_diddle'));

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(setlists);
        await migrator.createTable(setlistEntries);
      }
      if (from < 3) {
        await _addColumnIfMissing(
          migrator,
          songs,
          'songs',
          'audio_path',
          songs.audioPath,
        );
        await _addColumnIfMissing(
          migrator,
          songs,
          'songs',
          'audio_name',
          songs.audioName,
        );
      }
      if (from < 4) {
        await migrator.createTable(measures);
      }
      if (from < 5) {
        await _addColumnIfMissing(
          migrator,
          measures,
          'measures',
          'section',
          measures.section,
        );
      }
      if (from < 6) {
        await migrator.createTable(tempoMaps);
      }
      if (from < 7) {
        await migrator.createTable(timeSignatureMaps);
      }
      if (from < 8) {
        await migrator.createTable(audioAnchors);
      }
      if (from < 9) {
        await migrator.createTable(cues);
      }
      if (from < 10) {
        await _addColumnIfMissing(
          migrator,
          measures,
          'measures',
          'is_difficult',
          measures.isDifficult,
        );
      }
      if (from < 11) {
        await migrator.createTable(practiceSessions);
      }
      if (from < 12) {
        await _addColumnIfMissing(
          migrator,
          songs,
          'songs',
          'target_bpm',
          songs.targetBpm,
        );
      }
      if (from < 13) {
        await _addColumnIfMissing(
          migrator,
          songs,
          'songs',
          'remote_uri',
          songs.remoteUri,
        );
        await _addColumnIfMissing(
          migrator,
          songs,
          'songs',
          'remote_modified_at',
          songs.remoteModifiedAt,
        );
        await _addColumnIfMissing(
          migrator,
          songs,
          'songs',
          'remote_size',
          songs.remoteSize,
        );
        await _addColumnIfMissing(
          migrator,
          songs,
          'songs',
          'sync_status',
          songs.syncStatus,
        );
      }
      if (from < 14) {
        await migrator.createTable(folders);
        await migrator.createTable(labels);
        await _addColumnIfMissing(
          migrator,
          songs,
          'songs',
          'folder_id',
          songs.folderId,
        );
        await migrator.createTable(songLabels);
        await customStatement(
          "UPDATE songs SET score_type = 'pdf' "
          "WHERE score_type IN ('smart_score', 'native_score', 'music_xml')",
        );
      }
      if (from < 15) {
        await _addColumnIfMissing(
          migrator,
          folders,
          'folders',
          'parent_id',
          folders.parentId,
        );
      }
      if (from < 16) {
        await _addColumnIfMissing(
          migrator,
          setlistEntries,
          'setlist_entries',
          'metronome_json',
          setlistEntries.metronomeJson,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

Future<void> _addColumnIfMissing(
  Migrator migrator,
  TableInfo<Table, dynamic> tableInfo,
  String table,
  String column,
  GeneratedColumn<Object> definition,
) async {
  final columns = await migrator.database
      .customSelect('PRAGMA table_info("$table")')
      .get();
  if (columns.any((row) => row.read<String>('name') == column)) {
    return;
  }
  await migrator.addColumn(tableInfo, definition);
}
