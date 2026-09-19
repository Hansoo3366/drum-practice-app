import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';

const String arrangementVoice = 'arr';

enum ArrangementStyle { off, block, pulse, broken }

class ArrangementProfile {
  const ArrangementProfile({this.style = ArrangementStyle.off});

  factory ArrangementProfile.fromJson(Object? raw) {
    if (raw is! Map) return ArrangementProfile.off;
    final name = raw['style']?.toString();
    return ArrangementProfile(
      style: ArrangementStyle.values.asNameMap()[name] ?? ArrangementStyle.off,
    );
  }

  static const off = ArrangementProfile();

  final ArrangementStyle style;

  bool get isOff => style == ArrangementStyle.off;
  bool get isNotOff => !isOff;

  ArrangementProfile copyWith({ArrangementStyle? style}) {
    return ArrangementProfile(style: style ?? this.style);
  }

  Map<String, Object?> toJson() => {'style': style.name};

  @override
  bool operator ==(Object other) {
    return other is ArrangementProfile && other.style == style;
  }

  @override
  int get hashCode => style.hashCode;
}

MusicScore applyArrangement(MusicScore score, ArrangementProfile profile) {
  if (profile.isOff) return score;
  var changed = false;
  final parts = <MusicPart>[];
  for (final part in score.parts) {
    final arranged = _arrangePart(part, profile.style);
    changed = changed || !identical(arranged, part);
    parts.add(arranged);
  }
  return changed ? score.copyWith(parts: parts) : score;
}

MusicPart _arrangePart(MusicPart part, ArrangementStyle style) {
  var changed = false;
  final measures = <MusicMeasure>[];
  for (final measure in part.measures) {
    final arranged = _arrangeMeasure(measure, style);
    changed = changed || !identical(arranged, measure);
    measures.add(arranged);
  }
  return changed ? part.copyWith(measures: measures) : part;
}

MusicMeasure _arrangeMeasure(MusicMeasure measure, ArrangementStyle style) {
  final written = [
    for (final event in measure.events)
      if (event is! MusicNote || event.voice != arrangementVoice) event,
  ];
  final harmonies = written.whereType<MusicHarmony>().toList()
    ..sort((left, right) => left.onset.compareTo(right.onset));
  if (harmonies.isEmpty) {
    return written.length == measure.events.length
        ? measure
        : measure.copyWith(events: written);
  }

  final capacity = measureCapacity(measure.attributes);
  final generated = <MusicEvent>[];
  for (var index = 0; index < harmonies.length; index++) {
    final harmony = harmonies[index];
    final end = index + 1 < harmonies.length
        ? harmonies[index + 1].onset
        : capacity;
    final duration = end - harmony.onset;
    if (duration <= 0) continue;
    generated.addAll(
      _notesForHarmony(
        harmony,
        measure: measure,
        start: harmony.onset,
        duration: duration,
        style: style,
      ),
    );
  }
  if (generated.isEmpty) {
    return written.length == measure.events.length
        ? measure
        : measure.copyWith(events: written);
  }
  return measure.copyWith(events: [...written, ...generated]);
}

List<MusicNote> _notesForHarmony(
  MusicHarmony harmony, {
  required MusicMeasure measure,
  required int start,
  required int duration,
  required ArrangementStyle style,
}) {
  final tones = _voicedTones(harmony);
  if (tones == null) return const [];
  final divisions = measure.attributes.divisions;
  final time =
      measure.attributes.time ??
      const MusicTimeSignature(beats: 4, beatType: 4);
  final beat = ((divisions * 4) / time.beatType).round().clamp(1, duration);
  final chordStaff = 1;
  final bassStaff = measure.attributes.staves >= 2 ? 2 : 1;

  return switch (style) {
    ArrangementStyle.off => const [],
    ArrangementStyle.block => _heldChord(
      tones,
      start: start,
      duration: duration,
      divisions: divisions,
      chordStaff: chordStaff,
      bassStaff: bassStaff,
    ),
    ArrangementStyle.pulse => [
      for (
        var onset = start, remaining = duration;
        remaining > 0;
        onset += beat, remaining -= beat
      )
        ..._heldChord(
          tones,
          start: onset,
          duration: remaining < beat ? remaining : beat,
          divisions: divisions,
          chordStaff: chordStaff,
          bassStaff: bassStaff,
        ),
    ],
    ArrangementStyle.broken => _brokenChord(
      tones,
      start: start,
      duration: duration,
      divisions: divisions,
      beatType: time.beatType,
      chordStaff: chordStaff,
      bassStaff: bassStaff,
    ),
  };
}

List<MusicNote> _heldChord(
  _VoicedTones tones, {
  required int start,
  required int duration,
  required int divisions,
  required int chordStaff,
  required int bassStaff,
}) {
  final type = _noteType(duration, divisions);
  return [
    MusicNote(
      onset: start,
      duration: duration,
      voice: arrangementVoice,
      staff: bassStaff,
      pitch: tones.bass,
      type: type,
    ),
    for (var index = 0; index < tones.chord.length; index++)
      MusicNote(
        onset: start,
        duration: duration,
        voice: arrangementVoice,
        staff: chordStaff,
        pitch: tones.chord[index],
        type: type,
        isChord: index > 0 || (chordStaff == bassStaff && index == 0),
      ),
  ];
}

List<MusicNote> _brokenChord(
  _VoicedTones tones, {
  required int start,
  required int duration,
  required int divisions,
  required int beatType,
  required int chordStaff,
  required int bassStaff,
}) {
  final step = ((divisions * 2) / beatType).round().clamp(1, duration);
  final pattern = [tones.bass, ...tones.chord];
  final notes = <MusicNote>[];
  var onset = start;
  var remaining = duration;
  var index = 0;
  while (remaining > 0) {
    final length = remaining < step ? remaining : step;
    final pitch = pattern[index % pattern.length];
    final isBass = identical(pitch, tones.bass);
    notes.add(
      MusicNote(
        onset: onset,
        duration: length,
        voice: arrangementVoice,
        staff: isBass ? bassStaff : chordStaff,
        pitch: pitch,
        type: _noteType(length, divisions),
      ),
    );
    onset += length;
    remaining -= length;
    index++;
  }
  return notes;
}

class _VoicedTones {
  const _VoicedTones({required this.bass, required this.chord});

  final MusicPitch bass;
  final List<MusicPitch> chord;
}

_VoicedTones? _voicedTones(MusicHarmony harmony) {
  final intervals = _harmonyIntervals(harmony.kind);
  if (intervals.isEmpty) return null;
  final bassSource = harmony.bassStep == null
      ? (step: harmony.rootStep, alter: harmony.rootAlter)
      : (step: harmony.bassStep!, alter: harmony.bassAlter);
  final bass = _pitchInRange(
    step: bassSource.step,
    alter: bassSource.alter,
    octave: 2,
    minimumMidi: 36,
    maximumMidi: 52,
  );
  final chord = [
    for (final interval in intervals)
      _pitchFromInterval(
        rootStep: harmony.rootStep,
        rootAlter: harmony.rootAlter,
        semitones: interval,
        octave: 4,
      ),
  ];
  final inverted = [
    for (final pitch in chord)
      pitch.midi > 76
          ? MusicPitch(
              step: pitch.step,
              octave: pitch.octave - 1,
              alter: pitch.alter,
            )
          : pitch,
  ];
  return _VoicedTones(bass: bass, chord: inverted);
}

List<int> _harmonyIntervals(String kind) {
  return switch (kind.trim().toLowerCase()) {
    'none' => const [],
    'minor' || 'min' => const [0, 3, 7],
    'dominant' || '7' => const [0, 4, 7, 10],
    'major-seventh' || 'major-7th' || 'maj7' => const [0, 4, 7, 11],
    'minor-seventh' || 'minor-7th' || 'min7' => const [0, 3, 7, 10],
    'diminished' || 'dim' => const [0, 3, 6],
    'augmented' || 'aug' => const [0, 4, 8],
    'suspended-fourth' || 'sus4' => const [0, 5, 7],
    _ => const [0, 4, 7],
  };
}

MusicPitch _pitchFromInterval({
  required PitchStep rootStep,
  required int rootAlter,
  required int semitones,
  required int octave,
}) {
  final spelled = _spellInterval(
    rootStep: rootStep,
    rootAlter: rootAlter,
    semitones: semitones,
  );
  return MusicPitch(step: spelled.step, octave: octave, alter: spelled.alter);
}

({PitchStep step, int alter}) _spellInterval({
  required PitchStep rootStep,
  required int rootAlter,
  required int semitones,
}) {
  final letters = switch (semitones % 12) {
    0 => 0,
    1 || 2 => 1,
    3 || 4 => 2,
    5 => 3,
    6 || 7 || 8 => 4,
    _ => 6,
  };
  final step = PitchStep.values[(rootStep.index + letters) % 7];
  final natural = _positiveMod(
    step.naturalSemitone - rootStep.naturalSemitone,
    12,
  );
  return (step: step, alter: rootAlter + (semitones % 12) - natural);
}

MusicPitch _pitchInRange({
  required PitchStep step,
  required int alter,
  required int octave,
  required int minimumMidi,
  required int maximumMidi,
}) {
  var current = octave;
  var pitch = MusicPitch(step: step, octave: current, alter: alter);
  while (pitch.midi < minimumMidi && current < 8) {
    current++;
    pitch = MusicPitch(step: step, octave: current, alter: alter);
  }
  while (pitch.midi > maximumMidi && current > 0) {
    current--;
    pitch = MusicPitch(step: step, octave: current, alter: alter);
  }
  return pitch;
}

String _noteType(int duration, int divisions) {
  final ratio = duration / divisions;
  if (ratio >= 3.5) return 'whole';
  if (ratio >= 1.5) return 'half';
  if (ratio >= 0.75) return 'quarter';
  if (ratio >= 0.4) return 'eighth';
  return '16th';
}

int _positiveMod(int value, int modulo) => (value % modulo + modulo) % modulo;
