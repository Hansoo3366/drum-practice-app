import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';

void main() {
  test('maps a 0-based beat index to a displayed beat', () {
    const state = ScorePlaybackState(measureNumber: 4, beatIndex: 2);

    expect(state.displayBeat, 3);
    expect(state.progress, 0);
  });

  test('clamps playback progress between 0 and 1', () {
    expect(
      const ScorePlaybackState(currentTimeMs: 500, durationMs: 1000).progress,
      0.5,
    );
    expect(
      const ScorePlaybackState(currentTimeMs: -20, durationMs: 1000).progress,
      0,
    );
    expect(
      const ScorePlaybackState(currentTimeMs: 2000, durationMs: 1000).progress,
      1,
    );
    expect(
      const ScorePlaybackState(currentTimeMs: 20, durationMs: 0).progress,
      0,
    );
  });

  test('keeps a known duration when a zero timeline update arrives', () {
    const state = ScorePlaybackState(ready: true, durationMs: 4000);

    expect(state.withReportedDuration(0).durationMs, 4000);
    expect(state.withReportedDuration(8500).durationMs, 8500);
    expect(state.withReportedDuration(0).ready, isTrue);
  });

  test('estimates duration from tempo and time signatures', () {
    expect(estimateScoreDurationMs(_score()), 2000);
    expect(
      estimateScoreDurationMs(
        _score(
          tempoBpm: 60,
          extraMeasure: MusicMeasure(
            number: '2',
            attributes: MusicAttributes(
              divisions: 1,
              time: const MusicTimeSignature(beats: 3, beatType: 4),
            ),
            events: const [MusicDirection(onset: 0, staff: 1, tempoBpm: 120)],
          ),
        ),
      ),
      5500,
    );
  });

  test('formats a playback clock without a separate timer', () {
    expect(formatPlaybackClock(0), '0:00');
    expect(formatPlaybackClock(1500), '0:01');
    expect(formatPlaybackClock(65000), '1:05');
    expect(formatPlaybackClock(double.nan), '0:00');
  });
}

MusicScore _score({double? tempoBpm, MusicMeasure? extraMeasure}) {
  return MusicScore(
    tempoBpm: tempoBpm,
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          MusicMeasure(
            number: '1',
            attributes: MusicAttributes(
              divisions: 1,
              time: const MusicTimeSignature(beats: 4, beatType: 4),
            ),
            events: [
              MusicNote(onset: 0, duration: 1, voice: '1', staff: 1),
            ],
          ),
          if (extraMeasure != null) extraMeasure,
        ],
      ),
    ],
  );
}
