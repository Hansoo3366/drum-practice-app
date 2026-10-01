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
}
