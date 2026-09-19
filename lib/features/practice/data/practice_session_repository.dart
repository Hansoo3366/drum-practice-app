import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/database/database_providers.dart';

class PracticeSessionRepository {
  const PracticeSessionRepository(this._database);

  final AppDatabase _database;

  Stream<List<PracticeSession>> watch(String songId) {
    final query = _database.select(_database.practiceSessions)
      ..where((session) => session.songId.equals(songId))
      ..orderBy([(session) => OrderingTerm.desc(session.startedAt)]);
    return query.watch();
  }

  Stream<List<PracticeSession>> watchSince(DateTime since) {
    final query = _database.select(_database.practiceSessions)
      ..where((session) => session.startedAt.isBiggerOrEqualValue(since))
      ..orderBy([(session) => OrderingTerm.desc(session.startedAt)]);
    return query.watch();
  }

  Future<void> save({
    required String songId,
    required DateTime startedAt,
    required DateTime endedAt,
    required int bpm,
    String? id,
  }) async {
    if (endedAt.isBefore(startedAt)) {
      throw ArgumentError.value(endedAt, 'endedAt');
    }
    if (bpm < 40 || bpm > 240) {
      throw ArgumentError.value(bpm, 'bpm', 'BPM은 40~240이어야 합니다.');
    }
    await _database
        .into(_database.practiceSessions)
        .insert(
          PracticeSessionsCompanion.insert(
            id: id ?? '$songId-practice-${startedAt.microsecondsSinceEpoch}',
            songId: songId,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: endedAt.difference(startedAt).inSeconds,
            bpm: bpm,
          ),
        );
  }
}

final practiceSessionRepositoryProvider = Provider<PracticeSessionRepository>((
  ref,
) {
  return PracticeSessionRepository(ref.watch(appDatabaseProvider));
});

final practiceSessionsProvider = StreamProvider.autoDispose
    .family<List<PracticeSession>, String>((ref, songId) {
      return ref.watch(practiceSessionRepositoryProvider).watch(songId);
    });

/// Practice sessions from the last 7 days (home dashboard).
final recentPracticeSessionsProvider =
    StreamProvider.autoDispose<List<PracticeSession>>((ref) {
      final since = DateTime.now().subtract(const Duration(days: 7));
      return ref.watch(practiceSessionRepositoryProvider).watchSince(since);
    });
