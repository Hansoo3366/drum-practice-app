part of 'xml_measure_editor.dart';

// What is done to more than one note or bar, and to the score as a whole:
// bars copied, pasted, removed and transposed as a run; a second voice; a
// second staff; the instrument of a part; where lines and pages break.
// Pure like the rest of [XmlMeasureEditor]: a [FormatException] carries the
// message for an edit that cannot be made.

/// Bars taken with [XmlMeasureRanges.copyMeasures], to be pasted elsewhere:
/// the bars of every part, each with the clef, key and time it began in.
class MeasureClip {
  const MeasureClip._(this._parts);

  final List<List<({String xml, String begins})>> _parts;

  /// The number of bars.
  int get length => _parts.isEmpty ? 0 : _parts.first.length;
}

/// A General MIDI instrument a part can be given: its program counted from
/// 0, as the player counts.
const partInstruments = <({String name, int program})>[
  (name: 'Piano', program: 0),
  (name: 'Electric Piano', program: 4),
  (name: 'Organ', program: 19),
  (name: 'Acoustic Guitar', program: 25),
  (name: 'Electric Guitar', program: 27),
  (name: 'Bass', program: 33),
  (name: 'Violin', program: 40),
  (name: 'Cello', program: 42),
  (name: 'Strings', program: 48),
  (name: 'Trumpet', program: 56),
  (name: 'Saxophone', program: 65),
  (name: 'Flute', program: 73),
];

const _scorePartOrder = [
  'identification',
  'part-link',
  'part-name',
  'part-name-display',
  'part-abbreviation',
  'part-abbreviation-display',
  'group',
  'score-instrument',
  'player',
  'midi-device',
  'midi-instrument',
];

const _midiInstrumentOrder = [
  'midi-channel',
  'midi-name',
  'midi-bank',
  'midi-program',
  'midi-unpitched',
  'volume',
  'pan',
  'elevation',
];

extension XmlMeasureRanges on XmlMeasureEditor {
  // --- Runs of bars -----------------------------------------------------------

  /// Takes a copy of the bars [from]..[to] (both included) of every part:
  /// their notes, chords and words. What belongs to the place and not to
  /// the music (barlines, line breaks, section boxes, segno, coda, jumps)
  /// is left behind, as when one bar is copied.
  MeasureClip copyMeasures(String xml, int from, int to) {
    final doc = _ScoreDoc(xml);
    final parts = <List<({String xml, String begins})>>[];
    for (var partIndex = 0; partIndex < doc.parts.length; partIndex++) {
      final measures = doc._measures(partIndex);
      _checkRange(from, to, measures.length);
      final contexts = doc._contextsOf(measures);
      final bars = <({String xml, String begins})>[];
      for (var index = from; index <= to; index++) {
        final copy = measures[index].copy();
        for (final name in ['implicit', 'id', 'xml:id', 'width']) {
          copy.removeAttribute(name);
        }
        final begins = _beginning(measures[index], contexts[index]);
        _stripPlaceSigns(copy, startsIn: contexts[index], follows: _unstated);
        bars.add((
          xml: copy.toXmlString(),
          begins: begins.toAttributes().toXmlString(),
        ));
      }
      parts.add(bars);
    }
    doc.keep(xml);
    return MeasureClip._(parts);
  }

  /// Puts the bars of [clip] after the selected note's bar, in every part.
  /// The first of them says its clef, key and time where they differ from
  /// the bar before, and the bar after the last goes on as it was. The
  /// selection moves to the first pasted bar.
  XmlEditResult pasteMeasures(String xml, XmlNoteRef ref, MeasureClip clip) {
    if (clip.length == 0) throw const FormatException('복사한 마디가 없습니다.');
    final doc = _ScoreDoc(xml);
    doc.measureAt(ref.partIndex, ref.measureIndex);
    if (clip._parts.length != doc.parts.length) {
      throw const FormatException('복사한 악보와 파트 수가 다릅니다.');
    }
    final firstNumber = _firstNumberInOrder(doc);
    final origins = _readOrigins(doc, ref.partIndex);
    final at = ref.measureIndex;
    for (final (partIndex, part) in doc.parts.indexed) {
      final measures = doc._measures(partIndex);
      if (at >= measures.length) continue;
      final contexts = doc._contextsOf(measures);
      final freed = <XmlElement>[];
      final target = measures[at];
      final next = at + 1 < measures.length ? measures[at + 1] : null;
      final nextBegins = next == null
          ? null
          : _beginning(next, contexts[at + 1]);
      var given = contexts[at + 1];
      var previous = target;
      for (final bar in clip._parts[partIndex]) {
        final copy = XmlDocument.parse(bar.xml).rootElement.copy();
        final begins = const _Context().merge(
          XmlDocument.parse(bar.begins).rootElement,
        );
        _restate(copy, begins, given);
        part.children.insert(part.children.indexOf(previous) + 1, copy);
        given = _ending(copy, given);
        _mendTies(previous, copy, freed);
        previous = copy;
      }
      if (next != null) {
        _restate(next, nextBegins!, given);
        _mendTies(previous, next, freed);
      } else {
        // The end of the piece is after the pasted bars now.
        _moveBarline(from: target, to: previous, right: true);
        _dropTies(previous, 'start', freed);
      }
      _spellFreed(doc, partIndex, freed);
    }
    if (firstNumber != null) _renumber(doc, firstNumber);
    _writeOrigins(
      doc,
      origins..insertAll(at + 1, List.filled(clip.length, -1)),
    );
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(partIndex: ref.partIndex, measureIndex: at + 1, noteIndex: 0),
    );
  }

  /// Removes the bars [from]..[to] (both included) from every part, as
  /// [XmlMeasureEditor.deleteMeasure] removes one. One bar at least stays.
  XmlEditResult deleteMeasures(String xml, int partIndex, int from, int to) {
    final count = measureCountOf(xml, partIndex);
    _checkRange(from, to, count);
    if (to - from + 1 >= count) {
      throw const FormatException('마디를 모두 지울 수는 없습니다.');
    }
    var current = xml;
    for (var index = to; index >= from; index--) {
      current = deleteMeasure(
        current,
        XmlNoteRef(partIndex: partIndex, measureIndex: index, noteIndex: 0),
      ).xml;
    }
    return XmlEditResult(
      current,
      XmlNoteRef(
        partIndex: partIndex,
        measureIndex: math.min(from, count - (to - from + 1) - 1),
        noteIndex: 0,
      ),
    );
  }

  /// Moves the bars [from]..[to] of every part up or down by [semitones]:
  /// notes, chord symbols and the key. The first bar is given the new key
  /// signature and the bar after the last one the old one again, so the run
  /// reads as a passage in another key ("key up").
  XmlEditResult transposeMeasures(
    String xml,
    int partIndex,
    int from,
    int to,
    int semitones,
  ) {
    if (semitones == 0) throw const FormatException('옮길 음정을 고르세요.');
    if (semitones < minTransposeSemitones ||
        semitones > maxTransposeSemitones) {
      throw const FormatException('두 옥타브까지만 옮길 수 있습니다.');
    }
    final doc = _ScoreDoc(xml);
    _checkRange(from, to, doc.measureCount(partIndex));
    for (var index = 0; index < doc.parts.length; index++) {
      final measures = doc._measures(index);
      if (from >= measures.length) continue;
      final last = math.min(to, measures.length - 1);
      final contexts = doc._contextsOf(measures);
      final freed = <XmlElement>[];
      final begins = _beginning(measures[from], contexts[from]);
      final next = last + 1 < measures.length ? measures[last + 1] : null;
      final nextBegins = next == null
          ? null
          : _beginning(next, contexts[last + 1]);
      // The run on its own, saying everything it begins in, is transposed
      // like a whole score.
      final copies = [for (var i = from; i <= last; i++) measures[i].copy()];
      _restate(copies.first, begins, _unstated);
      final alone = XmlDocument([
        XmlElement(XmlName('score-partwise'), [], [
          XmlElement(XmlName('part-list'), [], [
            XmlElement(XmlName('score-part'), [
              XmlAttribute(XmlName('id'), 'P1'),
            ]),
          ]),
          XmlElement(XmlName('part'), [
            XmlAttribute(XmlName('id'), 'P1'),
          ], copies),
        ]),
      ]);
      final moved = XmlDocument.parse(
        transposeMusicXml(
          alone.toXmlString(),
          semitones: semitones,
          fifthsDelta: fifthsDeltaForSemitones(
            semitones,
            referenceFifths: begins.fifths,
          ),
        ),
      ).rootElement.getElement('part')!.findElements('measure').toList();
      for (var i = from; i <= last; i++) {
        measures[i].replace(moved[i - from].copy());
      }
      final fresh = doc._measures(index);
      // The run states its new key; what it shares with the bar before it
      // need not be said again.
      _dropRestated(fresh[from], from == 0 ? _unstated : contexts[from]);
      if (next != null) {
        _restate(next, nextBegins!, doc._contextsOf(fresh)[last + 1]);
      }
      // A note tied over either end of the run is another pitch now.
      if (from > 0) _mendTies(fresh[from - 1], fresh[from], freed);
      if (next != null) _mendTies(fresh[last], next, freed);
      _spellFreed(doc, index, freed);
    }
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(partIndex: partIndex, measureIndex: from, noteIndex: 0),
    );
  }

  // --- Voices -----------------------------------------------------------------

  /// Adds a voice to the staff of the selected note in its bar: rests as
  /// long as the bar, to be made into the notes of the second line. The
  /// selection moves to the first of them.
  XmlEditResult addVoice(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    final staff = info.staff;
    final used = {for (final note in measure.notes) note.voice};
    final onStaff = {
      for (final note in measure.notes)
        if (note.staff == staff) note.voice,
    };
    if (onStaff.length >= 4) {
      throw const FormatException('한 보표에 성부는 네 개까지입니다.');
    }
    // By convention the voices of a second staff are numbered from 5.
    var number = (staff - 1) * 4 + 1;
    while (used.contains('$number')) {
      number++;
    }
    final (cursor, length) = _barLength(measure);
    final staffText = info.element.getElement('staff')?.innerText;
    List<XmlElement> rests;
    try {
      rests = [
        for (final spelled in _spellGap(0, length, measure))
          _restElement(
            duration: spelled.duration,
            type: spelled.type,
            dots: spelled.dots,
            voice: '$number',
            staff: staffText,
          ),
      ];
    } on FormatException {
      rests = [_barRest(length, voice: '$number', staff: staffText)];
    }
    final added = [if (cursor > 0) _timing(-cursor), ...rests];
    for (final element in added) {
      _insertAtEnd(measure.element, element);
    }
    final index = doc
        .measure(ref)
        .notes
        .indexWhere((n) => identical(n.element, rests.first));
    return XmlEditResult(doc.toXml(), ref.withNote(index));
  }

  /// Takes the voice of the selected note out of its bar. The other voices
  /// stay where they are; a bar's only voice cannot be removed.
  XmlEditResult removeVoice(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final voice = measure.note(ref.noteIndex).voice;
    if (measure.notes.every((note) => note.voice == voice)) {
      throw const FormatException('하나뿐인 성부는 지울 수 없습니다.');
    }
    final steps = <int, Set<PitchStep>>{};
    for (final note in measure.notes) {
      if (note.voice != voice) continue;
      doc.breakTies(ref.measureIndex, note);
      if (note.pitch case final pitch?) {
        steps.putIfAbsent(note.staff, () => {}).add(pitch.step);
      }
    }
    final current = doc.measure(ref);
    for (final note in current.notes) {
      if (note.voice == voice) _detachNoteSpans(note.element);
    }
    _dropNotes(current, (note) => note.voice == voice);
    for (final MapEntry(key: staff, value: set) in steps.entries) {
      doc.measure(ref).refreshAccidentals(staff, set);
    }
    return XmlEditResult(doc.toXml(), ref.withNote(0));
  }

  // --- Staves -----------------------------------------------------------------

  /// Gives a one-staff part a second staff under the first, in the bass
  /// clef, with a rest in every bar: a lead sheet becomes a piano system to
  /// write the left hand into.
  XmlEditResult addStaff(String xml, int partIndex) {
    final doc = _ScoreDoc(xml);
    final measures = doc._measures(partIndex);
    if (_stavesOf(measures) != 1) {
      throw const FormatException('이미 보표가 둘인 파트입니다.');
    }
    for (var index = 0; index < measures.length; index++) {
      final view = doc.measureAt(partIndex, index);
      final used = {for (final note in view.notes) note.voice};
      var voice = 5;
      while (used.contains('$voice')) {
        voice++;
      }
      for (final note in view.notes) {
        if (note.element.getElement('staff') == null) {
          _insertOrdered(
            note.element,
            XmlElement(XmlName('staff'), [], [XmlText('1')]),
            _noteOrder,
          );
        }
      }
      final (cursor, length) = _barLength(view);
      for (final element in [
        if (cursor > 0) _timing(-cursor),
        _barRest(length, voice: '$voice', staff: '2'),
      ]) {
        _insertAtEnd(view.element, element);
      }
      for (final attributes in view.element.findElements('attributes')) {
        for (final clef in attributes.findElements('clef')) {
          if (clef.getAttribute('number') == null) {
            clef.setAttribute('number', '1');
          }
        }
      }
    }
    final opening = doc._firstAttributes(measures.first);
    _setChild(opening, 'staves', '2', _attributesOrder);
    opening.children.add(
      XmlElement(
        XmlName('clef'),
        [XmlAttribute(XmlName('number'), '2')],
        [
          XmlElement(XmlName('sign'), [], [XmlText('F')]),
          XmlElement(XmlName('line'), [], [XmlText('4')]),
        ],
      ),
    );
    _sortChildren(opening, _attributesOrder);
    return XmlEditResult(doc.toXml(), _barRef(partIndex, 0));
  }

  /// Takes the second staff of a two-staff part away with everything on
  /// it. The first staff stays as it is.
  XmlEditResult removeStaff(String xml, int partIndex) {
    final doc = _ScoreDoc(xml);
    final measures = doc._measures(partIndex);
    if (_stavesOf(measures) != 2) {
      throw const FormatException('보표가 둘인 파트에서만 지울 수 있습니다.');
    }
    final part = doc.parts[partIndex];
    for (final name in const ['slur', 'glissando']) {
      for (final (start, stop) in _spanPairs(part, name)) {
        final startBelow = _onStaff(start, 2);
        if (startBelow != _onStaff(stop, 2)) {
          _removeNotation(startBelow ? stop : start);
        }
      }
    }
    for (var index = 0; index < measures.length; index++) {
      final view = doc.measureAt(partIndex, index);
      final (_, length) = _barLength(view);
      _dropNotes(
        view,
        (note) => note.staff >= 2,
        other: (element) =>
            (int.tryParse(
                  element.getElement('staff')?.innerText.trim() ?? '',
                ) ??
                1) >=
            2,
      );
      final element = view.element;
      if (element.findElements('note').isEmpty) {
        _insertAtEnd(element, _barRest(length, voice: '1', staff: null));
      }
      for (final attributes in element.findElements('attributes').toList()) {
        for (final name in const ['staves', 'part-symbol']) {
          attributes.findElements(name).toList().forEach(_remove);
        }
        for (final clef in attributes.findElements('clef').toList()) {
          final number = int.tryParse(clef.getAttribute('number') ?? '') ?? 1;
          if (number >= 2) {
            _remove(clef);
          } else {
            clef.removeAttribute('number');
          }
        }
        for (final details
            in attributes.findElements('staff-details').toList()) {
          if ((int.tryParse(details.getAttribute('number') ?? '') ?? 1) >= 2) {
            _remove(details);
          }
        }
        if (attributes.childElements.isEmpty) _remove(attributes);
      }
      for (final staff in element.findAllElements('staff').toList()) {
        _remove(staff);
      }
    }
    return XmlEditResult(doc.toXml(), _barRef(partIndex, 0));
  }

  /// The number of staves of a part.
  int staffCount(String xml, int partIndex) {
    final doc = _ScoreDoc(xml);
    final count = _stavesOf(doc._measures(partIndex));
    doc.keep(xml);
    return count;
  }

  // --- The part ---------------------------------------------------------------

  /// Names the instrument of a part and the General MIDI [program] (from
  /// 0) that plays it.
  XmlEditResult setInstrument(
    String xml,
    int partIndex,
    String name,
    int program,
  ) {
    if (program < 0 || program > 127) {
      throw const FormatException('없는 악기입니다.');
    }
    final label = name.trim();
    if (label.isEmpty) throw const FormatException('악기 이름을 입력하세요.');
    final doc = _ScoreDoc(xml);
    final scorePart = _scorePart(doc, partIndex);
    final id = scorePart.getAttribute('id') ?? 'P${partIndex + 1}';
    _setChild(scorePart, 'part-name', label, _scorePartOrder);
    var instrument = scorePart.getElement('score-instrument');
    final instrumentId = instrument?.getAttribute('id') ?? '$id-I1';
    if (instrument == null) {
      instrument = XmlElement(XmlName('score-instrument'), [
        XmlAttribute(XmlName('id'), instrumentId),
      ]);
      _insertOrdered(scorePart, instrument, _scorePartOrder);
    }
    _setChild(instrument, 'instrument-name', label, const ['instrument-name']);
    var midi = scorePart.getElement('midi-instrument');
    if (midi == null) {
      midi = XmlElement(XmlName('midi-instrument'), [
        XmlAttribute(XmlName('id'), instrumentId),
      ]);
      _insertOrdered(scorePart, midi, _scorePartOrder);
    }
    // Written from 1.
    _setChild(midi, 'midi-program', '${program + 1}', _midiInstrumentOrder);
    return XmlEditResult(doc.toXml(), _barRef(partIndex, 0));
  }

  /// The name of a part and the General MIDI program (from 0) it plays on;
  /// the piano when the score names none.
  ({String name, int program}) instrumentOf(String xml, int partIndex) {
    final doc = _ScoreDoc(xml);
    final scorePart = _scorePart(doc, partIndex);
    final written = int.tryParse(
      scorePart.findAllElements('midi-program').firstOrNull?.innerText.trim() ??
          '',
    );
    final name = scorePart.getElement('part-name')?.innerText.trim() ?? '';
    doc.keep(xml);
    return (name: name, program: ((written ?? 1) - 1).clamp(0, 127));
  }

  // --- Lines and pages --------------------------------------------------------

  /// Begins a new line, or with [page] a new page, at the bar; or lets the
  /// bar follow the one before it again. The first bar begins both anyway.
  XmlEditResult toggleBreak(
    String xml,
    int partIndex,
    int measureIndex, {
    required bool page,
  }) {
    if (measureIndex == 0) {
      throw const FormatException('첫 마디는 언제나 새 줄에서 시작합니다.');
    }
    final doc = _ScoreDoc(xml);
    final measure = _bar(doc, partIndex, measureIndex);
    final attribute = page ? 'new-page' : 'new-system';
    var print = measure.getElement('print');
    if (print?.getAttribute(attribute) == 'yes') {
      print!.removeAttribute(attribute);
      if (print.attributes.isEmpty && print.childElements.isEmpty) {
        _remove(print);
      }
    } else {
      if (print == null) {
        print = XmlElement(XmlName('print'));
        measure.children.insert(0, print);
      }
      print.setAttribute(attribute, 'yes');
    }
    return XmlEditResult(doc.toXml(), _barRef(partIndex, measureIndex));
  }
}

// --- Helpers ------------------------------------------------------------------

void _checkRange(int from, int to, int count) {
  if (from < 0 || to < from || to >= count) {
    throw const FormatException('없는 마디입니다.');
  }
}

/// Where a bar's writing has got to at its end, and how long the bar is:
/// its time signature's length, or what its voices fill when that is less
/// (a pickup).
(int cursor, int length) _barLength(_MeasureView measure) {
  var cursor = 0;
  var reach = 0;
  for (final child in measure.element.childElements) {
    switch (child.name.local) {
      case 'backup':
        cursor -= _duration(child);
      case 'forward':
        cursor += _duration(child);
      case 'note':
        if (child.getElement('chord') == null &&
            child.getElement('grace') == null) {
          cursor += _duration(child);
        }
    }
    reach = math.max(reach, cursor);
  }
  return (
    cursor,
    reach > 0 && reach < measure.capacity ? reach : measure.capacity,
  );
}

/// A step forwards (positive) or back in a bar's writing.
XmlElement _timing(int delta) =>
    XmlElement(XmlName(delta < 0 ? 'backup' : 'forward'), [], [
      XmlElement(XmlName('duration'), [], [XmlText('${delta.abs()}')]),
    ]);

/// A rest that fills its bar.
XmlElement _barRest(int duration, {required String voice, String? staff}) =>
    XmlElement(XmlName('note'), [], [
      XmlElement(XmlName('rest'), [XmlAttribute(XmlName('measure'), 'yes')]),
      XmlElement(XmlName('duration'), [], [XmlText('$duration')]),
      XmlElement(XmlName('voice'), [], [XmlText(voice)]),
      if (staff != null) XmlElement(XmlName('staff'), [], [XmlText(staff)]),
    ]);

int _stavesOf(List<XmlElement> measures) {
  var staves = 1;
  for (final measure in measures) {
    for (final attributes in measure.findElements('attributes')) {
      final count = int.tryParse(
        attributes.getElement('staves')?.innerText.trim() ?? '',
      );
      if (count != null && count > staves) staves = count;
    }
  }
  return staves;
}

bool _onStaff(XmlElement mark, int staff) {
  final note = mark.parentElement?.parentElement;
  return (int.tryParse(note?.getElement('staff')?.innerText.trim() ?? '') ??
          1) >=
      staff;
}

XmlElement _scorePart(_ScoreDoc doc, int partIndex) {
  final parts = doc.parts;
  if (partIndex < 0 || partIndex >= parts.length) {
    throw const FormatException('파트를 찾을 수 없습니다.');
  }
  final id = parts[partIndex].getAttribute('id');
  final list = doc.document.rootElement.getElement('part-list');
  for (final part in list?.findElements('score-part') ?? const <XmlElement>[]) {
    if (part.getAttribute('id') == id) return part;
  }
  throw const FormatException('파트 목록에 없는 파트입니다.');
}

/// Puts the children of [parent] in the order MusicXML asks for; children
/// of one name keep their order.
void _sortChildren(XmlElement parent, List<String> order) {
  final children = parent.childElements.toList();
  final indexed = [for (final (i, child) in children.indexed) (i, child)];
  indexed.sort((a, b) {
    final rank = order
        .indexOf(a.$2.name.local)
        .compareTo(order.indexOf(b.$2.name.local));
    return rank != 0 ? rank : a.$1.compareTo(b.$1);
  });
  parent.children
    ..clear()
    ..addAll([for (final (_, child) in indexed) child]);
}

/// Takes the notes [drop] names out of a bar, and with [other] the chord
/// symbols and directions it names. Every note, chord symbol and direction
/// that stays keeps its time: the steps back and forwards between them are
/// written again for what is left.
void _dropNotes(
  _MeasureView measure,
  bool Function(_NoteInfo note) drop, {
  bool Function(XmlElement element)? other,
}) {
  final byElement = Map<XmlElement, _NoteInfo>.identity();
  for (final note in measure.notes) {
    byElement[note.element] = note;
  }
  var written = 0;
  var now = 0;
  void arrive(XmlElement before, int time) {
    if (time == now) return;
    final parent = before.parent!;
    parent.children.insert(
      parent.children.indexOf(before),
      _timing(time - now),
    );
    now = time;
  }

  for (final child in measure.element.childElements.toList()) {
    switch (child.name.local) {
      case 'backup':
        written -= _duration(child);
        _remove(child);
      case 'forward':
        written += _duration(child);
        _remove(child);
      case 'note':
        final info = byElement[child]!;
        final timed = !info.isChord && !info.isGrace;
        if (drop(info)) {
          _remove(child);
        } else {
          if (!info.isChord) arrive(child, info.onset);
          if (timed) now = info.onset + info.duration;
        }
        if (timed) written = info.onset + info.duration;
      case 'print' || 'barline':
        break;
      default:
        if (other?.call(child) ?? false) {
          _remove(child);
        } else {
          arrive(child, written);
        }
    }
  }
}
