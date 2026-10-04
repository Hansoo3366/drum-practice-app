import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';

void main() {
  test('sums the sequence at its tempo, following tempo changes', () {
    final sequence = nm.MidiSequence(
      ticksPerQuarter: 480,
      tracks: [
        nm.MidiTrack(
          name: 'piano',
          channel: 0,
          events: [
            nm.MidiEvent.tempo(tick: 0, bpm: 120),
            nm.MidiEvent.noteOn(tick: 0, channel: 0, note: 60, velocity: 80),
            nm.MidiEvent.noteOff(tick: 480, channel: 0, note: 60),
            // Twice as slow from the second quarter on.
            nm.MidiEvent.tempo(tick: 480, bpm: 60),
            nm.MidiEvent.noteOn(tick: 480, channel: 0, note: 62, velocity: 80),
            nm.MidiEvent.noteOff(tick: 960, channel: 0, note: 62),
          ],
        ),
      ],
    );

    // One quarter at 120 (500 ms) and one at 60 (1000 ms).
    expect(midiSequenceDurationMs(sequence), closeTo(1500, 0.01));
  });

  test('uses the fallback tempo when the sequence has none', () {
    final sequence = nm.MidiSequence(
      ticksPerQuarter: 960,
      tracks: [
        nm.MidiTrack(
          name: 'piano',
          channel: 0,
          events: [
            nm.MidiEvent.noteOn(tick: 0, channel: 0, note: 60, velocity: 80),
            nm.MidiEvent.noteOff(tick: 960 * 4, channel: 0, note: 60),
          ],
        ),
      ],
    );

    expect(
      midiSequenceDurationMs(sequence, fallbackBpm: 240),
      closeTo(1000, 0.01),
    );
    expect(
      midiSequenceDurationMs(
        nm.MidiSequence(ticksPerQuarter: 960, tracks: const []),
      ),
      0,
    );
  });

  group('what the native player is given', () {
    // The player keeps its first tempo and starts at its first tick: the
    // tempo changes, the place to start and the practice tempo are written
    // into the ticks.
    final sequence = nm.MidiSequence(
      ticksPerQuarter: 480,
      tracks: [
        nm.MidiTrack(
          name: 'Conductor',
          channel: 0,
          events: [
            nm.MidiEvent.tempo(tick: 0, bpm: 120),
            nm.MidiEvent.timeSignature(tick: 0, numerator: 3, denominator: 4),
            // Twice as slow from the second quarter on.
            nm.MidiEvent.tempo(tick: 480, bpm: 60),
          ],
        ),
        nm.MidiTrack(
          name: 'piano',
          channel: 0,
          events: [
            nm.MidiEvent.noteOn(tick: 0, channel: 0, note: 60, velocity: 80),
            nm.MidiEvent.noteOff(tick: 480, channel: 0, note: 60),
            nm.MidiEvent.noteOn(tick: 480, channel: 0, note: 62, velocity: 70),
            nm.MidiEvent.noteOff(tick: 960, channel: 0, note: 62),
          ],
        ),
      ],
    );
    final timing = MidiTiming(sequence);

    List<(int note, int start, int length)> played(nm.MidiSequence given) {
      // One tempo, the one every tick is counted in.
      final tempos = [
        for (final track in given.tracks)
          for (final event in track.events)
            if (event.type == nm.MidiEventType.tempo) (event.tick, event.bpm),
      ];
      expect(tempos, [(0, 120)]);
      return [
        for (final note in nm.extractScheduledNotes(given))
          (note.midiNote, note.startTick, note.durationTicks),
      ];
    }

    test('timing follows the tempo changes', () {
      expect(timing.msAt(0), 0);
      expect(timing.msAt(480), closeTo(500, 0.01));
      expect(timing.msAt(720), closeTo(1000, 0.01));
      expect(timing.durationMs, closeTo(1500, 0.01));
      expect(timing.durationMs, midiSequenceDurationMs(sequence));
    });

    test('a slower passage is written out longer', () {
      // At 120 a quarter is 480 ticks: the second note sounds for two.
      expect(played(playableSequence(sequence, timing)), [
        (60, 0, 480),
        (62, 480, 960),
      ]);
    });

    test('playing goes on from where it was paused or moved to', () {
      // From the second note: it is the first thing heard.
      expect(played(playableSequence(sequence, timing, fromMs: 500)), [
        (62, 0, 960),
      ]);
      // From inside the first note: that note is not struck again.
      expect(played(playableSequence(sequence, timing, fromMs: 250)), [
        (62, 240, 960),
      ]);
      // Half a second into the second note: nothing left to strike.
      expect(played(playableSequence(sequence, timing, fromMs: 1000)), isEmpty);
    });

    test('a practice tempo stretches everything alike', () {
      expect(played(playableSequence(sequence, timing, speed: 0.5)), [
        (60, 0, 960),
        (62, 960, 1920),
      ]);
      expect(
        played(playableSequence(sequence, timing, fromMs: 500, speed: 2)),
        [(62, 0, 480)],
      );
    });

    test('the time signature is kept for the player', () {
      final given = playableSequence(sequence, timing, fromMs: 500);
      final signature = given.tracks.first.events.singleWhere(
        (event) => event.type == nm.MidiEventType.timeSignature,
      );
      expect(
        (signature.tick, signature.numerator, signature.denominator),
        (0, 3, 4),
      );
    });
  });
}
