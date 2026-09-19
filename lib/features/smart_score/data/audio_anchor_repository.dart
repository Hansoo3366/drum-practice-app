import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';

class AudioAnchorRepository {
  const AudioAnchorRepository(this._database);

  final AppDatabase _database;

  Stream<List<AudioAnchor>> watch(String songId) {
    final query = _database.select(_database.audioAnchors)
      ..where((anchor) => anchor.songId.equals(songId))
      ..orderBy([(anchor) => OrderingTerm.asc(anchor.measureNumber)]);
    return query.watch();
  }

  Future<void> save({
    required String songId,
    required int measureNumber,
    required double audioTime,
    String? id,
  }) async {
    if (measureNumber < 1) {
      throw ArgumentError.value(measureNumber, 'measureNumber');
    }
    if (!audioTime.isFinite || audioTime < 0) {
      throw ArgumentError.value(audioTime, 'audioTime');
    }
    await _database
        .into(_database.audioAnchors)
        .insertOnConflictUpdate(
          AudioAnchorsCompanion.insert(
            id: id ?? '$songId-anchor-$measureNumber',
            songId: songId,
            measureNumber: measureNumber,
            audioTime: audioTime,
          ),
        );
  }

  Future<void> delete(AudioAnchor anchor) {
    return (_database.delete(
      _database.audioAnchors,
    )..where((row) => row.id.equals(anchor.id))).go();
  }
}

final audioAnchorRepositoryProvider = Provider<AudioAnchorRepository>((ref) {
  return AudioAnchorRepository(ref.watch(appDatabaseProvider));
});

final audioAnchorsProvider = StreamProvider.autoDispose
    .family<List<AudioAnchor>, String>((ref, songId) {
      return ref.watch(audioAnchorRepositoryProvider).watch(songId);
    });
