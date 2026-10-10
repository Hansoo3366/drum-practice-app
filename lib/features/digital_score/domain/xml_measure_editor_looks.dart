part of 'xml_measure_editor.dart';

// How notes look where the engraver's choice is not the writer's: the way a
// stem points, the shape of a notehead, the staff a note stands on, the
// side its marks are on; and what is taken off or added to many notes at
// once. Pure like the rest of [XmlMeasureEditor].

/// Intervals a note can be doubled at, in lines and spaces of the staff:
/// a third and a sixth above, an octave above, a third and an octave below.
const doublingSteps = [2, 5, 7, -2, -7];

extension XmlMeasureLooks on XmlMeasureEditor {
  /// Tells the stem of the selected note or chord where to stand: `up`,
  /// `down`, `none` (hidden), or null to leave it to the engraver.
  XmlEditResult setStem(String xml, XmlNoteRef ref, String? direction) {
    if (direction != null &&
        !const {'up', 'down', 'none'}.contains(direction)) {
      throw const FormatException('지원하지 않는 기둥 방향입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isRest) throw const FormatException('쉼표에는 기둥이 없습니다.');
    final group = measure.groupOf(info);
    if (group.first.element.getElement('stem')?.innerText.trim() == direction) {
      throw const FormatException('이미 그렇게 되어 있습니다.');
    }
    for (final member in group) {
      member.element.findElements('stem').toList().forEach(_remove);
      if (direction != null) {
        _insertOrdered(
          member.element,
          XmlElement(XmlName('stem'), [], [XmlText(direction)]),
          _noteOrder,
        );
      }
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Draws the selected note's head as a slash (rhythm notation), in
  /// parentheses (a ghost note), or with [head] null as usual.
  XmlEditResult setNotehead(String xml, XmlNoteRef ref, String? head) {
    if (head != null && !const {'slash', 'parentheses'}.contains(head)) {
      throw const FormatException('지원하지 않는 음표 머리입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isRest) throw const FormatException('쉼표에는 음표 머리가 없습니다.');
    if (_noteheadOf(info.element) == head) {
      throw const FormatException('이미 그렇게 되어 있습니다.');
    }
    // A slash stands for the whole chord; parentheses go round one note.
    final targets =
        head == 'parentheses' ||
            (head == null && _noteheadOf(info.element) == 'parentheses')
        ? [info]
        : measure.groupOf(info);
    for (final member in targets) {
      member.element.findElements('notehead').toList().forEach(_remove);
      if (head == null) continue;
      _insertOrdered(
        member.element,
        head == 'slash'
            ? XmlElement(XmlName('notehead'), [], [XmlText('slash')])
            : XmlElement(
                XmlName('notehead'),
                [XmlAttribute(XmlName('parentheses'), 'yes')],
                [XmlText('normal')],
              ),
        _noteOrder,
      );
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Writes the selected note or chord on the other staff of a part with
  /// two (a hand reaching over, or notes read onto the wrong staff). It
  /// stays in its voice, so its beams and its time are as before.
  XmlEditResult switchStaff(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음은 옮길 수 없습니다.');
    }
    var staves = 1;
    for (final element in doc.parts[ref.partIndex].findAllElements('staves')) {
      staves = math.max(staves, int.tryParse(element.innerText.trim()) ?? 1);
    }
    if (staves != 2) {
      throw const FormatException('보표가 둘인 파트에서만 옮길 수 있습니다.');
    }
    final target = info.staff == 1 ? 2 : 1;
    final steps = <PitchStep>{};
    for (final member in measure.groupOf(info)) {
      _setChild(member.element, 'staff', '$target', _noteOrder);
      if (member.pitch case final pitch?) steps.add(pitch.step);
    }
    // The accidentals of both staves are counted anew: a note left one
    // and came to the other.
    final rebuilt = doc.measure(ref);
    rebuilt
      ..refreshAccidentals(1, steps)
      ..refreshAccidentals(2, steps);
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Makes the upper voice of the selected note's staff the lower and the
  /// lower the upper, in its bar: the notes stay, the stems turn.
  XmlEditResult swapVoices(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final staff = measure.note(ref.noteIndex).staff;
    final voices = <String>[];
    for (final note in measure.notes) {
      if (note.staff == staff && !voices.contains(note.voice)) {
        voices.add(note.voice);
      }
    }
    if (voices.length != 2) {
      throw const FormatException('성부가 둘인 보표에서만 맞바꿀 수 있습니다.');
    }
    for (final note in measure.notes) {
      if (note.staff != staff) continue;
      _setChild(
        note.element,
        'voice',
        note.voice == voices[0] ? voices[1] : voices[0],
        _noteOrder,
      );
      // Stems told to point one way would point the wrong way now.
      note.element.findElements('stem').toList().forEach(_remove);
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Puts the marks of the selected note (articulations, fermata) above or
  /// below it, or with [placement] null where the engraver puts them.
  XmlEditResult setMarkPlacement(
    String xml,
    XmlNoteRef ref,
    String? placement,
  ) {
    if (placement != null && !const {'above', 'below'}.contains(placement)) {
      throw const FormatException('위 또는 아래만 고를 수 있습니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final head = measure.groupOf(measure.note(ref.noteIndex)).first.element;
    final notations = head.getElement('notations');
    final marks = [
      for (final articulations
          in notations?.findElements('articulations') ?? const <XmlElement>[])
        ...articulations.childElements,
    ];
    final fermatas = notations?.findElements('fermata').toList() ?? const [];
    if (marks.isEmpty && fermatas.isEmpty) {
      throw const FormatException('옮길 기호가 없습니다.');
    }
    for (final mark in marks) {
      if (placement == null) {
        mark.removeAttribute('placement');
      } else {
        mark.setAttribute('placement', placement);
      }
    }
    for (final fermata in fermatas) {
      // A fermata under the staff is drawn upside down.
      if (placement == 'below') {
        fermata.setAttribute('type', 'inverted');
      } else {
        fermata.removeAttribute('type');
      }
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Takes every articulation and the fermata off the selected note.
  XmlEditResult clearMarks(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final head = measure.groupOf(measure.note(ref.noteIndex)).first.element;
    final notations = head.getElement('notations');
    final marks = [
      ...?notations?.findElements('articulations'),
      ...?notations?.findElements('fermata'),
    ];
    if (marks.isEmpty) throw const FormatException('지울 기호가 없습니다.');
    marks.forEach(_remove);
    if (notations != null && notations.childElements.isEmpty) {
      _remove(notations);
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Takes the accidental off the selected note: it becomes what the key
  /// signature says of its line or space.
  XmlEditResult clearAccidental(String xml, XmlNoteRef ref) {
    return _editPitch(xml, ref, (doc, measure, info) {
      final pitch = info.pitch!;
      final alter = _keyAlter(pitch.step, measure.context.fifths);
      if (pitch.alter == alter) {
        throw const FormatException('임시표가 없는 음입니다.');
      }
      return MusicPitch(step: pitch.step, octave: pitch.octave, alter: alter);
    });
  }

  /// Adds a note to the selected one's chord, [steps] lines and spaces
  /// away ([doublingSteps]): a third above is 2, an octave below is -7. The
  /// key and the accidentals of the bar say whether it is sharp or flat.
  XmlEditResult doubleAt(String xml, XmlNoteRef ref, int steps) {
    if (steps == 0) throw const FormatException('같은 음입니다.');
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    final from = info.pitch;
    if (from == null) throw const FormatException('쉼표를 먼저 음표로 바꾸세요.');
    final number = from.octave * 7 + from.step.index + steps;
    if (number < 0) throw const FormatException('음역을 벗어났습니다.');
    final step = PitchStep.values[number % 7];
    final octave = number ~/ 7;
    final pitch = MusicPitch(
      step: step,
      octave: octave,
      // An octave is the same note: sharp or flat as the note itself.
      alter: steps % 7 == 0
          ? from.alter
          : measure.contextAlter(info, step, octave),
    );
    doc.keep(xml);
    if (pitch.midi < 12 || pitch.midi > 127) {
      throw const FormatException('음역을 벗어났습니다.');
    }
    // The picked note stays the picked one.
    return XmlEditResult(addChordNote(xml, ref, at: pitch).xml, ref);
  }
}

/// How a note's head is drawn when not as usual: `slash`, `parentheses`.
String? _noteheadOf(XmlElement note) {
  final head = note.getElement('notehead');
  if (head == null) return null;
  if (head.getAttribute('parentheses') == 'yes') return 'parentheses';
  return head.innerText.trim() == 'slash' ? 'slash' : null;
}
