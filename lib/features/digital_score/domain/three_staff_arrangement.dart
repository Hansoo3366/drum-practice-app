import 'dart:convert';
import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:xml/xml.dart';

/// Why a score cannot be made into a melody + piano score.
enum ThreeStaffObstacle { noMeasures, severalParts, severalStaves, noChords }

/// What [threeStaffMusicXml] needs to know about a score: whether it is a
/// single melody line with chord symbols.
class LeadSheetAnalysis {
  const LeadSheetAnalysis({
    required this.partCount,
    required this.staves,
    required this.measureCount,
    required this.chordCount,
    required this.measuresWithChord,
    required this.keyFifths,
    required this.beats,
    required this.beatType,
    this.lowestMidi,
    this.highestMidi,
  });

  final int partCount;
  final int staves;
  final int measureCount;

  /// Chord symbols that name a chord (not "N.C.").
  final int chordCount;

  /// Bars in which a chord sounds, written there or held from before.
  final int measuresWithChord;

  /// Key and time at the start.
  final int keyFifths;
  final int beats;
  final int beatType;

  /// Range of the melody, or null without notes.
  final int? lowestMidi;
  final int? highestMidi;

  ThreeStaffObstacle? get obstacle {
    if (measureCount == 0) return ThreeStaffObstacle.noMeasures;
    if (partCount > 1) return ThreeStaffObstacle.severalParts;
    if (staves > 1) return ThreeStaffObstacle.severalStaves;
    if (chordCount == 0) return ThreeStaffObstacle.noChords;
    return null;
  }

  bool get convertible => obstacle == null;
}

/// How the right hand plays a chord.
enum AccompanimentPattern {
  /// Struck once and held until the next chord.
  held,

  /// Struck again on every beat.
  beats,

  /// One chord tone after the other, in eighths.
  broken,
}

/// Where the right hand lies.
enum AccompanimentRegister {
  /// Around middle C to the C above.
  middle,

  /// About a fourth lower, more often under the melody.
  low,
}

class AccompanimentStyle {
  const AccompanimentStyle({
    this.pattern = AccompanimentPattern.held,
    this.register = AccompanimentRegister.middle,
  });

  final AccompanimentPattern pattern;
  final AccompanimentRegister register;

  AccompanimentStyle copyWith({
    AccompanimentPattern? pattern,
    AccompanimentRegister? register,
  }) => AccompanimentStyle(
    pattern: pattern ?? this.pattern,
    register: register ?? this.register,
  );

  @override
  bool operator ==(Object other) =>
      other is AccompanimentStyle &&
      other.pattern == pattern &&
      other.register == register;

  @override
  int get hashCode => Object.hash(pattern, register);
}

/// The style of the piano part: [base] for the whole score, and another
/// style from the first bar of each entry of [sections] to the next entry.
class AccompanimentPlan {
  const AccompanimentPlan({
    this.base = const AccompanimentStyle(),
    this.sections = const {},
  });

  final AccompanimentStyle base;

  /// Style by the index of the first bar it applies to.
  final Map<int, AccompanimentStyle> sections;

  AccompanimentStyle styleAt(int measureIndex) {
    int? start;
    for (final index in sections.keys) {
      if (index <= measureIndex && (start == null || index > start)) {
        start = index;
      }
    }
    return start == null ? base : sections[start]!;
  }
}

LeadSheetAnalysis analyzeLeadSheet(String xml) {
  final document = XmlDocument.parse(xml);
  final parts = document.rootElement.findElements('part').toList();
  if (parts.isEmpty) {
    return const LeadSheetAnalysis(
      partCount: 0,
      staves: 1,
      measureCount: 0,
      chordCount: 0,
      measuresWithChord: 0,
      keyFifths: 0,
      beats: 4,
      beatType: 4,
    );
  }
  final part = parts.first;
  var staves = 1;
  for (final element in part.findAllElements('staves')) {
    staves = math.max(staves, int.tryParse(element.innerText.trim()) ?? 1);
  }
  for (final element in part.findAllElements('staff')) {
    staves = math.max(staves, int.tryParse(element.innerText.trim()) ?? 1);
  }
  final bars = _readBars(part);
  var chords = 0;
  var covered = 0;
  var sounding = false;
  int? lowest;
  int? highest;
  for (final bar in bars) {
    // Held from the bar before, until a symbol at the start replaces it.
    var inBar = sounding && (bar.chords.isEmpty || bar.chords.first.$1 > 0);
    for (final (_, chord) in bar.chords) {
      sounding = chord != null;
      if (chord != null) {
        chords++;
        inBar = true;
      }
    }
    if (inBar) covered++;
    for (final note in bar.melody) {
      lowest = math.min(lowest ?? note.midi, note.midi);
      highest = math.max(highest ?? note.midi, note.midi);
    }
  }
  return LeadSheetAnalysis(
    partCount: parts.length,
    staves: staves,
    measureCount: bars.length,
    chordCount: chords,
    measuresWithChord: covered,
    keyFifths: bars.isEmpty ? 0 : bars.first.fifths,
    beats: bars.isEmpty ? 4 : bars.first.beats,
    beatType: bars.isEmpty ? 4 : bars.first.beatType,
    lowestMidi: lowest,
    highestMidi: highest,
  );
}

/// Adds a piano part under the melody of a lead sheet: the right hand holds
/// each chord symbol's chord under the melody, the left hand its bass note.
///
/// The melody part stays exactly as written, with its lyrics, chord symbols,
/// repeats and line breaks. The piano part has the same bars, keys, times and
/// barlines. Chords are struck again at every barline and held until the next
/// chord symbol; "N.C." and the bars before the first symbol are rests. A
/// chord lasting less than a beat is passed over, and a chord tone a semitone
/// from a held melody note is left out.
///
/// Throws a [FormatException] when [analyzeLeadSheet] finds an obstacle.
///
/// The style is written into the file, so the part can be made again from
/// an edited melody; see [regeneratePianoPart].
String threeStaffMusicXml(
  String xml, {
  String pianoName = 'Piano',
  AccompanimentPlan plan = const AccompanimentPlan(),
}) {
  final obstacle = analyzeLeadSheet(xml).obstacle;
  if (obstacle != null) {
    throw FormatException('Not a lead sheet: ${obstacle.name}');
  }
  return _withPianoPart(xml, pianoName: pianoName, plan: plan);
}

/// The piano part [threeStaffMusicXml] put into a score, as recorded in it.
class GeneratedPianoPart {
  const GeneratedPianoPart({
    required this.partId,
    required this.name,
    required this.plan,
  });

  final String partId;
  final String name;
  final AccompanimentPlan plan;
}

/// The generated piano part of [xml], or null when it has none.
GeneratedPianoPart? generatedPianoPart(String xml) {
  if (!xml.contains(_pianoPartField)) return null;
  return _generatedPianoPart(XmlDocument.parse(xml));
}

GeneratedPianoPart? _generatedPianoPart(XmlDocument document) {
  final root = document.rootElement;
  final field = _pianoField(root);
  if (field == null) return null;
  final Object? record;
  try {
    record = jsonDecode(field.innerText);
  } on FormatException {
    return null;
  }
  if (record is! Map) return null;
  final id = record['part'];
  final scorePart = root
      .findAllElements('score-part')
      .where((part) => part.getAttribute('id') == id)
      .firstOrNull;
  final parts = root.findElements('part').toList();
  final part = parts.where((p) => p.getAttribute('id') == id).firstOrNull;
  // The record of a part that is gone, or that is the only part, counts
  // for nothing.
  if (id is! String || scorePart == null || part == null || parts.length < 2) {
    return null;
  }
  AccompanimentStyle style(Object? raw) {
    if (raw is! Map) return const AccompanimentStyle();
    return AccompanimentStyle(
      pattern:
          AccompanimentPattern.values.asNameMap()[raw['pattern']] ??
          AccompanimentPattern.held,
      register:
          AccompanimentRegister.values.asNameMap()[raw['register']] ??
          AccompanimentRegister.middle,
    );
  }

  // Section styles are by bar index: they hold while the bars are the ones
  // the part was made for.
  final bars = parts.first.findElements('measure').length;
  final sections = <int, AccompanimentStyle>{};
  final rawSections = record['sections'];
  if (rawSections is Map && record['bars'] == bars) {
    for (final entry in rawSections.entries) {
      final index = int.tryParse('${entry.key}');
      if (index != null && index >= 0 && index < bars) {
        sections[index] = style(entry.value);
      }
    }
  }
  return GeneratedPianoPart(
    partId: id,
    name: scorePart.getElement('part-name')?.innerText ?? 'Piano',
    plan: AccompanimentPlan(base: style(record['base']), sections: sections),
  );
}

/// [xml] without its generated piano part: the lead sheet it was made from.
/// A score without one is returned as it is.
String withoutGeneratedPianoPart(String xml) {
  if (!xml.contains(_pianoPartField)) return xml;
  final document = XmlDocument.parse(xml);
  final generated = _generatedPianoPart(document);
  if (generated == null) return xml;
  _removePianoPart(document, generated.partId);
  return document.toXmlString();
}

/// Makes the generated piano part of [xml] again from the melody and chord
/// symbols as they are now, in the recorded style or in [plan]. A score
/// without a generated piano part is returned as it is.
String regeneratePianoPart(String xml, {AccompanimentPlan? plan}) {
  if (!xml.contains(_pianoPartField)) return xml;
  final document = XmlDocument.parse(xml);
  final generated = _generatedPianoPart(document);
  if (generated == null) return xml;
  _removePianoPart(document, generated.partId);
  return _withPianoPart(
    document.toXmlString(),
    pianoName: generated.name,
    plan: plan ?? generated.plan,
  );
}

const _pianoPartField = 'page-a-diddle:piano-part';

XmlElement? _pianoField(XmlElement root) => root
    .findAllElements('miscellaneous-field')
    .where((field) => field.getAttribute('name') == _pianoPartField)
    .firstOrNull;

void _removePianoPart(XmlDocument document, String id) {
  final root = document.rootElement;
  for (final name in const ['score-part', 'part']) {
    root
        .findAllElements(name)
        .where((element) => element.getAttribute('id') == id)
        .toList()
        .forEach((element) => element.remove());
  }
  final field = _pianoField(root);
  final miscellaneous = field?.parentElement;
  field?.remove();
  if (miscellaneous != null && miscellaneous.childElements.isEmpty) {
    final identification = miscellaneous.parentElement;
    miscellaneous.remove();
    if (identification != null && identification.childElements.isEmpty) {
      identification.remove();
    }
  }
}

/// Records the style of the piano part [id] where MusicXML keeps data of
/// the program that wrote the file.
void _recordPianoPart(
  XmlElement root,
  String id,
  AccompanimentPlan plan,
  int bars,
) {
  Map<String, String> style(AccompanimentStyle style) => {
    'pattern': style.pattern.name,
    'register': style.register.name,
  };
  final record = jsonEncode({
    'part': id,
    'bars': bars,
    'base': style(plan.base),
    'sections': {
      for (final entry in plan.sections.entries)
        '${entry.key}': style(entry.value),
    },
  });
  _pianoField(root)?.remove();
  var identification = root.getElement('identification');
  if (identification == null) {
    identification = XmlElement(XmlName('identification'));
    // The schema puts it before the layout defaults, credits and part list.
    final before = root.childElements
        .where(
          (e) =>
              const {'defaults', 'credit', 'part-list'}.contains(e.name.local),
        )
        .firstOrNull;
    root.children.insert(
      before == null ? 0 : root.children.indexOf(before),
      identification,
    );
  }
  var miscellaneous = identification.getElement('miscellaneous');
  if (miscellaneous == null) {
    miscellaneous = XmlElement(XmlName('miscellaneous'));
    identification.children.add(miscellaneous);
  }
  miscellaneous.children.add(
    XmlElement(
      XmlName('miscellaneous-field'),
      [XmlAttribute(XmlName('name'), _pianoPartField)],
      [XmlText(record)],
    ),
  );
}

String _withPianoPart(
  String xml, {
  required String pianoName,
  required AccompanimentPlan plan,
}) {
  final document = XmlDocument.parse(xml);
  final root = document.rootElement;
  final melody = root.findElements('part').first;
  final bars = _readBars(melody);

  final ids = {
    for (final part in root.findAllElements('score-part'))
      part.getAttribute('id'),
  };
  var number = 2;
  while (ids.contains('P$number')) {
    number++;
  }
  final id = 'P$number';

  final out = StringBuffer('<part id="$id">');
  _Chord? sounding;
  int? previousTop;
  for (var index = 0; index < bars.length; index++) {
    final bar = bars[index];
    out.write('<measure');
    for (final attribute in bar.measureAttributes) {
      out.write(' ${attribute.toXmlString()}');
    }
    out.write('>');
    final attributes = [
      if (index == 0 && !bar.attributes.any((e) => e.name.local == 'divisions'))
        '<divisions>${bar.divisions}</divisions>',
      for (final name in const ['divisions', 'key', 'time'])
        for (final element in bar.attributes)
          if (element.name.local == name) element.toXmlString(),
      if (index == 0) ...[
        '<staves>2</staves>',
        '<clef number="1"><sign>G</sign><line>2</line></clef>',
        '<clef number="2"><sign>F</sign><line>4</line></clef>',
      ],
    ];
    if (attributes.isNotEmpty) {
      out.write('<attributes>${attributes.join()}</attributes>');
    }
    for (final barline in bar.leftBarlines) {
      out.write(barline.toXmlString());
    }

    // Chord changes on the grid the bar can be written in.
    final unit = _unit(bar.divisions);
    final changes = <int, _Chord?>{};
    for (final (onset, chord) in bar.chords) {
      final snapped = onset ~/ unit * unit;
      if (snapped >= bar.length) {
        // Written at the very end: it sounds from the next bar.
        sounding = chord;
        continue;
      }
      changes[snapped] = chord;
    }
    final starts = {0, ...changes.keys}.toList()..sort();
    // A chord that would sound for less than a beat is not struck. At the
    // start of the bar the next chord takes its place; later the chord
    // before it is held on, and one at the end of the bar (a symbol over
    // the pickup notes) sounds from the next bar.
    final beat = bar.beatLength;
    var anticipates = false;
    _Chord? anticipated;
    if (bar.length >= 2 * beat) {
      var i = 0;
      while (i < starts.length && starts.length > 1) {
        final end = i + 1 < starts.length ? starts[i + 1] : bar.length;
        if (end - starts[i] >= beat) {
          i++;
        } else if (i == 0) {
          changes[0] = changes.remove(starts[1]);
          starts.removeAt(1);
        } else {
          final chord = changes.remove(starts[i]);
          if (i == starts.length - 1) {
            anticipates = true;
            anticipated = chord;
          }
          starts.removeAt(i);
        }
      }
    }
    final style = plan.styleAt(index);
    final rightHand = <_Strike>[];
    final leftHand = <_Strike>[];
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      if (changes.containsKey(start)) sounding = changes[start];
      final end = i + 1 < starts.length ? starts[i + 1] : bar.length;
      List<_Pitch> right = const [];
      _Pitch? left;
      // A pickup shorter than a beat is left to the melody.
      final chord = bar.length < beat ? null : sounding;
      if (chord != null) {
        int? melodyLow;
        for (final note in bar.melody) {
          if (note.onset < end && note.end > start) {
            melodyLow = math.min(melodyLow ?? note.midi, note.midi);
          }
        }
        right = _rightHand(
          chord,
          below: melodyLow,
          near: previousTop,
          register: style.register,
        );
        if (right.isNotEmpty) previousTop = right.last.midi;
        // A chord tone a semitone from a melody note held for a beat or
        // more grates against it: the melody has that place.
        final clear = [
          for (final pitch in right)
            if (!bar.melody.any(
              (note) =>
                  (note.midi - pitch.midi).abs() == 1 &&
                  math.min(end, note.end) - math.max(start, note.onset) >= beat,
            ))
              pitch,
        ];
        if (clear.length >= 2) right = clear;
        left = _leftHand(chord);
      }
      leftHand.add(_Strike(start, end, [if (left != null) left]));
      rightHand.addAll(
        _pattern(style.pattern, start, end, right, bar: bar, beat: beat),
      );
    }
    if (anticipates) sounding = anticipated;

    out.write(_staff(bar, rightHand, staff: 1, voice: 1));
    out.write('<backup><duration>${bar.length}</duration></backup>');
    out.write(_staff(bar, leftHand, staff: 2, voice: 5));
    for (final barline in bar.rightBarlines) {
      out.write(barline.toXmlString());
    }
    out.write('</measure>');
  }
  out.write('</part>');

  final partList = root.getElement('part-list');
  if (partList != null) {
    final scorePart = XmlElement(
      XmlName('score-part'),
      [XmlAttribute(XmlName('id'), id)],
      [
        XmlElement(XmlName('part-name'), [], [XmlText(pianoName)]),
      ],
    );
    partList.children.add(scorePart);
  }
  root.children.add(XmlDocument.parse(out.toString()).rootElement.copy());
  _recordPianoPart(root, id, plan, bars.length);
  return document.toXmlString();
}

/// One bar's notes or rests on one staff of the piano part.
String _staff(
  _Bar bar,
  List<_Strike> strikes, {
  required int staff,
  required int voice,
}) {
  final tail = '<voice>$voice</voice>';
  if (strikes.every((strike) => strike.pitches.isEmpty)) {
    return '<note><rest measure="yes"/><duration>${bar.length}</duration>'
        '$tail<staff>$staff</staff></note>';
  }
  final out = StringBuffer();
  // Accidental in force on each line of the staff, from the key.
  final inForce = <(PitchStep, int), int>{};
  final written = [
    for (final strike in strikes)
      _pieces(
        strike.start,
        strike.end,
        divisions: bar.divisions,
        beat: bar.beatLength,
      ),
  ];
  // Flagged notes next to each other within a beat share a beam.
  const flagged = {'eighth', '16th', '32nd', '64th'};
  final beams = <(int, int), String>{};
  var group = <(int, int)>[];
  int? groupBeat;
  void closeGroup() {
    for (var i = 0; group.length > 1 && i < group.length; i++) {
      beams[group[i]] = i == 0
          ? 'begin'
          : i == group.length - 1
          ? 'end'
          : 'continue';
    }
    group = [];
  }

  for (var s = 0; s < strikes.length; s++) {
    var position = strikes[s].start;
    for (var i = 0; i < written[s].values.length; i++) {
      final piece = written[s].values[i];
      final beat = position ~/ bar.beatLength;
      if (strikes[s].pitches.isEmpty || !flagged.contains(piece.type)) {
        closeGroup();
      } else {
        if (beat != groupBeat) closeGroup();
        groupBeat = beat;
        group.add((s, i));
      }
      position += piece.duration;
    }
    if (written[s].rest > 0) closeGroup();
  }
  closeGroup();

  for (var s = 0; s < strikes.length; s++) {
    final pitches = strikes[s].pitches;
    final pieces = written[s];
    for (var i = 0; i < pieces.values.length; i++) {
      final piece = pieces.values[i];
      final beam = beams[(s, i)];
      final value = '<type>${piece.type}</type>${piece.dotted ? '<dot/>' : ''}';
      if (pitches.isEmpty) {
        out.write(
          '<note><rest/><duration>${piece.duration}</duration>$tail$value'
          '<staff>$staff</staff></note>',
        );
        continue;
      }
      final tiedFrom = i > 0;
      final tiedTo = i < pieces.values.length - 1;
      for (var p = 0; p < pitches.length; p++) {
        final pitch = pitches[p];
        final line = (pitch.step, pitch.octave);
        var accidental = '';
        if (!tiedFrom) {
          final current = inForce[line] ?? _keyAlter(pitch.step, bar.fifths);
          if (current != pitch.alter) {
            accidental =
                '<accidental>${_accidentalName(pitch.alter)}</accidental>';
          }
          inForce[line] = pitch.alter;
        }
        out
          ..write('<note>')
          ..write(p > 0 ? '<chord/>' : '')
          ..write('<pitch><step>${pitch.step.musicXmlName}</step>')
          ..write(pitch.alter == 0 ? '' : '<alter>${pitch.alter}</alter>')
          ..write('<octave>${pitch.octave}</octave></pitch>')
          ..write('<duration>${piece.duration}</duration>')
          ..write(tiedFrom ? '<tie type="stop"/>' : '')
          ..write(tiedTo ? '<tie type="start"/>' : '')
          ..write('$tail$value$accidental<staff>$staff</staff>')
          ..write(beam == null || p > 0 ? '' : '<beam number="1">$beam</beam>');
        if (tiedFrom || tiedTo) {
          out
            ..write('<notations>')
            ..write(tiedFrom ? '<tied type="stop"/>' : '')
            ..write(tiedTo ? '<tied type="start"/>' : '')
            ..write('</notations>');
        }
        out.write('</note>');
      }
    }
    if (pieces.rest > 0) {
      // Too short for any note value at these divisions.
      out.write('<forward><duration>${pieces.rest}</duration></forward>');
    }
  }
  return out.toString();
}

/// Notes struck together at [start] and held to [end]; a rest when empty.
class _Strike {
  const _Strike(this.start, this.end, this.pitches);

  final int start;
  final int end;

  /// From the bottom up.
  final List<_Pitch> pitches;
}

/// The right hand's strikes for [chord] sounding from [start] to [end].
List<_Strike> _pattern(
  AccompanimentPattern pattern,
  int start,
  int end,
  List<_Pitch> chord, {
  required _Bar bar,
  required int beat,
}) {
  if (chord.isEmpty || pattern == AccompanimentPattern.held) {
    return [_Strike(start, end, chord)];
  }
  // Eighths: half a beat, or a third of the dotted beat of compound time.
  final eighth = bar.divisions ~/ 2;
  final broken =
      pattern == AccompanimentPattern.broken &&
      bar.divisions.isEven &&
      chord.length > 1;
  final step = broken ? eighth : beat;
  final strikes = <_Strike>[];
  var position = start;
  var count = 0;
  while (position < end) {
    // The first strike reaches the grid, the others stand on it.
    final next = math.min(end, (position ~/ step + 1) * step);
    var pitches = chord;
    if (broken) {
      // Up the chord and back: 1 2 3 2 | 1 2 3 2, or 1 2 3 4 3 2.
      final cycle = chord.length * 2 - 2;
      final at = count % cycle;
      pitches = [chord[at < chord.length ? at : cycle - at]];
    }
    strikes.add(_Strike(position, next, pitches));
    position = next;
    count++;
  }
  return strikes;
}

class _Pitch {
  const _Pitch(this.step, this.alter, this.octave);

  final PitchStep step;
  final int alter;
  final int octave;

  int get midi => 12 * (octave + 1) + step.naturalSemitone + alter;
}

/// A chord tone as letters and semitones above the root.
typedef _Tone = ({int letters, int semitones});

class _Chord {
  const _Chord({
    required this.rootStep,
    required this.rootAlter,
    required this.tones,
    this.bassStep,
    this.bassAlter = 0,
  });

  final PitchStep rootStep;
  final int rootAlter;

  /// Tones above the root, without the root itself.
  final List<_Tone> tones;
  final PitchStep? bassStep;
  final int bassAlter;
}

class _Bar {
  _Bar({
    required this.divisions,
    required this.fifths,
    required this.beats,
    required this.beatType,
  });

  final int divisions;
  final int fifths;
  final int beats;
  final int beatType;
  int length = 0;

  /// `number`, `implicit` and the like of the melody's bar.
  final measureAttributes = <XmlAttribute>[];

  /// Divisions, keys and times written in the bar.
  final attributes = <XmlElement>[];
  final leftBarlines = <XmlElement>[];
  final rightBarlines = <XmlElement>[];

  /// Chord symbols by onset; null for "N.C.".
  final chords = <(int, _Chord?)>[];
  final melody = <({int onset, int end, int midi})>[];

  /// A beat in divisions: a dotted quarter in compound time.
  int get beatLength {
    final compound = beatType == 8 && beats > 3 && beats % 3 == 0;
    final length = divisions * 4 * (compound ? 3 : 1) / beatType;
    return length == length.roundToDouble() && length >= 1
        ? length.round()
        : divisions;
  }
}

List<_Bar> _readBars(XmlElement part) {
  var divisions = 1;
  var fifths = 0;
  var beats = 4;
  var beatType = 4;
  final bars = <_Bar>[];
  for (final measure in part.findElements('measure')) {
    // The bar is read with the attributes at its start.
    for (final child in measure.childElements) {
      final name = child.name.local;
      if (name == 'note') break;
      if (name != 'attributes') continue;
      divisions = _int(child.getElement('divisions')) ?? divisions;
      fifths = _int(child.getElement('key')?.getElement('fifths')) ?? fifths;
      final time = child.getElement('time');
      beats = _int(time?.getElement('beats')) ?? beats;
      beatType = _int(time?.getElement('beat-type')) ?? beatType;
    }
    if (divisions < 1) divisions = 1;
    final bar = _Bar(
      divisions: divisions,
      fifths: fifths,
      beats: beats,
      beatType: beatType,
    );
    for (final attribute in measure.attributes) {
      if (attribute.name.local == 'width') continue;
      bar.measureAttributes.add(attribute.copy());
    }
    var cursor = 0;
    var furthest = 0;
    var previousOnset = 0;
    for (final child in measure.childElements) {
      switch (child.name.local) {
        case 'attributes':
          for (final name in const ['divisions', 'key', 'time']) {
            for (final element in child.findElements(name)) {
              // Written twice in a bar, the later one counts.
              bar.attributes
                ..removeWhere((e) => e.name.local == name)
                ..add(element.copy());
            }
          }
          // A change after the first note counts from the next bar.
          divisions = _int(child.getElement('divisions')) ?? divisions;
          fifths =
              _int(child.getElement('key')?.getElement('fifths')) ?? fifths;
          final time = child.getElement('time');
          beats = _int(time?.getElement('beats')) ?? beats;
          beatType = _int(time?.getElement('beat-type')) ?? beatType;
        case 'note':
          if (child.getElement('grace') != null) continue;
          final duration = _int(child.getElement('duration')) ?? 0;
          final chordTone = child.getElement('chord') != null;
          final onset = chordTone ? previousOnset : cursor;
          final pitch = child.getElement('pitch');
          if (pitch != null) {
            final step = pitch.getElement('step')?.innerText;
            final octave = _int(pitch.getElement('octave'));
            if (step != null && octave != null) {
              final alter =
                  double.tryParse(
                    pitch.getElement('alter')?.innerText.trim() ?? '',
                  )?.round() ??
                  0;
              bar.melody.add((
                onset: onset,
                end: onset + duration,
                midi: _Pitch(PitchStepMusicXml.parse(step), alter, octave).midi,
              ));
            }
          }
          if (!chordTone) {
            previousOnset = cursor;
            cursor += duration;
          }
        case 'backup':
          cursor = math.max(
            0,
            cursor - (_int(child.getElement('duration')) ?? 0),
          );
        case 'forward':
          cursor += _int(child.getElement('duration')) ?? 0;
        case 'harmony':
          final onset = math.max(
            0,
            cursor + (_int(child.getElement('offset')) ?? 0),
          );
          bar.chords.add((onset, _readChord(child)));
        case 'barline':
          final copy = child.copy();
          if (child.getAttribute('location') == 'left') {
            bar.leftBarlines.add(copy);
          } else if (child.getAttribute('location') != 'middle') {
            bar.rightBarlines.add(copy);
          }
      }
      furthest = math.max(furthest, cursor);
    }
    bar.chords.sort((a, b) => a.$1.compareTo(b.$1));
    bar.length = furthest > 0
        ? furthest
        : math.max(1, (bar.divisions * 4 * bar.beats / bar.beatType).round());
    bars.add(bar);
  }
  return bars;
}

int? _int(XmlElement? element) {
  if (element == null) return null;
  return double.tryParse(element.innerText.trim())?.round();
}

const _Tone _majorThird = (letters: 2, semitones: 4);
const _Tone _minorThird = (letters: 2, semitones: 3);
const _Tone _fifth = (letters: 4, semitones: 7);
const _Tone _flatFifth = (letters: 4, semitones: 6);
const _Tone _sharpFifth = (letters: 4, semitones: 8);
const _Tone _sixth = (letters: 5, semitones: 9);
const _Tone _minorSeventh = (letters: 6, semitones: 10);
const _Tone _majorSeventh = (letters: 6, semitones: 11);
const _Tone _diminishedSeventh = (letters: 6, semitones: 9);
const _Tone _second = (letters: 1, semitones: 2);
const _Tone _fourth = (letters: 3, semitones: 5);

/// The chord of a `<harmony>`, or null when it names none ("N.C.").
_Chord? _readChord(XmlElement harmony) {
  final root = harmony.getElement('root');
  final rootStep = root?.getElement('root-step')?.innerText;
  if (rootStep == null) return null;
  final kind = harmony.getElement('kind')?.innerText.trim().toLowerCase() ?? '';
  final tones = switch (kind) {
    'none' => null,
    'minor' => [_minorThird, _fifth],
    'augmented' => [_majorThird, _sharpFifth],
    'diminished' => [_minorThird, _flatFifth],
    'dominant' => [_majorThird, _fifth, _minorSeventh],
    'major-seventh' => [_majorThird, _fifth, _majorSeventh],
    'minor-seventh' => [_minorThird, _fifth, _minorSeventh],
    'diminished-seventh' => [_minorThird, _flatFifth, _diminishedSeventh],
    'augmented-seventh' => [_majorThird, _sharpFifth, _minorSeventh],
    'half-diminished' => [_minorThird, _flatFifth, _minorSeventh],
    'major-minor' => [_minorThird, _fifth, _majorSeventh],
    'major-sixth' => [_majorThird, _fifth, _sixth],
    'minor-sixth' => [_minorThird, _fifth, _sixth],
    'dominant-ninth' => [_majorThird, _fifth, _minorSeventh, _second],
    'major-ninth' => [_majorThird, _fifth, _majorSeventh, _second],
    'minor-ninth' => [_minorThird, _fifth, _minorSeventh, _second],
    'dominant-11th' => [_fifth, _minorSeventh, _second, _fourth],
    'major-11th' => [_fifth, _majorSeventh, _second, _fourth],
    'minor-11th' => [_minorThird, _minorSeventh, _second, _fourth],
    'dominant-13th' => [_majorThird, _minorSeventh, _second, _sixth],
    'major-13th' => [_majorThird, _majorSeventh, _second, _sixth],
    'minor-13th' => [_minorThird, _minorSeventh, _second, _sixth],
    'suspended-second' => [_second, _fifth],
    'suspended-fourth' => [_fourth, _fifth],
    'power' => [_fifth],
    _ => [_majorThird, _fifth],
  };
  if (tones == null) return null;
  final altered = [...tones];
  for (final degree in harmony.findElements('degree')) {
    final value = _int(degree.getElement('degree-value'));
    final base = switch (value) {
      2 || 9 => _second,
      3 => _majorThird,
      4 || 11 => _fourth,
      5 => _fifth,
      6 || 13 => _sixth,
      7 => _minorSeventh,
      _ => null,
    };
    if (base == null) continue;
    final tone = (
      letters: base.letters,
      semitones:
          base.semitones + (_int(degree.getElement('degree-alter')) ?? 0),
    );
    final type = degree.getElement('degree-type')?.innerText.trim();
    final at = altered.indexWhere((t) => t.letters == tone.letters);
    if (type == 'subtract') {
      if (at >= 0) altered.removeAt(at);
    } else if (at >= 0) {
      altered[at] = tone;
    } else if (type == 'add') {
      altered.add(tone);
    }
  }
  final bass = harmony.getElement('bass');
  final bassStep = bass?.getElement('bass-step')?.innerText;
  return _Chord(
    rootStep: PitchStepMusicXml.parse(rootStep),
    rootAlter: _int(root?.getElement('root-alter')) ?? 0,
    tones: altered,
    bassStep: bassStep == null ? null : PitchStepMusicXml.parse(bassStep),
    bassAlter: _int(bass?.getElement('bass-alter')) ?? 0,
  );
}

/// Letter and alteration of the right hand's tones: at most four, leaving
/// the root and then the fifth to the left hand when there are more.
List<(PitchStep, int)> _rightHandTones(_Chord chord) {
  var tones = <_Tone>[(letters: 0, semitones: 0), ...chord.tones];
  if (tones.length > 4) tones = tones.sublist(1);
  if (tones.length > 4) {
    tones = [
      for (final tone in tones)
        if (tone.letters != 4) tone,
    ];
  }
  if (tones.length > 4) tones = tones.sublist(0, 4);
  return [
    for (final tone in tones) _spell(chord.rootStep, chord.rootAlter, tone),
  ];
}

(PitchStep, int) _spell(PitchStep rootStep, int rootAlter, _Tone tone) {
  final step = PitchStep.values[(rootStep.index + tone.letters) % 7];
  final natural = (step.naturalSemitone - rootStep.naturalSemitone + 12) % 12;
  var alter = rootAlter + tone.semitones % 12 - natural;
  if (alter > 6) alter -= 12;
  if (alter < -6) alter += 12;
  if (alter.abs() < 2) return (step, alter);
  // A double sharp or flat reads worse than its plain neighbour.
  final pitchClass = ((step.naturalSemitone + alter) % 12 + 12) % 12;
  for (final candidate in PitchStep.values) {
    if (candidate.naturalSemitone == pitchClass) return (candidate, 0);
  }
  for (final candidate in PitchStep.values) {
    final difference = pitchClass - candidate.naturalSemitone;
    if (difference == (alter > 0 ? 1 : -1)) return (candidate, difference);
  }
  return (step, alter);
}

/// The chord in close position around middle C, as near to [near] (the last
/// top note) as it gets, and under [below] (the lowest melody note above it)
/// where the melody is high enough for that.
List<_Pitch> _rightHand(
  _Chord chord, {
  int? below,
  int? near,
  AccompanimentRegister register = AccompanimentRegister.middle,
}) {
  final tones = _rightHandTones(chord);
  List<List<_Pitch>> voicings({
    required int lowestTop,
    required int highestTop,
    required int lowestBottom,
  }) {
    final found = <List<_Pitch>>[];
    for (var t = 0; t < tones.length; t++) {
      for (var octave = 2; octave <= 6; octave++) {
        final top = _Pitch(tones[t].$1, tones[t].$2, octave);
        if (top.midi < lowestTop || top.midi > highestTop) continue;
        final voicing = [top];
        for (var other = 0; other < tones.length; other++) {
          if (other == t) continue;
          for (var under = octave; under >= 0; under--) {
            final pitch = _Pitch(tones[other].$1, tones[other].$2, under);
            if (pitch.midi < top.midi) {
              voicing.add(pitch);
              break;
            }
          }
        }
        voicing.sort((a, b) => a.midi.compareTo(b.midi));
        if (voicing.first.midi >= lowestBottom) found.add(voicing);
      }
    }
    return found;
  }

  // Middle: C4..D5 on top and nothing under F3. Low: A3..G4 on top and
  // nothing under E3, clear of the left hand. Wider when a chord does not fit.
  final low = register == AccompanimentRegister.low;
  var choices = low
      ? voicings(lowestTop: 57, highestTop: 67, lowestBottom: 52)
      : voicings(lowestTop: 60, highestTop: 74, lowestBottom: 53);
  if (choices.isEmpty) {
    choices = voicings(lowestTop: 55, highestTop: 76, lowestBottom: 48);
  }
  if (choices.isEmpty) return const [];
  var target = near ?? (low ? 62 : 67);
  // A change of register does not follow the last chord across.
  if (low && target > 67) target = 62;
  if (!low && target < 60) target = 67;
  if (below != null) {
    final under = choices.where((v) => v.last.midi < below).toList();
    if (under.isNotEmpty) {
      choices = under;
      target = math.min(target, below - 3);
    }
  }
  choices.sort((a, b) {
    final byDistance = (a.last.midi - target).abs().compareTo(
      (b.last.midi - target).abs(),
    );
    return byDistance != 0 ? byDistance : a.last.midi.compareTo(b.last.midi);
  });
  return choices.first;
}

/// The bass note (the slash bass, or the root) between E2 and E flat 3.
_Pitch _leftHand(_Chord chord) {
  final step = chord.bassStep ?? chord.rootStep;
  final alter = chord.bassStep == null ? chord.rootAlter : chord.bassAlter;
  for (var octave = 1; octave <= 4; octave++) {
    final pitch = _Pitch(step, alter, octave);
    if (pitch.midi >= 40) return pitch;
  }
  return _Pitch(step, alter, 2);
}

/// The grid chord changes are written on: a sixteenth where the divisions
/// allow it, else an eighth or a quarter.
int _unit(int divisions) {
  if (divisions % 4 == 0) return divisions ~/ 4;
  if (divisions % 2 == 0) return divisions ~/ 2;
  return divisions;
}

typedef _Piece = ({int duration, String type, bool dotted});

/// Note values that fill [start]..[end], first up to the next beat when
/// [start] is off the beat; [rest] is what no value at these divisions fits.
({List<_Piece> values, int rest}) _pieces(
  int start,
  int end, {
  required int divisions,
  required int beat,
}) {
  const types = ['whole', 'half', 'quarter', 'eighth', '16th', '32nd', '64th'];
  final values = <_Piece>[];
  for (var i = 0; i < types.length; i++) {
    final plain = divisions * 4 / (1 << i);
    if (plain != plain.roundToDouble() || plain < 1) continue;
    final dotted = plain * 3 / 2;
    if (dotted == dotted.roundToDouble()) {
      values.add((duration: dotted.round(), type: types[i], dotted: true));
    }
    values.add((duration: plain.round(), type: types[i], dotted: false));
  }
  values.sort((a, b) => b.duration.compareTo(a.duration));

  final result = <_Piece>[];
  var rest = 0;
  void fill(int length) {
    var remaining = length;
    while (remaining > 0) {
      final value = values.where((v) => v.duration <= remaining).firstOrNull;
      if (value == null) {
        rest += remaining;
        return;
      }
      result.add(value);
      remaining -= value.duration;
    }
  }

  var position = start;
  if (beat > 0 && position % beat != 0) {
    final nextBeat = (position ~/ beat + 1) * beat;
    if (nextBeat < end) {
      fill(nextBeat - position);
      position = nextBeat;
    }
  }
  fill(end - position);
  return (values: result, rest: rest);
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
