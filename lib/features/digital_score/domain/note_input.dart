import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';

/// Where the next note or rest will be written.
///
/// MuseScore and Flat keep this cursor visible during note input. A tap or
/// key chooses the pitch; the cursor chooses the rhythmic position and then
/// advances by the written duration.
class NoteCaret {
  const NoteCaret({
    required this.partIndex,
    required this.measureIndex,
    required this.staff,
    required this.onset,
    this.voice = '1',
  });

  final int partIndex;
  final int measureIndex;
  final int staff;
  final int onset;
  final String voice;

  NoteCaret copyWith({
    int? partIndex,
    int? measureIndex,
    int? staff,
    int? onset,
    String? voice,
  }) {
    return NoteCaret(
      partIndex: partIndex ?? this.partIndex,
      measureIndex: measureIndex ?? this.measureIndex,
      staff: staff ?? this.staff,
      onset: onset ?? this.onset,
      voice: voice ?? this.voice,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NoteCaret &&
        other.partIndex == partIndex &&
        other.measureIndex == measureIndex &&
        other.staff == staff &&
        other.onset == onset &&
        other.voice == voice;
  }

  @override
  int get hashCode => Object.hash(partIndex, measureIndex, staff, onset, voice);
}

class NoteInputRequest {
  const NoteInputRequest({
    required this.partIndex,
    required this.measureIndex,
    required this.staff,
    required this.onsetTicks,
    required this.midi,
    required this.durationType,
    this.rest = false,
    this.alter = 0,
    this.dots = 0,
    this.chord = false,
    this.spelledPitch,
  });

  final int partIndex;
  final int measureIndex;
  final int staff;
  final int onsetTicks;
  final int midi;
  final String durationType;
  final bool rest;
  final int alter;
  final int dots;
  final bool chord;

  /// Keeps an existing spelling when the command changes duration, not pitch.
  final MusicPitch? spelledPitch;
}

class NoteWriteResult {
  const NoteWriteResult({
    required this.score,
    required this.caret,
    required this.changed,
    this.address,
  });

  final MusicScore score;
  final NoteCaret caret;
  final bool changed;
  final ScoreEventAddress? address;
}

class DurationSpelling {
  const DurationSpelling({required this.type, required this.dots});

  final String? type;
  final int dots;
}

DurationSpelling spellDuration(int duration, int divisions) {
  const types = ['whole', 'half', 'quarter', 'eighth', '16th'];
  final attributes = MusicAttributes(
    divisions: math.max(1, divisions),
    time: const MusicTimeSignature(beats: 4, beatType: 4),
  );
  for (final type in types) {
    final plain = durationForType(attributes, type);
    if (plain == duration) {
      return DurationSpelling(type: type, dots: 0);
    }
    final dotted = durationForType(attributes, type, dots: 1);
    if (dotted != plain && dotted == duration) {
      return DurationSpelling(type: type, dots: 1);
    }
  }
  return const DurationSpelling(type: null, dots: 0);
}

int onsetToTicks(int onset, int divisions) {
  return math.max(
    0,
    (onset * alphaTabQuarterTicks / math.max(1, divisions)).round(),
  );
}

/// Letter-name entry uses the octave closest to the previous note on the staff.
int midiForLetter(
  String letter, {
  required int? previousMidi,
  required int staff,
}) {
  const semitones = {'c': 0, 'd': 2, 'e': 4, 'f': 5, 'g': 7, 'a': 9, 'b': 11};
  final step = semitones[letter.toLowerCase()];
  if (step == null) {
    throw FormatException('Unsupported pitch letter $letter.');
  }
  final octave = previousMidi == null
      ? (staff >= 2 ? 3 : 4)
      : (previousMidi ~/ 12) - 1;
  var midi = ((octave + 1) * 12) + step;
  if (previousMidi != null) {
    final candidates = [midi - 12, midi, midi + 12];
    midi = candidates.reduce(
      (best, candidate) =>
          (candidate - previousMidi).abs() < (best - previousMidi).abs()
          ? candidate
          : best,
    );
  }
  return midi.clamp(21, 108);
}

int? previousMidiOnStaff(MusicScore score, NoteCaret caret) {
  if (caret.partIndex < 0 || caret.partIndex >= score.parts.length) {
    return null;
  }
  final measures = score.parts[caret.partIndex].measures;
  MusicNote? latest;
  final lastMeasure = math.min(caret.measureIndex, measures.length - 1);
  for (var measureIndex = 0; measureIndex <= lastMeasure; measureIndex++) {
    for (final event in measures[measureIndex].events) {
      if (event is! MusicNote || event.isRest || event.pitch == null) continue;
      if (event.staff != caret.staff || event.isGrace) continue;
      if (measureIndex == caret.measureIndex && event.onset >= caret.onset) {
        continue;
      }
      latest = event;
    }
  }
  return latest?.pitch?.midi;
}

String voiceOnStaff(
  MusicMeasure measure, {
  required int staff,
  required int onset,
}) {
  for (final event in measure.events) {
    if (event is! MusicNote || event.isGrace || event.staff != staff) continue;
    if (event.onset <= onset && event.end > onset) return event.voice;
  }
  for (final event in measure.events) {
    if (event is MusicNote && !event.isGrace && event.staff == staff) {
      return event.voice;
    }
  }
  return '$staff';
}

NoteWriteResult writeNoteInput(MusicScore score, NoteInputRequest request) {
  final before = _signature(score);
  final written = _write(score, request);
  final changed = _signature(written.score) != before;
  return NoteWriteResult(
    score: changed ? written.score : score,
    caret: written.caret,
    changed: changed,
    address: written.address,
  );
}

NoteWriteResult changeNoteDuration(
  MusicScore score,
  ScoreEventAddress address, {
  required String durationType,
  int dots = 0,
}) {
  final located = _noteAt(score, address);
  if (located == null) {
    return _unchanged(score, address);
  }
  final note = located.note;
  final measure = located.measure;
  final siblings = <MusicPitch>[];
  if (!note.isRest && note.pitch != null) {
    for (final event in measure.events) {
      if (event is! MusicNote || event.isRest || event.pitch == null) continue;
      if (event.staff != note.staff || event.voice != note.voice) continue;
      if (event.onset != note.onset || event.isGrace) continue;
      if (event.pitch!.midi == note.pitch!.midi) continue;
      siblings.add(event.pitch!);
    }
  }
  var result = writeNoteInput(
    score,
    NoteInputRequest(
      partIndex: address.partIndex,
      measureIndex: address.measureIndex,
      staff: note.staff,
      onsetTicks: onsetToTicks(note.onset, measure.attributes.divisions),
      midi: note.pitch?.midi ?? 60,
      durationType: durationType,
      dots: dots,
      rest: note.isRest,
      spelledPitch: note.pitch,
    ),
  );
  for (final pitch in siblings) {
    final caret = result.caret;
    final writtenMeasure = result.address == null
        ? address.measureIndex
        : result.address!.measureIndex;
    final host = result.score.parts[address.partIndex].measures[writtenMeasure];
    result = writeNoteInput(
      result.score,
      NoteInputRequest(
        partIndex: address.partIndex,
        measureIndex: writtenMeasure,
        staff: note.staff,
        onsetTicks: onsetToTicks(note.onset, host.attributes.divisions),
        midi: pitch.midi,
        durationType: durationType,
        dots: dots,
        chord: true,
        spelledPitch: pitch,
      ),
    );
    result = NoteWriteResult(
      score: result.score,
      caret: result.changed ? result.caret : caret,
      changed: result.changed,
      address: result.address,
    );
  }
  return result;
}

NoteWriteResult repitchNote(
  MusicScore score,
  ScoreEventAddress address, {
  required int semitones,
}) {
  final located = _noteAt(score, address);
  if (located == null || located.note.isRest || located.note.pitch == null) {
    return _unchanged(score, address);
  }
  final nextPitch = pitchBySemitone(located.note.pitch!, semitones);
  if (nextPitch.midi == located.note.pitch!.midi &&
      nextPitch.step == located.note.pitch!.step &&
      nextPitch.alter == located.note.pitch!.alter) {
    return _unchanged(score, address, caret: _caretAfter(located));
  }
  final next = ReplaceScoreEventCommand(
    address: address,
    event: located.note.copyWith(pitch: nextPitch),
  ).apply(score);
  return NoteWriteResult(
    score: next,
    caret: _caretAfter(located),
    changed: true,
    address: address,
  );
}

NoteWriteResult shiftNoteOctave(
  MusicScore score,
  ScoreEventAddress address, {
  required int octaves,
}) {
  final located = _noteAt(score, address);
  if (located == null || located.note.isRest || located.note.pitch == null) {
    return _unchanged(score, address);
  }
  final nextPitch = pitchByOctave(located.note.pitch!, octaves);
  if (nextPitch.octave == located.note.pitch!.octave) {
    return _unchanged(score, address, caret: _caretAfter(located));
  }
  final next = ReplaceScoreEventCommand(
    address: address,
    event: located.note.copyWith(pitch: nextPitch),
  ).apply(score);
  return NoteWriteResult(
    score: next,
    caret: _caretAfter(located),
    changed: true,
    address: address,
  );
}

NoteWriteResult deleteNoteRestoringRest(
  MusicScore score,
  ScoreEventAddress address,
) {
  if (address.partIndex < 0 || address.partIndex >= score.parts.length) {
    return _unchanged(score, address);
  }
  final part = score.parts[address.partIndex];
  if (address.measureIndex < 0 ||
      address.measureIndex >= part.measures.length) {
    return _unchanged(score, address);
  }
  final measure = part.measures[address.measureIndex];
  if (address.eventIndex < 0 || address.eventIndex >= measure.events.length) {
    return _unchanged(score, address);
  }
  final event = measure.events[address.eventIndex];
  if (event is! MusicNote) {
    return NoteWriteResult(
      score: DeleteScoreEventCommand(address).apply(score),
      caret: NoteCaret(
        partIndex: address.partIndex,
        measureIndex: address.measureIndex,
        staff: event.staff,
        onset: event.onset,
      ),
      changed: true,
    );
  }
  var working = score;
  final removals = <_NoteRef>[_NoteRef(address.measureIndex, event)];
  if (event.tieStart && event.pitch != null) {
    final nextIndex = address.measureIndex + 1;
    if (nextIndex < part.measures.length) {
      final nextMeasure = part.measures[nextIndex];
      for (final candidate in nextMeasure.events) {
        if (candidate is! MusicNote || !candidate.tieStop) continue;
        if (candidate.staff != event.staff || candidate.voice != event.voice) {
          continue;
        }
        if (candidate.onset != 0 ||
            candidate.pitch?.midi != event.pitch!.midi) {
          continue;
        }
        removals.add(_NoteRef(nextIndex, candidate));
      }
    }
  }
  for (final removal in removals.reversed) {
    final current =
        working.parts[address.partIndex].measures[removal.measureIndex];
    final staff = removal.note.staff;
    final voice = removal.note.voice;
    final kept = [
      for (final candidate in current.events)
        if (!_sameNote(candidate, removal.note)) candidate,
    ];
    final voiceNotes = [
      for (final candidate in kept)
        if (candidate is MusicNote &&
            candidate.staff == staff &&
            candidate.voice == voice &&
            !candidate.isGrace)
          candidate,
    ];
    final grace = [
      for (final candidate in kept)
        if (candidate is MusicNote &&
            candidate.staff == staff &&
            candidate.voice == voice &&
            candidate.isGrace)
          candidate,
    ];
    final others = [
      for (final candidate in kept)
        if (candidate is! MusicNote ||
            candidate.staff != staff ||
            candidate.voice != voice)
          candidate,
    ];
    final filled = _fillVoice(
      voiceNotes,
      capacity: measureCapacity(current.attributes),
      staff: staff,
      voice: voice,
      divisions: current.attributes.divisions,
    );
    working = _putEvents(
      working,
      address.partIndex,
      removal.measureIndex,
      _sorted([...others, ...filled, ...grace]),
    );
  }
  final caret = NoteCaret(
    partIndex: address.partIndex,
    measureIndex: address.measureIndex,
    staff: event.staff,
    onset: event.onset,
    voice: event.voice,
  );
  return NoteWriteResult(
    score: working,
    caret: caret,
    changed: _signature(working) != _signature(score),
  );
}

class WriteNoteInputCommand implements ScoreEditCommand {
  const WriteNoteInputCommand(this.request);

  final NoteInputRequest request;

  @override
  MusicScore apply(MusicScore score) => writeNoteInput(score, request).score;
}

class ChangeNoteDurationCommand implements ScoreEditCommand {
  const ChangeNoteDurationCommand({
    required this.address,
    required this.durationType,
    this.dots = 0,
  });

  final ScoreEventAddress address;
  final String durationType;
  final int dots;

  @override
  MusicScore apply(MusicScore score) {
    return changeNoteDuration(
      score,
      address,
      durationType: durationType,
      dots: dots,
    ).score;
  }
}

class RepitchNoteCommand implements ScoreEditCommand {
  const RepitchNoteCommand(this.address, this.semitones);

  final ScoreEventAddress address;
  final int semitones;

  @override
  MusicScore apply(MusicScore score) {
    return repitchNote(score, address, semitones: semitones).score;
  }
}

class ShiftNoteOctaveCommand implements ScoreEditCommand {
  const ShiftNoteOctaveCommand(this.address, this.octaves);

  final ScoreEventAddress address;
  final int octaves;

  @override
  MusicScore apply(MusicScore score) {
    return shiftNoteOctave(score, address, octaves: octaves).score;
  }
}

class DeleteNoteRestoringRestCommand implements ScoreEditCommand {
  const DeleteNoteRestoringRestCommand(this.address);

  final ScoreEventAddress address;

  @override
  MusicScore apply(MusicScore score) {
    return deleteNoteRestoringRest(score, address).score;
  }
}

NoteWriteResult _write(MusicScore score, NoteInputRequest request) {
  if (request.partIndex < 0 || request.partIndex >= score.parts.length) {
    return _unchanged(
      score,
      const ScoreEventAddress(partIndex: 0, measureIndex: 0, eventIndex: 0),
    );
  }
  var working = score;
  var measureIndex = math.max(0, request.measureIndex);
  while (measureIndex >= working.parts[request.partIndex].measures.length) {
    working = InsertMeasureCommand(
      afterMeasureIndex: working.measureCount - 1,
    ).apply(working);
  }
  var measure = working.parts[request.partIndex].measures[measureIndex];
  var onset = onsetFromTicks(request.onsetTicks, measure.attributes.divisions);
  if (onset >= measureCapacity(measure.attributes)) {
    measureIndex += 1;
    onset = 0;
    while (measureIndex >= working.parts[request.partIndex].measures.length) {
      working = InsertMeasureCommand(
        afterMeasureIndex: working.measureCount - 1,
      ).apply(working);
    }
    measure = working.parts[request.partIndex].measures[measureIndex];
  }
  final staff = request.staff
      .clamp(1, math.max(1, measure.attributes.staves))
      .toInt();
  final capacity = measureCapacity(measure.attributes);
  onset = onset.clamp(0, math.max(0, capacity - 1));
  final voice = voiceOnStaff(measure, staff: staff, onset: onset);
  final pitch = request.rest
      ? null
      : request.spelledPitch ??
            pitchFromMidi(request.midi, alter: request.alter);
  var remaining = durationForType(
    measure.attributes,
    request.durationType,
    dots: request.dots,
  );
  if (request.chord && !request.rest) {
    final existing = _voiceNotes(measure, staff: staff, voice: voice);
    final atOnset = existing.where(
      (note) => !note.isRest && note.onset == onset,
    );
    if (atOnset.isNotEmpty) {
      remaining = atOnset.first.duration;
    }
  }
  ScoreEventAddress? address;
  var continuation = false;
  while (remaining > 0) {
    while (measureIndex >= working.parts[request.partIndex].measures.length) {
      working = InsertMeasureCommand(
        afterMeasureIndex: working.measureCount - 1,
      ).apply(working);
    }
    measure = working.parts[request.partIndex].measures[measureIndex];
    final measureCapacityTicks = measureCapacity(measure.attributes);
    final room = math.max(1, measureCapacityTicks - onset);
    final slice = math.min(remaining, room);
    final continues = remaining > room && !request.rest && !request.chord;
    final requestedDuration = durationForType(
      measure.attributes,
      request.durationType,
      dots: request.dots,
    );
    final spelling = slice == requestedDuration
        ? DurationSpelling(type: request.durationType, dots: request.dots)
        : spellDuration(slice, measure.attributes.divisions);
    final written = MusicNote(
      onset: onset,
      duration: slice,
      voice: voice,
      staff: staff,
      pitch: pitch,
      type: spelling.type,
      dots: spelling.dots,
      tieStart: continues,
      tieStop: continuation,
    );
    final replaced = _replaceVoiceSpan(
      measure: measure,
      staff: staff,
      voice: voice,
      onset: onset,
      duration: slice,
      written: written,
      chord: request.chord && !continuation && !request.rest,
    );
    working = _putEvents(
      working,
      request.partIndex,
      measureIndex,
      replaced.events,
    );
    address ??= findNoteAt(
      score: working,
      partIndex: request.partIndex,
      measureIndex: measureIndex,
      staff: staff,
      onset: onset,
      midi: pitch?.midi,
      rest: request.rest,
    );
    remaining -= slice;
    if (!continues || request.rest || request.chord) {
      final end = onset + slice;
      final caret = end >= measureCapacityTicks
          ? NoteCaret(
              partIndex: request.partIndex,
              measureIndex: measureIndex + 1,
              staff: staff,
              onset: 0,
              voice: voice,
            )
          : NoteCaret(
              partIndex: request.partIndex,
              measureIndex: measureIndex,
              staff: staff,
              onset: end,
              voice: voice,
            );
      if (caret.measureIndex >=
              working.parts[request.partIndex].measures.length &&
          end >= measureCapacityTicks) {
        working = InsertMeasureCommand(
          afterMeasureIndex: working.measureCount - 1,
        ).apply(working);
      }
      return NoteWriteResult(
        score: working,
        caret: caret,
        changed: true,
        address: address,
      );
    }
    measureIndex += 1;
    onset = 0;
    continuation = true;
  }
  return NoteWriteResult(
    score: working,
    caret: NoteCaret(
      partIndex: request.partIndex,
      measureIndex: measureIndex,
      staff: staff,
      onset: onset,
      voice: voice,
    ),
    changed: true,
    address: address,
  );
}

class _SpanRewrite {
  const _SpanRewrite(this.events);

  final List<MusicEvent> events;
}

_SpanRewrite _replaceVoiceSpan({
  required MusicMeasure measure,
  required int staff,
  required String voice,
  required int onset,
  required int duration,
  required MusicNote written,
  required bool chord,
}) {
  final existing = _voiceNotes(measure, staff: staff, voice: voice);
  final grace = existing.where((note) => note.isGrace).toList();
  final timed = existing.where((note) => !note.isGrace).toList();
  final end = onset + duration;
  final List<MusicNote> kept;
  if (chord && !written.isRest) {
    final atOnset = timed.where((note) => !note.isRest && note.onset == onset);
    if (atOnset.any((note) => note.pitch?.midi == written.pitch?.midi)) {
      return _SpanRewrite(measure.events);
    } else if (atOnset.isNotEmpty) {
      final primary = atOnset.first;
      kept = [
        ...timed,
        written.copyWith(
          duration: primary.duration,
          type: primary.type,
          dots: primary.dots,
          tieStart: primary.tieStart,
          tieStop: primary.tieStop,
        ),
      ];
    } else {
      kept = _cutSpan(timed, onset, end, written, measure.attributes.divisions);
    }
  } else {
    kept = _cutSpan(timed, onset, end, written, measure.attributes.divisions);
  }
  final filled = _fillVoice(
    kept,
    capacity: measureCapacity(measure.attributes),
    staff: staff,
    voice: voice,
    divisions: measure.attributes.divisions,
  );
  final others = [
    for (final event in measure.events)
      if (event is! MusicNote || event.staff != staff || event.voice != voice)
        event,
  ];
  return _SpanRewrite(_sorted([...others, ..._markChords(filled), ...grace]));
}

List<MusicNote> _cutSpan(
  List<MusicNote> notes,
  int onset,
  int end,
  MusicNote written,
  int divisions,
) {
  final kept = <MusicNote>[];
  for (final note in notes) {
    if (note.end <= onset || note.onset >= end) {
      kept.add(note);
      continue;
    }
    if (note.onset < onset) {
      kept.add(
        _retimed(
          note,
          onset: note.onset,
          duration: onset - note.onset,
          divisions: divisions,
          tieStart: false,
        ),
      );
    }
  }
  kept.add(written);
  return kept;
}

List<MusicNote> _fillVoice(
  List<MusicNote> notes, {
  required int capacity,
  required int staff,
  required String voice,
  required int divisions,
}) {
  final sorted = [...notes]
    ..sort((a, b) {
      final onset = a.onset.compareTo(b.onset);
      if (onset != 0) return onset;
      if (a.isRest != b.isRest) return a.isRest ? 1 : -1;
      return (a.pitch?.midi ?? 0).compareTo(b.pitch?.midi ?? 0);
    });
  final filled = <MusicNote>[];
  var cursor = 0;
  var index = 0;
  while (index < sorted.length) {
    final note = sorted[index];
    if (note.onset > cursor) {
      filled.add(_rest(cursor, note.onset - cursor, staff, voice, divisions));
      cursor = note.onset;
    }
    if (note.end <= cursor && note.onset < cursor) {
      index++;
      continue;
    }
    final onset = sorted[index].onset;
    final cluster = <MusicNote>[];
    while (index < sorted.length && sorted[index].onset == onset) {
      cluster.add(sorted[index]);
      index++;
    }
    final sounding = cluster.where((candidate) => !candidate.isRest).toList();
    final use = sounding.isEmpty ? cluster.take(1).toList() : sounding;
    filled.addAll(use);
    cursor = use.fold(
      cursor,
      (maximum, candidate) => math.max(maximum, candidate.end),
    );
  }
  if (cursor < capacity) {
    filled.add(_rest(cursor, capacity - cursor, staff, voice, divisions));
  }
  return _mergeRests(filled, divisions);
}

List<MusicNote> _mergeRests(List<MusicNote> notes, int divisions) {
  final merged = <MusicNote>[];
  for (final note in notes) {
    final previous = merged.isEmpty ? null : merged.last;
    if (previous != null &&
        previous.isRest &&
        note.isRest &&
        previous.staff == note.staff &&
        previous.voice == note.voice &&
        previous.end == note.onset) {
      merged[merged.length - 1] = _retimed(
        previous,
        onset: previous.onset,
        duration: previous.duration + note.duration,
        divisions: divisions,
      );
      continue;
    }
    merged.add(note);
  }
  return merged;
}

List<MusicNote> _markChords(List<MusicNote> notes) {
  final groups = <int, List<int>>{};
  for (var index = 0; index < notes.length; index++) {
    final note = notes[index];
    if (note.isRest || note.isGrace) continue;
    groups.putIfAbsent(note.onset, () => []).add(index);
  }
  final marked = [...notes];
  for (final indexes in groups.values) {
    indexes.sort(
      (left, right) => (notes[left].pitch?.midi ?? 0).compareTo(
        notes[right].pitch?.midi ?? 0,
      ),
    );
    for (var chordIndex = 0; chordIndex < indexes.length; chordIndex++) {
      marked[indexes[chordIndex]] = notes[indexes[chordIndex]].copyWith(
        isChord: chordIndex > 0,
      );
    }
  }
  return marked;
}

MusicNote _rest(
  int onset,
  int duration,
  int staff,
  String voice,
  int divisions,
) {
  final spelling = spellDuration(duration, divisions);
  return MusicNote(
    onset: onset,
    duration: duration,
    voice: voice,
    staff: staff,
    type: spelling.type,
    dots: spelling.dots,
  );
}

MusicNote _retimed(
  MusicNote note, {
  required int onset,
  required int duration,
  required int divisions,
  bool? tieStart,
  bool? tieStop,
}) {
  final spelling = spellDuration(duration, divisions);
  return note.copyWith(
    onset: onset,
    duration: duration,
    type: spelling.type,
    dots: spelling.dots,
    tieStart: tieStart ?? note.tieStart,
    tieStop: tieStop ?? note.tieStop,
    isChord: false,
  );
}

List<MusicNote> _voiceNotes(
  MusicMeasure measure, {
  required int staff,
  required String voice,
}) {
  return [
    for (final event in measure.events)
      if (event is MusicNote && event.staff == staff && event.voice == voice)
        event,
  ];
}

List<MusicEvent> _sorted(List<MusicEvent> events) {
  final sorted = [...events]
    ..sort((left, right) {
      final onset = left.onset.compareTo(right.onset);
      if (onset != 0) return onset;
      final staff = left.staff.compareTo(right.staff);
      if (staff != 0) return staff;
      if (left is MusicNote && right is MusicNote) {
        if (left.isChord != right.isChord) return left.isChord ? 1 : -1;
      }
      return 0;
    });
  return sorted;
}

MusicScore _putEvents(
  MusicScore score,
  int partIndex,
  int measureIndex,
  List<MusicEvent> events,
) {
  final parts = score.parts.toList();
  final part = parts[partIndex];
  final measures = part.measures.toList();
  measures[measureIndex] = measures[measureIndex].copyWith(events: events);
  parts[partIndex] = part.copyWith(measures: measures);
  return score.copyWith(parts: parts);
}

class _LocatedNote {
  const _LocatedNote(this.note, this.measure, this.address);

  final MusicNote note;
  final MusicMeasure measure;
  final ScoreEventAddress address;
}

_LocatedNote? _noteAt(MusicScore score, ScoreEventAddress address) {
  if (address.partIndex < 0 || address.partIndex >= score.parts.length) {
    return null;
  }
  final measures = score.parts[address.partIndex].measures;
  if (address.measureIndex < 0 || address.measureIndex >= measures.length) {
    return null;
  }
  final measure = measures[address.measureIndex];
  if (address.eventIndex < 0 || address.eventIndex >= measure.events.length) {
    return null;
  }
  final event = measure.events[address.eventIndex];
  if (event is! MusicNote) return null;
  return _LocatedNote(event, measure, address);
}

NoteCaret _caretAfter(_LocatedNote located) {
  final capacity = measureCapacity(located.measure.attributes);
  if (located.note.end >= capacity) {
    return NoteCaret(
      partIndex: located.address.partIndex,
      measureIndex: located.address.measureIndex + 1,
      staff: located.note.staff,
      onset: 0,
      voice: located.note.voice,
    );
  }
  return NoteCaret(
    partIndex: located.address.partIndex,
    measureIndex: located.address.measureIndex,
    staff: located.note.staff,
    onset: located.note.end,
    voice: located.note.voice,
  );
}

NoteWriteResult _unchanged(
  MusicScore score,
  ScoreEventAddress address, {
  NoteCaret? caret,
}) {
  return NoteWriteResult(
    score: score,
    caret:
        caret ??
        NoteCaret(
          partIndex: address.partIndex,
          measureIndex: address.measureIndex,
          staff: 1,
          onset: 0,
        ),
    changed: false,
    address: address,
  );
}

class _NoteRef {
  const _NoteRef(this.measureIndex, this.note);

  final int measureIndex;
  final MusicNote note;
}

bool _sameNote(MusicEvent event, MusicNote note) {
  return identical(event, note);
}

String _signature(MusicScore score) {
  final buffer = StringBuffer();
  for (final part in score.parts) {
    for (final measure in part.measures) {
      buffer.write('#${measure.events.length}');
      for (final event in measure.events) {
        if (event is! MusicNote) continue;
        buffer.write(
          '|${event.staff}:${event.voice}:${event.onset}:${event.duration}:${event.pitch?.step.name}:${event.pitch?.alter}:${event.pitch?.octave}:${event.isChord}:${event.tieStart}:${event.tieStop}:${event.dots}:${event.type}',
        );
      }
    }
  }
  return buffer.toString();
}
