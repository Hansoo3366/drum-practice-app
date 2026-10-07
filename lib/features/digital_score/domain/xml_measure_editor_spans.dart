part of 'xml_measure_editor.dart';

// Marks that reach from one note to another (slurs, hairpins, octave lines,
// pedal, glissando), ornaments, and entering a pitch by its key or its place
// on the staff. Pure like the rest of [XmlMeasureEditor]: a [FormatException]
// carries the message for an edit that cannot be made.

/// A mark that reaches from one note to a later one.
enum SpanKind {
  slur,
  glissando,
  crescendo,
  diminuendo,

  /// 8va: written an octave lower than it sounds.
  octaveUp,

  /// 8vb: written an octave higher than it sounds.
  octaveDown,
  pedal;

  /// Whether the mark is written on its two notes (in `<notations>`) rather
  /// than between the notes (a `<direction>`).
  bool get onNotes => this == slur || this == glissando;

  String get _element => switch (this) {
    slur => 'slur',
    glissando => 'glissando',
    crescendo || diminuendo => 'wedge',
    octaveUp || octaveDown => 'octave-shift',
    pedal => 'pedal',
  };

  String get _startType => switch (this) {
    slur || glissando || pedal => 'start',
    crescendo => 'crescendo',
    diminuendo => 'diminuendo',
    // MusicXML names the way the written notes are moved.
    octaveUp => 'down',
    octaveDown => 'up',
  };

  /// Octaves the notes under the line sound above where they are written.
  int get _octaves => switch (this) {
    octaveUp => 1,
    octaveDown => -1,
    _ => 0,
  };

  static SpanKind? _ofStart(XmlElement mark) =>
      switch ((mark.name.local, mark.getAttribute('type'))) {
        ('slur', 'start') => slur,
        ('glissando', 'start') => glissando,
        ('wedge', 'crescendo') => crescendo,
        ('wedge', 'diminuendo') => diminuendo,
        ('octave-shift', 'down') => octaveUp,
        ('octave-shift', 'up') => octaveDown,
        ('pedal', 'start') => pedal,
        _ => null,
      };
}

/// Ornaments written at a note, as MusicXML names them. `arpeggiate` rolls
/// the note's chord.
const ornamentNames = [
  'trill-mark',
  'mordent',
  'inverted-mordent',
  'turn',
  'tremolo',
  'arpeggiate',
];

const _spanElements = ['slur', 'glissando', 'wedge', 'octave-shift', 'pedal'];

/// Names a MIDI pitch as the key signature would write it: sharps in sharp
/// keys, flats in flat keys ("F#4", "Bb3").
String spellMidi(int midi, int fifths) {
  const sharps = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  const flats = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];
  const plain = [
    'C',
    'C#',
    'D',
    'Eb',
    'E',
    'F',
    'F#',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];
  final names = fifths > 0 ? sharps : (fifths < 0 ? flats : plain);
  return '${names[midi % 12]}${midi ~/ 12 - 1}';
}

extension XmlMeasureSpans on XmlMeasureEditor {
  /// Draws [kind] from the note [from] to the note [to] of the same part,
  /// whichever of the two comes first. Under an octave line the notes keep
  /// their place on the staff and sound an octave higher or lower.
  XmlEditResult addSpan(
    String xml,
    XmlNoteRef from,
    XmlNoteRef to,
    SpanKind kind,
  ) {
    if (from.partIndex != to.partIndex) {
      throw const FormatException('같은 파트의 두 음을 고르세요.');
    }
    final doc = _ScoreDoc(xml);
    var a = from;
    var b = to;
    // One reading of each bar: a note is known to the reading it came from.
    var startBar = doc.measure(a);
    var endBar = a.measureIndex == b.measureIndex ? startBar : doc.measure(b);
    var first = startBar.note(a.noteIndex);
    var last = endBar.note(b.noteIndex);
    final backwards =
        b.measureIndex < a.measureIndex ||
        (b.measureIndex == a.measureIndex &&
            (last.onset < first.onset ||
                (last.onset == first.onset && last.docIndex < first.docIndex)));
    if (backwards) {
      (a, b) = (b, a);
      (first, last) = (last, first);
      (startBar, endBar) = (endBar, startBar);
    }
    final startGroup = startBar.groupOf(first);
    final endGroup = endBar.groupOf(last);
    final startHead = startGroup.first;
    final endHead = endGroup.first;
    final part = doc.parts[a.partIndex];
    if (kind.onNotes) {
      if (identical(startHead.element, endHead.element)) {
        throw const FormatException('서로 다른 두 음을 골라야 합니다.');
      }
      if (startHead.isRest || endHead.isRest) {
        throw const FormatException('쉼표에는 걸 수 없습니다.');
      }
      final number = _freeNumber(
        part,
        kind._element,
        startHead.element,
        endHead.element,
      );
      XmlElement mark(String type) => XmlElement(XmlName(kind._element), [
        XmlAttribute(XmlName('type'), type),
        XmlAttribute(XmlName('number'), number),
        if (kind == SpanKind.glissando)
          XmlAttribute(XmlName('line-type'), 'wavy'),
      ]);
      _notationsOf(startHead.element).children.add(mark('start'));
      _notationsOf(endHead.element).children.add(mark('stop'));
      return XmlEditResult(doc.toXml(), to);
    }
    if (first.isGrace || last.isGrace) {
      throw const FormatException('꾸밈음에서는 시작하거나 끝낼 수 없습니다.');
    }
    if (kind._octaves != 0) {
      _shiftOctaves(
        doc,
        a.partIndex,
        startHead.staff,
        (a.measureIndex, startHead.onset),
        (b.measureIndex, endHead.onset),
        kind._octaves,
      );
    }
    final number = kind == SpanKind.pedal
        ? null
        : _freeNumber(
            part,
            kind._element,
            startHead.element,
            endGroup.last.element,
          );
    final staves = startBar.staves;
    XmlElement direction(String type) => XmlElement(
      XmlName('direction'),
      [
        XmlAttribute(
          XmlName('placement'),
          kind == SpanKind.octaveUp ? 'above' : 'below',
        ),
      ],
      [
        XmlElement(XmlName('direction-type'), [], [
          XmlElement(XmlName(kind._element), [
            XmlAttribute(XmlName('type'), type),
            if (number != null) XmlAttribute(XmlName('number'), number),
            if (kind._octaves != 0) XmlAttribute(XmlName('size'), '8'),
            if (kind == SpanKind.pedal) XmlAttribute(XmlName('line'), 'yes'),
          ]),
        ]),
        if (staves > 1)
          XmlElement(XmlName('staff'), [], [XmlText('${startHead.staff}')]),
      ],
    );
    // The end first: it stands after the start in the same bar, and putting
    // the start in would move it.
    _insertAfter(endGroup.last.element, [direction('stop')]);
    final parent = startHead.element.parent!;
    parent.children.insert(
      parent.children.indexOf(startHead.element),
      direction(kind._startType),
    );
    return XmlEditResult(doc.toXml(), to);
  }

  /// Takes away the [kind] marks that begin or end at the selected note,
  /// each with its other end. Notes under a removed octave line go back to
  /// sounding where they are written.
  XmlEditResult removeSpan(String xml, XmlNoteRef ref, SpanKind kind) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    final group = measure.groupOf(info);
    final part = doc.parts[ref.partIndex];
    final pairs = _spanPairs(part, kind._element);
    var removed = false;
    if (kind.onNotes) {
      final marks =
          group.first.element
              .getElement('notations')
              ?.findElements(kind._element)
              .toList() ??
          const <XmlElement>[];
      for (final mark in marks) {
        for (final (start, stop) in pairs) {
          if (identical(start, mark)) _removeNotation(stop);
          if (identical(stop, mark)) _removeNotation(start);
        }
        _removeNotation(mark);
        removed = true;
      }
    } else {
      final before = _directionsBefore(measure.element, group.first.element);
      final after = _directionsAfter(measure.element, group.last.element);
      for (final (start, stop) in pairs) {
        if (SpanKind._ofStart(start) != kind) continue;
        final startDirection = _directionOf(start);
        final stopDirection = _directionOf(stop);
        if (startDirection == null || stopDirection == null) continue;
        if (!before.any((d) => identical(d, startDirection)) &&
            !after.any((d) => identical(d, stopDirection))) {
          continue;
        }
        if (kind._octaves != 0) {
          final from = _noteBeside(
            doc,
            ref.partIndex,
            startDirection,
            after: true,
          );
          final to = _noteBeside(
            doc,
            ref.partIndex,
            stopDirection,
            after: false,
          );
          if (from != null && to != null) {
            _shiftOctaves(
              doc,
              ref.partIndex,
              from.$2.staff,
              (from.$1, from.$2.onset),
              (to.$1, to.$2.onset),
              -kind._octaves,
            );
          }
        }
        _removeMark(start);
        _removeMark(stop);
        removed = true;
      }
    }
    if (!removed) throw const FormatException('여기서 시작하거나 끝나는 선이 없습니다.');
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Puts an ornament ([ornamentNames]) on the selected note, or takes it
  /// off.
  XmlEditResult toggleOrnament(String xml, XmlNoteRef ref, String name) {
    if (!ornamentNames.contains(name)) {
      throw const FormatException('지원하지 않는 꾸밈입니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isRest) throw const FormatException('쉼표에는 붙일 수 없습니다.');
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음에는 붙일 수 없습니다.');
    }
    final group = measure.groupOf(info);
    if (name == 'arpeggiate') {
      if (group.length < 2) {
        throw const FormatException('화음에만 붙일 수 있습니다.');
      }
      final on = group.any(
        (n) => n.element.getElement('notations')?.getElement(name) != null,
      );
      for (final member in group) {
        final notations = _notationsOf(member.element);
        notations.findElements(name).toList().forEach(_remove);
        if (!on) notations.children.add(XmlElement(XmlName(name)));
        if (notations.childElements.isEmpty) _remove(notations);
      }
      return XmlEditResult(doc.toXml(), ref);
    }
    final notations = _notationsOf(group.first.element);
    var ornaments = notations.getElement('ornaments');
    final existing = ornaments?.findElements(name).toList() ?? const [];
    if (existing.isNotEmpty) {
      existing.forEach(_remove);
    } else {
      if (ornaments == null) {
        ornaments = XmlElement(XmlName('ornaments'));
        notations.children.add(ornaments);
      }
      ornaments.children.add(
        name == 'tremolo'
            ? XmlElement(
                XmlName(name),
                [XmlAttribute(XmlName('type'), 'single')],
                [XmlText('3')],
              )
            : XmlElement(XmlName(name)),
      );
    }
    if (ornaments != null && ornaments.childElements.isEmpty) {
      _remove(ornaments);
    }
    if (notations.childElements.isEmpty) _remove(notations);
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Gives the selected note the pitch of a piano key (a MIDI number),
  /// spelled as its key signature would; a rest becomes a note of that
  /// pitch. Its length stays.
  XmlEditResult enterPitch(String xml, XmlNoteRef ref, int midi) {
    if (midi < 12 || midi > 127) {
      throw const FormatException('음역을 벗어났습니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    final fifths = measure.context.fifths;
    final isRest = info.isRest;
    if (info.isCue) throw const FormatException('바꿀 수 없는 음표입니다.');
    doc.keep(xml);
    final spelled = spellMidi(midi, fifths);
    if (!isRest && info.pitch?.midi == midi) {
      throw const FormatException('이미 같은 음입니다.');
    }
    return setNotePitch(isRest ? restToNote(xml, ref).xml : xml, ref, spelled);
  }

  /// Puts the selected note on a line or space of the staff ([step] and
  /// [octave]); the key and the accidentals earlier in the bar say whether
  /// it is sharp or flat there. A rest becomes a note at that place.
  XmlEditResult placeNote(
    String xml,
    XmlNoteRef ref,
    PitchStep step,
    int octave,
  ) {
    final doc = _ScoreDoc(xml);
    final isRest = doc.measure(ref).note(ref.noteIndex).isRest;
    doc.keep(xml);
    return _editPitch(
      isRest ? restToNote(xml, ref).xml : xml,
      ref,
      (doc, measure, info) => MusicPitch(
        step: step,
        octave: octave,
        alter: measure.contextAlter(info, step, octave),
      ),
    );
  }
}

// --- Helpers ------------------------------------------------------------------

/// The marks named [name] of [part] as (start, stop) elements, matched by
/// their number in the order they are written.
List<(XmlElement, XmlElement)> _spanPairs(XmlElement part, String name) {
  final open = <String, XmlElement>{};
  final pairs = <(XmlElement, XmlElement)>[];
  for (final mark in part.findAllElements(name)) {
    final number = mark.getAttribute('number') ?? '1';
    switch (mark.getAttribute('type')) {
      case 'stop':
        if (open.remove(number) case final start?) pairs.add((start, mark));
      case 'continue' || 'change' || null:
        break;
      default:
        open[number] = mark;
    }
  }
  return pairs;
}

/// Where [element] stands in [part]: its bar, and its place in the bar.
(int, int) _placeIn(XmlElement part, XmlElement element) {
  XmlNode child = element;
  while (child.parent is XmlElement &&
      (child.parent! as XmlElement).name.local != 'measure') {
    child = child.parent!;
  }
  final measure = child.parent;
  if (measure is! XmlElement) return (-1, -1);
  final measures = part.findElements('measure').toList();
  return (measures.indexOf(measure), measure.children.indexOf(child));
}

bool _notAfter((int, int) a, (int, int) b) =>
    a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 <= b.$2);

/// A number no mark named [name] uses between [from] and [to]: marks of one
/// kind that overlap are told apart by their number.
String _freeNumber(
  XmlElement part,
  String name,
  XmlElement from,
  XmlElement to,
) {
  final start = _placeIn(part, from);
  final end = _placeIn(part, to);
  final used = <String>{};
  for (final (first, last) in _spanPairs(part, name)) {
    if (_notAfter(_placeIn(part, first), end) &&
        _notAfter(start, _placeIn(part, last))) {
      used.add(first.getAttribute('number') ?? '1');
    }
  }
  // MusicXML numbers concurrent marks from 1; 16 is its upper bound.
  for (var n = 1; n <= 16; n++) {
    if (!used.contains('$n')) return '$n';
  }
  throw const FormatException('여기에는 선을 더 걸 수 없습니다.');
}

List<XmlElement> _directionsAfter(XmlElement measure, XmlElement note) {
  final found = <XmlElement>[];
  final children = measure.childElements.toList();
  for (var i = children.indexOf(note) + 1; i < children.length; i++) {
    final child = children[i];
    if (child.name.local != 'direction') break;
    found.add(child);
  }
  return found;
}

XmlElement? _directionOf(XmlElement mark) {
  final type = mark.parentElement;
  final direction = type?.parentElement;
  return direction != null && direction.name.local == 'direction'
      ? direction
      : null;
}

/// Removes a mark written in a `<direction>`, and the direction with it
/// when it says nothing else.
void _removeMark(XmlElement mark) {
  final type = mark.parentElement;
  _remove(mark);
  if (type == null || type.childElements.isNotEmpty) return;
  final direction = type.parentElement;
  _remove(type);
  if (direction != null && direction.findElements('direction-type').isEmpty) {
    _remove(direction);
  }
}

/// The note written next to [direction] in its bar, after or before it, as
/// (bar index, note).
(int, _NoteInfo)? _noteBeside(
  _ScoreDoc doc,
  int partIndex,
  XmlElement direction, {
  required bool after,
}) {
  final measure = direction.parentElement;
  if (measure == null) return null;
  final index = doc._measures(partIndex).indexOf(measure);
  if (index < 0) return null;
  final children = measure.childElements.toList();
  final at = children.indexOf(direction);
  XmlElement? note;
  if (after) {
    for (var i = at + 1; i < children.length; i++) {
      if (children[i].name.local == 'note') {
        note = children[i];
        break;
      }
    }
  } else {
    for (var i = at - 1; i >= 0; i--) {
      if (children[i].name.local == 'note') {
        note = children[i];
        break;
      }
    }
  }
  if (note == null) return null;
  for (final info in doc.measureAt(partIndex, index).notes) {
    if (identical(info.element, note)) return (index, info);
  }
  return null;
}

/// Moves the notes of [staff] from [from] to [to] (bar index and onset,
/// both ends included) by [octaves].
void _shiftOctaves(
  _ScoreDoc doc,
  int partIndex,
  int staff,
  (int, int) from,
  (int, int) to,
  int octaves,
) {
  for (var index = from.$1; index <= to.$1; index++) {
    final view = doc.measureAt(partIndex, index);
    for (final note in view.notes) {
      final pitch = note.pitch;
      if (pitch == null || note.staff != staff) continue;
      if (index == from.$1 && note.onset < from.$2) continue;
      if (index == to.$1 && note.onset > to.$2) continue;
      final octave = pitch.octave + octaves;
      if (octave < 0 || octave > 9) {
        throw const FormatException('음역을 벗어났습니다.');
      }
      note.element
          .getElement('pitch')!
          .replace(
            _pitchElement(
              MusicPitch(step: pitch.step, octave: octave, alter: pitch.alter),
            ),
          );
    }
    view.refreshAccidentals(staff, PitchStep.values.toSet());
  }
}

/// Takes the slurs and glissandos of [note] away with their other ends:
/// for a note that is about to go.
void _detachNoteSpans(XmlElement note) {
  final notations = note.getElement('notations');
  if (notations == null) return;
  final part = note.parentElement?.parentElement;
  for (final name in const ['slur', 'glissando']) {
    final marks = notations.findElements(name).toList();
    if (marks.isEmpty) continue;
    final pairs = part == null
        ? const <(XmlElement, XmlElement)>[]
        : _spanPairs(part, name);
    for (final mark in marks) {
      for (final (start, stop) in pairs) {
        if (identical(start, mark)) _removeNotation(stop);
        if (identical(stop, mark)) _removeNotation(start);
      }
      _removeNotation(mark);
    }
  }
}

/// The marks that reach from or to the chord of [head] (its last note is
/// [last]).
Set<SpanKind> _spansAt(_MeasureView measure, _NoteInfo head, _NoteInfo last) {
  final found = <SpanKind>{};
  final notations = head.element.getElement('notations');
  if (notations != null) {
    if (notations.getElement('slur') != null) found.add(SpanKind.slur);
    if (notations.getElement('glissando') != null) {
      found.add(SpanKind.glissando);
    }
  }
  for (final direction in _directionsBefore(measure.element, head.element)) {
    for (final name in _spanElements) {
      for (final mark in direction.findAllElements(name)) {
        if (SpanKind._ofStart(mark) case final kind?) found.add(kind);
      }
    }
  }
  final part = measure.element.parentElement;
  if (part == null) return found;
  for (final direction in _directionsAfter(measure.element, last.element)) {
    for (final name in _spanElements) {
      for (final mark in direction.findAllElements(name)) {
        if (mark.getAttribute('type') != 'stop') continue;
        for (final (start, stop) in _spanPairs(part, name)) {
          if (!identical(stop, mark)) continue;
          if (SpanKind._ofStart(start) case final kind?) found.add(kind);
        }
      }
    }
  }
  return found;
}
