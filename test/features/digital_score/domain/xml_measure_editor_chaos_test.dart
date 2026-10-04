import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_advice.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';

const _editor = XmlMeasureEditor();
const _codec = MusicXmlCodec();

const _types = ['whole', 'half', 'quarter', 'eighth', '16th', '32nd', 'breve'];
const _chords = [
  'C',
  'F#m7',
  'Bb/D',
  'Gsus4',
  'C(add2)',
  'N.C.',
  '',
  'H7',
  'Xq9',
  '   ',
  '/',
  'Cmaj7/G#',
];
const _melodies = [
  'C4 q, D4 q, E4 q, F4 q',
  'G4 w',
  'rest h, A4 h',
  'C4 8., D4 16, E4 q, rest h',
  'C4 q',
  'Z9 q, C4 q',
  '',
  ', ,',
  'C4',
  'C4 q, D4 q, E4 q, F4 q, G4 q, A4 q',
  'Bb3 h., F#5 q',
];
const _pitches = ['C4', 'F#5', 'Bb3', 'E##4', 'H2', '', 'c4', 'G10', 'Abb2'];

/// One thing the proofreading and review screens can ask of the editor, on
/// a bar and a note that may or may not still be there.
String _act(Random r, String xml, XmlNoteRef ref) {
  switch (r.nextInt(20)) {
    case 0:
      return _editor.moveDiatonic(xml, ref, r.nextInt(9) - 4).xml;
    case 1:
      return _editor.shiftOctave(xml, ref, r.nextInt(5) - 2).xml;
    case 2:
      return _editor.setAlter(xml, ref, r.nextInt(7) - 3).xml;
    case 3:
      return _editor.addChordNote(xml, ref).xml;
    case 4:
      return _editor.deleteNote(xml, ref).xml;
    case 5:
      return _editor.restToNote(xml, ref).xml;
    case 6:
      return _editor
          .setDuration(xml, ref, _types[r.nextInt(_types.length)], r.nextInt(4))
          .xml;
    case 7:
      return _editor.setNoteLengths(xml, ref.partIndex, ref.measureIndex, {
        for (var n = r.nextInt(3) + 1; n > 0; n--)
          ref.noteIndex + r.nextInt(4) - 1: (
            type: _types[r.nextInt(_types.length)],
            dots: r.nextInt(3),
          ),
      }).xml;
    case 8:
      final text = _chords[r.nextInt(_chords.length)];
      return _editor.setHarmony(xml, ref, r.nextInt(6) == 0 ? null : text).xml;
    case 9:
      return _editor.insertMeasureAfter(xml, ref).xml;
    case 10:
      return _editor.duplicateMeasure(xml, ref).xml;
    case 11:
      return _editor.moveMeasure(xml, ref, r.nextInt(9) - 4).xml;
    case 12:
      return _editor.deleteMeasure(xml, ref).xml;
    case 13:
      return _editor
          .replaceMelody(
            xml,
            ref.partIndex,
            ref.measureIndex,
            _melodies[r.nextInt(_melodies.length)],
          )
          .xml;
    case 14:
      return _editor
          .setNotePitch(xml, ref, _pitches[r.nextInt(_pitches.length)])
          .xml;
    case 15:
      return _editor
          .setText(xml, ref, r.nextInt(3), ['Verse', '', ' x '][r.nextInt(3)])
          .xml;
    case 16:
      return _editor.removeText(xml, ref, r.nextInt(3) - 1).xml;
    case 18:
      return _editor
          .setLyric(
            xml,
            ref,
            ['가', '', ' 주 ', '<&>', 'la-'][r.nextInt(5)],
            verse: 1 + r.nextInt(2),
          )
          .xml;
    case 17:
      // Looking is asked as often as changing.
      _editor.describe(xml, ref);
      _editor.inspect(xml, ref.partIndex, ref.measureIndex);
      _editor.measureTexts(xml, ref.partIndex, ref.measureIndex);
      isolateMeasureXml(xml, ref.partIndex, ref.measureIndex);
      return xml;
    default:
      // What the score screen does with any version it shows.
      engravingMusicXml(xml);
      arrangementBrief(xml);
      final score = _codec.decodeXml(xml);
      final count = score.parts.first.measures.length;
      final map = [
        for (var i = 0; i < 1 + r.nextInt(12); i++) r.nextInt(count),
      ];
      expandMusicXml(xml, map);
      performanceMeasureMap(score, PlaybackSequence.empty);
      return xml;
  }
}

/// A score is sound when it still reads and its parts have the same bars.
void _check(String xml, String where) {
  final MusicScore score;
  try {
    score = _codec.decodeXml(xml);
  } on Object catch (error) {
    fail('$where: the score no longer reads: $error');
  }
  final counts = {for (final part in score.parts) part.measures.length};
  expect(counts, hasLength(1), reason: '$where: parts differ in length');
  expect(counts.single, greaterThan(0), reason: '$where: no bars left');
}

void _chaos(
  String name,
  String start, {
  required int rounds,
  required int steps,
}) {
  var applied = 0;
  var refused = 0;
  var compared = 0;
  // CHAOS_SCALE=10 runs ten times as many rounds, for a longer hunt.
  final scale = int.tryParse(Platform.environment['CHAOS_SCALE'] ?? '') ?? 1;
  for (var round = 0; round < rounds * scale; round++) {
    final r = Random(name.hashCode ^ (round * 7919));
    var xml = start;
    final trail = <String>[];
    for (var step = 0; step < steps; step++) {
      final score = _codec.decodeXml(xml);
      final partIndex = r.nextInt(score.parts.length);
      final measures = score.parts[partIndex].measures;
      // Mostly a bar and a note that exist; sometimes one that was there
      // a moment ago, as a screen holding a stale selection would ask.
      final measureIndex = r.nextInt(12) == 0
          ? measures.length + r.nextInt(2)
          : r.nextInt(measures.length);
      final notes = measureIndex < measures.length
          ? measures[measureIndex].notes.length
          : 0;
      final noteIndex = notes == 0 || r.nextInt(10) == 0
          ? notes + r.nextInt(3)
          : r.nextInt(notes);
      final ref = XmlNoteRef(
        partIndex: partIndex,
        measureIndex: measureIndex,
        noteIndex: noteIndex,
      );
      final seed = r.nextInt(1 << 30);
      final where =
          '$name round $round step $step '
          '(p$partIndex m$measureIndex n$noteIndex, action seed $seed) '
          'after [${trail.join(' ')}]';
      // The editor keeps the score it read last and uses it again when the
      // next edit is of the text it wrote. What it does with a kept score
      // must be what it does with one read afresh, to the letter: every
      // other edit is made a second time on a copy of the text, which the
      // editor has never seen.
      String? next;
      String? refusal;
      try {
        next = _act(Random(seed), xml, ref);
      } on FormatException catch (error) {
        // A refusal the user can read.
        expect(error.message, isNotEmpty, reason: where);
        refusal = error.message;
      } on Object catch (error, stack) {
        fail('$where: $error\n$stack');
      }
      if (seed.isEven) {
        String? afresh;
        String? afreshRefusal;
        try {
          afresh = _act(Random(seed), String.fromCharCodes(xml.codeUnits), ref);
        } on FormatException catch (error) {
          afreshRefusal = error.message;
        }
        expect(refusal, afreshRefusal, reason: '$where: kept and afresh');
        if (next != null && !identical(next, xml)) {
          expect(next == afresh, isTrue, reason: '$where: kept, afresh differ');
        }
        compared++;
      }
      if (next == null) {
        refused++;
        continue;
      }
      if (!identical(next, xml)) {
        _check(next, where);
        trail.add('$seed@m$measureIndex');
        if (trail.length > 12) trail.removeAt(0);
        applied++;
      }
      xml = next;
    }
  }
  // Both outcomes are really exercised.
  expect(applied, greaterThan(rounds * 2), reason: '$name applied');
  expect(refused, greaterThan(rounds), reason: '$name refused');
  expect(compared, greaterThan(rounds * 4), reason: '$name compared');
}

String _asset(String path) {
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());
  return _codec.xmlString(bytes, fileName: path);
}

String _leadSheet() {
  final out = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?><score-partwise version="4.0">'
    '<part-list><score-part id="P1"><part-name>Voice</part-name>'
    '</score-part></part-list><part id="P1">',
  );
  const steps = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  for (var i = 0; i < 12; i++) {
    out.write('<measure number="$i"${i == 0 ? ' implicit="yes"' : ''}>');
    if (i == 0) {
      out.write(
        '<attributes><divisions>2</divisions><key><fifths>-1</fifths></key>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>',
      );
    }
    if (i == 5) out.write('<print new-system="yes"/>');
    if (i == 3) {
      out.write(
        '<barline location="left"><repeat direction="forward"/></barline>',
      );
    }
    out.write(
      '<harmony><root><root-step>${steps[i % 7]}</root-step></root>'
      '<kind>major</kind></harmony>',
    );
    final count = i == 0 ? 1 : 4;
    for (var n = 0; n < count; n++) {
      final tied = i == 6 && n == 3 || i == 7 && n == 0;
      out.write(
        '<note><pitch><step>${steps[(i + n) % 7]}</step><octave>4</octave>'
        '</pitch><duration>2</duration>'
        '${tied ? '<tie type="${i == 6 ? 'start' : 'stop'}"/>' : ''}'
        '<voice>1</voice><type>quarter</type>'
        '<lyric number="1"><syllabic>single</syllabic><text>가</text></lyric>'
        '</note>',
      );
    }
    if (i == 8) {
      out.write(
        '<barline location="right"><repeat direction="backward"/></barline>',
      );
    }
    out.write('</measure>');
  }
  out.write('</part></score-partwise>');
  return out.toString();
}

/// Edits of every kind, in any order, on bars and notes that may be gone:
/// what a user who presses everything does to a score. After every edit
/// that went through the score must still read, with the same bars in
/// every part; an edit that cannot be made must say so. Nothing else may
/// happen, however the edits pile up.
void main() {
  test(
    'a lead sheet survives any pile of edits',
    () => _chaos('lead sheet', _leadSheet(), rounds: 60, steps: 60),
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'Clair de lune survives any pile of edits',
    () => _chaos(
      'clair',
      _asset('assets/scores/clair-de-lune-claude-debussy.mxl'),
      rounds: 6,
      steps: 40,
    ),
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'Fantaisie-Impromptu survives any pile of edits',
    () => _chaos(
      'fantaisie',
      _asset('assets/scores/fantaisie-impromptu-in-c-minor-chopin.mxl'),
      rounds: 4,
      steps: 30,
    ),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
