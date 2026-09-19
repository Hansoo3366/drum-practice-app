import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/practice/domain/practice_stats.dart';
import 'package:page_a_diddle/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ko'));

  test('연습 횟수·시간·평균 BPM·최고 BPM을 계산한다', () {
    final startedAt = DateTime(2026, 8, 20, 10);
    final stats = PracticeStats.from([
      PracticeSession(
        id: 'session-1',
        songId: 'song-1',
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 2)),
        durationSeconds: 120,
        bpm: 100,
      ),
      PracticeSession(
        id: 'session-2',
        songId: 'song-1',
        startedAt: startedAt.add(const Duration(hours: 1)),
        endedAt: startedAt.add(const Duration(hours: 1, minutes: 3)),
        durationSeconds: 180,
        bpm: 140,
      ),
    ]);

    expect(stats.sessionCount, 2);
    expect(stats.totalSeconds, 300);
    expect(stats.averageBpm, 120);
    expect(stats.maxBpm, 140);
  });

  test('기록이 없으면 0으로 반환한다', () {
    final stats = PracticeStats.from(const <PracticeSession>[]);

    expect(stats.sessionCount, 0);
    expect(stats.totalSeconds, 0);
    expect(stats.averageBpm, 0);
    expect(stats.maxBpm, 0);
  });

  test('총 연습 시간을 짧게 표기한다', () {
    expect(
      const PracticeStats(
        sessionCount: 1,
        totalSeconds: 45,
        averageBpm: 100,
        maxBpm: 100,
      ).totalDurationLabel(l10n),
      '45초',
    );
    expect(
      const PracticeStats(
        sessionCount: 1,
        totalSeconds: 150,
        averageBpm: 100,
        maxBpm: 100,
      ).totalDurationLabel(l10n),
      '2분',
    );
    expect(
      const PracticeStats(
        sessionCount: 1,
        totalSeconds: 3660,
        averageBpm: 100,
        maxBpm: 100,
      ).totalDurationLabel(l10n),
      '1시간 1분',
    );
  });
}
