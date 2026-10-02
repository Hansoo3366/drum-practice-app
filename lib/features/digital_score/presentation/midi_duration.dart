import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:xml/xml.dart';

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

/// The MIDI of a score with the instrument of each channel.
class PlaybackMidi {
  const PlaybackMidi(this.sequence, this.programs, this.levels);

  final nm.MidiSequence sequence;

  /// General MIDI program (from 0) by MIDI channel; a channel not listed
  /// plays the piano.
  final Map<int, int> programs;

  /// Volume by MIDI channel, 1.0 for full and for a channel not listed.
  final Map<int, double> levels;
}

/// General MIDI program (from 0) of every staff of [musicXml] in score
/// order: that of its part's `<midi-program>`, the piano without one or for
/// a sung part.
List<int> staffPrograms(String musicXml) =>
    _staffPrograms(XmlDocument.parse(musicXml).rootElement);

List<int> _staffPrograms(XmlElement root) {
  final byPart = <String?, int>{};
  for (final part in root.findAllElements('score-part')) {
    final written = int.tryParse(
      part.findAllElements('midi-program').firstOrNull?.innerText.trim() ?? '',
    );
    // Written from 1. A sung part (choir aahs, voice oohs, synth voice:
    // 52-54) is played on the piano: sampled voices blur a quick melody.
    final program = ((written ?? 1) - 1).clamp(0, 127);
    byPart[part.getAttribute('id')] = program >= 52 && program <= 54
        ? 0
        : program;
  }
  final programs = <int>[];
  for (final part in root.findElements('part')) {
    var staves = 1;
    for (final element in part.findAllElements('staves')) {
      final count = int.tryParse(element.innerText.trim()) ?? 1;
      if (count > staves) staves = count;
    }
    for (var staff = 0; staff < staves; staff++) {
      programs.add(byPart[part.getAttribute('id')] ?? 0);
    }
  }
  return programs;
}

/// How loud each staff of [musicXml] plays next to the first part (1.0), in
/// score order: the parts under it accompany, and instruments that hold
/// their notes at full strength (organ, strings, pads) cover more than a
/// piano that fades.
List<double> staffLevels(String musicXml) =>
    _staffLevels(XmlDocument.parse(musicXml).rootElement);

List<double> _staffLevels(XmlElement root) {
  final programs = _staffPrograms(root);
  final levels = <double>[];
  var first = true;
  for (final part in root.findElements('part')) {
    var staves = 1;
    for (final element in part.findAllElements('staves')) {
      final count = int.tryParse(element.innerText.trim()) ?? 1;
      if (count > staves) staves = count;
    }
    for (var staff = 0; staff < staves; staff++) {
      final program = programs[levels.length];
      // General MIDI families: organs 16-23, strings and ensembles 40-55,
      // brass 56-63, pads 88-95.
      final sustained =
          (program >= 16 && program <= 23) ||
          (program >= 40 && program <= 55) ||
          (program >= 88 && program <= 95);
      final brass = program >= 56 && program <= 63;
      levels.add(
        first
            ? 1.0
            : sustained
            ? 0.22
            : brass
            ? 0.35
            : 0.5,
      );
    }
    first = false;
  }
  return levels;
}

/// The program of each channel of [sequence], made from [musicXml]: the
/// mapper writes one track per staff, in score order.
Map<int, int> channelPrograms(nm.MidiSequence sequence, String musicXml) =>
    _byChannel(sequence, staffPrograms(musicXml));

/// The level of each channel of [sequence]; see [staffLevels].
Map<int, double> channelLevels(nm.MidiSequence sequence, String musicXml) =>
    _byChannel(sequence, staffLevels(musicXml));

Map<int, T> _byChannel<T>(nm.MidiSequence sequence, List<T> staves) {
  final programs = <int, T>{};
  var staff = 0;
  for (final track in sequence.tracks) {
    final name = track.name.toLowerCase();
    if (name == 'conductor' || name == 'metronome') continue;
    if (staff < staves.length) {
      for (final event in track.events) {
        if (event.type == nm.MidiEventType.noteOn) {
          programs[event.channel] = staves[staff];
        }
      }
    }
    staff++;
  }
  return programs;
}

/// A Standard MIDI File of [midi] in which every channel is set to its
/// instrument, so other programs play the parts as this one does.
Uint8List playbackMidiFile(PlaybackMidi midi) {
  final sequence = midi.sequence;
  return nm.MidiFileWriter.write(
    nm.MidiSequence(
      ticksPerQuarter: sequence.ticksPerQuarter,
      tracks: [
        for (final track in sequence.tracks)
          nm.MidiTrack(
            name: track.name,
            channel: track.channel,
            events: [
              for (final event in track.events)
                event.type == nm.MidiEventType.programChange
                    ? nm.MidiEvent.programChange(
                        tick: event.tick,
                        channel: event.channel,
                        program: midi.programs[event.channel] ?? 0,
                      )
                    : event,
            ],
          ),
      ],
    ),
  );
}

/// The MIDI the player plays for [score]: its bars in [performanceMeasureMap]
/// order, the order the play head follows and the expanded copy uses.
///
/// Made from the file [engravingXml] when it is on screen and no
/// accompaniment is added, so tuplets, ties and every voice play as written;
/// otherwise from the editing model.
PlaybackMidi buildPlaybackMidi({
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
  final midi = playbackMidi(
    playing,
    options: nm.MidiGenerationOptions(defaultBpm: bpm, includeMetronome: false),
    codec: codec,
  );
  // Instruments and levels from one reading of the score.
  final root = XmlDocument.parse(playing).rootElement;
  return PlaybackMidi(
    midi,
    _byChannel(midi, _staffPrograms(root)),
    _byChannel(midi, _staffLevels(root)),
  );
}

/// [buildPlaybackMidi] off the UI isolate: reading a long score takes long
/// enough to stall the screen.
Future<PlaybackMidi> buildPlaybackMidiInBackground({
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
