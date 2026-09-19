import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';

class MeasureRepository {
  const MeasureRepository(this._database);

  final AppDatabase _database;

  Stream<List<Measure>> watchMeasures(String songId) {
    final query = _database.select(_database.measures)
      ..where((measure) => measure.songId.equals(songId))
      ..orderBy([(measure) => OrderingTerm.asc(measure.number)]);
    return query.watch();
  }

  Future<void> add({
    required String songId,
    required int page,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    if (page < 1) {
      throw ArgumentError.value(page, 'page');
    }
    _validateRect(x, y, width, height);
    await _database.transaction(() async {
      final current = await (_database.select(
        _database.measures,
      )..where((measure) => measure.songId.equals(songId))).get();
      final number = current.fold(
        1,
        (next, measure) => measure.number >= next ? measure.number + 1 : next,
      );
      await _database
          .into(_database.measures)
          .insert(
            MeasuresCompanion.insert(
              id: '$songId-${DateTime.now().microsecondsSinceEpoch}',
              songId: songId,
              number: number,
              page: page,
              x: x,
              y: y,
              width: width,
              height: height,
            ),
          );
      await _markScoreType(songId, 'pdf');
    });
  }

  Future<void> updateRect({
    required String id,
    required double x,
    required double y,
    required double width,
    required double height,
  }) async {
    _validateRect(x, y, width, height);
    await (_database.update(
      _database.measures,
    )..where((measure) => measure.id.equals(id))).write(
      MeasuresCompanion(
        x: Value(x),
        y: Value(y),
        width: Value(width),
        height: Value(height),
      ),
    );
  }

  Future<void> delete(Measure measure) async {
    await _database.transaction(() async {
      await (_database.delete(
        _database.measures,
      )..where((row) => row.id.equals(measure.id))).go();
      final remaining =
          await (_database.select(_database.measures)
                ..where((row) => row.songId.equals(measure.songId))
                ..limit(1))
              .getSingleOrNull();
      if (remaining == null) {
        await _markScoreType(measure.songId, 'pdf');
      } else {
        await _touchSong(measure.songId);
      }
    });
  }

  Future<void> updateSection({required String id, String? section}) async {
    final value = section?.trim().toUpperCase();
    await (_database.update(
      _database.measures,
    )..where((measure) => measure.id.equals(id))).write(
      MeasuresCompanion(
        section: Value(value == null || value.isEmpty ? null : value),
      ),
    );
  }

  Future<void> updateDifficult({
    required Measure measure,
    required bool isDifficult,
  }) async {
    await _database.transaction(() async {
      await (_database.update(_database.measures)
            ..where((row) => row.id.equals(measure.id)))
          .write(MeasuresCompanion(isDifficult: Value(isDifficult)));
      await _touchSong(measure.songId);
    });
  }

  Future<void> _markScoreType(String songId, String scoreType) {
    return (_database.update(
      _database.songs,
    )..where((song) => song.id.equals(songId))).write(
      SongsCompanion(
        scoreType: Value(scoreType),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _touchSong(String songId) {
    return (_database.update(_database.songs)
          ..where((song) => song.id.equals(songId)))
        .write(SongsCompanion(updatedAt: Value(DateTime.now())));
  }

  void _validateRect(double x, double y, double width, double height) {
    if (x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > 1 ||
        y + height > 1) {
      throw ArgumentError('마디 영역이 페이지 안에 있어야 합니다.');
    }
  }
}

final measureRepositoryProvider = Provider<MeasureRepository>((ref) {
  return MeasureRepository(ref.watch(appDatabaseProvider));
});

final measuresProvider = StreamProvider.autoDispose
    .family<List<Measure>, String>((ref, songId) {
      return ref.watch(measureRepositoryProvider).watchMeasures(songId);
    });
