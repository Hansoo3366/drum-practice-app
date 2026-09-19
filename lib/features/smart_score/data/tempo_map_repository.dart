import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';

class TempoMapRepository {
  const TempoMapRepository(this._database);

  final AppDatabase _database;

  Stream<List<TempoMap>> watch(String songId) {
    final query = _database.select(_database.tempoMaps)
      ..where((map) => map.songId.equals(songId))
      ..orderBy([(map) => OrderingTerm.asc(map.startMeasure)]);
    return query.watch();
  }

  Future<void> save({
    String? id,
    required String songId,
    required int startMeasure,
    required int endMeasure,
    required String mode,
    required int startBpm,
    int? endBpm,
  }) async {
    _validate(
      startMeasure: startMeasure,
      endMeasure: endMeasure,
      mode: mode,
      startBpm: startBpm,
      endBpm: endBpm,
    );
    await _database
        .into(_database.tempoMaps)
        .insertOnConflictUpdate(
          TempoMapsCompanion.insert(
            id: id ?? '$songId-tempo-$startMeasure',
            songId: songId,
            startMeasure: startMeasure,
            endMeasure: endMeasure,
            mode: mode,
            startBpm: startBpm,
            endBpm: Value(endBpm),
          ),
        );
  }

  Future<void> delete(TempoMap map) {
    return (_database.delete(
      _database.tempoMaps,
    )..where((row) => row.id.equals(map.id))).go();
  }

  void _validate({
    required int startMeasure,
    required int endMeasure,
    required String mode,
    required int startBpm,
    required int? endBpm,
  }) {
    if (startMeasure < 1 || endMeasure < startMeasure) {
      throw ArgumentError('템포 맵 범위를 확인하세요.');
    }
    if (mode != 'step' && mode != 'gradual') {
      throw ArgumentError('템포 맵 방식이 올바르지 않습니다.');
    }
    if (startBpm < 40 || startBpm > 240) {
      throw ArgumentError('BPM은 40~240이어야 합니다.');
    }
    if (mode == 'gradual' && (endBpm == null || endBpm < 40 || endBpm > 240)) {
      throw ArgumentError('끝 BPM은 40~240이어야 합니다.');
    }
    if (mode == 'step' && endBpm != null) {
      throw ArgumentError('스텝 모드에는 끝 BPM이 없습니다.');
    }
  }
}

final tempoMapRepositoryProvider = Provider<TempoMapRepository>((ref) {
  return TempoMapRepository(ref.watch(appDatabaseProvider));
});

final tempoMapsProvider = StreamProvider.autoDispose
    .family<List<TempoMap>, String>((ref, songId) {
      return ref.watch(tempoMapRepositoryProvider).watch(songId);
    });
