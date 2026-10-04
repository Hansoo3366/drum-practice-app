import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:xml/xml.dart';

/// Addresses the n-th `<note>` child of a measure in a `score-partwise` file.
///
/// The index counts every `<note>` element (rests, chord members and grace
/// notes included), so it matches the order of [MusicNote] events decoded by
/// the MusicXML codec.
class XmlNoteRef {
  const XmlNoteRef({
    required this.partIndex,
    required this.measureIndex,
    required this.noteIndex,
  });

  final int partIndex;
  final int measureIndex;
  final int noteIndex;

  XmlNoteRef withNote(int noteIndex) => XmlNoteRef(
    partIndex: partIndex,
    measureIndex: measureIndex,
    noteIndex: noteIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is XmlNoteRef &&
      other.partIndex == partIndex &&
      other.measureIndex == measureIndex &&
      other.noteIndex == noteIndex;

  @override
  int get hashCode => Object.hash(partIndex, measureIndex, noteIndex);
}

/// Maps a decoded event index to the `<note>` index used by [XmlNoteRef].
int? xmlNoteIndexForEvent(MusicMeasure measure, int eventIndex) {
  if (eventIndex < 0 || eventIndex >= measure.events.length) return null;
  if (measure.events[eventIndex] is! MusicNote) return null;
  var index = 0;
  for (var i = 0; i < eventIndex; i++) {
    if (measure.events[i] is MusicNote) index++;
  }
  return index;
}

/// Maps a `<note>` index back to the decoded event index.
int? eventIndexForXmlNote(MusicMeasure measure, int noteIndex) {
  var index = 0;
  for (var i = 0; i < measure.events.length; i++) {
    if (measure.events[i] is! MusicNote) continue;
    if (index == noteIndex) return i;
    index++;
  }
  return null;
}

/// A copy of the score reduced to one measure of one part, for engraving the
/// bar on its own. Clef, key, time and divisions from earlier bars are carried
/// in so the bar reads as it does in context. Never saved.
String isolateMeasureXml(String xml, int partIndex, int measureIndex) {
  final doc = _ScoreDoc(xml);
  final isolated = _isolated(doc, partIndex, measureIndex);
  doc.keep(xml);
  return isolated;
}

/// One measure of one part of [doc] as a score of its own (see
/// [isolateMeasureXml]). [doc] is left as it is: the bar is copied out, so
/// the score read for it can be used again.
String _isolated(_ScoreDoc doc, int partIndex, int measureIndex) {
  final root = doc.document.rootElement;
  final parts = root.findElements('part').toList();
  final measures = doc._measures(partIndex);
  if (measureIndex < 0 || measureIndex >= measures.length) {
    throw const FormatException('마디를 찾을 수 없습니다.');
  }
  final part = parts[partIndex];
  final bar = measures[measureIndex].copy();
  bar.children.insertAll(0, [
    for (final measure in measures.take(measureIndex))
      for (final attributes in measure.findElements('attributes'))
        attributes.copy(),
  ]);
  bar.children.removeWhere(
    (node) => node is XmlElement && node.name.local == 'print',
  );
  final children = <XmlNode>[];
  for (final node in root.children) {
    if (node is XmlElement) {
      final name = node.name.local;
      if (name == 'credit' || name == 'defaults') continue;
      if (name == 'part') {
        if (!identical(node, part)) continue;
        children.add(
          XmlElement(
            node.name.copy(),
            node.attributes.map((attribute) => attribute.copy()),
            [
              // What stands between the bars (line breaks of the file)
              // stays; the other bars go.
              for (final child in node.children)
                if (child is XmlElement && child.name.local == 'measure')
                  if (identical(child, measures[measureIndex])) bar else ...[]
                else
                  child.copy(),
            ],
          ),
        );
        continue;
      }
      if (name == 'part-list') {
        final list = node.copy();
        list.children.removeWhere(
          (entry) =>
              entry is XmlElement &&
              (entry.name.local == 'part-group' ||
                  (entry.name.local == 'score-part' &&
                      entry.getAttribute('id') != part.getAttribute('id'))),
        );
        children.add(list);
        continue;
      }
    }
    children.add(node.copy());
  }
  final document = XmlDocument([
    for (final node in doc.document.children)
      if (identical(node, root))
        XmlElement(
          root.name.copy(),
          root.attributes.map((attribute) => attribute.copy()),
          children,
        )
      else
        node.copy(),
  ]);
  return document.toXmlString();
}

/// One bar as the proofreading screen needs it, read from the score in a
/// single pass: parsing a large score is the slow part of every edit.
class XmlBarInspection {
  const XmlBarInspection({
    required this.isolatedXml,
    required this.notes,
    required this.texts,
  });

  /// See [isolateMeasureXml].
  final String isolatedXml;

  /// What [XmlMeasureEditor.describe] says of each `<note>` of the bar.
  final List<XmlNoteSummary> notes;

  /// See [XmlMeasureEditor.measureTexts].
  final List<String> texts;
}

/// Stamps the note ids the MusicXML codec uses (`p0-m0-e<event>`) on an
/// isolated one-bar score. Verovio keeps them, so tapped hit boxes map back to
/// the exact decoded event, chord members included.
String tagIsolatedNotes(String isolatedXml, MusicMeasure decoded) {
  final document = XmlDocument.parse(isolatedXml);
  final measure = document.findAllElements('measure').first;
  var noteIndex = 0;
  for (final note in measure.findElements('note')) {
    final eventIndex = eventIndexForXmlNote(decoded, noteIndex++);
    if (eventIndex != null) note.setAttribute('id', 'p0-m0-e$eventIndex');
  }
  return document.toXmlString();
}

/// The score's bars copied in [measureMap] order, e.g. a playback order.
///
/// Bars are copied from the source XML, so markings the app does not model
/// survive. Repeat signs and ending brackets are dropped because the order
/// already spells out every pass. Where the order jumps, the clef, key, time
/// and divisions in force at the source bar are written again.
const _jumpSounds = ['dalsegno', 'dacapo', 'tocoda', 'fine'];

/// Removes key, time, clef and divisions of [measure]'s own attributes that
/// [active] already has, and attributes left empty. A bar may carry several
/// `<attributes>` (a converter can leave one behind another); each is read
/// against the state the ones before it leave, so the bar ends in the same
/// state as written.
void _dropRestated(XmlElement measure, _Context active) {
  int? number(XmlElement? element) =>
      int.tryParse(element?.innerText.trim() ?? '');
  var state = active;
  // Several <attributes> before the first note: the later ones override the
  // earlier (a converter's leftovers), so what they override goes.
  final leading = <XmlElement>[];
  for (final child in measure.childElements) {
    if (child.name.local == 'note') break;
    if (child.name.local == 'attributes') leading.add(child);
  }
  for (var i = 0; i < leading.length; i++) {
    for (final later in leading.skip(i + 1)) {
      for (final name in ['key', 'time', 'divisions']) {
        if (later.getElement(name) != null) {
          leading[i].findElements(name).toList().forEach(_remove);
        }
      }
      for (final clef in later.findElements('clef')) {
        final staff = clef.getAttribute('number') ?? '1';
        leading[i]
            .findElements('clef')
            .where((c) => (c.getAttribute('number') ?? '1') == staff)
            .toList()
            .forEach(_remove);
      }
    }
  }
  for (final attributes in measure.findElements('attributes').toList()) {
    final next = state.merge(attributes);
    for (final key in attributes.findElements('key').toList()) {
      if (number(key.getElement('fifths')) == state.fifths) _remove(key);
    }
    for (final time in attributes.findElements('time').toList()) {
      if (number(time.getElement('beats')) == state.beats &&
          number(time.getElement('beat-type')) == state.beatType) {
        _remove(time);
      }
    }
    for (final clef in attributes.findElements('clef').toList()) {
      final staff = int.tryParse(clef.getAttribute('number') ?? '') ?? 1;
      final written = (
        clef.getElement('sign')?.innerText.trim() ?? 'G',
        number(clef.getElement('line')) ?? 2,
      );
      if (state.clefs[staff] == written) _remove(clef);
    }
    for (final divisions in attributes.findElements('divisions').toList()) {
      if (number(divisions) == state.divisions) _remove(divisions);
    }
    if (attributes.childElements.isEmpty) _remove(attributes);
    state = next;
  }
}

/// A copy of [xml] whose rehearsal boxes are the user's sections: every
/// printed rehearsal mark is dropped and a boxed [marks] label is written at
/// the start of its bar (first part). For display only; the source string,
/// and so the original version, is never changed.
String withSectionRehearsals(
  String xml,
  List<({int measureIndex, String label})> marks,
) {
  final document = XmlDocument.parse(xml);
  final parts = document.rootElement.findElements('part').toList();
  for (final part in parts) {
    for (final direction in part.findAllElements('direction').toList()) {
      for (final type in direction.findElements('direction-type').toList()) {
        if (type.getElement('rehearsal') != null) _remove(type);
      }
      if (direction.findElements('direction-type').isEmpty) _remove(direction);
    }
  }
  if (parts.isEmpty) return document.toXmlString();
  final measures = parts.first.findElements('measure').toList();
  for (final mark in marks) {
    if (mark.measureIndex < 0 ||
        mark.measureIndex >= measures.length ||
        mark.label.trim().isEmpty) {
      continue;
    }
    final measure = measures[mark.measureIndex];
    final at = measure.children.indexWhere(
      (node) =>
          node is XmlElement &&
          !(node.name.local == 'print' ||
              node.name.local == 'attributes' ||
              (node.name.local == 'barline' &&
                  node.getAttribute('location') == 'left')),
    );
    final box = XmlElement(
      XmlName('direction'),
      [XmlAttribute(XmlName('placement'), 'above')],
      [
        XmlElement(XmlName('direction-type'), [], [
          XmlElement(
            XmlName('rehearsal'),
            [XmlAttribute(XmlName('enclosure'), 'square')],
            [XmlText(mark.label.trim())],
          ),
        ]),
      ],
    );
    measure.children.insert(at < 0 ? measure.children.length : at, box);
  }
  return document.toXmlString();
}

final _partOrMeasureTag = RegExp(r'<(?:part|measure)(?=[\s/>])[^>]*>');
final _numberAttribute = RegExp(r'''\snumber\s*=\s*(?:"[^"]*"|'[^']*')''');
final _pickupAttribute = RegExp(
  r'''\s(?:implicit\s*=\s*["']yes["']|number\s*=\s*["']0["'])''',
);

/// The number the first bar of [xml] is called by, as
/// [MusicScore.firstBarNumber] reads it from a decoded score: 0 when the
/// first part opens with a pickup bar, else 1.
int xmlFirstBarNumber(String xml) {
  for (final match in _partOrMeasureTag.allMatches(xml)) {
    final tag = match.group(0)!;
    if (tag.startsWith('<measure')) {
      return _pickupAttribute.hasMatch(tag) ? 0 : 1;
    }
  }
  return 1;
}

/// A copy of [xml] whose bars are numbered by position in each part, the
/// way every screen counts them and a printed score numbers them: from 1,
/// or from 0 when the score opens with a pickup bar. Files that were edited
/// or made in playing order carry numbers that no longer say that. For
/// display only; the source string is never changed. Works on the text,
/// since the engraver's caller must not parse a long score.
String withPositionMeasureNumbers(String xml) {
  final first = xmlFirstBarNumber(xml);
  var number = first;
  return xml.replaceAllMapped(_partOrMeasureTag, (match) {
    final tag = match.group(0)!;
    if (tag.startsWith('<part')) {
      number = first;
      return tag;
    }
    final written = _numberAttribute.firstMatch(tag);
    final numbered = written == null
        ? tag.replaceFirst('<measure', '<measure number="$number"')
        : tag.replaceRange(written.start, written.end, ' number="$number"');
    number++;
    return numbered;
  });
}

final _partLabels = RegExp(
  r'<(part-name|part-abbreviation|group-name|group-abbreviation)'
  r'(-display)?(?=[\s>])[^>]*>[\s\S]*?</\1\2>',
);
final _noMeasureNumbers = RegExp(
  r'<measure-numbering(?=[\s>])[^>]*>\s*none\s*</measure-numbering>',
);

/// A copy of [xml] as the app engraves it. For display only; the source
/// string is never changed.
///
/// - Bars are numbered by position ([withPositionMeasureNumbers]) and the
///   numbers show at the head of each line, whatever the file asks: a
///   converted score often says "none".
/// - Part and group names are taken out. The viewer does not draw them,
///   but the engraver would still keep room for them left of every line,
///   which pushes the music off the centre of the page.
String engravingMusicXml(String xml) {
  final numbered = withPositionMeasureNumbers(
    xml,
  ).replaceAll(_noMeasureNumbers, '');
  final listEnd = numbered.indexOf('</part-list>');
  if (listEnd < 0) return numbered;
  final list = numbered.substring(0, listEnd).replaceAllMapped(_partLabels, (
    match,
  ) {
    // A part must still have a name element; an empty one draws nothing.
    return match.group(1) == 'part-name' && match.group(2) == null
        ? '<part-name/>'
        : '';
  });
  return '$list${numbered.substring(listEnd)}';
}

String expandMusicXml(String xml, List<int> measureMap) {
  if (measureMap.isEmpty) {
    throw const FormatException('연주할 마디가 없습니다.');
  }
  final doc = _ScoreDoc(xml);
  final parts = doc.document.rootElement.findElements('part').toList();
  for (var partIndex = 0; partIndex < parts.length; partIndex++) {
    final part = parts[partIndex];
    final measures = doc._measures(partIndex);
    // The clef, key and time in force before each bar, read once: looking
    // them up from the first bar for every played bar is quadratic.
    final contexts = doc._contextsOf(measures);
    final lineOf = _writtenLineOf(measures);
    final expanded = <XmlElement>[];
    for (var position = 0; position < measureMap.length; position++) {
      final source = measureMap[position];
      if (source < 0 || source >= measures.length) {
        throw const FormatException('마디를 찾을 수 없습니다.');
      }
      final copy = measures[source].copy()
        ..setAttribute('number', '${position + 1}');
      final previous = position == 0 ? null : measureMap[position - 1];
      final jumped = previous == null ? source != 0 : source != previous + 1;
      // Skipping ahead inside a written line (a first ending left out) is
      // not a new line; the line just loses the skipped bars.
      final skipsWithinLine =
          jumped &&
          previous != null &&
          source > previous &&
          lineOf[source] == lineOf[previous];
      // Keep the written line starts, and start a line where playing jumps
      // back, so the copy reads like the page instead of reflowing.
      final lineStart = copy
          .findElements('print')
          .any(
            (p) =>
                p.getAttribute('new-system') == 'yes' ||
                p.getAttribute('new-page') == 'yes',
          );
      copy.children.removeWhere(
        (node) => node is XmlElement && node.name.local == 'print',
      );
      if (position > 0 && (lineStart || (jumped && !skipsWithinLine))) {
        copy.children.insert(
          0,
          XmlElement(XmlName('print'), [
            XmlAttribute(XmlName('new-system'), 'yes'),
          ]),
        );
      }
      // What is in force where playing arrives.
      final arriving = previous == null ? null : contexts[previous + 1];
      if (jumped) {
        // A bar taken from elsewhere is read in the clef, key and time it
        // was written in: it says how it begins, as far as that is not in
        // force where it lands. What it changes on its way (a clef printed
        // at its end for the bar after it) stays where it is written.
        _restate(
          copy,
          _beginning(measures[source], contexts[source]),
          arriving ?? _unstated,
        );
      } else if (arriving != null) {
        // A copied bar brings its own clef, key and time; drop what is
        // already in force, so a repeated first bar does not print its time
        // signature again.
        _dropRestated(copy, arriving);
      }
      for (final barline in copy.findElements('barline').toList()) {
        barline.findElements('repeat').toList().forEach(_remove);
        barline.findElements('ending').toList().forEach(_remove);
        final style = barline.getElement('bar-style')?.innerText.trim();
        if (barline.childElements.isEmpty ||
            (barline.childElements.length == 1 &&
                (style == 'heavy-light' || style == 'light-heavy') &&
                source != measures.length - 1)) {
          _remove(barline);
        }
      }
      // The copy is already in playing order: a D.S., D.C., To Coda or Fine
      // left in it would be followed a second time. Signs stay as landmarks.
      for (final direction in copy.findElements('direction').toList()) {
        final sound = direction.getElement('sound');
        if (sound != null &&
            _jumpSounds.any((a) => sound.getAttribute(a) != null)) {
          _remove(direction);
        }
      }
      for (final sound in copy.findElements('sound')) {
        for (final name in _jumpSounds) {
          sound.removeAttribute(name);
        }
      }
      expanded.add(copy);
    }
    part.children.removeWhere(
      (node) => node is XmlElement && node.name.local == 'measure',
    );
    part.children.addAll(expanded);
    // A tie over a barline holds a note into the bar written after it. At
    // a seam of the new order that bar is no longer there: the tie would
    // be drawn into another bar's note, and that note not struck.
    final freed = <XmlElement>[];
    for (var position = 0; position < expanded.length; position++) {
      final source = measureMap[position];
      final seamBefore = position == 0
          ? source != 0
          : source != measureMap[position - 1] + 1;
      final seamAfter = position == expanded.length - 1
          ? source != measures.length - 1
          : measureMap[position + 1] != source + 1;
      if (seamBefore) _dropTies(expanded[position], 'stop', freed);
      if (seamAfter) _dropTies(expanded[position], 'start', freed);
    }
    _spellFreed(doc, partIndex, freed);
  }
  // Bars are now in playing order: where each came from follows it.
  if (_originsOf(doc.document) case final origins?
      when measureMap.every((source) => source < origins.length)) {
    _writeOrigins(doc, [for (final source in measureMap) origins[source]]);
  } else if (!_sameOrder(measureMap)) {
    _writeOrigins(doc, measureMap);
  }
  return doc.toXml();
}

/// The written line (0-based, counted from `<print new-system|new-page>`)
/// each measure of a part is on.
List<int> _writtenLineOf(List<XmlElement> measures) {
  var line = -1;
  return [
    for (var i = 0; i < measures.length; i++)
      if (i == 0 ||
          measures[i]
              .findElements('print')
              .any(
                (p) =>
                    p.getAttribute('new-system') == 'yes' ||
                    p.getAttribute('new-page') == 'yes',
              ))
        ++line
      else
        line,
  ];
}

bool _sameOrder(List<int> measureMap) {
  for (var i = 0; i < measureMap.length; i++) {
    if (measureMap[i] != i) return false;
  }
  return true;
}

int measureCountOf(String xml, int partIndex) {
  final doc = _ScoreDoc(xml);
  final count = doc.measureCount(partIndex);
  // Only read: whoever asks about this score next need not read it again.
  doc.keep(xml);
  return count;
}

class XmlEditResult {
  const XmlEditResult(this.xml, this.selection);

  final String xml;
  final XmlNoteRef selection;
}

/// What the proofreading toolbar needs to know about the selected note.
class XmlNoteSummary {
  const XmlNoteSummary({
    required this.isRest,
    required this.type,
    required this.dots,
    required this.pitch,
    required this.isGrace,
    required this.isTied,
    required this.inTuplet,
    required this.chordSize,
    required this.harmony,
    this.lyric,
    this.leadsChord = true,
  });

  final bool isRest;
  final String? type;
  final int dots;
  final MusicPitch? pitch;
  final bool isGrace;
  final bool isTied;
  final bool inTuplet;
  final int chordSize;

  /// Chord symbol text anchored at this note's onset, if any.
  final String? harmony;

  /// The syllable of the first verse sung on this note, if any.
  final String? lyric;

  /// False for the second and later notes of a chord.
  final bool leadsChord;
}

const noteDurationTypes = ['whole', 'half', 'quarter', 'eighth', '16th'];

/// Edits raw MusicXML one measure at a time.
///
/// Only the touched `<note>`/`<harmony>` elements change, so dynamics,
/// articulations, slurs, lyrics and layout hints survive a proofreading pass.
/// Every method is pure and throws a [FormatException] whose message can be
/// shown to the user when an edit is not supported.
class XmlMeasureEditor {
  const XmlMeasureEditor();

  XmlNoteSummary describe(String xml, XmlNoteRef ref) {
    final measure = _ScoreDoc(xml).measure(ref);
    return _summarize(measure, measure.note(ref.noteIndex));
  }

  /// The bar on its own, a summary of each of its notes and its texts.
  XmlBarInspection inspect(String xml, int partIndex, int measureIndex) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measureAt(partIndex, measureIndex);
    final notes = [for (final info in measure.notes) _summarize(measure, info)];
    final texts = [
      for (final direction in _textDirections(measure.element))
        _directionText(direction),
    ];
    final isolated = _isolated(doc, partIndex, measureIndex);
    // Nothing was changed: the next edit of this score need not read it
    // again.
    doc.keep(xml);
    return XmlBarInspection(isolatedXml: isolated, notes: notes, texts: texts);
  }

  XmlNoteSummary _summarize(_MeasureView measure, _NoteInfo info) {
    final group = measure.groupOf(info);
    final head = group.first;
    final harmony = measure.harmonyAt(head);
    return XmlNoteSummary(
      isRest: info.isRest,
      type: info.type,
      dots: info.dots,
      pitch: info.pitch,
      isGrace: info.isGrace || info.isCue,
      isTied: info.tieStart || info.tieStop,
      inTuplet: info.element.getElement('time-modification') != null,
      chordSize: group.length,
      harmony: harmony == null ? null : harmonyText(harmony),
      lyric: _lyricOf(head.element, 1)?.getElement('text')?.innerText,
      leadsChord: identical(head, info),
    );
  }

  /// Moves a note one staff position up or down in the key and measure
  /// context. Tied notes move together.
  XmlEditResult moveDiatonic(String xml, XmlNoteRef ref, int steps) {
    return _editPitch(xml, ref, (doc, measure, info) {
      final pitch = info.pitch!;
      final number = pitch.octave * 7 + pitch.step.index + steps;
      final step = PitchStep.values[number % 7];
      final octave = number ~/ 7;
      return MusicPitch(
        step: step,
        octave: octave,
        alter: measure.contextAlter(info, step, octave),
      );
    });
  }

  XmlEditResult shiftOctave(String xml, XmlNoteRef ref, int octaves) {
    return _editPitch(xml, ref, (doc, measure, info) {
      final pitch = info.pitch!;
      return MusicPitch(
        step: pitch.step,
        octave: pitch.octave + octaves,
        alter: pitch.alter,
      );
    });
  }

  XmlEditResult setAlter(String xml, XmlNoteRef ref, int alter) {
    if (alter < -2 || alter > 2) {
      throw const FormatException('지원하지 않는 임시표입니다.');
    }
    return _editPitch(xml, ref, (doc, measure, info) {
      final pitch = info.pitch!;
      if (pitch.alter == alter) {
        throw const FormatException('이미 같은 음입니다.');
      }
      return MusicPitch(step: pitch.step, octave: pitch.octave, alter: alter);
    });
  }

  /// Adds a note a third above the top note of the selected chord.
  XmlEditResult addChordNote(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isRest) {
      throw const FormatException('쉼표를 먼저 음표로 바꾸세요.');
    }
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음에는 화음을 더할 수 없습니다.');
    }
    final group = measure.groupOf(info);
    final top = group.reduce(
      (a, b) => (a.pitch!.midi >= b.pitch!.midi) ? a : b,
    );
    final number = top.pitch!.octave * 7 + top.pitch!.step.index + 2;
    final step = PitchStep.values[number % 7];
    final octave = number ~/ 7;
    final pitch = MusicPitch(
      step: step,
      octave: octave,
      alter: measure.contextAlter(top, step, octave),
    );
    if (group.any((note) => note.pitch!.midi == pitch.midi)) {
      throw const FormatException('같은 음이 이미 있습니다.');
    }

    final head = group.first.element;
    final note = XmlElement(XmlName('note'));
    note.children.add(XmlElement(XmlName('chord')));
    note.children.add(_pitchElement(pitch));
    for (final name in const [
      'duration',
      'voice',
      'type',
      'dot',
      'time-modification',
      'stem',
      'staff',
    ]) {
      for (final child in head.findElements(name)) {
        note.children.add(child.copy());
      }
    }
    final last = group.last.element;
    last.parent!.children.insert(last.parent!.children.indexOf(last) + 1, note);
    final rebuilt = doc.measure(ref)..refreshAccidentals(info.staff, {step});
    final index = rebuilt.notes.indexWhere((n) => identical(n.element, note));
    return XmlEditResult(doc.toXml(), ref.withNote(index));
  }

  /// Removes a chord member, or turns a single note into a rest.
  XmlEditResult deleteNote(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    var measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isRest) {
      throw const FormatException('이미 쉼표입니다.');
    }
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음은 삭제할 수 없습니다.');
    }
    final step = info.pitch!.step;
    doc.breakTies(ref.measureIndex, info);
    measure = doc.measure(ref);
    final current = measure.note(ref.noteIndex);
    final group = measure.groupOf(current);
    var selection = ref.noteIndex;
    if (group.length > 1) {
      final element = current.element;
      if (identical(group.first, current)) {
        final next = group[1].element;
        next.findElements('chord').toList().forEach(_remove);
        for (final name in const ['beam', 'notations', 'lyric']) {
          final moved = element.findElements(name).toList();
          if (moved.isEmpty) continue;
          next.findElements(name).toList().forEach(_remove);
          for (final child in moved) {
            _insertOrdered(next, child.copy(), _noteOrder);
          }
        }
      } else {
        selection = ref.noteIndex - 1;
      }
      _remove(element);
    } else {
      final element = current.element;
      for (final name in const [
        'pitch',
        'accidental',
        'stem',
        'notehead',
        'tie',
      ]) {
        element.findElements(name).toList().forEach(_remove);
      }
      _insertOrdered(element, XmlElement(XmlName('rest')), _noteOrder);
      final notations = element.getElement('notations');
      if (notations != null) {
        for (final name in const ['tied', 'slur', 'arpeggiate', 'glissando']) {
          notations.findElements(name).toList().forEach(_remove);
        }
        if (notations.childElements.isEmpty) _remove(notations);
      }
      measure = doc.measure(ref);
      measure.repairBeams(measure.note(ref.noteIndex).voice);
      doc.measure(ref).fixOrphanBeams(info.voice);
    }
    doc.measure(ref).refreshAccidentals(info.staff, {step});
    return XmlEditResult(doc.toXml(), ref.withNote(selection));
  }

  /// Turns a rest into a note on the middle line of its staff.
  XmlEditResult restToNote(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (!info.isRest) throw const FormatException('쉼표가 아닙니다.');
    final element = info.element;
    final rest = element.getElement('rest')!;
    if (element.getElement('type') == null) {
      final spelled = _spellSingle(info.duration, measure.divisions);
      if (spelled == null) {
        throw const FormatException('이 쉼표 길이는 음표 하나로 바꿀 수 없습니다.');
      }
      _setChild(element, 'type', spelled.type, _noteOrder);
      element.findElements('dot').toList().forEach(_remove);
      for (var i = 0; i < spelled.dots; i++) {
        _insertOrdered(element, XmlElement(XmlName('dot')), _noteOrder);
      }
    }
    final (step, octave) = measure.middleLine(info.staff);
    final pitch = MusicPitch(
      step: step,
      octave: octave,
      alter: measure.contextAlter(info, step, octave),
    );
    rest.replace(_pitchElement(pitch));
    final rebuilt = doc.measure(ref);
    rebuilt
      ..rebeamRange(info.voice, info.onset, info.onset + info.duration)
      ..refreshAccidentals(info.staff, {step});
    doc.measure(ref).fixOrphanBeams(info.voice);
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Changes a note or rest duration inside its voice.
  ///
  /// Shortening leaves rests; lengthening overwrites the following notes of
  /// the same voice, like MuseScore's replace input. The voice keeps its total
  /// length, so `<backup>`/`<forward>` values stay valid.
  XmlEditResult setDuration(String xml, XmlNoteRef ref, String type, int dots) {
    final quarters = _typeQuarters[type];
    if (quarters == null || dots < 0 || dots > 2) {
      throw const FormatException('지원하지 않는 음가입니다.');
    }
    final doc = _ScoreDoc(xml);
    var measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음은 음가를 바꿀 수 없습니다.');
    }
    final factor = 2 - 1 / math.pow(2, dots);
    var exact = measure.divisions * quarters * factor;
    if (exact != exact.roundToDouble()) {
      var multiplier = 1;
      while (exact * multiplier != (exact * multiplier).roundToDouble()) {
        multiplier *= 2;
        if (multiplier > 64) {
          throw const FormatException('지원하지 않는 음가입니다.');
        }
      }
      doc.scaleDivisions(ref.partIndex, ref.measureIndex, multiplier);
      measure = doc.measure(ref);
      exact *= multiplier;
    }
    final target = measure.note(ref.noteIndex);
    final newDuration = exact.round();
    final groups = measure.voiceGroups(target.voice);
    final targetIndex = groups.indexWhere((g) => g.contains(target));
    final group = groups[targetIndex];
    final head = group.first;
    if (newDuration == head.duration &&
        head.type == type &&
        head.dots == dots) {
      throw const FormatException('이미 같은 음가입니다.');
    }
    measure.requireSimpleVoice(groups);
    final voiceEnd = groups.last.last.onset + groups.last.last.duration;
    final newEnd = head.onset + newDuration;
    // Converted scores often drop beats. A voice may grow into the missing
    // part of the bar, but never past the time signature.
    if (newEnd > math.max(voiceEnd, measure.capacity)) {
      throw const FormatException('마디 길이를 넘습니다.');
    }
    final growth = math.max(0, newEnd - voiceEnd);
    XmlElement? backupAfter;
    if (growth > 0) {
      final following = measure.timingAfter(groups.last.last.element);
      if (following != null && following.name.local != 'backup') {
        throw const FormatException('여러 성부가 섞인 마디라 음가를 바꿀 수 없습니다.');
      }
      backupAfter = following;
    }
    if (groups.any(
      (g) =>
          g.first.onset < math.max(newEnd, head.onset + head.duration) &&
          g.first.onset + g.first.duration > head.onset &&
          g.any((n) => n.element.getElement('time-modification') != null),
    )) {
      throw const FormatException('잇단음표가 있는 구간은 음가를 바꿀 수 없습니다.');
    }

    if (backupAfter != null) {
      final element = backupAfter.getElement('duration')!;
      element.innerText = '${_duration(backupAfter) + growth}';
    }

    // The note no longer ends where its tie partner starts. A tie arriving
    // from the previous note still lines up because the onset is unchanged.
    for (final note in group) {
      if (note.tieStart) doc.breakTies(ref.measureIndex, note, stop: false);
    }
    // Notes the longer value overwrites. Their ties are cut now, while every
    // note is still where its tie partner expects it.
    final overwritten = <_NoteInfo>[
      if (newDuration > head.duration)
        for (final next in groups.skip(targetIndex + 1))
          if (next.first.onset < newEnd) ...next,
    ];
    for (final note in overwritten) {
      if (note.tieStart || note.tieStop) doc.breakTies(ref.measureIndex, note);
    }
    // Chord symbols stay on their beat, whatever happens to the notes they
    // were written before.
    final kept = measure.harmonies;
    for (final note in group) {
      _setChild(note.element, 'duration', '$newDuration', _noteOrder);
      _setChild(note.element, 'type', type, _noteOrder);
      note.element.findElements('dot').toList().forEach(_remove);
      for (var i = 0; i < dots; i++) {
        _insertOrdered(note.element, XmlElement(XmlName('dot')), _noteOrder);
      }
      note.element.getElement('rest')?.removeAttribute('measure');
    }

    var fillStart = newEnd;
    var fillLength = 0;
    if (newDuration < head.duration) {
      fillLength = head.duration - newDuration;
    } else {
      for (final next in groups.skip(targetIndex + 1)) {
        final start = next.first.onset;
        final end = start + next.first.duration;
        if (start >= newEnd) break;
        for (final note in next) {
          _remove(note.element);
        }
        if (end > newEnd) fillLength = end - newEnd;
      }
      measure = doc.measure(ref);
    }
    if (fillLength > 0) {
      final rests = _spellGap(fillStart, fillLength, measure);
      var anchor = group.last.element;
      for (final spelled in rests) {
        final rest = _restElement(
          duration: spelled.duration,
          type: spelled.type,
          dots: spelled.dots,
          voice: head.element.getElement('voice')?.innerText,
          staff: head.element.getElement('staff')?.innerText,
        );
        anchor.parent!.children.insert(
          anchor.parent!.children.indexOf(anchor) + 1,
          rest,
        );
        anchor = rest;
        fillStart += spelled.duration;
      }
    }
    measure = doc.measure(ref);
    measure.rebeamRange(
      target.voice,
      head.onset,
      math.max(newEnd, head.onset + head.duration),
    );
    doc.measure(ref).fixOrphanBeams(target.voice);
    for (final (onset, harmony) in kept) {
      final written = doc.measure(ref).writtenOnsetOf(harmony);
      if (written == null) continue;
      harmony.findElements('offset').toList().forEach(_remove);
      if (onset != written) {
        _insertOrdered(
          harmony,
          XmlElement(XmlName('offset'), [], [XmlText('${onset - written}')]),
          _harmonyOrder,
        );
      }
    }
    // An overwritten note may have carried the accidental a later note of
    // the bar relied on.
    final respell = <int, Set<PitchStep>>{};
    for (final note in overwritten) {
      if (note.pitch case final pitch?) {
        respell.putIfAbsent(note.staff, () => {}).add(pitch.step);
      }
    }
    for (final MapEntry(key: staff, value: steps) in respell.entries) {
      doc.measure(ref).refreshAccidentals(staff, steps);
    }
    // The selection stays on the note that was picked, a chord's upper note
    // included.
    final index = doc
        .measure(ref)
        .notes
        .indexWhere((n) => identical(n.element, target.element));
    return XmlEditResult(doc.toXml(), ref.withNote(index));
  }

  /// Gives notes of one measure new lengths (by note index) and closes the
  /// bar up behind them: what follows a changed note follows it directly,
  /// as when the lengths were misread and not the rhythm. ([setDuration]
  /// keeps every other note in its place and leaves rests instead.)
  ///
  /// A bar that was full is filled up at its end with rests. A bar that was
  /// short already, such as a pickup, only becomes shorter. The bar may not
  /// come out longer than its time signature, unless it was too long before
  /// and does not grow. Only for a bar with one voice and no tuplets.
  XmlEditResult setNoteLengths(
    String xml,
    int partIndex,
    int measureIndex,
    Map<int, ({String type, int dots})> lengths,
  ) {
    if (lengths.isEmpty) throw const FormatException('바꿀 음표가 없습니다.');
    final doc = _ScoreDoc(xml);
    var measure = doc.measureAt(partIndex, measureIndex);
    double quarters(({String type, int dots}) length) {
      final value = _typeQuarters[length.type];
      if (value == null || length.dots < 0 || length.dots > 2) {
        throw const FormatException('지원하지 않는 음가입니다.');
      }
      return value * (2 - 1 / math.pow(2, length.dots));
    }

    var multiplier = 1;
    for (final length in lengths.values) {
      final exact = measure.divisions * quarters(length);
      while (exact * multiplier != (exact * multiplier).roundToDouble()) {
        multiplier *= 2;
        if (multiplier > 64) {
          throw const FormatException('지원하지 않는 음가입니다.');
        }
      }
    }
    if (multiplier > 1) {
      doc.scaleDivisions(partIndex, measureIndex, multiplier);
      measure = doc.measureAt(partIndex, measureIndex);
    }
    final targets = {
      for (final index in lengths.keys) measure.note(index): lengths[index]!,
    };
    final voice = targets.keys.first.voice;
    final groups = measure.voiceGroups(voice);
    final timed = measure.notes.where((note) => !note.isGrace);
    if (timed.any((note) => note.voice != voice) ||
        measure.element.childElements.any(
          (child) => const {'backup', 'forward'}.contains(child.name.local),
        )) {
      throw const FormatException('여러 성부가 섞인 마디라 음가를 바꿀 수 없습니다.');
    }
    if (timed.any(
      (note) => note.element.getElement('time-modification') != null,
    )) {
      throw const FormatException('잇단음표가 있는 마디는 음가를 바꿀 수 없습니다.');
    }
    int total() => doc
        .measureAt(partIndex, measureIndex)
        .voiceGroups(voice)
        .fold(0, (sum, group) => sum + group.first.duration);
    final before = total();
    for (final MapEntry(key: note, value: length) in targets.entries) {
      if (note.isGrace || note.isCue) {
        throw const FormatException('꾸밈음은 음가를 바꿀 수 없습니다.');
      }
      final duration = (measure.divisions * quarters(length)).round();
      for (final member in measure.groupOf(note)) {
        _setChild(member.element, 'duration', '$duration', _noteOrder);
        _setChild(member.element, 'type', length.type, _noteOrder);
        member.element.findElements('dot').toList().forEach(_remove);
        for (var i = 0; i < length.dots; i++) {
          _insertOrdered(
            member.element,
            XmlElement(XmlName('dot')),
            _noteOrder,
          );
        }
        member.element.getElement('rest')?.removeAttribute('measure');
      }
    }
    final after = total();
    final capacity = measure.capacity;
    if (after > capacity && after > before) {
      throw const FormatException('마디 길이를 넘습니다.');
    }
    if (before >= capacity && after < capacity) {
      final head = groups.last.first.element;
      var anchor = groups.last.last.element;
      for (final spelled in _spellGap(
        after,
        capacity - after,
        doc.measureAt(partIndex, measureIndex),
      )) {
        final rest = _restElement(
          duration: spelled.duration,
          type: spelled.type,
          dots: spelled.dots,
          voice: head.getElement('voice')?.innerText,
          staff: head.getElement('staff')?.innerText,
        );
        anchor.parent!.children.insert(
          anchor.parent!.children.indexOf(anchor) + 1,
          rest,
        );
        anchor = rest;
      }
    }
    doc
        .measureAt(partIndex, measureIndex)
        .rebeamRange(voice, 0, math.max(capacity, after));
    doc.measureAt(partIndex, measureIndex).fixOrphanBeams(voice);
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(
        partIndex: partIndex,
        measureIndex: measureIndex,
        noteIndex: lengths.keys.reduce(math.min),
      ),
    );
  }

  /// Sets, replaces or (with an empty [text]) removes the chord symbol at the
  /// selected note's onset.
  XmlEditResult setHarmony(String xml, XmlNoteRef ref, String? text) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음에는 코드를 달 수 없습니다.');
    }
    final head = measure.groupOf(info).first;
    final existing = measure.harmonyAt(head);
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (existing == null) throw const FormatException('지울 코드가 없습니다.');
      _remove(existing);
      return XmlEditResult(doc.toXml(), ref);
    }
    final symbol = parseChordSymbol(trimmed);
    final harmony = symbol.toXml(staff: measure.staves > 1 ? 1 : null);
    // Written at the note: a symbol found there by its <offset> may stand
    // anywhere in the bar.
    if (existing != null) _remove(existing);
    final parent = head.element.parent!;
    parent.children.insert(parent.children.indexOf(head.element), harmony);
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Writes the syllable of [verse] sung on the selected note; an empty
  /// [text] takes it away. A converted lead sheet often has a syllable
  /// misread: the note is right and only its word is not.
  ///
  /// A syllable that is there keeps how it joins its neighbours (the hyphen
  /// or the held line after it); a new one stands on its own.
  XmlEditResult setLyric(
    String xml,
    XmlNoteRef ref,
    String? text, {
    int verse = 1,
  }) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isRest) {
      throw const FormatException('쉼표에는 가사를 넣을 수 없습니다.');
    }
    if (info.isGrace || info.isCue) {
      throw const FormatException('꾸밈음에는 가사를 넣을 수 없습니다.');
    }
    // The words of a chord are written on its first note.
    final head = measure.groupOf(info).first.element;
    final existing = _lyricOf(head, verse);
    final trimmed = text?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (existing == null) throw const FormatException('지울 가사가 없습니다.');
      _remove(existing);
      return XmlEditResult(doc.toXml(), ref);
    }
    if (trimmed.length > maxLyricLength) {
      throw const FormatException('가사가 너무 깁니다.');
    }
    if (existing != null) {
      final words = existing.getElement('text');
      if (words != null) {
        words.innerText = trimmed;
      } else {
        existing.children.add(
          XmlElement(XmlName('text'), [], [XmlText(trimmed)]),
        );
      }
      return XmlEditResult(doc.toXml(), ref);
    }
    _insertOrdered(
      head,
      XmlElement(
        XmlName('lyric'),
        [XmlAttribute(XmlName('number'), '$verse')],
        [
          XmlElement(XmlName('syllabic'), [], [XmlText('single')]),
          XmlElement(XmlName('text'), [], [XmlText(trimmed)]),
        ],
      ),
      _noteOrder,
    );
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Adds an empty bar (a whole-bar rest) after the selected note's bar, in
  /// every part. The selection moves to the new bar.
  XmlEditResult insertMeasureAfter(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    doc.measureAt(ref.partIndex, ref.measureIndex);
    final firstNumber = _firstNumberInOrder(doc);
    final origins = _readOrigins(doc, ref.partIndex);
    for (final (partIndex, part) in doc.parts.indexed) {
      final measures = doc._measures(partIndex);
      final freed = <XmlElement>[];
      if (ref.measureIndex >= measures.length) continue;
      final source = measures[ref.measureIndex];
      final bar = _emptyMeasure(
        doc._contextBefore(measures, ref.measureIndex + 1),
        number: source.getAttribute('number') ?? '${ref.measureIndex + 1}',
      );
      part.children.insert(part.children.indexOf(source) + 1, bar);
      if (ref.measureIndex == measures.length - 1) {
        _moveBarline(from: source, to: bar, right: true);
      }
      _mendTies(source, bar, freed);
      if (ref.measureIndex + 1 < measures.length) {
        _mendTies(bar, measures[ref.measureIndex + 1], freed);
      }
      _spellFreed(doc, partIndex, freed);
    }
    if (firstNumber != null) _renumber(doc, firstNumber);
    _writeOrigins(doc, origins..insert(ref.measureIndex + 1, -1));
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(
        partIndex: ref.partIndex,
        measureIndex: ref.measureIndex + 1,
        noteIndex: 0,
      ),
    );
  }

  /// Copies the selected note's bar after itself, in every part: notes,
  /// chords and lyrics. Signs that belong to the place rather than the music
  /// (repeat and ending barlines, section boxes, segno, coda, jumps, clef,
  /// key and time) are not repeated. The selection moves to the copy.
  XmlEditResult duplicateMeasure(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    doc.measureAt(ref.partIndex, ref.measureIndex);
    final firstNumber = _firstNumberInOrder(doc);
    final origins = _readOrigins(doc, ref.partIndex);
    for (final (partIndex, part) in doc.parts.indexed) {
      final measures = doc._measures(partIndex);
      final freed = <XmlElement>[];
      if (ref.measureIndex >= measures.length) continue;
      final source = measures[ref.measureIndex];
      final copy = source.copy();
      // A pickup bar is one by its place; an id names one element.
      for (final name in ['implicit', 'id', 'xml:id', 'width']) {
        copy.removeAttribute(name);
      }
      // A slur that leaves the bar now runs over the copy: a slur inside the
      // copy must not answer to its number.
      final passing = {
        for (final slur in _openSlurs(source))
          if (slur.getAttribute('type') == 'start')
            slur.getAttribute('number') ?? '1',
      };
      _stripPlaceSigns(
        copy,
        startsIn: doc._contextBefore(measures, ref.measureIndex),
        follows: doc._contextBefore(measures, ref.measureIndex + 1),
      );
      _renumberSlurs(copy, passing);
      part.children.insert(part.children.indexOf(source) + 1, copy);
      if (ref.measureIndex == measures.length - 1) {
        _moveBarline(from: source, to: copy, right: true);
      }
      _mendTies(source, copy, freed);
      if (ref.measureIndex + 1 < measures.length) {
        _mendTies(copy, measures[ref.measureIndex + 1], freed);
      }
      _spellFreed(doc, partIndex, freed);
    }
    if (firstNumber != null) _renumber(doc, firstNumber);
    _writeOrigins(doc, origins..insert(ref.measureIndex + 1, -1));
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(
        partIndex: ref.partIndex,
        measureIndex: ref.measureIndex + 1,
        noteIndex: ref.noteIndex,
      ),
    );
  }

  /// Moves the selected note's bar one place earlier ([places] -1) or later
  /// (+1), in every part: it changes places with its neighbour. Each bar
  /// keeps its music, clef, key and time; repeat and ending barlines and
  /// line breaks stay where they are in the score. The selection follows
  /// the bar.
  XmlEditResult moveMeasure(String xml, XmlNoteRef ref, int places) {
    if (places != 1 && places != -1) {
      throw const FormatException('마디는 한 칸씩 옮길 수 있습니다.');
    }
    final doc = _ScoreDoc(xml);
    doc.measureAt(ref.partIndex, ref.measureIndex);
    final first = places < 0 ? ref.measureIndex - 1 : ref.measureIndex;
    if (first < 0 || first + 1 >= doc.measureCount(ref.partIndex)) {
      throw const FormatException('더 옮길 자리가 없습니다.');
    }
    final firstNumber = _firstNumberInOrder(doc);
    final origins = _readOrigins(doc, ref.partIndex);
    for (final (partIndex, part) in doc.parts.indexed) {
      final measures = doc._measures(partIndex);
      final freed = <XmlElement>[];
      if (first + 1 >= measures.length) continue;
      final contexts = doc._contextsOf(measures);
      final a = measures[first];
      final b = measures[first + 1];
      final before = first > 0 ? measures[first - 1] : null;
      final after = first + 2 < measures.length ? measures[first + 2] : null;
      // What the score is in before the pair, and how each bar begins.
      final given = first == 0 ? _unstated : contexts[first];
      final aBegins = _beginning(a, contexts[first]);
      final bBegins = _beginning(b, contexts[first + 1]);
      // A slur that leaves either bar cannot follow it to its new place.
      for (final (start, stop) in _slurPairs(part)) {
        bool inside(XmlElement e) => _within(e, a) || _within(e, b);
        final together =
            (_within(start, a) && _within(stop, a)) ||
            (_within(start, b) && _within(stop, b));
        if (!together && (inside(start) || inside(stop))) {
          _removeNotation(start);
          _removeNotation(stop);
        }
      }
      // Barlines and line breaks belong to the place: they are taken off,
      // and put back on the bar that comes to stand there.
      final aPlace = _takePlaceSigns(a);
      final bPlace = _takePlaceSigns(b);
      final at = part.children.indexOf(a);
      _remove(b);
      part.children.insert(at, b);
      _putPlaceSigns(b, aPlace);
      _putPlaceSigns(a, bPlace);
      // Each bar says how it begins, as far as that is not in force already.
      _restate(b, bBegins, given);
      final afterB = _ending(b, first == 0 ? const _Context() : given);
      _restate(a, aBegins, afterB);
      if (after != null) {
        // The bar after the pair went on from the second one, now the first.
        _restate(
          after,
          _beginning(after, contexts[first + 2]),
          _ending(a, afterB),
        );
      }
      if (before != null) _mendTies(before, b, freed);
      if (before == null) _dropTies(b, 'stop', freed);
      _mendTies(b, a, freed);
      if (after != null) _mendTies(a, after, freed);
      if (after == null) _dropTies(a, 'start', freed);
      _spellFreed(doc, partIndex, freed);
    }
    if (firstNumber != null) _renumber(doc, firstNumber);
    final moved = origins[first];
    origins[first] = origins[first + 1];
    origins[first + 1] = moved;
    _writeOrigins(doc, origins);
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(
        partIndex: ref.partIndex,
        measureIndex: ref.measureIndex + places,
        noteIndex: ref.noteIndex,
      ),
    );
  }

  /// Removes the selected note's bar from every part. Its clef, key and time
  /// go to the next bar, a repeat or ending sign to the neighbour on that
  /// side. The selection moves to the bar that takes its place.
  XmlEditResult deleteMeasure(String xml, XmlNoteRef ref) {
    final doc = _ScoreDoc(xml);
    doc.measureAt(ref.partIndex, ref.measureIndex);
    final count = doc.measureCount(ref.partIndex);
    if (count <= 1) {
      throw const FormatException('마지막 남은 마디는 지울 수 없습니다.');
    }
    final firstNumber = _firstNumberInOrder(doc);
    final origins = _readOrigins(doc, ref.partIndex);
    for (final partIndex in [for (var i = 0; i < doc.parts.length; i++) i]) {
      final measures = doc._measures(partIndex);
      final freed = <XmlElement>[];
      final index = ref.measureIndex;
      if (index >= measures.length || measures.length <= 1) continue;
      final target = measures[index];
      final previous = index > 0 ? measures[index - 1] : null;
      final next = index + 1 < measures.length ? measures[index + 1] : null;
      // An ending bracket over this bar alone goes with it.
      final endings = target
          .findElements('barline')
          .expand((barline) => barline.findElements('ending'))
          .toList();
      if (endings.any((e) => e.getAttribute('type') == 'start') &&
          endings.any((e) => e.getAttribute('type') != 'start')) {
        for (final ending in endings) {
          final barline = ending.parentElement;
          _remove(ending);
          // A barline that only held the bracket.
          if (barline != null &&
              barline.childElements.every(
                (child) =>
                    child.name.local == 'bar-style' &&
                    child.innerText.trim() == 'regular',
              )) {
            _remove(barline);
          }
        }
      }
      if (next != null) {
        // The tempo set in this bar holds for what follows.
        final tempo = [
          for (final child in target.childElements)
            if (_setsTempo(child)) child,
        ];
        if (tempo.isNotEmpty && !next.childElements.any(_setsTempo)) {
          tempo.forEach(_remove);
          final at = next.children.indexWhere(
            (node) =>
                node is XmlElement &&
                !['print', 'attributes'].contains(node.name.local) &&
                !(node.name.local == 'barline' &&
                    node.getAttribute('location') == 'left'),
          );
          next.children.insertAll(at < 0 ? next.children.length : at, tempo);
        }
        final carried = target.findElements('attributes').toList();
        carried.forEach(_remove);
        next.children.insertAll(0, carried);
        _dropRestated(
          next,
          // The first bar states everything: nothing is "already known".
          index == 0 ? _unstated : doc._contextBefore(measures, index),
        );
        _moveBarline(from: target, to: next, right: false);
      }
      if (previous != null) {
        _moveBarline(from: target, to: previous, right: true);
      }
      // A slur with one end in the bar loses it: the other end goes too.
      final part = doc.parts[partIndex];
      for (final (start, stop) in _slurPairs(part)) {
        final startInside = _within(start, target);
        if (startInside != _within(stop, target)) {
          _removeNotation(startInside ? stop : start);
        }
      }
      _remove(target);
      if (previous != null && next != null) _mendTies(previous, next, freed);
      if (previous == null && next != null) _dropTies(next, 'stop', freed);
      if (next == null && previous != null) {
        _dropTies(previous, 'start', freed);
      }
      _spellFreed(doc, partIndex, freed);
    }
    if (firstNumber != null) {
      // Without its pickup bar (numbered 0) a score starts at bar 1.
      _renumber(
        doc,
        ref.measureIndex == 0 && firstNumber == 0 ? 1 : firstNumber,
      );
    }
    _writeOrigins(doc, origins..removeAt(ref.measureIndex));
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(
        partIndex: ref.partIndex,
        measureIndex: ref.measureIndex.clamp(0, count - 2),
        noteIndex: 0,
      ),
    );
  }

  /// Writes [melody] as the notes of one measure of one part, in place of
  /// its notes: a suggestion such as "G4 q, A4 8, B4 8., rest 16" (pitch or
  /// rest, then w h q 8 16 32 with dots). Chord symbols keep their place in
  /// the bar and the lyrics move onto the new sung notes in order. The
  /// melody must fill the measure for its time signature. Multi-staff
  /// measures and measures with more than one voice are not changed.
  XmlEditResult replaceMelody(
    String xml,
    int partIndex,
    int measureIndex,
    String melody,
  ) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measureAt(partIndex, measureIndex);
    if (measure.context.staves > 1) {
      throw const FormatException('보표가 둘인 마디에는 멜로디를 쓸 수 없습니다.');
    }
    final voices = {for (final note in measure.notes) note.voice};
    if (voices.length > 1) {
      throw const FormatException('성부가 둘 이상인 마디에는 멜로디를 쓸 수 없습니다.');
    }
    final tokens = parseMelodyTokens(melody);
    if (tokens.isEmpty) throw const FormatException('멜로디가 비어 있습니다.');
    final divisions = measure.divisions;
    var total = 0;
    final lengths = <int>[];
    for (final token in tokens) {
      final quarters = _typeQuarters[token.type]!;
      final value = divisions * quarters * (2 - 1 / math.pow(2, token.dots));
      if (value != value.roundToDouble() || value < 1) {
        throw const FormatException('이 악보의 음가 단위로 쓸 수 없는 음표가 있습니다.');
      }
      lengths.add(value.round());
      total += value.round();
    }
    if (total != measure.capacity) {
      throw const FormatException('멜로디 길이가 박자표와 맞지 않습니다.');
    }
    final voice = voices.isEmpty ? '1' : voices.first;
    final element = measure.element;
    // What the old notes carried that the new ones take over.
    final lyrics = [
      for (final note in measure.notes)
        if (!note.isRest && !note.isGrace)
          for (final lyric in note.element.findElements('lyric')) lyric.copy(),
    ];
    final harmonies = [
      for (final (onset, harmony) in measure._harmonies) (onset, harmony),
    ];
    final old = [for (final note in measure.notes) note.element];
    // Where the new notes go: where the old ones began, else after what
    // opens the bar. Marked before anything is taken out.
    final marker = XmlComment('melody');
    if (old.isNotEmpty) {
      element.children.insert(element.children.indexOf(old.first), marker);
    } else {
      final index = element.children.indexWhere(
        (node) =>
            node is XmlElement &&
            !['print', 'attributes'].contains(node.name.local) &&
            !(node.name.local == 'barline' &&
                node.getAttribute('location') == 'left'),
      );
      element.children.insert(
        index < 0 ? element.children.length : index,
        marker,
      );
    }
    for (final harmony in harmonies) {
      _remove(harmony.$2);
    }
    for (final note in old) {
      _remove(note);
    }
    // The new notes, each chord symbol before the note at (or after) its
    // onset, as it stood before.
    final made = <XmlElement>[];
    var onset = 0;
    var lyricAt = 0;
    final pending = harmonies.toList();
    for (final (index, token) in tokens.indexed) {
      final note = XmlElement(XmlName('note'));
      if (token.pitch case final pitch?) {
        note.children.add(_pitchElement(pitch));
      } else {
        note.children.add(XmlElement(XmlName('rest')));
      }
      note.children.add(
        XmlElement(XmlName('duration'), [], [XmlText('${lengths[index]}')]),
      );
      note.children.add(XmlElement(XmlName('voice'), [], [XmlText(voice)]));
      note.children.add(XmlElement(XmlName('type'), [], [XmlText(token.type)]));
      for (var i = 0; i < token.dots; i++) {
        note.children.add(XmlElement(XmlName('dot')));
      }
      if (token.pitch != null && lyricAt < lyrics.length) {
        final lyric = lyrics[lyricAt++];
        for (final other in lyrics.skip(lyricAt)) {
          // Several verses on one note travel together.
          if (other.getAttribute('number') == lyric.getAttribute('number')) {
            break;
          }
          note.children.add(other);
          lyricAt++;
        }
        note.children.insert(note.children.length - 0, lyric);
      }
      while (pending.isNotEmpty && pending.first.$1 <= onset) {
        made.add(pending.removeAt(0).$2);
      }
      made.add(note);
      onset += lengths[index];
    }
    made.addAll(pending.map((h) => h.$2));
    final at = element.children.indexOf(marker);
    element.children.insertAll(at, made);
    _remove(marker);
    final rebuilt = doc.measureAt(partIndex, measureIndex);
    rebuilt
      ..rebeamRange(voice, 0, rebuilt.capacity)
      ..refreshAccidentals(1, {
        for (final token in tokens)
          if (token.pitch case final pitch?) pitch.step,
      });
    doc.measureAt(partIndex, measureIndex).fixOrphanBeams(voice);
    return XmlEditResult(
      doc.toXml(),
      XmlNoteRef(
        partIndex: partIndex,
        measureIndex: measureIndex,
        noteIndex: 0,
      ),
    );
  }

  /// Gives the [noteIndex]-th note of a measure the pitch [spelled] ("F#4",
  /// "Bb3"); its length stays. Tied notes move together.
  XmlEditResult setNotePitch(String xml, XmlNoteRef ref, String spelled) {
    final pitch = parseSpelledPitch(spelled);
    if (pitch == null) throw FormatException('음높이를 읽을 수 없습니다: $spelled');
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isRest) throw const FormatException('쉼표에는 음높이가 없습니다.');
    final steps = {pitch.step, if (info.pitch case final old?) old.step};
    for (final (index, note) in doc.tieChain(ref.measureIndex, info)) {
      note.element.getElement('pitch')?.replace(_pitchElement(pitch));
      doc.measureAt(ref.partIndex, index).refreshAccidentals(note.staff, steps);
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// The texts written in a measure (`<words>`: instructions such as "rit.",
  /// or what a recogniser left of a chord or lyric it could not read), in
  /// document order.
  List<String> measureTexts(String xml, int partIndex, int measureIndex) => [
    for (final direction in _textDirections(
      _ScoreDoc(xml).measureAt(partIndex, measureIndex).element,
    ))
      _directionText(direction),
  ];

  /// [measureTexts] of every bar of a part, read in one pass.
  List<List<String>> allMeasureTexts(String xml, int partIndex) => [
    for (final measure in _ScoreDoc(xml)._measures(partIndex))
      [
        for (final direction in _textDirections(measure))
          _directionText(direction),
      ],
  ];

  /// Rewrites the [textIndex]-th text of the selected note's measure, as
  /// [measureTexts] lists them (a section name read as "Uerse'").
  XmlEditResult setText(
    String xml,
    XmlNoteRef ref,
    int textIndex,
    String text,
  ) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return removeText(xml, ref, textIndex);
    final doc = _ScoreDoc(xml);
    final directions = _textDirections(doc.measure(ref).element).toList();
    if (textIndex < 0 || textIndex >= directions.length) {
      throw const FormatException('고칠 글자가 없습니다.');
    }
    final words = directions[textIndex]
        .findElements('direction-type')
        .expand((type) => type.findElements('words'))
        .where((words) => words.innerText.trim().isNotEmpty)
        .toList();
    words.first.innerText = trimmed;
    // A text split over several <words> becomes the one that was typed.
    words.skip(1).forEach(_remove);
    for (final type
        in directions[textIndex].findElements('direction-type').toList()) {
      if (type.childElements.isEmpty) _remove(type);
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  /// Removes the [textIndex]-th text of the selected note's measure, as
  /// [measureTexts] lists them. Notes, chords and lyrics stay.
  XmlEditResult removeText(String xml, XmlNoteRef ref, int textIndex) {
    final doc = _ScoreDoc(xml);
    final directions = _textDirections(doc.measure(ref).element).toList();
    if (textIndex < 0 || textIndex >= directions.length) {
      throw const FormatException('지울 글자가 없습니다.');
    }
    final direction = directions[textIndex];
    final types = direction.findElements('direction-type').toList();
    final worded = types
        .where((type) => type.findElements('words').isNotEmpty)
        .toList();
    if (worded.length == types.length) {
      // What the direction plays (a tempo) stays, as a sound of the bar.
      final sounds = direction.findElements('sound').toList();
      final parent = direction.parent!;
      final at = parent.children.indexOf(direction);
      _remove(direction);
      for (final sound in sounds) {
        _remove(sound);
      }
      parent.children.insertAll(at, sounds);
    } else {
      // The direction also carries a sign (a dynamic, a segno): that stays.
      worded.forEach(_remove);
    }
    return XmlEditResult(doc.toXml(), ref);
  }

  XmlEditResult _editPitch(
    String xml,
    XmlNoteRef ref,
    MusicPitch Function(_ScoreDoc doc, _MeasureView measure, _NoteInfo info)
    next,
  ) {
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
    if (info.isRest) {
      throw const FormatException('쉼표를 먼저 음표로 바꾸세요.');
    }
    final pitch = next(doc, measure, info);
    if (pitch.octave < 0 || pitch.octave > 9) {
      throw const FormatException('음역을 벗어났습니다.');
    }
    final old = info.pitch!;
    final chain = doc.tieChain(ref.measureIndex, info);
    for (final (_, note) in chain) {
      note.element.getElement('pitch')!.replace(_pitchElement(pitch));
    }
    final touched = <int>{for (final (index, _) in chain) index};
    for (final index in touched) {
      doc.measureAt(ref.partIndex, index).refreshAccidentals(info.staff, {
        old.step,
        pitch.step,
      });
    }
    return XmlEditResult(doc.toXml(), ref);
  }
}

class ChordSymbol {
  const ChordSymbol({
    required this.rootStep,
    required this.rootAlter,
    required this.kind,
    required this.text,
    this.bassStep,
    this.bassAlter = 0,
  });

  final PitchStep rootStep;
  final int rootAlter;
  final String kind;
  final String text;
  final PitchStep? bassStep;
  final int bassAlter;

  XmlElement toXml({int? staff}) {
    XmlElement leaf(String name, String value) =>
        XmlElement(XmlName(name), [], [XmlText(value)]);
    return XmlElement(XmlName('harmony'), [], [
      XmlElement(XmlName('root'), [], [
        leaf('root-step', rootStep.musicXmlName),
        if (rootAlter != 0) leaf('root-alter', '$rootAlter'),
      ]),
      XmlElement(
        XmlName('kind'),
        [XmlAttribute(XmlName('text'), text)],
        [XmlText(kind)],
      ),
      if (bassStep != null)
        XmlElement(XmlName('bass'), [], [
          leaf('bass-step', bassStep!.musicXmlName),
          if (bassAlter != 0) leaf('bass-alter', '$bassAlter'),
        ]),
      if (staff != null) leaf('staff', '$staff'),
    ]);
  }
}

const _kindBySuffix = <String, String>{
  '': 'major',
  'M': 'major',
  'maj': 'major',
  'm': 'minor',
  'min': 'minor',
  '-': 'minor',
  '7': 'dominant',
  'maj7': 'major-seventh',
  'M7': 'major-seventh',
  'ma7': 'major-seventh',
  'Δ': 'major-seventh',
  'Δ7': 'major-seventh',
  'm7': 'minor-seventh',
  'min7': 'minor-seventh',
  '-7': 'minor-seventh',
  'dim': 'diminished',
  '°': 'diminished',
  'o': 'diminished',
  'dim7': 'diminished-seventh',
  '°7': 'diminished-seventh',
  'o7': 'diminished-seventh',
  'm7b5': 'half-diminished',
  'm7♭5': 'half-diminished',
  'ø': 'half-diminished',
  'ø7': 'half-diminished',
  'aug': 'augmented',
  '+': 'augmented',
  'aug7': 'augmented-seventh',
  '+7': 'augmented-seventh',
  '7#5': 'augmented-seventh',
  '7♯5': 'augmented-seventh',
  'mmaj7': 'major-minor',
  'mM7': 'major-minor',
  '6': 'major-sixth',
  'm6': 'minor-sixth',
  '9': 'dominant-ninth',
  'maj9': 'major-ninth',
  'M9': 'major-ninth',
  'm9': 'minor-ninth',
  '11': 'dominant-11th',
  'm11': 'minor-11th',
  '13': 'dominant-13th',
  'sus': 'suspended-fourth',
  '7sus4': 'suspended-fourth',
  '7sus': 'suspended-fourth',
  '2': 'suspended-second',
  'add2': 'major',
  'add9': 'major',
  'sus4': 'suspended-fourth',
  'sus2': 'suspended-second',
  '5': 'power',
};

/// Parses chord text such as `C`, `F#m7`, `B♭maj7/D` or `Gsus4`.
///
/// Unknown extensions keep the typed text for display and use the closest
/// basic quality so transposition and accompaniment still work.
ChordSymbol parseChordSymbol(String input) {
  final text = input.replaceAll(RegExp(r'\s+'), '');
  final match = RegExp(
    r'^([A-Ga-g])([#♯b♭]?)(.*?)(?:/([A-Ga-g])([#♯b♭]?))?$',
  ).firstMatch(text);
  if (match == null) {
    throw const FormatException('코드를 C, F#m7, B♭/D 형식으로 입력하세요.');
  }
  int alterOf(String? value) => switch (value) {
    '#' || '♯' => 1,
    'b' || '♭' => -1,
    _ => 0,
  };
  final suffix = match.group(3)!;
  // "C/H" or "A/" has no bass to read, and "C##" no root a chord is named
  // by; taken as written they would not transpose.
  if (suffix.contains('/') || RegExp('^[#♯b♭]').hasMatch(suffix)) {
    throw const FormatException('코드를 C, F#m7, B♭/D 형식으로 입력하세요.');
  }
  final kind =
      _kindBySuffix[suffix] ??
      (suffix.startsWith('maj') || suffix.startsWith('M')
          ? 'major-seventh'
          : suffix.startsWith('m') && !suffix.startsWith('maj')
          ? 'minor'
          : suffix.startsWith('7') ||
                suffix.startsWith('9') ||
                suffix.startsWith('13')
          ? 'dominant'
          : 'major');
  return ChordSymbol(
    rootStep: PitchStepMusicXml.parse(match.group(1)!),
    rootAlter: alterOf(match.group(2)),
    kind: kind,
    text: suffix,
    bassStep: match.group(4) == null
        ? null
        : PitchStepMusicXml.parse(match.group(4)!),
    bassAlter: alterOf(match.group(5)),
  );
}

const _kindAbbreviation = <String, String>{
  'major': '',
  'minor': 'm',
  'augmented': 'aug',
  'diminished': 'dim',
  'dominant': '7',
  'major-seventh': 'maj7',
  'minor-seventh': 'm7',
  'diminished-seventh': 'dim7',
  'augmented-seventh': 'aug7',
  'half-diminished': 'm7b5',
  'major-minor': 'mMaj7',
  'major-sixth': '6',
  'minor-sixth': 'm6',
  'dominant-ninth': '9',
  'major-ninth': 'maj9',
  'minor-ninth': 'm9',
  'dominant-11th': '11',
  'minor-11th': 'm11',
  'dominant-13th': '13',
  'suspended-second': 'sus2',
  'suspended-fourth': 'sus4',
  'power': '5',
};

/// Plain text for a `<harmony>` element, e.g. `F#m7/C#`.
String harmonyText(XmlElement harmony) {
  String accidental(String? value) => switch (int.tryParse(value ?? '')) {
    1 => '#',
    -1 => 'b',
    _ => '',
  };
  final root = harmony.getElement('root');
  final kind = harmony.getElement('kind');
  final bass = harmony.getElement('bass');
  final buffer = StringBuffer()
    ..write(root?.getElement('root-step')?.innerText.trim() ?? '')
    ..write(accidental(root?.getElement('root-alter')?.innerText.trim()))
    ..write(
      kind?.getAttribute('text') ??
          _kindAbbreviation[kind?.innerText.trim()] ??
          '',
    );
  if (bass != null) {
    buffer
      ..write('/')
      ..write(bass.getElement('bass-step')?.innerText.trim() ?? '')
      ..write(accidental(bass.getElement('bass-alter')?.innerText.trim()));
  }
  return buffer.toString();
}

// --- Document model -------------------------------------------------------

class _ScoreDoc {
  _ScoreDoc(String xml) : document = _take(xml) {
    if (document.rootElement.name.local != 'score-partwise') {
      throw const FormatException('score-partwise MusicXML만 편집할 수 있습니다.');
    }
  }

  static XmlDocument _parse(String xml) {
    try {
      return XmlDocument.parse(xml);
    } on XmlException {
      throw const FormatException('악보 파일을 읽을 수 없습니다.');
    }
  }

  // Reading a long score is most of the time an edit takes, and an editor
  // edits the text the edit before it wrote. The document of the text
  // written last is therefore kept, and handed to whoever asks for that
  // very text next. It is handed out once: the taker changes it, and only
  // what it writes with [toXml], or keeps unchanged with [keep], is kept
  // again. An edit that fails half way leaves nothing behind.
  static String? _keptXml;
  static XmlDocument? _keptDocument;

  static XmlDocument _take(String xml) {
    final kept = _keptDocument;
    if (kept != null && identical(xml, _keptXml)) {
      _keptXml = null;
      _keptDocument = null;
      return kept;
    }
    return _parse(xml);
  }

  final XmlDocument document;

  /// The score as text. The document must not be changed after this.
  String toXml() {
    final xml = document.toXmlString();
    _keptXml = xml;
    _keptDocument = document;
    return xml;
  }

  /// Says the document was only read and still is what [xml] says.
  void keep(String xml) {
    _keptXml = xml;
    _keptDocument = document;
  }

  List<XmlElement> get parts =>
      document.rootElement.findElements('part').toList();

  List<XmlElement> _measures(int partIndex) {
    final parts = document.rootElement.findElements('part').toList();
    if (partIndex < 0 || partIndex >= parts.length) {
      throw const FormatException('파트를 찾을 수 없습니다.');
    }
    return parts[partIndex].findElements('measure').toList();
  }

  _MeasureView measure(XmlNoteRef ref) =>
      measureAt(ref.partIndex, ref.measureIndex);

  _MeasureView measureAt(int partIndex, int measureIndex) {
    final measures = _measures(partIndex);
    if (measureIndex < 0 || measureIndex >= measures.length) {
      throw const FormatException('마디를 찾을 수 없습니다.');
    }
    return _MeasureView(
      partIndex: partIndex,
      index: measureIndex,
      element: measures[measureIndex],
      context: _contextBefore(measures, measureIndex),
    );
  }

  int measureCount(int partIndex) => _measures(partIndex).length;

  /// For each bar the context before it, and after the last bar at the end.
  List<_Context> _contextsOf(List<XmlElement> measures) {
    var context = const _Context();
    final contexts = [context];
    for (final measure in measures) {
      for (final attributes in measure.findElements('attributes')) {
        context = context.merge(attributes);
      }
      contexts.add(context);
    }
    return contexts;
  }

  _Context _contextBefore(List<XmlElement> measures, int measureIndex) {
    var context = const _Context();
    for (var i = 0; i < measureIndex; i++) {
      for (final attributes in measures[i].findElements('attributes')) {
        context = context.merge(attributes);
      }
    }
    return context;
  }

  /// All notes tied to [note], in order, as (measureIndex, note) pairs.
  List<(int, _NoteInfo)> tieChain(int measureIndex, _NoteInfo note) {
    final chain = <(int, _NoteInfo)>[(measureIndex, note)];
    var cursor = (measureIndex, note);
    while (cursor.$2.tieStop) {
      final previous = _previousTied(cursor.$1, cursor.$2);
      if (previous == null ||
          chain.any((c) => identical(c.$2.element, previous.$2.element))) {
        break;
      }
      chain.insert(0, previous);
      cursor = previous;
    }
    cursor = (measureIndex, note);
    while (cursor.$2.tieStart) {
      final next = _nextTied(cursor.$1, cursor.$2);
      if (next == null ||
          chain.any((c) => identical(c.$2.element, next.$2.element))) {
        break;
      }
      chain.add(next);
      cursor = next;
    }
    return chain;
  }

  (int, _NoteInfo)? _nextTied(int measureIndex, _NoteInfo note) {
    final measure = measureAt(note.partIndex, measureIndex);
    final end = note.onset + note.duration;
    for (final candidate in measure.notes) {
      if (candidate.tieStop &&
          candidate.onset == end &&
          candidate.staff == note.staff &&
          candidate.pitch?.midi == note.pitch?.midi) {
        return (measureIndex, candidate);
      }
    }
    if (measureIndex + 1 >= measureCount(note.partIndex)) return null;
    // Only a note that reaches the barline ties into the next bar.
    if (end < _voiceEnd(measure, note)) return null;
    final next = measureAt(note.partIndex, measureIndex + 1);
    for (final candidate in next.notes) {
      if (candidate.tieStop &&
          candidate.onset == 0 &&
          candidate.staff == note.staff &&
          candidate.pitch?.midi == note.pitch?.midi) {
        return (measureIndex + 1, candidate);
      }
    }
    return null;
  }

  (int, _NoteInfo)? _previousTied(int measureIndex, _NoteInfo note) {
    final measure = measureAt(note.partIndex, measureIndex);
    for (final candidate in measure.notes) {
      if (candidate.tieStart &&
          candidate.onset + candidate.duration == note.onset &&
          candidate.staff == note.staff &&
          candidate.pitch?.midi == note.pitch?.midi) {
        return (measureIndex, candidate);
      }
    }
    if (note.onset != 0 || measureIndex == 0) return null;
    final previous = measureAt(note.partIndex, measureIndex - 1);
    _NoteInfo? best;
    for (final candidate in previous.notes) {
      if (candidate.tieStart &&
          candidate.staff == note.staff &&
          candidate.pitch?.midi == note.pitch?.midi &&
          candidate.onset + candidate.duration >=
              _voiceEnd(previous, candidate) &&
          (best == null ||
              candidate.onset + candidate.duration >
                  best.onset + best.duration)) {
        best = candidate;
      }
    }
    return best == null ? null : (measureIndex - 1, best);
  }

  /// Where the voice of [note] ends in [measure].
  int _voiceEnd(_MeasureView measure, _NoteInfo note) {
    var end = 0;
    for (final other in measure.notes) {
      if (other.voice != note.voice || other.isGrace) continue;
      end = math.max(end, other.onset + other.duration);
    }
    return end;
  }

  /// Removes tie markers that point at [note] from its partners and itself.
  void breakTies(
    int measureIndex,
    _NoteInfo note, {
    bool start = true,
    bool stop = true,
  }) {
    if (start && note.tieStart) {
      final next = _nextTied(measureIndex, note);
      if (next != null) _removeTieMarks(next.$2.element, 'stop');
      _removeTieMarks(note.element, 'start');
      // A note tied over a barline carries no accidental of its own; on its
      // own again, it needs the one its pitch asks for.
      if (next != null && next.$1 != measureIndex && note.pitch != null) {
        measureAt(
          note.partIndex,
          next.$1,
        ).refreshAccidentals(note.staff, {note.pitch!.step});
      }
    }
    if (stop && note.tieStop) {
      final previous = _previousTied(measureIndex, note);
      if (previous != null) _removeTieMarks(previous.$2.element, 'start');
      _removeTieMarks(note.element, 'stop');
      if (note.onset == 0 && note.pitch != null) {
        measureAt(
          note.partIndex,
          measureIndex,
        ).refreshAccidentals(note.staff, {note.pitch!.step});
      }
    }
  }

  /// Multiplies `<divisions>` for one measure and restores the old value in
  /// the next measure, so the rest of the part stays byte-for-byte unchanged.
  void scaleDivisions(int partIndex, int measureIndex, int multiplier) {
    final measures = _measures(partIndex);
    final element = measures[measureIndex];
    final context = _contextBefore(measures, measureIndex);
    var original = context.divisions;
    final ownDivisions = element
        .findElements('attributes')
        .expand((a) => a.findElements('divisions'))
        .toList();
    if (ownDivisions.length > 1) {
      throw const FormatException('박 단위가 여러 번 바뀌는 마디는 편집할 수 없습니다.');
    }
    if (ownDivisions.isNotEmpty) {
      original = int.parse(ownDivisions.single.innerText.trim());
    }
    for (final duration in element.descendants.whereType<XmlElement>()) {
      final name = duration.name.local;
      if (name != 'duration' && name != 'offset') continue;
      final parent = duration.parent;
      if (parent is! XmlElement ||
          !const {
            'note',
            'backup',
            'forward',
            'direction',
            'harmony',
          }.contains(parent.name.local)) {
        continue;
      }
      final value = int.tryParse(duration.innerText.trim());
      if (value != null) duration.innerText = '${value * multiplier}';
    }
    if (ownDivisions.isNotEmpty) {
      ownDivisions.single.innerText = '${original * multiplier}';
    } else {
      final attributes = _firstAttributes(element);
      _setChild(
        attributes,
        'divisions',
        '${original * multiplier}',
        _attributesOrder,
      );
    }
    if (measureIndex + 1 < measures.length) {
      final next = measures[measureIndex + 1];
      final declares = next
          .findElements('attributes')
          .any((a) => a.getElement('divisions') != null);
      if (!declares) {
        _setChild(
          _firstAttributes(next),
          'divisions',
          '$original',
          _attributesOrder,
        );
      }
    }
  }

  XmlElement _firstAttributes(XmlElement measure) {
    final existing = measure.findElements('attributes').firstOrNull;
    if (existing != null &&
        !measure.childElements
            .takeWhile((e) => !identical(e, existing))
            .any((e) => e.name.local == 'note')) {
      return existing;
    }
    final attributes = XmlElement(XmlName('attributes'));
    final firstMusic = measure.childElements
        .where((e) => e.name.local != 'print')
        .firstOrNull;
    if (firstMusic == null) {
      measure.children.add(attributes);
    } else {
      measure.children.insert(measure.children.indexOf(firstMusic), attributes);
    }
    return attributes;
  }
}

class _Context {
  const _Context({
    this.divisions = 1,
    this.fifths = 0,
    this.beats = 4,
    this.beatType = 4,
    this.staves = 1,
    this.clefs = const {},
  });

  final int divisions;
  final int fifths;
  final int beats;
  final int beatType;
  final int staves;
  final Map<int, (String, int)> clefs;

  bool sameAs(_Context other) =>
      divisions == other.divisions &&
      fifths == other.fifths &&
      beats == other.beats &&
      beatType == other.beatType &&
      staves == other.staves &&
      clefs.length == other.clefs.length &&
      clefs.entries.every((entry) => other.clefs[entry.key] == entry.value);

  /// An `<attributes>` element restating this context.
  XmlElement toAttributes() {
    XmlElement leaf(String name, String value) =>
        XmlElement(XmlName(name), [], [XmlText(value)]);
    return XmlElement(XmlName('attributes'), [], [
      leaf('divisions', '$divisions'),
      XmlElement(XmlName('key'), [], [leaf('fifths', '$fifths')]),
      XmlElement(XmlName('time'), [], [
        leaf('beats', '$beats'),
        leaf('beat-type', '$beatType'),
      ]),
      if (staves > 1) leaf('staves', '$staves'),
      for (final entry
          in (clefs.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
        XmlElement(
          XmlName('clef'),
          [if (staves > 1) XmlAttribute(XmlName('number'), '${entry.key}')],
          [leaf('sign', entry.value.$1), leaf('line', '${entry.value.$2}')],
        ),
    ]);
  }

  _Context merge(XmlElement attributes) {
    final clefs = Map<int, (String, int)>.of(this.clefs);
    for (final clef in attributes.findElements('clef')) {
      final number = int.tryParse(clef.getAttribute('number') ?? '') ?? 1;
      clefs[number] = (
        clef.getElement('sign')?.innerText.trim() ?? 'G',
        int.tryParse(clef.getElement('line')?.innerText.trim() ?? '') ?? 2,
      );
    }
    final time = attributes.getElement('time');
    return _Context(
      divisions:
          int.tryParse(
            attributes.getElement('divisions')?.innerText.trim() ?? '',
          ) ??
          divisions,
      fifths:
          int.tryParse(
            attributes
                    .getElement('key')
                    ?.getElement('fifths')
                    ?.innerText
                    .trim() ??
                '',
          ) ??
          fifths,
      beats:
          int.tryParse(time?.getElement('beats')?.innerText.trim() ?? '') ??
          beats,
      beatType:
          int.tryParse(time?.getElement('beat-type')?.innerText.trim() ?? '') ??
          beatType,
      staves:
          int.tryParse(
            attributes.getElement('staves')?.innerText.trim() ?? '',
          ) ??
          staves,
      clefs: clefs,
    );
  }
}

class _NoteInfo {
  _NoteInfo({
    required this.partIndex,
    required this.element,
    required this.onset,
    required this.duration,
    required this.docIndex,
  });

  final int partIndex;
  final XmlElement element;
  final int onset;
  final int duration;
  final int docIndex;

  bool get isRest => element.getElement('rest') != null;
  bool get isChord => element.getElement('chord') != null;
  bool get isGrace => element.getElement('grace') != null;
  bool get isCue => element.getElement('cue') != null;
  String get voice => element.getElement('voice')?.innerText.trim() ?? '1';
  int get staff =>
      int.tryParse(element.getElement('staff')?.innerText.trim() ?? '') ?? 1;
  String? get type => element.getElement('type')?.innerText.trim();
  int get dots => element.findElements('dot').length;

  bool get tieStart => _hasTie(element, 'start');
  bool get tieStop => _hasTie(element, 'stop');

  MusicPitch? get pitch {
    final pitch = element.getElement('pitch');
    if (pitch == null) return null;
    return MusicPitch(
      step: PitchStepMusicXml.parse(pitch.getElement('step')!.innerText),
      alter:
          double.tryParse(
            pitch.getElement('alter')?.innerText.trim() ?? '',
          )?.round() ??
          0,
      octave: int.parse(pitch.getElement('octave')!.innerText.trim()),
    );
  }
}

class _MeasureView {
  _MeasureView({
    required this.partIndex,
    required this.index,
    required this.element,
    required _Context context,
  }) {
    var ctx = context;
    var cursor = 0;
    var previousOnset = 0;
    var docIndex = 0;
    for (final child in element.childElements) {
      switch (child.name.local) {
        case 'attributes':
          // Mid-measure attribute changes are rare; the measure-start state
          // drives accidentals and beaming.
          ctx = ctx.merge(child);
        case 'backup':
          cursor -= _duration(child);
        case 'forward':
          cursor += _duration(child);
        case 'harmony':
          // A chord symbol sounds where it is written plus its <offset>.
          final offset =
              int.tryParse(
                child.getElement('offset')?.innerText.trim() ?? '',
              ) ??
              0;
          _harmonies.add((cursor + offset, child));
        case 'note':
          final isChord = child.getElement('chord') != null;
          final isGrace = child.getElement('grace') != null;
          final duration = isGrace ? 0 : _duration(child);
          final onset = isChord ? previousOnset : cursor;
          notes.add(
            _NoteInfo(
              partIndex: partIndex,
              element: child,
              onset: onset,
              duration: duration,
              docIndex: docIndex++,
            ),
          );
          previousOnset = onset;
          if (!isGrace && !isChord) cursor = onset + duration;
      }
    }
    this.context = ctx;
  }

  final int partIndex;
  final int index;
  final XmlElement element;
  late final _Context context;
  final notes = <_NoteInfo>[];
  final _harmonies = <(int, XmlElement)>[];

  int get divisions => context.divisions;

  /// Bar length from the time signature, in divisions.
  int get capacity => math.max(
    1,
    (context.divisions * context.beats * 4 / context.beatType).round(),
  );

  /// The first `<note>`, `<backup>` or `<forward>` after [element].
  XmlElement? timingAfter(XmlElement element) {
    var after = false;
    for (final child in this.element.childElements) {
      if (identical(child, element)) {
        after = true;
        continue;
      }
      if (after &&
          const {'note', 'backup', 'forward'}.contains(child.name.local)) {
        return child;
      }
    }
    return null;
  }

  int get staves => context.staves;

  _NoteInfo note(int noteIndex) {
    if (noteIndex < 0 || noteIndex >= notes.length) {
      throw const FormatException('음표를 다시 선택하세요.');
    }
    return notes[noteIndex];
  }

  /// The chord group (head first) that contains [note].
  List<_NoteInfo> groupOf(_NoteInfo note) {
    var start = notes.indexOf(note);
    while (start > 0 && notes[start].isChord) {
      start--;
    }
    final group = [notes[start]];
    for (var i = start + 1; i < notes.length && notes[i].isChord; i++) {
      group.add(notes[i]);
    }
    return group;
  }

  /// Timed chord groups of one voice, in document order.
  List<List<_NoteInfo>> voiceGroups(String voice) {
    final groups = <List<_NoteInfo>>[];
    for (final note in notes) {
      if (note.isGrace || note.voice != voice) continue;
      if (note.isChord && groups.isNotEmpty) {
        groups.last.add(note);
      } else {
        groups.add([note]);
      }
    }
    return groups;
  }

  void requireSimpleVoice(List<List<_NoteInfo>> groups) {
    final first = groups.first.first.element;
    final last = groups.last.last.element;
    var inside = false;
    for (final child in element.childElements) {
      if (identical(child, first)) inside = true;
      if (inside &&
          (child.name.local == 'backup' || child.name.local == 'forward')) {
        throw const FormatException('여러 성부가 섞인 마디라 음가를 바꿀 수 없습니다.');
      }
      if (inside &&
          child.name.local == 'note' &&
          child.getElement('grace') == null &&
          (child.getElement('voice')?.innerText.trim() ?? '1') !=
              groups.first.first.voice) {
        throw const FormatException('여러 성부가 섞인 마디라 음가를 바꿀 수 없습니다.');
      }
      if (identical(child, last)) break;
    }
    for (var i = 1; i < groups.length; i++) {
      final previous = groups[i - 1].first;
      if (previous.onset + previous.duration != groups[i].first.onset) {
        throw const FormatException('박이 비어 있는 마디라 음가를 바꿀 수 없습니다.');
      }
    }
  }

  /// Chord symbols sit above the top staff, so any staff's note at the same
  /// onset shares one symbol.
  /// Chord symbols of the bar with the time they sound at.
  List<(int, XmlElement)> get harmonies => List.unmodifiable(_harmonies);

  /// Where [harmony] is written in the bar, without its `<offset>`.
  int? writtenOnsetOf(XmlElement harmony) {
    for (final (onset, element) in _harmonies) {
      if (!identical(element, harmony)) continue;
      final offset =
          int.tryParse(element.getElement('offset')?.innerText.trim() ?? '') ??
          0;
      return onset - offset;
    }
    return null;
  }

  XmlElement? harmonyAt(_NoteInfo head) {
    for (final (onset, harmony) in _harmonies) {
      if (onset == head.onset) return harmony;
    }
    return null;
  }

  (PitchStep, int) middleLine(int staff) {
    final (sign, line) =
        context.clefs[staff] ?? (staff == 1 ? ('G', 2) : ('F', 4));
    return switch ((sign, line)) {
      ('F', 4) => (PitchStep.d, 3),
      ('F', 3) => (PitchStep.f, 3),
      ('C', 3) => (PitchStep.c, 4),
      ('C', 4) => (PitchStep.a, 3),
      _ => (PitchStep.b, 4),
    };
  }

  /// The alter a note written at [step]/[octave] gets without its own
  /// accidental: the last accidental earlier in the bar, else the key.
  int contextAlter(_NoteInfo at, PitchStep step, int octave) {
    int? alter;
    var best = (-1, -1);
    for (final note in notes) {
      if (identical(note, at) || note.staff != at.staff) continue;
      final pitch = note.pitch;
      if (pitch == null || pitch.step != step || pitch.octave != octave) {
        continue;
      }
      if (note.tieStop && note.onset == 0) continue;
      final before =
          note.onset < at.onset ||
          (note.onset == at.onset && note.docIndex < at.docIndex);
      if (!before) continue;
      final key = (note.onset, note.docIndex);
      if (key.$1 > best.$1 || (key.$1 == best.$1 && key.$2 > best.$2)) {
        best = key;
        alter = pitch.alter;
      }
    }
    return alter ?? _keyAlter(step, context.fifths);
  }

  /// Rewrites `<accidental>` for notes of [steps] on [staff] so that each
  /// shows exactly when its alter differs from the bar context.
  void refreshAccidentals(int staff, Set<PitchStep> steps) {
    final ordered =
        notes.where((n) => n.staff == staff && n.pitch != null).toList()..sort(
          (a, b) => a.onset != b.onset
              ? a.onset.compareTo(b.onset)
              : a.docIndex.compareTo(b.docIndex),
        );
    final seen = <(PitchStep, int), int>{};
    for (final note in ordered) {
      final pitch = note.pitch!;
      final key = (pitch.step, pitch.octave);
      final expected = seen[key] ?? _keyAlter(pitch.step, context.fifths);
      final continued = note.tieStop && note.onset == 0;
      if (steps.contains(pitch.step)) {
        final existing = note.element.getElement('accidental');
        final courtesy =
            existing != null &&
            (existing.getAttribute('cautionary') == 'yes' ||
                existing.getAttribute('editorial') == 'yes' ||
                existing.getAttribute('parentheses') == 'yes');
        final needed = !continued && pitch.alter != expected;
        final value = _accidentalName(pitch.alter);
        if (needed) {
          if (existing == null) {
            _insertOrdered(
              note.element,
              XmlElement(XmlName('accidental'), [], [XmlText(value)]),
              _noteOrder,
            );
          } else if (existing.innerText.trim() != value) {
            existing.innerText = value;
          }
        } else if (existing != null &&
            !(courtesy && existing.innerText.trim() == value)) {
          _remove(existing);
        }
      }
      if (!continued) seen[key] = pitch.alter;
    }
  }

  /// Re-derives beams around an edited span of a voice, grouping by beat.
  ///
  /// The span grows to whole beats (half bars in 4/4) and to any existing
  /// beam group it touches, so beams elsewhere in the bar stay as engraved.
  void rebeamRange(String voice, int start, int end) {
    final groups = voiceGroups(voice);
    final beat = _beatLength();
    final unit = context.beats == 4 && context.beatType == 4 ? beat * 2 : beat;
    var from = start ~/ unit * unit;
    var to = math.max(from + 1, (end + unit - 1) ~/ unit * unit);
    final existing = _beamRuns(groups);
    for (var changed = true; changed;) {
      changed = false;
      for (final run in existing) {
        final runStart = run.first.onset;
        final runEnd = run.last.onset + run.last.duration;
        if (runStart >= to || runEnd <= from) continue;
        if (runStart < from) {
          from = runStart;
          changed = true;
        }
        if (runEnd > to) {
          to = runEnd;
          changed = true;
        }
      }
    }
    final inside = groups
        .where((g) => g.first.onset >= from && g.first.onset < to)
        .toList();
    for (final group in inside) {
      for (final note in group) {
        note.element.findElements('beam').toList().forEach(_remove);
      }
    }
    final runs = <List<_NoteInfo>>[];
    List<_NoteInfo>? run;
    for (final group in inside) {
      final head = group.first;
      final window = head.onset ~/ beat;
      final fits = (head.onset + head.duration - 1) ~/ beat == window;
      if (head.isRest || _flags(head) == 0 || !fits) {
        run = null;
        continue;
      }
      if (run == null || run.first.onset ~/ beat != window) {
        run = [head];
        runs.add(run);
      } else {
        run.add(head);
      }
    }
    // 4/4: two beats of plain eighths beam as one group of four.
    final merged = <List<_NoteInfo>>[];
    for (final current in runs) {
      final previous = merged.isEmpty ? null : merged.last;
      if (previous != null &&
          unit == beat * 2 &&
          _plainEighthBeat(previous, beat) &&
          _plainEighthBeat(current, beat) &&
          previous.first.onset ~/ beat % 2 == 0 &&
          current.first.onset ~/ beat == previous.first.onset ~/ beat + 1) {
        merged[merged.length - 1] = [...previous, ...current];
      } else {
        merged.add(current);
      }
    }
    merged.forEach(_writeBeams);
  }

  /// Existing level-1 beam groups of a voice, as chord heads.
  List<List<_NoteInfo>> _beamRuns(List<List<_NoteInfo>> groups) {
    final runs = <List<_NoteInfo>>[];
    List<_NoteInfo>? open;
    for (final group in groups) {
      final head = group.first;
      final beam = head.element
          .findElements('beam')
          .where((b) => (b.getAttribute('number') ?? '1') == '1')
          .map((b) => b.innerText.trim())
          .firstOrNull;
      if (beam == 'begin') {
        open = [head];
        runs.add(open);
      } else if ((beam == 'continue' || beam == 'end') && open != null) {
        open.add(head);
        if (beam == 'end') open = null;
      } else {
        open = null;
      }
    }
    return runs;
  }

  /// Rewrites beam groups an edit left without a beginning or an end (a rest
  /// or a longer note now stands inside the old group). Whole groups stay as
  /// engraved.
  void fixOrphanBeams(String voice) {
    List<_NoteInfo>? run;
    var broken = false;
    void close({required bool ended}) {
      final notes = run;
      if (notes != null && (broken || !ended)) {
        for (final note in notes) {
          for (final member in groupOf(note)) {
            member.element.findElements('beam').toList().forEach(_remove);
          }
        }
        _writeBeams(notes);
      }
      run = null;
      broken = false;
    }

    for (final group in voiceGroups(voice)) {
      final head = group.first;
      final beam = head.element
          .findElements('beam')
          .where((b) => (b.getAttribute('number') ?? '1') == '1')
          .map((b) => b.innerText.trim())
          .firstOrNull;
      final beamable = !head.isRest && _flags(head) > 0;
      if (!beamable ||
          !(beam == 'begin' || beam == 'continue' || beam == 'end')) {
        close(ended: false);
        if (!beamable) {
          for (final member in group) {
            member.element.findElements('beam').toList().forEach(_remove);
          }
        }
        continue;
      }
      if (beam == 'begin') {
        close(ended: false);
        run = [head];
      } else if (run == null) {
        run = [head];
        broken = true;
      } else {
        run!.add(head);
      }
      if (beam == 'end') close(ended: true);
    }
    close(ended: false);
  }

  /// Keeps existing beam groups but splits them around rests and notes that
  /// no longer carry a flag.
  void repairBeams(String voice) {
    final groups = voiceGroups(voice);
    final runs = _beamRuns(groups);
    for (final group in groups) {
      for (final note in group) {
        note.element.findElements('beam').toList().forEach(_remove);
      }
    }
    for (final run in runs) {
      var segment = <_NoteInfo>[];
      for (final note in run) {
        if (note.isRest || _flags(note) == 0) {
          _writeBeams(segment);
          segment = [];
        } else {
          segment.add(note);
        }
      }
      _writeBeams(segment);
    }
  }

  bool _plainEighthBeat(List<_NoteInfo> run, int beat) =>
      run.length == 2 &&
      run.every((n) => _flags(n) == 1 && n.dots == 0) &&
      run.first.onset % beat == 0;

  /// Beam and rest grouping unit: a dotted quarter in compound meters, a
  /// half in cut time, otherwise a quarter.
  int _beatLength() {
    final divisions = context.divisions;
    if (context.beatType == 8 && context.beats % 3 == 0) {
      return math.max(1, divisions * 3 ~/ 2);
    }
    if (context.beatType <= 2) return divisions * 2;
    return divisions;
  }

  void _writeBeams(List<_NoteInfo> run) {
    if (run.length < 2) return;
    final flags = run.map(_flags).toList();
    final levels = flags.reduce(math.max);
    for (var i = 0; i < run.length; i++) {
      for (var level = 1; level <= levels; level++) {
        if (flags[i] < level) continue;
        final String value;
        if (level == 1) {
          value = i == 0
              ? 'begin'
              : i == run.length - 1
              ? 'end'
              : 'continue';
        } else {
          final previous = i > 0 && flags[i - 1] >= level;
          final next = i < run.length - 1 && flags[i + 1] >= level;
          value = previous && next
              ? 'continue'
              : previous
              ? 'end'
              : next
              ? 'begin'
              : i == 0
              ? 'forward hook'
              : 'backward hook';
        }
        _insertOrdered(
          run[i].element,
          XmlElement(
            XmlName('beam'),
            [XmlAttribute(XmlName('number'), '$level')],
            [XmlText(value)],
          ),
          _noteOrder,
          afterSameName: true,
        );
      }
    }
  }
}

// --- Helpers --------------------------------------------------------------

const _typeQuarters = <String, double>{
  'whole': 4,
  'half': 2,
  'quarter': 1,
  'eighth': 0.5,
  '16th': 0.25,
  '32nd': 0.125,
  '64th': 0.0625,
};

int _flags(_NoteInfo note) => switch (note.type) {
  'eighth' => 1,
  '16th' => 2,
  '32nd' => 3,
  '64th' => 4,
  _ => 0,
};

const _harmonyOrder = [
  'root',
  'function',
  'numeral',
  'kind',
  'inversion',
  'bass',
  'degree',
  'frame',
  'offset',
  'footnote',
  'level',
  'staff',
];

const _noteOrder = [
  'grace',
  'cue',
  'chord',
  'pitch',
  'unpitched',
  'rest',
  'duration',
  'tie',
  'instrument',
  'footnote',
  'level',
  'voice',
  'type',
  'dot',
  'accidental',
  'time-modification',
  'stem',
  'notehead',
  'notehead-text',
  'staff',
  'beam',
  'notations',
  'lyric',
  'play',
  'listen',
];

const _attributesOrder = [
  'footnote',
  'level',
  'divisions',
  'key',
  'time',
  'staves',
  'part-symbol',
  'instruments',
  'clef',
  'staff-details',
  'transpose',
  'for-part',
  'directive',
  'measure-style',
];

int _duration(XmlElement element) =>
    int.tryParse(element.getElement('duration')?.innerText.trim() ?? '') ?? 0;

bool _hasTie(XmlElement note, String type) {
  if (note.findElements('tie').any((t) => t.getAttribute('type') == type)) {
    return true;
  }
  return note
      .findElements('notations')
      .expand((n) => n.findElements('tied'))
      .any((t) => t.getAttribute('type') == type);
}

void _removeTieMarks(XmlElement note, String type) {
  note
      .findElements('tie')
      .where((t) => t.getAttribute('type') == type)
      .toList()
      .forEach(_remove);
  for (final notations in note.findElements('notations').toList()) {
    notations
        .findElements('tied')
        .where((t) => t.getAttribute('type') == type)
        .toList()
        .forEach(_remove);
    if (notations.childElements.isEmpty) _remove(notations);
  }
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

XmlElement _pitchElement(MusicPitch pitch) {
  return XmlElement(XmlName('pitch'), [], [
    XmlElement(XmlName('step'), [], [XmlText(pitch.step.musicXmlName)]),
    if (pitch.alter != 0)
      XmlElement(XmlName('alter'), [], [XmlText('${pitch.alter}')]),
    XmlElement(XmlName('octave'), [], [XmlText('${pitch.octave}')]),
  ]);
}

XmlElement _restElement({
  required int duration,
  required String type,
  required int dots,
  String? voice,
  String? staff,
}) {
  return XmlElement(XmlName('note'), [], [
    XmlElement(XmlName('rest')),
    XmlElement(XmlName('duration'), [], [XmlText('$duration')]),
    if (voice != null) XmlElement(XmlName('voice'), [], [XmlText(voice)]),
    XmlElement(XmlName('type'), [], [XmlText(type)]),
    for (var i = 0; i < dots; i++) XmlElement(XmlName('dot')),
    if (staff != null) XmlElement(XmlName('staff'), [], [XmlText(staff)]),
  ]);
}

class _Spelled {
  const _Spelled(this.type, this.dots, this.duration);

  final String type;
  final int dots;
  final int duration;
}

_Spelled? _spellSingle(int duration, int divisions) {
  for (final entry in _typeQuarters.entries) {
    for (var dots = 0; dots <= 1; dots++) {
      final value = divisions * entry.value * (2 - 1 / math.pow(2, dots));
      if (value == duration) return _Spelled(entry.key, dots, duration);
    }
  }
  return null;
}

/// Splits a gap into rests that do not cross beat boundaries needlessly.
List<_Spelled> _spellGap(int start, int length, _MeasureView measure) {
  final divisions = measure.divisions;
  final beat = measure._beatLength();
  final result = <_Spelled>[];
  var position = start;
  var remaining = length;
  while (remaining > 0) {
    // Off the beat, fill up to the next beat. On the beat, grow the rest only
    // while it stays aligned (a half rest starts on beat 1 or 3 in 4/4).
    var limit = beat - position % beat;
    if (position % beat == 0) {
      var span = beat;
      while (position % (span * 2) == 0 && span * 2 <= remaining) {
        span *= 2;
      }
      limit = span;
    }
    limit = math.min(limit, remaining);
    _Spelled? chosen;
    for (final entry in _typeQuarters.entries) {
      final value = divisions * entry.value;
      if (value != value.roundToDouble() || value <= 0) continue;
      if (value <= limit) {
        chosen = _Spelled(entry.key, 0, value.round());
        break;
      }
    }
    if (chosen == null) {
      throw const FormatException('남는 박을 쉼표로 채울 수 없습니다.');
    }
    result.add(chosen);
    position += chosen.duration;
    remaining -= chosen.duration;
  }
  return result;
}

void _remove(XmlNode node) => node.parent?.children.remove(node);

/// The longest syllable [XmlMeasureEditor.setLyric] takes.
const maxLyricLength = 40;

/// The lyric of [verse] on [note]. A lyric without a number is of the first
/// verse.
XmlElement? _lyricOf(XmlElement note, int verse) {
  for (final lyric in note.findElements('lyric')) {
    final number = int.tryParse(lyric.getAttribute('number') ?? '') ?? 1;
    if (number == verse) return lyric;
  }
  return null;
}

Iterable<XmlElement> _textDirections(XmlElement measure) => measure
    .findElements('direction')
    .where((direction) => _directionText(direction).isNotEmpty);

String _directionText(XmlElement direction) => direction
    .findElements('direction-type')
    .expand((type) => type.findElements('words'))
    .map((words) => words.innerText.trim())
    .where((text) => text.isNotEmpty)
    .join(' ');

void _setChild(
  XmlElement parent,
  String name,
  String text,
  List<String> order,
) {
  final existing = parent.getElement(name);
  if (existing != null) {
    existing.innerText = text;
    return;
  }
  _insertOrdered(parent, XmlElement(XmlName(name), [], [XmlText(text)]), order);
}

void _insertOrdered(
  XmlElement parent,
  XmlElement child,
  List<String> order, {
  bool afterSameName = true,
}) {
  final rank = order.indexOf(child.name.local);
  final children = parent.children;
  var insertAt = children.length;
  for (var i = 0; i < children.length; i++) {
    final node = children[i];
    if (node is! XmlElement) continue;
    final other = order.indexOf(node.name.local);
    if (other > rank || (!afterSameName && other == rank)) {
      insertAt = i;
      break;
    }
  }
  children.insert(insertAt, child);
}

// --- Melody suggestions -------------------------------------------------------

/// One note or rest of a suggested melody.
typedef MelodyToken = ({MusicPitch? pitch, String type, int dots});

/// "G4 q, A4 8, B4 8., rest 16" as tokens; throws a [FormatException] with a
/// readable message for anything else.
List<MelodyToken> parseMelodyTokens(String melody) {
  const types = {
    'w': 'whole',
    'h': 'half',
    'q': 'quarter',
    '8': 'eighth',
    '16': '16th',
    '32': '32nd',
  };
  final tokens = <MelodyToken>[];
  for (final raw in melody.split(RegExp(r'[,;]'))) {
    final text = raw.trim();
    if (text.isEmpty) continue;
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length != 2) {
      throw FormatException('멜로디 표기를 읽을 수 없습니다: $text');
    }
    final length = RegExp(r'^(w|h|q|8|16|32)(\.*)$').firstMatch(parts[1]);
    if (length == null) {
      throw FormatException('음가를 읽을 수 없습니다: ${parts[1]}');
    }
    final dots = length.group(2)!.length;
    if (dots > 2) throw FormatException('음가를 읽을 수 없습니다: ${parts[1]}');
    final MusicPitch? pitch;
    if (parts[0].toLowerCase() == 'rest' || parts[0] == 'r') {
      pitch = null;
    } else {
      pitch = parseSpelledPitch(parts[0]);
      if (pitch == null) {
        throw FormatException('음높이를 읽을 수 없습니다: ${parts[0]}');
      }
    }
    tokens.add((pitch: pitch, type: types[length.group(1)]!, dots: dots));
  }
  return tokens;
}

/// "F#4", "Bb3", "C5" as a pitch; null when it is not one.
MusicPitch? parseSpelledPitch(String text) {
  final match = RegExp(
    r'^([A-Ga-g])(#|♯|b|♭|x|bb)?(-?\d)$',
  ).firstMatch(text.trim());
  if (match == null) return null;
  final step = PitchStep.values.byName(match.group(1)!.toLowerCase());
  final alter = switch (match.group(2)) {
    '#' || '♯' => 1,
    'b' || '♭' => -1,
    'x' => 2,
    'bb' => -2,
    _ => 0,
  };
  return MusicPitch(
    step: step,
    octave: int.parse(match.group(3)!),
    alter: alter,
  );
}

// --- Whole bars -------------------------------------------------------------

const _originsField = 'page-a-diddle:bar-origins';

/// For each bar of [xml], the index it had before bars were added or removed
/// (-1 for an added bar), or null when the score still has its first bars.
/// Whatever was recorded against the bars as first read (a conversion's
/// suspect measures) finds its bar by this.
List<int>? barOrigins(String xml) {
  final _ScoreDoc doc;
  try {
    doc = _ScoreDoc(xml);
  } on FormatException {
    return null;
  }
  // Only read; a long score is read once for everything asked of it.
  doc.keep(xml);
  final document = doc.document;
  final origins = _originsOf(document);
  final bars = document.rootElement
      .findElements('part')
      .firstOrNull
      ?.findElements('measure')
      .length;
  // A record that does not fit the bars (the score was rebuilt by something
  // that does not keep it) says nothing.
  return origins == null || origins.length != bars ? null : origins;
}

List<int>? _originsOf(XmlDocument document) {
  // The record is in the score's identification, not among its notes.
  final root = document.rootElement;
  for (final field
      in (root.getElement('identification') ?? root).findAllElements(
        'miscellaneous-field',
      )) {
    if (field.getAttribute('name') != _originsField) continue;
    final values = [
      for (final value in field.innerText.split(','))
        int.tryParse(value.trim()),
    ];
    return values.contains(null) ? null : values.cast<int>();
  }
  return null;
}

List<int> _readOrigins(_ScoreDoc doc, int partIndex) {
  final count = doc.measureCount(partIndex);
  final stored = _originsOf(doc.document);
  return stored != null && stored.length == count
      ? stored
      : [for (var i = 0; i < count; i++) i];
}

void _writeOrigins(_ScoreDoc doc, List<int> origins) {
  final root = doc.document.rootElement;
  var identification = root.getElement('identification');
  if (identification == null) {
    identification = XmlElement(XmlName('identification'));
    // The schema wants it before defaults, credits and the part list.
    final at = root.children.indexWhere(
      (node) =>
          node is XmlElement &&
          ['defaults', 'credit', 'part-list'].contains(node.name.local),
    );
    root.children.insert(at < 0 ? 0 : at, identification);
  }
  var miscellaneous = identification.getElement('miscellaneous');
  if (miscellaneous == null) {
    miscellaneous = XmlElement(XmlName('miscellaneous'));
    identification.children.add(miscellaneous);
  }
  miscellaneous
      .findElements('miscellaneous-field')
      .where((field) => field.getAttribute('name') == _originsField)
      .toList()
      .forEach(_remove);
  miscellaneous.children.add(
    XmlElement(
      XmlName('miscellaneous-field'),
      [XmlAttribute(XmlName('name'), _originsField)],
      [XmlText(origins.join(','))],
    ),
  );
}

/// A bar holding only a whole-bar rest on every staff, in [context].
XmlElement _emptyMeasure(_Context context, {required String number}) {
  XmlElement leaf(String name, String value) =>
      XmlElement(XmlName(name), [], [XmlText(value)]);
  final length = context.divisions * 4 * context.beats ~/ context.beatType;
  final staves = context.staves < 1 ? 1 : context.staves;
  return XmlElement(
    XmlName('measure'),
    [XmlAttribute(XmlName('number'), number)],
    [
      for (var staff = 1; staff <= staves; staff++) ...[
        if (staff > 1)
          XmlElement(XmlName('backup'), [], [leaf('duration', '$length')]),
        XmlElement(XmlName('note'), [], [
          XmlElement(XmlName('rest'), [
            XmlAttribute(XmlName('measure'), 'yes'),
          ]),
          leaf('duration', '$length'),
          // Voices 1-4 belong to the first staff, 5-8 to the second.
          leaf('voice', '${(staff - 1) * 4 + 1}'),
          if (staves > 1) leaf('staff', '$staff'),
        ]),
      ],
    ],
  );
}

/// A context no bar is in: against it, every clef, key and time is new.
const _unstated = _Context(
  divisions: -1,
  fifths: 99,
  beats: -1,
  beatType: -1,
  staves: -1,
);

/// The clef, key and time [measure] begins in: [before] with what the bar
/// states ahead of its first note.
_Context _beginning(XmlElement measure, _Context before) {
  var context = before;
  for (final child in measure.childElements) {
    if (child.name.local == 'note') break;
    if (child.name.local == 'attributes') context = context.merge(child);
  }
  return context;
}

/// The clef, key and time in force after [measure], entered in [before].
_Context _ending(XmlElement measure, _Context before) {
  var context = before;
  for (final attributes in measure.findElements('attributes')) {
    context = context.merge(attributes);
  }
  return context;
}

/// Makes [measure] begin in [begins] when it follows a bar ending in
/// [given]: it states what differs from [given], and no longer what [given]
/// already has. What the bar itself wrote (a common-time sign, a transposing
/// clef) is kept where it still says something.
void _restate(XmlElement measure, _Context begins, _Context given) {
  final own = [
    for (final child in measure.childElements.takeWhile(
      (child) => child.name.local != 'note',
    ))
      if (child.name.local == 'attributes') child,
  ];
  final opening = begins.toAttributes();
  opening.findElements('staves').toList().forEach(_remove);
  if (begins.staves > 1 &&
      given.staves != begins.staves &&
      own.every((attributes) => attributes.getElement('staves') == null)) {
    // The number of staves stands before the clefs.
    final clef = opening.findElements('clef').firstOrNull;
    opening.children.insert(
      clef == null ? opening.children.length : opening.children.indexOf(clef),
      XmlElement(XmlName('staves'), [], [XmlText('${begins.staves}')]),
    );
  }
  final at = measure.children.indexWhere(
    (node) => node is XmlElement && node.name.local != 'print',
  );
  // Ahead of the bar's own: where both say the same thing, the bar's stays.
  measure.children.insert(at < 0 ? measure.children.length : at, opening);
  _dropRestated(measure, given);
}

/// Takes the barlines and line breaks off [measure], in document order.
({List<XmlElement> prints, List<XmlElement> left, List<XmlElement> right})
_takePlaceSigns(XmlElement measure) {
  final prints = measure.findElements('print').toList();
  final barlines = measure.findElements('barline').toList();
  [...prints, ...barlines].forEach(_remove);
  return (
    prints: prints,
    left: [
      for (final barline in barlines)
        if (!_isRightBarline(barline)) barline,
    ],
    right: barlines.where(_isRightBarline).toList(),
  );
}

void _putPlaceSigns(
  XmlElement measure,
  ({List<XmlElement> prints, List<XmlElement> left, List<XmlElement> right})
  signs,
) {
  measure.children.insertAll(0, [...signs.prints, ...signs.left]);
  measure.children.addAll(signs.right);
}

bool _isRightBarline(XmlElement barline) =>
    (barline.getAttribute('location') ?? 'right') == 'right';

/// Moves the barline on one side of [from] to that side of [to], unless
/// [to] has its own.
void _moveBarline({
  required XmlElement from,
  required XmlElement to,
  required bool right,
}) {
  bool onSide(XmlElement barline) => right
      ? _isRightBarline(barline)
      : barline.getAttribute('location') == 'left';
  final moving = from.findElements('barline').where(onSide).toList();
  if (moving.isEmpty) return;
  moving.forEach(_remove);
  if (to.findElements('barline').any(onSide)) return;
  if (right) {
    to.children.addAll(moving);
  } else {
    final at = to.children.indexWhere(
      (node) =>
          node is XmlElement &&
          node.name.local != 'print' &&
          node.name.local != 'attributes',
    );
    to.children.insertAll(at < 0 ? to.children.length : at, moving);
  }
}

/// Removes from a copied bar what marks its place in the score.
///
/// The bar it is copied from was entered in [startsIn] (clef, key, time) and
/// the copy comes after it, in [follows]. They differ when the bar changes
/// clef, key or time on its way: the copy then says how it starts, and keeps
/// the change, so it reads like the bar it was copied from.
void _stripPlaceSigns(
  XmlElement measure, {
  required _Context startsIn,
  required _Context follows,
}) {
  for (final name in ['print', 'barline']) {
    measure.findElements(name).toList().forEach(_remove);
  }
  var start = startsIn;
  var seenNote = false;
  var changesOnTheWay = false;
  for (final child in measure.childElements.toList()) {
    if (child.name.local == 'note') seenNote = true;
    if (child.name.local != 'attributes') continue;
    if (seenNote) {
      changesOnTheWay = true;
    } else {
      // What the bar opens with is in force after it too, unless it changes
      // again later in the bar.
      start = start.merge(child);
      _remove(child);
    }
  }
  if (changesOnTheWay) {
    final opening = start.toAttributes();
    opening.findElements('staves').toList().forEach(_remove);
    measure.children.insert(0, opening);
    _dropRestated(measure, follows);
  }
  // A slur into or out of the bar belongs to the bars around the original.
  for (final slur in _openSlurs(measure)) {
    _removeNotation(slur);
  }
  const placed = ['rehearsal', 'segno', 'coda'];
  for (final direction in measure.findElements('direction').toList()) {
    for (final type in direction.findElements('direction-type').toList()) {
      if (type.childElements.any((e) => placed.contains(e.name.local))) {
        _remove(type);
      }
    }
    if (direction.findElements('direction-type').isEmpty) _remove(direction);
  }
  bool jumps(XmlElement sound) => sound.attributes.any(
    (a) => [..._jumpSounds, 'segno', 'coda'].contains(a.name.local),
  );
  for (final sound in measure.findAllElements('sound').toList()) {
    if (jumps(sound)) _remove(sound);
  }
  for (final element in measure.descendantElements) {
    element.removeAttribute('id');
    element.removeAttribute('xml:id');
  }
}

/// Whether a measure child sets the playing tempo: a `<sound tempo>`, or a
/// direction with one or with a metronome mark.
bool _setsTempo(XmlElement child) => switch (child.name.local) {
  'sound' => child.getAttribute('tempo') != null,
  'direction' =>
    child.findAllElements('metronome').isNotEmpty ||
        child.findElements('sound').any((s) => s.getAttribute('tempo') != null),
  _ => false,
};

bool _within(XmlElement element, XmlElement measure) =>
    element.ancestorElements.any((ancestor) => identical(ancestor, measure));

/// Removes a `<notations>` child, and the `<notations>` left empty by it.
void _removeNotation(XmlElement mark) {
  final notations = mark.parentElement;
  _remove(mark);
  if (notations != null && notations.childElements.isEmpty) _remove(notations);
}

/// The slurs of [part] as (start, stop) elements, matched by their number
/// in the order they are written.
List<(XmlElement, XmlElement)> _slurPairs(XmlElement part) {
  final open = <String, XmlElement>{};
  final pairs = <(XmlElement, XmlElement)>[];
  for (final slur in part.findAllElements('slur')) {
    final number = slur.getAttribute('number') ?? '1';
    switch (slur.getAttribute('type')) {
      case 'start':
        open[number] = slur;
      case 'stop':
        if (open.remove(number) case final start?) pairs.add((start, slur));
    }
  }
  return pairs;
}

/// Gives the slurs of [measure] that use a number in [taken] another one.
void _renumberSlurs(XmlElement measure, Set<String> taken) {
  if (taken.isEmpty) return;
  final slurs = measure.findAllElements('slur').toList();
  final used = {
    ...taken,
    for (final slur in slurs) slur.getAttribute('number') ?? '1',
  };
  final renamed = <String, String>{};
  for (final slur in slurs) {
    final number = slur.getAttribute('number') ?? '1';
    if (!taken.contains(number)) continue;
    final other = renamed.putIfAbsent(number, () {
      // MusicXML numbers concurrent slurs from 1; 16 is its upper bound.
      for (var n = 1; n <= 16; n++) {
        if (used.add('$n')) return '$n';
      }
      return number;
    });
    slur.setAttribute('number', other);
  }
}

/// The slur ends of [measure] whose other end is not in it.
List<XmlElement> _openSlurs(XmlElement measure) {
  final open = <String, XmlElement>{};
  final loose = <XmlElement>[];
  for (final slur in measure.findAllElements('slur')) {
    final number = slur.getAttribute('number') ?? '1';
    switch (slur.getAttribute('type')) {
      case 'start':
        if (open[number] case final earlier?) loose.add(earlier);
        open[number] = slur;
      case 'stop':
        if (open.remove(number) == null) loose.add(slur);
      default:
        loose.add(slur);
    }
  }
  return [...loose, ...open.values];
}

String _pitchKey(XmlElement note) {
  final pitch = note.getElement('pitch');
  if (pitch == null) return '';
  String text(String name) => pitch.getElement(name)?.innerText.trim() ?? '';
  return '${text('step')}${text('alter')}/${text('octave')}';
}

/// The notes of [measure] whose tie leaves the bar ([type] `start`) or comes
/// into it (`stop`), by pitch.
Map<String, List<XmlElement>> _openTies(XmlElement measure, String type) {
  final notes = measure.findElements('note').toList();
  final open = <String, List<XmlElement>>{};
  for (var i = 0; i < notes.length; i++) {
    final note = notes[i];
    if (!_hasTie(note, type)) continue;
    final key = _pitchKey(note);
    // A tie within the bar has its other end on the same pitch, later (for
    // a start) or earlier (for a stop).
    final others = type == 'start' ? notes.skip(i + 1) : notes.take(i);
    final closing = type == 'start' ? 'stop' : 'start';
    final voice = note.getElement('voice')?.innerText.trim();
    // The other end of a tie inside the bar is in the same voice: the same
    // pitch in another voice is another note.
    if (others.any(
      (n) =>
          _pitchKey(n) == key &&
          n.getElement('voice')?.innerText.trim() == voice &&
          _hasTie(n, closing),
    )) {
      continue;
    }
    open.putIfAbsent(key, () => []).add(note);
  }
  return open;
}

/// After bars were put next to each other: a tie out of [left] needs the
/// same pitch tied in at [right], and the other way round. Ties without
/// their other end are removed.
///
/// A note that is no longer tied into is added to [freed]: it was written
/// without its accidental, which the tie carried over the barline.
void _mendTies(XmlElement left, XmlElement right, List<XmlElement> freed) {
  final leaving = _openTies(left, 'start');
  final arriving = _openTies(right, 'stop');
  for (final MapEntry(:key, value: notes) in leaving.entries) {
    if (!arriving.containsKey(key)) {
      for (final note in notes) {
        _removeTieMarks(note, 'start');
      }
    }
  }
  for (final MapEntry(:key, value: notes) in arriving.entries) {
    if (!leaving.containsKey(key)) {
      for (final note in notes) {
        _removeTieMarks(note, 'stop');
        freed.add(note);
      }
    }
  }
}

/// Writes the accidentals of notes a bar edit freed from a tie.
void _spellFreed(_ScoreDoc doc, int partIndex, List<XmlElement> freed) {
  if (freed.isEmpty) return;
  final measures = doc._measures(partIndex);
  for (final note in freed) {
    final index = measures.indexWhere((m) => identical(m, note.parentElement));
    if (index < 0) continue;
    final view = doc.measureAt(partIndex, index);
    final info = view.notes
        .where((info) => identical(info.element, note))
        .firstOrNull;
    final pitch = info?.pitch;
    if (info == null || pitch == null) continue;
    view.refreshAccidentals(info.staff, {pitch.step});
  }
}

/// Removes the ties of [measure] that leave (`start`) or enter (`stop`) it.
void _dropTies(XmlElement measure, String type, List<XmlElement> freed) {
  for (final notes in _openTies(measure, type).values) {
    for (final note in notes) {
      _removeTieMarks(note, type);
      if (type == 'stop') freed.add(note);
    }
  }
}

/// The number of the first bar when every part numbers its bars in order
/// from it (1, 2, 3…, from 0 with a pickup, or from 17 in an excerpt), so
/// the numbers can be written again after bars were added or removed; null
/// when they are not in order.
int? _firstNumberInOrder(_ScoreDoc doc) {
  int? first;
  for (final part in doc.parts) {
    final numbers = [
      for (final measure in part.findElements('measure'))
        int.tryParse(measure.getAttribute('number') ?? ''),
    ];
    if (numbers.isEmpty || numbers.first == null) return null;
    for (var i = 0; i < numbers.length; i++) {
      if (numbers[i] != numbers.first! + i) return null;
    }
    first ??= numbers.first;
  }
  return first;
}

/// Numbers the bars of every part from [start] on.
void _renumber(_ScoreDoc doc, int start) {
  for (final part in doc.parts) {
    final measures = part.findElements('measure').toList();
    for (var i = 0; i < measures.length; i++) {
      measures[i].setAttribute('number', '${start + i}');
    }
  }
}
