import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/l10n/app_localizations.dart';

class PracticeStats {
  const PracticeStats({
    required this.sessionCount,
    required this.totalSeconds,
    required this.averageBpm,
    required this.maxBpm,
  });

  factory PracticeStats.from(Iterable<PracticeSession> sessions) {
    var sessionCount = 0;
    var totalSeconds = 0;
    var totalBpm = 0;
    var maxBpm = 0;
    for (final session in sessions) {
      sessionCount += 1;
      totalSeconds += session.durationSeconds;
      totalBpm += session.bpm;
      if (session.bpm > maxBpm) {
        maxBpm = session.bpm;
      }
    }
    return PracticeStats(
      sessionCount: sessionCount,
      totalSeconds: totalSeconds,
      averageBpm: sessionCount == 0 ? 0 : (totalBpm / sessionCount).round(),
      maxBpm: maxBpm,
    );
  }

  final int sessionCount;
  final int totalSeconds;
  final int averageBpm;
  final int maxBpm;

  String totalDurationLabel(AppLocalizations l10n) {
    if (totalSeconds < 60) return l10n.durationSeconds(totalSeconds);
    final minutes = totalSeconds ~/ 60;
    if (minutes < 60) return l10n.durationMinutes(minutes);
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return rem == 0
        ? l10n.durationHours(hours)
        : l10n.durationHoursMinutes(hours, rem);
  }
}
