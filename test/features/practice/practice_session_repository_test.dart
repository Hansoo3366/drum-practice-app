import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/practice/data/practice_session_repository.dart';

void main() {
  test('연습 세션을 저장하고 최근 순서와 시간을 조회한다', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PracticeSessionRepository(database);
    final createdAt = DateTime(2026, 8, 20);
    await database
        .into(database.songs)
        .insert(
          SongsCompanion.insert(
            id: 'song-1',
            title: 'Practice',
            sourcePath: 'scores/practice.pdf',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );

    final startedAt = DateTime(2026, 8, 20, 10);
    await repository.save(
      songId: 'song-1',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 3, seconds: 12)),
      bpm: 128,
    );

    final sessions = await repository.watch('song-1').first;
    expect(sessions.single.durationSeconds, 192);
    expect(sessions.single.bpm, 128);
  });

  test('끝 시각과 BPM을 검증한다', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = PracticeSessionRepository(database);
    final startedAt = DateTime(2026, 8, 20, 10);

    expect(
      () => repository.save(
        songId: 'song-1',
        startedAt: startedAt,
        endedAt: startedAt.subtract(const Duration(seconds: 1)),
        bpm: 120,
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.save(
        songId: 'song-1',
        startedAt: startedAt,
        endedAt: startedAt,
        bpm: 20,
      ),
      throwsArgumentError,
    );
  });
}
