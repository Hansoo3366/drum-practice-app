import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

/// Length of [sequence] in milliseconds, following its tempo events, so the
/// play head and the stop point match the audio rather than an estimate.
double midiSequenceDurationMs(
  nm.MidiSequence sequence, {
  int fallbackBpm = 120,
}) {
  final events = [for (final track in sequence.tracks) ...track.events]
    ..sort((a, b) => a.tick.compareTo(b.tick));
  if (events.isEmpty) return 0;
  final ticksPerQuarter = sequence.ticksPerQuarter <= 0
      ? 960
      : sequence.ticksPerQuarter;
  var bpm = fallbackBpm <= 0 ? 120 : fallbackBpm;
  var tick = 0;
  var milliseconds = 0.0;
  for (final event in events) {
    milliseconds += (event.tick - tick) * 60000 / (bpm * ticksPerQuarter);
    tick = event.tick;
    if (event.bpm case final next? when next > 0) bpm = next;
  }
  return milliseconds;
}

/// [sequence] with the notes at [tiedInto] not struck again: the note-on is
/// dropped together with the note-off of the note held into it, so the first
/// note sounds through. [tiedInto] gives, per track of notes in order, the
/// ticks and pitches of the tied-to notes.
///
/// The mapper ties notes within one voice only; a converted score often
/// writes the two notes of a tie in different voices.
nm.MidiSequence mergeTiedNotes(
  nm.MidiSequence sequence,
  List<List<(int tick, int midi)>> tiedInto,
) {
  bool isOn(nm.MidiEvent e) =>
      e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) > 0;
  bool isOff(nm.MidiEvent e) =>
      e.type == nm.MidiEventType.noteOff ||
      (e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) == 0);
  // One track per staff, in score order, after the conductor track. A staff
  // without notes still has its track.
  var staffTracks = [
    for (final track in sequence.tracks)
      if (track.name != 'Conductor') track,
  ];
  if (staffTracks.length != tiedInto.length) {
    staffTracks = [
      for (final track in sequence.tracks)
        if (track.events.any(isOn)) track,
    ];
  }
  // Without one track per staff there is no telling which is which.
  if (staffTracks.length != tiedInto.length) return sequence;
  final tracks = <nm.MidiTrack>[];
  for (final track in sequence.tracks) {
    final index = staffTracks.indexOf(track);
    if (index < 0 || tiedInto[index].isEmpty) {
      tracks.add(track);
      continue;
    }
    final events = track.events.toList();
    for (final (tick, midi) in tiedInto[index]) {
      final on = events.indexWhere(
        (e) => isOn(e) && e.note == midi && (e.tick - tick).abs() <= 2,
      );
      if (on < 0) continue;
      // The note held into it ends here, or a little before when the mapper
      // shortened it.
      var off = -1;
      for (var i = 0; i < events.length; i++) {
        final e = events[i];
        if (i == on || !isOff(e) || e.note != midi) continue;
        if (e.channel != events[on].channel || e.tick > events[on].tick) {
          continue;
        }
        if (off < 0 || e.tick >= events[off].tick) off = i;
      }
      if (off < 0) continue;
      // Only when nothing of that pitch starts between the two.
      final between = events.any(
        (e) =>
            isOn(e) &&
            e.note == midi &&
            e.tick > events[off].tick &&
            e.tick < events[on].tick,
      );
      if (between) continue;
      final remove = [on, off]..sort();
      events
        ..removeAt(remove[1])
        ..removeAt(remove[0]);
    }
    tracks.add(
      nm.MidiTrack(name: track.name, channel: track.channel, events: events),
    );
  }
  return nm.MidiSequence(
    ticksPerQuarter: sequence.ticksPerQuarter,
    tracks: tracks,
  );
}

/// The MIDI of [musicXml], a score whose bars are already in playing order.
///
/// The mapper reads [midiReadyMusicXml] with its ties taken off, so every
/// note is there at its time; ties are then joined from the score itself.
nm.MidiSequence playbackMidi(
  String musicXml, {
  required nm.MidiGenerationOptions options,
  MusicXmlCodec codec = const MusicXmlCodec(),
}) {
  final copies = midiReadyCopies(musicXml);
  final sequence = nm.MidiMapper.fromScore(
    nm.MusicXMLParser.scoreFromMusicXML(copies.untied),
    options: options,
  );
  final played = codec.decodeXml(copies.ready);
  final staves = <List<(int, int)>>[
    for (final part in played.parts)
      for (
        var staff = 0;
        staff <
            part.measures.fold<int>(
              1,
              (most, bar) => math.max(most, bar.attributes.staves),
            );
        staff++
      )
        [],
  ];
  for (final tied in tiedContinuations(played)) {
    if (tied.staffIndex >= staves.length) continue;
    staves[tied.staffIndex].add((
      (tied.quarters * sequence.ticksPerQuarter).round(),
      tied.midi,
    ));
  }
  return mergeTiedNotes(sequence, staves);
}

/// The MIDI the player plays for [score]: its bars in [performanceMeasureMap]
/// order, the order the play head follows and the expanded copy uses.
///
/// Made from the file [engravingXml] when it is on screen and no
/// accompaniment is added, so tuplets, ties and every voice play as written;
/// otherwise from the editing model.
nm.MidiSequence buildPlaybackMidi({
  required String? engravingXml,
  required MusicScore score,
  required PlaybackSequence sequence,
  required ArrangementProfile arrangement,
  required int bpm,
}) {
  const codec = MusicXmlCodec();
  String? playing;
  if (engravingXml != null && arrangement.isOff) {
    try {
      playing = playbackMusicXml(engravingXml, score, sequence) ?? engravingXml;
    } on FormatException {
      // An order that cannot be laid out plays from the model below.
    }
  }
  playing ??= utf8.decode(
    codec.encodeMusicXml(
      composePerformanceScore(
        score,
        sequence: sequence,
        arrangement: arrangement,
        ignoreErrors: true,
        flattenRepeats: true,
      ),
    ),
  );
  return playbackMidi(
    playing,
    options: nm.MidiGenerationOptions(defaultBpm: bpm, includeMetronome: false),
    codec: codec,
  );
}

/// [buildPlaybackMidi] off the UI isolate: reading a long score takes long
/// enough to stall the screen.
Future<nm.MidiSequence> buildPlaybackMidiInBackground({
  required String? engravingXml,
  required MusicScore score,
  required PlaybackSequence sequence,
  required ArrangementProfile arrangement,
  required int bpm,
}) {
  return Isolate.run(
    () => buildPlaybackMidi(
      engravingXml: engravingXml,
      score: score,
      sequence: sequence,
      arrangement: arrangement,
      bpm: bpm,
    ),
  );
}
