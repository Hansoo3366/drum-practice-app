import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';

double estimateScoreDurationMs(MusicScore score) {
  var bpm = score.tempoBpm ?? 120;
  if (bpm <= 0) bpm = 120;
  var milliseconds = 0.0;
  for (final measure in score.parts.first.measures) {
    for (final event in measure.events) {
      if (event is MusicDirection &&
          event.tempoBpm != null &&
          event.tempoBpm! > 0) {
        bpm = event.tempoBpm!;
      }
    }
    final time =
        measure.attributes.time ??
        const MusicTimeSignature(beats: 4, beatType: 4);
    final quarterBeats = time.beats * (4 / time.beatType);
    milliseconds += quarterBeats * (60000 / bpm);
  }
  return milliseconds;
}

class ScorePlaybackState {
  const ScorePlaybackState({
    this.ready = false,
    this.loaded = false,
    this.playing = false,
    this.currentTimeMs = 0,
    this.durationMs = 0,
    this.measureNumber = 1,
    this.beatIndex = 0,
  });

  final bool ready;
  final bool loaded;
  final bool playing;
  final double currentTimeMs;
  final double durationMs;
  final int measureNumber;
  final int beatIndex;

  bool get canControl => ready || loaded;

  int get displayBeat => beatIndex + 1;

  double get progress {
    if (!durationMs.isFinite || durationMs <= 0) return 0;
    if (!currentTimeMs.isFinite) return 0;
    return (currentTimeMs / durationMs).clamp(0, 1);
  }

  ScorePlaybackState withReportedDuration(double durationMs) {
    return copyWith(
      ready: true,
      durationMs: durationMs > 0 ? durationMs : null,
    );
  }

  ScorePlaybackState copyWith({
    bool? ready,
    bool? loaded,
    bool? playing,
    double? currentTimeMs,
    double? durationMs,
    int? measureNumber,
    int? beatIndex,
  }) {
    return ScorePlaybackState(
      ready: ready ?? this.ready,
      loaded: loaded ?? this.loaded,
      playing: playing ?? this.playing,
      currentTimeMs: currentTimeMs ?? this.currentTimeMs,
      durationMs: durationMs ?? this.durationMs,
      measureNumber: measureNumber ?? this.measureNumber,
      beatIndex: beatIndex ?? this.beatIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ScorePlaybackState &&
        other.ready == ready &&
        other.loaded == loaded &&
        other.playing == playing &&
        other.currentTimeMs == currentTimeMs &&
        other.durationMs == durationMs &&
        other.measureNumber == measureNumber &&
        other.beatIndex == beatIndex;
  }

  @override
  int get hashCode => Object.hash(
    ready,
    loaded,
    playing,
    currentTimeMs,
    durationMs,
    measureNumber,
    beatIndex,
  );
}

String formatPlaybackClock(double milliseconds) {
  final totalSeconds = !milliseconds.isFinite || milliseconds <= 0
      ? 0
      : (milliseconds / 1000).floor();
  final bounded = totalSeconds.clamp(0, 99 * 60 + 59);
  final minutes = bounded ~/ 60;
  final seconds = bounded % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
