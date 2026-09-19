import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';

class CueRepository {
  const CueRepository(this._database);

  final AppDatabase _database;

  Stream<List<Cue>> watch(String songId) {
    final query = _database.select(_database.cues)
      ..where((cue) => cue.songId.equals(songId))
      ..orderBy([(cue) => OrderingTerm.asc(cue.measureNumber)]);
    return query.watch();
  }

  Future<void> save({
    required String songId,
    required int measureNumber,
    required String label,
    String? id,
  }) async {
    if (measureNumber < 1) {
      throw ArgumentError.value(measureNumber, 'measureNumber');
    }
    final value = label.trim();
    if (value.isEmpty || value.length > 40) {
      throw ArgumentError.value(label, 'label');
    }
    await _database
        .into(_database.cues)
        .insertOnConflictUpdate(
          CuesCompanion.insert(
            id: id ?? '$songId-cue-$measureNumber',
            songId: songId,
            measureNumber: measureNumber,
            label: value,
          ),
        );
  }

  Future<void> delete(Cue cue) {
    return (_database.delete(
      _database.cues,
    )..where((row) => row.id.equals(cue.id))).go();
  }
}

final cueRepositoryProvider = Provider<CueRepository>((ref) {
  return CueRepository(ref.watch(appDatabaseProvider));
});

final cuesProvider = StreamProvider.autoDispose.family<List<Cue>, String>(
  (ref, songId) => ref.watch(cueRepositoryProvider).watch(songId),
);
