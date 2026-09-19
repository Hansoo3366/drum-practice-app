import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

/// 쓰기 중이거나 재생이 꺼져 있으면 원본 악보만 보여 준다.
MusicScore displayedDigitalScore({
  required MusicScore written,
  required bool editing,
  required bool playbackEnabled,
  PlaybackSequence sequence = PlaybackSequence.empty,
  ArrangementProfile arrangement = ArrangementProfile.off,
}) {
  if (editing || !playbackEnabled) return written;
  return composePerformanceScore(
    written,
    sequence: sequence,
    arrangement: arrangement,
    ignoreErrors: true,
  );
}

MusicScore composePerformanceScore(
  MusicScore written, {
  PlaybackSequence sequence = PlaybackSequence.empty,
  ArrangementProfile arrangement = ArrangementProfile.off,
  bool ignoreErrors = false,
}) {
  var score = written;
  if (sequence.isNotEmpty) {
    try {
      score = expandPlaybackSequence(score, sequence);
    } on Object {
      if (!ignoreErrors) rethrow;
    }
  }
  if (arrangement.isNotOff) {
    try {
      score = applyArrangement(score, arrangement);
    } on Object {
      if (!ignoreErrors) rethrow;
    }
  }
  return score;
}
