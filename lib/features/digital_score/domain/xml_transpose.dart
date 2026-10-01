import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:xml/xml.dart';

/// Transposes a MusicXML document in place of its pitches, key signatures,
/// chord symbols and written accidentals, and leaves everything else (line
/// breaks, lyrics, slurs, tuplets, dynamics, articulations) exactly as
/// written. Same spelling rules as [transposeScore].
///
/// Written accidentals are decided again for the new spelling: a note gets
/// one when its alteration differs from the key, or from the last accidental
/// on that line of the bar, and keeps a cautionary one where the source had
/// an accidental the key already implied.
String transposeMusicXml(
  String xml, {
  required int semitones,
  required int fifthsDelta,
}) {
  if (semitones < minTransposeSemitones || semitones > maxTransposeSemitones) {
    throw const FormatException(
      'Transpose must be between -24 and 24 semitones.',
    );
  }
  if (semitones == 0 && fifthsDelta == 0) return xml;
  final document = XmlDocument.parse(xml);
  for (final part in document.rootElement.findElements('part')) {
    _writeImpliedKey(part);
    var fifths = 0;
    var newFifths = wrapKeyFifths(fifthsDelta);
    // The first key moves by [fifthsDelta]; later keys keep their distance
    // from it, so a piece that changes key stays in sharps or in flats.
    (int, int)? firstKey;
    for (final measure in part.findElements('measure')) {
      // Accidental in force per staff, letter and octave, from the key.
      final inForce = <(int, PitchStep, int), int>{};
      // The key written last before the first note of the bar: an earlier
      // one there is overridden, and engravers disagree on which to draw.
      XmlElement? leadingKey;
      var notesSeen = false;
      for (final child in measure.children.whereType<XmlElement>().toList()) {
        final name = child.name.local;
        if (name == 'attributes') {
          for (final key in child.findElements('key').toList()) {
            final element = key.getElement('fifths');
            if (element == null) continue;
            final written = int.tryParse(element.innerText.trim());
            if (written == null) continue;
            fifths = written;
            final first = firstKey ??= (
              written,
              wrapKeyFifths(written + fifthsDelta),
            );
            final kept = first.$2 + (written - first.$1);
            newFifths = kept >= -7 && kept <= 7
                ? kept
                : wrapKeyFifths(written + fifthsDelta);
            element.innerText = '$newFifths';
            inForce.clear();
            if (!notesSeen) {
              final overridden = leadingKey;
              if (overridden != null) {
                final attributes = overridden.parentElement;
                overridden.remove();
                if (attributes != null &&
                    attributes.childElements.isEmpty &&
                    !identical(attributes, child)) {
                  attributes.remove();
                }
              }
              leadingKey = key;
            }
          }
          continue;
        }
        final letterShift = _positiveMod((newFifths - fifths) * 4, 7);
        if (name == 'harmony') {
          _transposeHarmonyPart(
            child.getElement('root'),
            'root-step',
            'root-alter',
            semitones: semitones,
            letterShift: letterShift,
          );
          _transposeHarmonyPart(
            child.getElement('bass'),
            'bass-step',
            'bass-alter',
            semitones: semitones,
            letterShift: letterShift,
          );
          continue;
        }
        if (name != 'note') continue;
        notesSeen = true;
        final note = child;
        final pitchElement = note.getElement('pitch');
        if (pitchElement == null) continue;
        final stepElement = pitchElement.getElement('step');
        final octaveElement = pitchElement.getElement('octave');
        if (stepElement == null || octaveElement == null) continue;
        final alterElement = pitchElement.getElement('alter');
        final pitch = MusicPitch(
          step: PitchStepMusicXml.parse(stepElement.innerText),
          octave: int.parse(octaveElement.innerText.trim()),
          alter:
              double.tryParse(alterElement?.innerText.trim() ?? '')?.round() ??
              0,
        );
        final moved = transposePitch(
          pitch,
          semitones: semitones,
          letterShift: letterShift,
        );
        stepElement.innerText = moved.step.musicXmlName;
        octaveElement.innerText = '${moved.octave}';
        if (moved.alter == 0) {
          alterElement?.remove();
        } else if (alterElement != null) {
          alterElement.innerText = '${moved.alter}';
        } else {
          final alter = XmlElement(XmlName('alter'), [], [
            XmlText('${moved.alter}'),
          ]);
          pitchElement.children.insert(
            pitchElement.children.indexOf(stepElement) + 1,
            alter,
          );
        }
        final staff =
            int.tryParse(note.getElement('staff')?.innerText.trim() ?? '') ?? 1;
        final line = (staff, moved.step, moved.octave);
        final current = inForce[line] ?? _keyAlter(moved.step, newFifths);
        final accidental = note.getElement('accidental');
        // A note tied from the bar before carries its accidental over.
        final tiedOver =
            note
                .findElements('tie')
                .any((t) => t.getAttribute('type') == 'stop') ||
            note
                .findAllElements('tied')
                .any((t) => t.getAttribute('type') == 'stop');
        if (accidental != null || (moved.alter != current && !tiedOver)) {
          if (accidental != null) {
            accidental.innerText = _accidentalName(moved.alter);
          } else {
            _insertAccidental(note, _accidentalName(moved.alter));
          }
        }
        // An accidental carried over the barline by a tie holds for that
        // note only: the next one on the line is marked again.
        if (accidental != null || !tiedOver) inForce[line] = moved.alter;
      }
    }
  }
  return document.toXmlString();
}

/// Writes the C major key a part without a key signature implies, so the
/// transposed part gets its new signature.
void _writeImpliedKey(XmlElement part) {
  final measure = part.getElement('measure');
  if (measure == null) return;
  XmlElement? attributes;
  for (final child in measure.childElements) {
    final name = child.name.local;
    if (name == 'note') break;
    if (name != 'attributes') continue;
    if (child.getElement('key') != null) return;
    attributes ??= child;
  }
  final key = XmlElement(XmlName('key'), [], [
    XmlElement(XmlName('fifths'), [], [XmlText('0')]),
  ]);
  if (attributes == null) {
    measure.children.insert(0, XmlElement(XmlName('attributes'), [], [key]));
    return;
  }
  // The schema puts `key` after `divisions` and before everything else.
  final divisions = attributes.getElement('divisions');
  attributes.children.insert(
    divisions == null ? 0 : attributes.children.indexOf(divisions) + 1,
    key,
  );
}

void _transposeHarmonyPart(
  XmlElement? container,
  String stepName,
  String alterName, {
  required int semitones,
  required int letterShift,
}) {
  final stepElement = container?.getElement(stepName);
  if (container == null || stepElement == null) return;
  final alterElement = container.getElement(alterName);
  final moved = transposePitchClass(
    step: PitchStepMusicXml.parse(stepElement.innerText),
    alter: double.tryParse(alterElement?.innerText.trim() ?? '')?.round() ?? 0,
    semitones: semitones,
    letterShift: letterShift,
  );
  stepElement.innerText = moved.step.musicXmlName;
  if (moved.alter == 0) {
    alterElement?.remove();
  } else if (alterElement != null) {
    alterElement.innerText = '${moved.alter}';
  } else {
    container.children.insert(
      container.children.indexOf(stepElement) + 1,
      XmlElement(XmlName(alterName), [], [XmlText('${moved.alter}')]),
    );
  }
}

/// MusicXML orders a note's children; `accidental` follows `dot`, `type`,
/// `duration`, `pitch` and comes before `time-modification` and `stem`.
void _insertAccidental(XmlElement note, String name) {
  const before = {
    'pitch',
    'rest',
    'unpitched',
    'duration',
    'tie',
    'instrument',
    'voice',
    'type',
    'dot',
  };
  var index = 0;
  for (var i = 0; i < note.children.length; i++) {
    final child = note.children[i];
    if (child is XmlElement && before.contains(child.name.local)) index = i + 1;
  }
  note.children.insert(
    index,
    XmlElement(XmlName('accidental'), [], [XmlText(name)]),
  );
}

int _keyAlter(PitchStep step, int fifths) {
  const sharps = [
    PitchStep.f,
    PitchStep.c,
    PitchStep.g,
    PitchStep.d,
    PitchStep.a,
    PitchStep.e,
    PitchStep.b,
  ];
  if (fifths > 0) return sharps.take(fifths).contains(step) ? 1 : 0;
  if (fifths < 0) {
    return sharps.reversed.take(-fifths).contains(step) ? -1 : 0;
  }
  return 0;
}

String _accidentalName(int alter) => switch (alter) {
  -2 => 'flat-flat',
  -1 => 'flat',
  1 => 'sharp',
  2 => 'double-sharp',
  _ => 'natural',
};

int _positiveMod(int value, int modulo) => (value % modulo + modulo) % modulo;
