import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';

const int minTransposeSemitones = -24;
const int maxTransposeSemitones = 24;

class TransposeScoreCommand implements ScoreEditCommand {
  const TransposeScoreCommand({required this.semitones, this.fifthsDelta});

  final int semitones;
  final int? fifthsDelta;

  @override
  MusicScore apply(MusicScore score) {
    return transposeScore(
      score,
      semitones: semitones,
      fifthsDelta: fifthsDelta,
    );
  }
}

int concertKeyFifths(MusicScore score) {
  return score.parts.first.measures.first.attributes.keyFifths;
}

int wrapKeyFifths(int fifths) {
  var value = fifths;
  while (value > 7) {
    value -= 12;
  }
  while (value < -7) {
    value += 12;
  }
  return value;
}

int tonicPitchClass(int fifths) => _positiveMod(fifths * 7, 12);

int semitonesForKeyChange(int fromFifths, int toFifths) {
  return _positiveMod((toFifths - fromFifths) * 7, 12);
}

int fifthsDeltaForSemitones(int semitones, {required int referenceFifths}) {
  final normalized = _positiveMod(semitones, 12);
  if (normalized == 0) return 0;
  final sharpDelta = (normalized * 7) % 12;
  final flatDelta = sharpDelta - 12;
  final sharpAbs = wrapKeyFifths(referenceFifths + sharpDelta).abs();
  final flatAbs = wrapKeyFifths(referenceFifths + flatDelta).abs();
  if (sharpAbs < flatAbs) return sharpDelta;
  if (flatAbs < sharpAbs) return flatDelta;
  return referenceFifths >= 0 ? sharpDelta : flatDelta;
}

String keySignatureLabel(int fifths) {
  const labels = {
    -7: 'C♭ / A♭m',
    -6: 'G♭ / E♭m',
    -5: 'D♭ / B♭m',
    -4: 'A♭ / Fm',
    -3: 'E♭ / Cm',
    -2: 'B♭ / Gm',
    -1: 'F / Dm',
    0: 'C / Am',
    1: 'G / Em',
    2: 'D / Bm',
    3: 'A / F♯m',
    4: 'E / C♯m',
    5: 'B / G♯m',
    6: 'F♯ / D♯m',
    7: 'C♯ / A♯m',
  };
  return labels[wrapKeyFifths(fifths)]!;
}

String keyTonicLabel(int fifths) {
  const labels = {
    -7: 'C♭',
    -6: 'G♭',
    -5: 'D♭',
    -4: 'A♭',
    -3: 'E♭',
    -2: 'B♭',
    -1: 'F',
    0: 'C',
    1: 'G',
    2: 'D',
    3: 'A',
    4: 'E',
    5: 'B',
    6: 'F♯',
    7: 'C♯',
  };
  return labels[wrapKeyFifths(fifths)]!;
}

List<int> measureKeyFifths(MusicScore score) {
  if (score.parts.isEmpty) return const [];
  return [
    for (final measure in score.parts.first.measures)
      wrapKeyFifths(measure.attributes.keyFifths),
  ];
}

MusicScore transposeScore(
  MusicScore score, {
  required int semitones,
  int? fifthsDelta,
}) {
  if (semitones < minTransposeSemitones || semitones > maxTransposeSemitones) {
    throw const FormatException(
      'Transpose must be between -24 and 24 semitones.',
    );
  }
  final delta =
      fifthsDelta ??
      fifthsDeltaForSemitones(
        semitones,
        referenceFifths: concertKeyFifths(score),
      );
  if (semitones == 0 && delta == 0) return score;

  return score.copyWith(
    parts: [
      for (final part in score.parts)
        part.copyWith(
          measures: [
            for (final measure in part.measures)
              _transposeMeasure(
                measure,
                semitones: semitones,
                fifthsDelta: delta,
              ),
          ],
        ),
    ],
  );
}

MusicMeasure _transposeMeasure(
  MusicMeasure measure, {
  required int semitones,
  required int fifthsDelta,
}) {
  final newFifths = wrapKeyFifths(measure.attributes.keyFifths + fifthsDelta);
  final letterShift = _positiveMod(
    (newFifths - measure.attributes.keyFifths) * 4,
    7,
  );
  return measure.copyWith(
    attributes: measure.attributes.copyWith(keyFifths: newFifths),
    events: [
      for (final event in measure.events)
        _transposeEvent(event, semitones: semitones, letterShift: letterShift),
    ],
  );
}

MusicEvent _transposeEvent(
  MusicEvent event, {
  required int semitones,
  required int letterShift,
}) {
  return switch (event) {
    MusicNote(:final pitch?) => event.copyWith(
      pitch: transposePitch(
        pitch,
        semitones: semitones,
        letterShift: letterShift,
      ),
    ),
    MusicHarmony() => _transposeHarmony(
      event,
      semitones: semitones,
      letterShift: letterShift,
    ),
    _ => event,
  };
}

MusicHarmony _transposeHarmony(
  MusicHarmony harmony, {
  required int semitones,
  required int letterShift,
}) {
  final root = transposePitchClass(
    step: harmony.rootStep,
    alter: harmony.rootAlter,
    semitones: semitones,
    letterShift: letterShift,
  );
  final bass = harmony.bassStep == null
      ? null
      : transposePitchClass(
          step: harmony.bassStep!,
          alter: harmony.bassAlter,
          semitones: semitones,
          letterShift: letterShift,
        );
  return harmony.copyWith(
    rootStep: root.step,
    rootAlter: root.alter,
    bassStep: bass?.step,
    bassAlter: bass?.alter,
  );
}

MusicPitch transposePitch(
  MusicPitch pitch, {
  required int semitones,
  required int letterShift,
}) {
  final midi = pitch.midi + semitones;
  if (midi < 0 || midi > 127) {
    throw const FormatException('Transposed pitch is out of range.');
  }
  final step = PitchStep.values[_positiveMod(pitch.step.index + letterShift, 7)];
  var alter = _positiveMod(midi, 12) - step.naturalSemitone;
  if (alter > 6) alter -= 12;
  if (alter < -6) alter += 12;
  if (alter < -2 || alter > 2) {
    throw const FormatException('Transposed pitch cannot be spelled.');
  }
  final octave = ((midi - step.naturalSemitone - alter) ~/ 12) - 1;
  return MusicPitch(step: step, octave: octave, alter: alter);
}

({PitchStep step, int alter}) transposePitchClass({
  required PitchStep step,
  required int alter,
  required int semitones,
  required int letterShift,
}) {
  final newPc = _positiveMod(step.naturalSemitone + alter + semitones, 12);
  final newStep = PitchStep.values[_positiveMod(step.index + letterShift, 7)];
  var newAlter = newPc - newStep.naturalSemitone;
  if (newAlter > 6) newAlter -= 12;
  if (newAlter < -6) newAlter += 12;
  return (step: newStep, alter: newAlter);
}

int _positiveMod(int value, int modulo) => (value % modulo + modulo) % modulo;
