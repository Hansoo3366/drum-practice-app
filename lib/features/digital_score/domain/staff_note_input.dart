import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';

const staffDurationTypes = ['whole', 'half', 'quarter', 'eighth', '16th'];

const staffDurationLabels = {
  'whole': '1',
  'half': '1/2',
  'quarter': '1/4',
  'eighth': '1/8',
  '16th': '1/16',
};

const _sharpSpellings = <(PitchStep, int)>[
  (PitchStep.c, 0),
  (PitchStep.c, 1),
  (PitchStep.d, 0),
  (PitchStep.d, 1),
  (PitchStep.e, 0),
  (PitchStep.f, 0),
  (PitchStep.f, 1),
  (PitchStep.g, 0),
  (PitchStep.g, 1),
  (PitchStep.a, 0),
  (PitchStep.a, 1),
  (PitchStep.b, 0),
];

const _flatSpellings = <(PitchStep, int)>[
  (PitchStep.c, 0),
  (PitchStep.d, -1),
  (PitchStep.d, 0),
  (PitchStep.e, -1),
  (PitchStep.e, 0),
  (PitchStep.f, 0),
  (PitchStep.g, -1),
  (PitchStep.g, 0),
  (PitchStep.a, -1),
  (PitchStep.a, 0),
  (PitchStep.b, -1),
  (PitchStep.b, 0),
];

int durationForType(MusicAttributes attributes, String type, {int dots = 0}) {
  final divisions = attributes.divisions;
  var duration = switch (type) {
    'whole' => divisions * 4,
    'half' => divisions * 2,
    'quarter' => divisions,
    'eighth' => math.max(1, (divisions / 2).round()),
    '16th' => math.max(1, (divisions / 4).round()),
    _ => divisions,
  };
  if (dots > 0) {
    final extra = duration ~/ 2;
    if (extra > 0) duration += extra;
  }
  return duration;
}

/// Spells [midi] with sharps, or with flats when [preferFlats] is set.
MusicPitch spellMidi(int midi, {bool preferFlats = false}) {
  final clamped = midi.clamp(12, 127);
  final spelled = (preferFlats
      ? _flatSpellings
      : _sharpSpellings)[clamped % 12];
  return MusicPitch(
    step: spelled.$1,
    octave: (clamped ~/ 12) - 1,
    alter: spelled.$2,
  );
}

int onsetFromTicks(int onsetTicks, int divisions) {
  return math.max(0, (onsetTicks * divisions / alphaTabQuarterTicks).round());
}

MusicPitch pitchFromMidi(int midi, {int alter = 0}) {
  final clamped = midi.clamp(12, 127);
  if (alter == 0) return spellMidi(clamped);
  final natural = _sharpSpellings[clamped % 12];
  if (natural.$2 == 0) {
    return MusicPitch(
      step: natural.$1,
      octave: (clamped ~/ 12) - 1,
      alter: alter.clamp(-1, 1),
    );
  }
  final spelled = alter < 0
      ? _flatSpellings[clamped % 12]
      : _sharpSpellings[clamped % 12];
  return MusicPitch(
    step: spelled.$1,
    octave: (clamped ~/ 12) - 1,
    alter: spelled.$2,
  );
}

/// Moves one semitone. Upward motion spells with sharps, downward with flats.
MusicPitch pitchBySemitone(MusicPitch pitch, int delta) {
  if (delta == 0) return pitch;
  return spellMidi(pitch.midi + delta, preferFlats: delta < 0);
}

MusicPitch pitchByOctave(MusicPitch pitch, int octaves) {
  if (octaves == 0) return pitch;
  return MusicPitch(
    step: pitch.step,
    alter: pitch.alter,
    octave: (pitch.octave + octaves).clamp(0, 8),
  );
}

int clampOnsetForDuration({
  required MusicAttributes attributes,
  required int onset,
  required int duration,
}) {
  final capacity = measureCapacity(attributes);
  final boundedDuration = math.min(math.max(1, duration), capacity);
  return onset.clamp(0, math.max(0, capacity - boundedDuration));
}

MusicNote noteFromStaffTap({
  required MusicMeasure measure,
  required int staff,
  required int onsetTicks,
  required int midi,
  required String durationType,
  required bool rest,
  int alter = 0,
  String? voice,
}) {
  final duration = durationForType(measure.attributes, durationType);
  final onset = clampOnsetForDuration(
    attributes: measure.attributes,
    onset: onsetFromTicks(onsetTicks, measure.attributes.divisions),
    duration: duration,
  );
  final resolvedStaff = staff.clamp(1, measure.attributes.staves);
  return MusicNote(
    onset: onset,
    duration: duration,
    voice: voice ?? '$resolvedStaff',
    staff: resolvedStaff,
    pitch: rest ? null : pitchFromMidi(midi, alter: alter),
    type: durationType,
  );
}

ScoreEventAddress? findNoteAt({
  required MusicScore score,
  required int partIndex,
  required int measureIndex,
  required int staff,
  required int onset,
  int? midi,
  bool rest = false,
}) {
  if (partIndex < 0 || partIndex >= score.parts.length) return null;
  final part = score.parts[partIndex];
  if (measureIndex < 0 || measureIndex >= part.measures.length) return null;
  final measure = part.measures[measureIndex];
  for (var index = 0; index < measure.events.length; index++) {
    final event = measure.events[index];
    if (event is! MusicNote || event.staff != staff || event.onset != onset) {
      continue;
    }
    if (rest) {
      if (event.isRest) {
        return ScoreEventAddress(
          partIndex: partIndex,
          measureIndex: measureIndex,
          eventIndex: index,
        );
      }
      continue;
    }
    if (event.isRest) continue;
    if (midi != null && midiForPitch(event.pitch!) != midi) continue;
    return ScoreEventAddress(
      partIndex: partIndex,
      measureIndex: measureIndex,
      eventIndex: index,
    );
  }
  return null;
}

bool scoreHasHarmony(MusicScore score) {
  return score.parts.any(
    (part) => part.measures.any(
      (measure) => measure.events.any((event) => event is MusicHarmony),
    ),
  );
}
