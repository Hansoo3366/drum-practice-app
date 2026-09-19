import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';

class TimeSignatureMapRepository {
  const TimeSignatureMapRepository(this._database);

  final AppDatabase _database;

  Stream<List<TimeSignatureMap>> watch(String songId) {
    final query = _database.select(_database.timeSignatureMaps)
      ..where((map) => map.songId.equals(songId))
      ..orderBy([(map) => OrderingTerm.asc(map.startMeasure)]);
    return query.watch();
  }

  Future<void> save({
    String? id,
    required String songId,
    required int startMeasure,
    required int endMeasure,
    required int numerator,
    required int denominator,
  }) async {
    _validate(
      startMeasure: startMeasure,
      endMeasure: endMeasure,
      numerator: numerator,
      denominator: denominator,
    );
    await _database
        .into(_database.timeSignatureMaps)
        .insertOnConflictUpdate(
          TimeSignatureMapsCompanion.insert(
            id: id ?? '$songId-time-signature-$startMeasure',
            songId: songId,
            startMeasure: startMeasure,
            endMeasure: endMeasure,
            numerator: numerator,
            denominator: denominator,
          ),
        );
  }

  Future<void> delete(TimeSignatureMap map) {
    return (_database.delete(
      _database.timeSignatureMaps,
    )..where((row) => row.id.equals(map.id))).go();
  }

  void _validate({
    required int startMeasure,
    required int endMeasure,
    required int numerator,
    required int denominator,
  }) {
    if (startMeasure < 1 || endMeasure < startMeasure) {
      throw ArgumentError('박자표 범위를 확인하세요.');
    }
    if (numerator < 1 || numerator > 32) {
      throw ArgumentError('분자는 1~32이어야 합니다.');
    }
    if (![1, 2, 4, 8, 16, 32].contains(denominator)) {
      throw ArgumentError('분모는 1, 2, 4, 8, 16, 32 중 하나여야 합니다.');
    }
  }
}

final timeSignatureMapRepositoryProvider = Provider<TimeSignatureMapRepository>(
  (ref) {
    return TimeSignatureMapRepository(ref.watch(appDatabaseProvider));
  },
);

final timeSignatureMapsProvider = StreamProvider.autoDispose
    .family<List<TimeSignatureMap>, String>((ref, songId) {
      return ref.watch(timeSignatureMapRepositoryProvider).watch(songId);
    });
