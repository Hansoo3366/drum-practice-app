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
  final root = doc.document.rootElement;
  final parts = root.findElements('part').toList();
  final measures = doc._measures(partIndex);
  if (measureIndex < 0 || measureIndex >= measures.length) {
    throw const FormatException('마디를 찾을 수 없습니다.');
  }
  final part = parts[partIndex];
  final target = measures[measureIndex];
  final carried = [
    for (final measure in measures.take(measureIndex))
      for (final attributes in measure.findElements('attributes'))
        attributes.copy(),
  ];
  target.children.insertAll(0, carried);
  target.children.removeWhere(
    (node) => node is XmlElement && node.name.local == 'print',
  );
  part.children.removeWhere(
    (node) =>
        node is XmlElement &&
        node.name.local == 'measure' &&
        !identical(node, target),
  );
  root.children.removeWhere(
    (node) =>
        node is XmlElement &&
        ((node.name.local == 'part' && !identical(node, part)) ||
            node.name.local == 'credit' ||
            node.name.local == 'defaults'),
  );
  root
      .getElement('part-list')
      ?.children
      .removeWhere(
        (node) =>
            node is XmlElement &&
            (node.name.local == 'part-group' ||
                (node.name.local == 'score-part' &&
                    node.getAttribute('id') != part.getAttribute('id'))),
      );
  return doc.toXml();
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

String expandMusicXml(String xml, List<int> measureMap) {
  if (measureMap.isEmpty) {
    throw const FormatException('연주할 마디가 없습니다.');
  }
  final doc = _ScoreDoc(xml);
  final parts = doc.document.rootElement.findElements('part').toList();
  for (var partIndex = 0; partIndex < parts.length; partIndex++) {
    final part = parts[partIndex];
    final measures = doc._measures(partIndex);
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
      if (position > 0 && (lineStart || jumped)) {
        copy.children.insert(
          0,
          XmlElement(XmlName('print'), [
            XmlAttribute(XmlName('new-system'), 'yes'),
          ]),
        );
      }
      // Context where playing arrives, and the one the bar starts with.
      final arriving = previous == null
          ? null
          : doc._contextBefore(measures, previous + 1);
      final starting = doc._contextBefore(measures, source + 1);
      if (jumped && (arriving == null || !starting.sameAs(arriving))) {
        // A jump into another key or time restates the whole context.
        copy.findElements('attributes').toList().forEach(_remove);
        copy.children.insert(
          copy.children.indexWhere(
                (n) => n is XmlElement && n.name.local == 'print',
              ) +
              1,
          starting.toAttributes(),
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
  }
  return doc.toXml();
}

int measureCountOf(String xml, int partIndex) =>
    _ScoreDoc(xml).measureCount(partIndex);

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
    final doc = _ScoreDoc(xml);
    final measure = doc.measure(ref);
    final info = measure.note(ref.noteIndex);
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
  _ScoreDoc(String xml) : document = _parse(xml) {
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

  final XmlDocument document;

  String toXml() => document.toXmlString();

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
