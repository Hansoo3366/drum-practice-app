import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/metronome_tempo.dart';
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

/// When each tick of a sequence sounds, following its tempo changes.
class MidiTiming {
  MidiTiming(nm.MidiSequence sequence, {int fallbackBpm = 120})
    : ticksPerQuarter = sequence.ticksPerQuarter <= 0
          ? 960
          : sequence.ticksPerQuarter,
      totalTicks = sequence.totalTicks {
    final tempos = [
      for (final track in sequence.tracks)
        for (final event in track.events)
          if (event.type == nm.MidiEventType.tempo && (event.bpm ?? 0) > 0)
            event,
    ]..sort((a, b) => a.tick.compareTo(b.tick));
    var bpm = fallbackBpm <= 0 ? 120 : fallbackBpm;
    var tick = 0;
    var ms = 0.0;
    _ticks.add(0);
    _ms.add(0);
    _bpm.add(bpm);
    for (final event in tempos) {
      ms += (event.tick - tick) * 60000 / (bpm * ticksPerQuarter);
      tick = event.tick;
      bpm = event.bpm!;
      if (_ticks.last == tick) {
        _bpm[_bpm.length - 1] = bpm;
      } else {
        _ticks.add(tick);
        _ms.add(ms);
        _bpm.add(bpm);
      }
    }
  }

  final int ticksPerQuarter;
  final int totalTicks;
  final _ticks = <int>[];
  final _ms = <double>[];
  final _bpm = <int>[];

  /// Milliseconds from the start at which [tick] sounds.
  double msAt(num tick) {
    var i = _ticks.length - 1;
    while (i > 0 && _ticks[i] > tick) {
      i--;
    }
    return _ms[i] + (tick - _ticks[i]) * 60000 / (_bpm[i] * ticksPerQuarter);
  }

  double get durationMs => msAt(totalTicks);
}

/// The one tempo [playableSequence] is written in.
const _playerBpm = 120;

/// [sequence] as the native player can play it. The player keeps the first
/// tempo for the whole piece and always starts at its first tick, so a
/// ritardando, a pause that is taken up again, a move along the bar and a
/// slower practice tempo all have to be written into the ticks: every note
/// is put where it sounds, counted from [fromMs] of the music's own time
/// and played [speed] times as fast, at one tempo.
///
/// A note already sounding at [fromMs] is left out with its end.
nm.MidiSequence playableSequence(
  nm.MidiSequence sequence,
  MidiTiming timing, {
  double fromMs = 0,
  double speed = 1,
}) {
  final perMs = _playerBpm * timing.ticksPerQuarter / 60000;
  final rate = speed <= 0 ? 1.0 : speed;
  int at(int tick) => ((timing.msAt(tick) - fromMs) / rate * perMs).round();
  bool isOn(nm.MidiEvent e) =>
      e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) > 0;
  bool isOff(nm.MidiEvent e) =>
      e.type == nm.MidiEventType.noteOff ||
      (e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) == 0);

  nm.MidiEvent? signature;
  for (final track in sequence.tracks) {
    for (final event in track.events) {
      if (event.type != nm.MidiEventType.timeSignature) continue;
      if (event.numerator == null || event.denominator == null) continue;
      if (signature == null || event.tick < signature.tick) signature = event;
    }
  }
  final tracks = <nm.MidiTrack>[
    nm.MidiTrack(
      name: 'Conductor',
      channel: 0,
      events: [
        const nm.MidiEvent.tempo(tick: 0, bpm: _playerBpm),
        if (signature != null)
          nm.MidiEvent.timeSignature(
            tick: 0,
            numerator: signature.numerator!,
            denominator: signature.denominator!,
          ),
      ],
    ),
  ];
  for (final track in sequence.tracks) {
    if (track.name.toLowerCase() == 'conductor') continue;
    // Ends before beginnings at the same tick, as the player pairs them.
    final ordered = [
      for (final event in track.events)
        if (isOn(event) || isOff(event)) event,
    ];
    final indexed = [for (var i = 0; i < ordered.length; i++) (i, ordered[i])]
      ..sort((a, b) {
        final byTick = a.$2.tick.compareTo(b.$2.tick);
        if (byTick != 0) return byTick;
        final byKind = (isOff(a.$2) ? 0 : 1).compareTo(isOff(b.$2) ? 0 : 1);
        return byKind != 0 ? byKind : a.$1.compareTo(b.$1);
      });
    // Notes begun before the start: how many ends of each are still to come.
    final leftOut = <(int, int), int>{};
    final events = <nm.MidiEvent>[];
    for (final (_, event) in indexed) {
      final key = (event.channel, event.note ?? 0);
      final tick = at(event.tick);
      if (isOn(event)) {
        if (tick < 0) {
          leftOut[key] = (leftOut[key] ?? 0) + 1;
          continue;
        }
        events.add(
          nm.MidiEvent.noteOn(
            tick: tick,
            channel: event.channel,
            note: event.note ?? 0,
            velocity: event.velocity ?? 0,
          ),
        );
        continue;
      }
      final waiting = leftOut[key] ?? 0;
      if (waiting > 0) {
        leftOut[key] = waiting - 1;
        continue;
      }
      events.add(
        nm.MidiEvent.noteOff(
          tick: math.max(0, tick),
          channel: event.channel,
          note: event.note ?? 0,
        ),
      );
    }
    tracks.add(track.copyWith(events: events));
  }
  return nm.MidiSequence(
    ticksPerQuarter: timing.ticksPerQuarter,
    tracks: tracks,
    warnings: sequence.warnings,
  );
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
    // The reader of this file knows a mark's beat unit but not its dot.
    nm.MusicXMLParser.scoreFromMusicXML(metronomesInQuarters(copies.untied)),
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
  final shapes = playedHairpins(copies.ready, played);
  final tempo = playedTempo(copies.ready, played);
  final silent = tacetNotes(copies.ready, played);
  return shapeTempo(
    shapeSwing(
      shapeHairpins(
        withoutNotes(mergeTiedNotes(sequence, staves), [
          for (var staff = 0; staff < staves.length; staff++)
            [
              for (final note in silent)
                if (note.staffIndex == staff)
                  (
                    (note.quarters * sequence.ticksPerQuarter).round(),
                    note.midi,
                  ),
            ],
        ]),
        shapes.hairpins,
        shapes.marks,
      ),
      tempo,
    ),
    tempo,
    fallbackBpm: options.defaultBpm,
  );
}

/// [sequence] with the eighths between the beats played late, as jazz
/// players play them, from where the score says "Swing" to where it says
/// "Straight" (or to the end): two eighths of a beat are a long one and a
/// short one, two thirds and one third of the beat.
nm.MidiSequence shapeSwing(nm.MidiSequence sequence, PlayedTempo tempo) {
  final spans = <(int, int)>[];
  int? from;
  final tpq = sequence.ticksPerQuarter;
  for (final word in tempo.words) {
    final tick = (word.at * tpq).round();
    if (word.word == TempoWord.swing) {
      from ??= tick;
    } else if (word.word == TempoWord.straight && from != null) {
      spans.add((from, tick));
      from = null;
    }
  }
  if (from != null) spans.add((from, 1 << 40));
  if (spans.isEmpty) return sequence;
  final half = tpq ~/ 2;
  final late = tpq * 2 ~/ 3 - half;
  int swung(int tick) {
    if (!spans.any((span) => tick >= span.$1 && tick < span.$2)) return tick;
    // On the eighth between two beats, give or take what a shortened note
    // ends early by.
    return (tick % tpq - half).abs() <= tpq ~/ 16 ? tick + late : tick;
  }

  return nm.MidiSequence(
    ticksPerQuarter: tpq,
    tracks: [
      for (final track in sequence.tracks)
        nm.MidiTrack(
          name: track.name,
          channel: track.channel,
          events: _inTickOrder([
            for (final event in track.events)
              if (event.type == nm.MidiEventType.noteOn &&
                  (event.velocity ?? 0) > 0)
                nm.MidiEvent.noteOn(
                  tick: swung(event.tick),
                  channel: event.channel,
                  note: event.note!,
                  velocity: event.velocity!,
                )
              else if (event.note != null &&
                  (event.type == nm.MidiEventType.noteOff ||
                      event.type == nm.MidiEventType.noteOn))
                nm.MidiEvent.noteOff(
                  tick: swung(event.tick),
                  channel: event.channel,
                  note: event.note!,
                )
              else
                event,
          ]),
        ),
    ],
  );
}

/// [sequence] without the notes at [silent]: per staff track in score
/// order, the tick each begins at and its pitch. Notes written but not
/// played (tacet).
nm.MidiSequence withoutNotes(
  nm.MidiSequence sequence,
  List<List<(int tick, int midi)>> silent,
) {
  if (silent.every((notes) => notes.isEmpty)) return sequence;
  bool isOn(nm.MidiEvent e) =>
      e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) > 0;
  bool isOff(nm.MidiEvent e) =>
      e.type == nm.MidiEventType.noteOff ||
      (e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) == 0);
  final staffTracks = [
    for (final track in sequence.tracks)
      if (track.name != 'Conductor') track,
  ];
  if (staffTracks.length != silent.length) return sequence;
  return nm.MidiSequence(
    ticksPerQuarter: sequence.ticksPerQuarter,
    tracks: [
      for (final track in sequence.tracks)
        if (staffTracks.indexOf(track) case final index
            when index >= 0 && silent[index].isNotEmpty)
          nm.MidiTrack(
            name: track.name,
            channel: track.channel,
            events: () {
              final events = track.events.toList();
              for (final (tick, midi) in silent[index]) {
                final on = events.indexWhere(
                  (e) =>
                      isOn(e) && e.note == midi && (e.tick - tick).abs() <= 2,
                );
                if (on < 0) continue;
                final channel = events[on].channel;
                final start = events[on].tick;
                events.removeAt(on);
                // Its end is the first end of that pitch after it began.
                final off = events.indexWhere(
                  (e) =>
                      isOff(e) &&
                      e.note == midi &&
                      e.channel == channel &&
                      e.tick >= start,
                );
                if (off >= 0) events.removeAt(off);
              }
              return events;
            }(),
          )
        else
          track,
    ],
  );
}

/// The channel the metronome clicks on, and the instrument it clicks with
/// (a woodblock, counted from 0 as the player counts).
const metronomeChannel = 15;
const metronomeProgram = 115;

/// [sequence] with a click on every beat: [bars] are the bars as they are
/// played, each with its length and the length of its beat in quarter
/// notes. The first click of a bar is higher and louder. The bars are
/// spread over the sequence as the play head spreads them.
nm.MidiSequence withMetronomeClicks(
  nm.MidiSequence sequence,
  List<({double quarters, double beat})> bars,
) {
  final total = bars.fold<double>(0, (sum, bar) => sum + bar.quarters);
  final ticks = sequence.totalTicks;
  if (total <= 0 || ticks <= 0) return sequence;
  final clicks = <nm.MidiEvent>[];
  final length = math.max(1, sequence.ticksPerQuarter ~/ 8);
  var start = 0.0;
  for (final bar in bars) {
    final beat = bar.beat <= 0 ? 1.0 : bar.beat;
    for (var at = 0.0; at < bar.quarters - 1e-6; at += beat) {
      final tick = ((start + at) / total * ticks).round();
      final first = at == 0;
      clicks
        ..add(
          nm.MidiEvent.noteOn(
            tick: tick,
            channel: metronomeChannel,
            note: first ? 88 : 81,
            velocity: first ? 112 : 84,
          ),
        )
        ..add(
          nm.MidiEvent.noteOff(
            tick: tick + length,
            channel: metronomeChannel,
            note: first ? 88 : 81,
          ),
        );
    }
    start += bar.quarters;
  }
  return nm.MidiSequence(
    ticksPerQuarter: sequence.ticksPerQuarter,
    tracks: [
      ...sequence.tracks,
      nm.MidiTrack(
        name: 'Metronome',
        channel: metronomeChannel,
        events: _inTickOrder(clicks),
      ),
    ],
  );
}

/// [events] in the order of their ticks; those of one tick stay in the
/// order they were in (a note that ends where the next begins must end
/// first).
List<nm.MidiEvent> _inTickOrder(List<nm.MidiEvent> events) {
  final numbered = [for (final (index, event) in events.indexed) (index, event)]
    ..sort(
      (a, b) => a.$2.tick != b.$2.tick
          ? a.$2.tick.compareTo(b.$2.tick)
          : a.$1.compareTo(b.$1),
    );
  return [for (final (_, event) in numbered) event];
}

/// [sequence] with what the score says of its tempo in words and signs
/// played: it slows down under "rit." and speeds up under "accel." (by
/// about a quarter, beat by beat, until "a tempo", the next tempo mark, or
/// two bars on), and a note under a fermata is held twice as long (half as
/// long again under an angled one, three times under a square one).
nm.MidiSequence shapeTempo(
  nm.MidiSequence sequence,
  PlayedTempo tempo, {
  required int fallbackBpm,
}) {
  final moves = [
    for (final word in tempo.words)
      if (word.word == TempoWord.slower || word.word == TempoWord.faster) word,
  ];
  if (moves.isEmpty && tempo.holds.isEmpty) return sequence;
  final tpq = sequence.ticksPerQuarter;
  int tickOf(double quarters) => (quarters * tpq).round();
  // The tempo as written, by tick.
  final written = <int, int>{};
  for (final track in sequence.tracks) {
    for (final event in track.events) {
      if (event.type == nm.MidiEventType.tempo && (event.bpm ?? 0) > 0) {
        written[event.tick] = event.bpm!;
      }
    }
  }
  final marks = written.keys.toList()..sort();
  int bpmAt(int tick) {
    var bpm = fallbackBpm <= 0 ? 120 : fallbackBpm;
    for (final mark in marks) {
      if (mark > tick) break;
      bpm = written[mark]!;
    }
    return bpm;
  }

  // The tempo as played, by tick: the written one with the changes below.
  final played = <int, int>{};
  for (final (index, move) in moves.indexed) {
    final from = tickOf(move.at);
    // Until the score says how fast again: a tempo mark, "a tempo", the
    // next "rit." or "accel."; without any, two bars on.
    final bar = tempo.bars.lastIndexWhere((start) => start <= move.at + 1e-6);
    final twoBars = bar + 2 < tempo.bars.length
        ? tempo.bars[bar + 2]
        : tempo.end;
    var until = tickOf(twoBars);
    for (final mark in marks) {
      if (mark > from && mark < until) until = mark;
    }
    for (final word in tempo.words) {
      final tick = tickOf(word.at);
      if (word.word == TempoWord.asBefore && tick > from && tick < until) {
        until = tick;
      }
    }
    if (index + 1 < moves.length) {
      final next = tickOf(moves[index + 1].at);
      if (next > from && next < until) until = next;
    }
    if (until <= from) continue;
    final base = bpmAt(from);
    final goal = base * (move.word == TempoWord.slower ? 0.72 : 1.3);
    // A step every beat, the last one at the goal.
    final steps = math.max(1, ((until - from) / tpq).round());
    for (var step = 0; step < steps; step++) {
      final tick = from + (until - from) * step ~/ steps;
      played[tick] = (base + (goal - base) * (step + 1) / steps).round();
    }
    // What follows goes as it was written, unless it says itself how fast.
    played.putIfAbsent(until, () => bpmAt(until));
  }
  for (final hold in tempo.holds) {
    final from = tickOf(hold.from);
    final to = tickOf(hold.to);
    if (to <= from) continue;
    int nowAt(int tick) {
      var bpm = bpmAt(tick);
      final earlier = played.keys.where((at) => at <= tick).toList()..sort();
      if (earlier.isNotEmpty &&
          !marks.any((m) => m > earlier.last && m <= tick)) {
        bpm = played[earlier.last]!;
      }
      return bpm;
    }

    final after = nowAt(to);
    played[from] = math.max(10, (nowAt(from) / hold.times).round());
    // Changes inside the held note would end the hold early.
    played.removeWhere((tick, _) => tick > from && tick < to);
    played[to] = written[to] ?? after;
  }
  if (played.isEmpty) return sequence;
  final conductor = sequence.tracks.indexWhere(
    (track) => track.events.any((e) => e.type == nm.MidiEventType.tempo),
  );
  final target = conductor < 0 ? 0 : conductor;
  return nm.MidiSequence(
    ticksPerQuarter: tpq,
    tracks: [
      for (final (index, track) in sequence.tracks.indexed)
        if (index != target)
          track
        else
          nm.MidiTrack(
            name: track.name,
            channel: track.channel,
            events: _inTickOrder([
              for (final event in track.events)
                if (event.type != nm.MidiEventType.tempo ||
                    !played.containsKey(event.tick))
                  event,
              for (final MapEntry(key: tick, value: bpm) in played.entries)
                nm.MidiEvent.tempo(tick: tick, bpm: bpm),
            ]),
          ),
    ],
  );
}

/// [sequence] with its hairpins played: under a crescendo every note is a
/// little louder than the one before, under a diminuendo softer.
///
/// Where a dynamic mark follows the hairpin, the notes grow to what it
/// says. Without one they grow by about a mark's worth (mf to f) and stay
/// there, as a player does, until the next dynamic mark.
///
/// The mapper writes one track per staff, in score order.
nm.MidiSequence shapeHairpins(
  nm.MidiSequence sequence,
  List<PlayedHairpin> hairpins,
  List<({double at, int firstStaff})> marks,
) {
  if (hairpins.isEmpty) return sequence;
  bool isOn(nm.MidiEvent e) =>
      e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) > 0;
  final staffTracks = [
    for (final track in sequence.tracks)
      if (track.name != 'Conductor') track,
  ];
  final tpq = sequence.ticksPerQuarter;
  // By how much a note at a tick is louder or softer than written, per
  // staff track: pieces of a line, each from one factor to another.
  final shapes =
      <nm.MidiTrack, List<({int from, int to, double begin, double end})>>{};
  final byPart = <int, List<PlayedHairpin>>{};
  for (final hairpin in hairpins) {
    byPart.putIfAbsent(hairpin.firstStaff, () => []).add(hairpin);
  }
  for (final MapEntry(key: firstStaff, value: ofPart) in byPart.entries) {
    ofPart.sort((a, b) => a.from.compareTo(b.from));
    final staves = ofPart.first.staves;
    if (firstStaff + staves > staffTracks.length) continue;
    final tracks = staffTracks.sublist(firstStaff, firstStaff + staves);
    final notes = [
      for (final track in tracks)
        for (final event in track.events)
          if (isOn(event)) event,
    ]..sort((a, b) => a.tick.compareTo(b.tick));
    if (notes.isEmpty) continue;
    final markTicks = [
      for (final mark in marks)
        if (mark.firstStaff == firstStaff) (mark.at * tpq).round(),
    ]..sort();
    final pieces = <({int from, int to, double begin, double end})>[];
    // What the last hairpin left the notes at, and until where.
    var held = 1.0;
    var heldUntil = 0;
    for (var i = 0; i < ofPart.length; i++) {
      final hairpin = ofPart[i];
      final from = (hairpin.from * tpq).round();
      final to = (hairpin.to * tpq).round();
      final begin = from < heldUntil ? held : 1.0;
      // As loud as written where the hairpin begins, and where it ends.
      final before = notes.lastWhere(
        (note) => note.tick <= from,
        orElse: () => notes.first,
      );
      // A mark under the hairpin, or right at its end, is where it goes:
      // the last note under a hairpin is often the one that is marked.
      final goal =
          markTicks
              .where((tick) => tick > from + 2 && tick <= to + 2)
              .lastOrNull ??
          to;
      final after = notes.where((note) => note.tick >= goal - 2).firstOrNull;
      final written = after == null
          ? 1.0
          : (after.velocity ?? 1) / math.max(1, before.velocity ?? 1);
      final marked = hairpin.louder ? written > 1.05 : written < 0.95;
      if (marked) {
        // The mark after it says where it goes.
        pieces.add((from: from, to: goal, begin: begin, end: written));
        held = 1.0;
        heldUntil = goal;
        continue;
      }
      final end = (begin * (hairpin.louder ? 1.3 : 1 / 1.3)).clamp(0.4, 2.0);
      pieces.add((from: from, to: to, begin: begin, end: end));
      // It stays there until a mark says otherwise, or the next hairpin
      // takes over.
      final nextMark = markTicks.where((tick) => tick >= to - 2).firstOrNull;
      final nextHairpin = i + 1 < ofPart.length
          ? (ofPart[i + 1].from * tpq).round()
          : null;
      final until = [?nextMark, ?nextHairpin].fold<int?>(
        null,
        (least, tick) => least == null || tick < least ? tick : least,
      );
      held = end;
      heldUntil = until ?? (1 << 40);
      if (heldUntil > to) {
        pieces.add((from: to, to: heldUntil, begin: end, end: end));
      }
    }
    for (final track in tracks) {
      shapes[track] = pieces;
    }
  }
  if (shapes.isEmpty) return sequence;
  return nm.MidiSequence(
    ticksPerQuarter: tpq,
    tracks: [
      for (final track in sequence.tracks)
        if (shapes[track] case final pieces?)
          nm.MidiTrack(
            name: track.name,
            channel: track.channel,
            events: [
              for (final event in track.events)
                if (isOn(event)) _shaped(event, pieces) else event,
            ],
          )
        else
          track,
    ],
  );
}

nm.MidiEvent _shaped(
  nm.MidiEvent event,
  List<({int from, int to, double begin, double end})> pieces,
) {
  for (final piece in pieces) {
    if (event.tick < piece.from || event.tick >= piece.to) continue;
    final along = piece.to == piece.from
        ? 1.0
        : (event.tick - piece.from) / (piece.to - piece.from);
    final factor = piece.begin + (piece.end - piece.begin) * along;
    final velocity = ((event.velocity ?? 0) * factor).round().clamp(1, 127);
    if (velocity == event.velocity) return event;
    return nm.MidiEvent.noteOn(
      tick: event.tick,
      channel: event.channel,
      note: event.note!,
      velocity: velocity,
    );
  }
  return event;
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

/// The part (counted through the score) each channel of [sequence] plays:
/// the mapper writes one track per staff, in score order, and a part has
/// as many staves as its bars say at most.
Map<int, int> channelParts(nm.MidiSequence sequence, MusicScore score) =>
    _byChannel(sequence, [
      for (final (index, part) in score.parts.indexed)
        for (
          var staff = 0;
          staff <
              part.measures.fold<int>(
                1,
                (most, bar) => math.max(most, bar.attributes.staves),
              );
          staff++
        )
          index,
    ]);

/// How loud each part is to be heard, as a listener sets a mixer: [levels]
/// by part (1.0 as written), with the parts in [muted] silent and, when
/// any part is in [solo], only those heard.
List<double> mixedLevels(
  int parts, {
  Map<int, double> levels = const {},
  Set<int> muted = const {},
  Set<int> solo = const {},
}) => [
  for (var part = 0; part < parts; part++)
    muted.contains(part) || (solo.isNotEmpty && !solo.contains(part))
        ? 0.0
        : (levels[part] ?? 1.0).clamp(0.0, 1.5),
];

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
  final built = PlaybackMidi(
    midi,
    _byChannel(midi, _staffPrograms(root)),
    _byChannel(midi, _staffLevels(root)),
  );
  // A part that changes its instrument on the way is read once more for
  // where it does; most scores have no such change.
  if (!playing.contains('<midi-instrument') ||
      !root
          .findAllElements('measure')
          .any((m) => m.findAllElements('midi-instrument').isNotEmpty)) {
    return built;
  }
  return withInstrumentChanges(
    built,
    instrumentChanges(playing, codec.decodeXml(playing)),
  );
}

/// [midi] with the parts going on with other instruments where the score
/// says so. The player gives each channel one instrument for the whole
/// piece, so what a part plays after a change is moved to a channel of
/// its own, set to the new instrument and as loud as the part was.
PlaybackMidi withInstrumentChanges(
  PlaybackMidi midi,
  List<({double at, int firstStaff, int staves, int program})> changes,
) {
  if (changes.isEmpty) return midi;
  final sequence = midi.sequence;
  final tpq = sequence.ticksPerQuarter;
  bool isOn(nm.MidiEvent e) =>
      e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) > 0;
  bool isOff(nm.MidiEvent e) =>
      e.note != null &&
      (e.type == nm.MidiEventType.noteOff ||
          (e.type == nm.MidiEventType.noteOn && (e.velocity ?? 0) == 0));
  final staffTracks = [
    for (final track in sequence.tracks)
      if (track.name != 'Conductor' && track.name != 'Metronome') track,
  ];
  final programs = {...midi.programs};
  final levels = {...midi.levels};
  // Channel 10 is the drums of every synthesizer; the last is the click.
  final taken = <int>{9, metronomeChannel, ...programs.keys};
  for (final track in sequence.tracks) {
    for (final event in track.events) {
      if (event.note != null) taken.add(event.channel);
    }
  }
  final sorted = [...changes]..sort((a, b) => a.at.compareTo(b.at));
  // Per staff track: from which tick on which channel.
  final moves = <nm.MidiTrack, List<({int from, int channel})>>{};
  for (final change in sorted) {
    for (var staff = 0; staff < change.staves; staff++) {
      final index = change.firstStaff + staff;
      if (index >= staffTracks.length) continue;
      final track = staffTracks[index];
      final first = track.events.where(isOn).firstOrNull;
      if (first == null) continue;
      final spare = [
        for (var channel = 0; channel < 16; channel++)
          if (!taken.contains(channel)) channel,
      ].firstOrNull;
      // Every channel is in use: the part keeps its instrument.
      if (spare == null) continue;
      taken.add(spare);
      // A sung part is played on the piano, as in [staffPrograms].
      programs[spare] = change.program >= 52 && change.program <= 54
          ? 0
          : change.program;
      levels[spare] = levels[first.channel] ?? 1.0;
      moves.putIfAbsent(track, () => []).add((
        from: (change.at * tpq).round(),
        channel: spare,
      ));
    }
  }
  if (moves.isEmpty) return midi;
  return PlaybackMidi(
    nm.MidiSequence(
      ticksPerQuarter: tpq,
      tracks: [
        for (final track in sequence.tracks)
          if (moves[track] case final steps?)
            nm.MidiTrack(
              name: track.name,
              channel: track.channel,
              events: () {
                // A note ends on the channel it began on.
                final open = <int, List<int>>{};
                return [
                  for (final event in track.events)
                    if (isOn(event))
                      () {
                        final channel =
                            steps
                                .where((step) => event.tick >= step.from - 2)
                                .lastOrNull
                                ?.channel ??
                            event.channel;
                        open.putIfAbsent(event.note!, () => []).add(channel);
                        return nm.MidiEvent.noteOn(
                          tick: event.tick,
                          channel: channel,
                          note: event.note!,
                          velocity: event.velocity!,
                        );
                      }()
                    else if (isOff(event))
                      nm.MidiEvent.noteOff(
                        tick: event.tick,
                        channel: switch (open[event.note!]) {
                          final channels? when channels.isNotEmpty =>
                            channels.removeAt(0),
                          _ => event.channel,
                        },
                        note: event.note!,
                      )
                    else
                      event,
                ];
              }(),
            )
          else
            track,
      ],
    ),
    programs,
    levels,
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
