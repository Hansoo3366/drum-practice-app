import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/midi_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/score_pdf_exporter.dart';
import 'package:page_a_diddle/features/digital_score/data/score_project_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_advice.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';

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

const _marks = [
  'staccato',
  'accent',
  'tenuto',
  'fermata',
  'breath-mark',
  'caesura',
  'falloff',
  'strong-accent',
  'nonsense',
];
const _words = [
  'rit.',
  'accel.',
  'a tempo',
  'Swing',
  'Straight',
  'Strings',
  '',
];

/// What the editor screen's palettes, gestures and menus can ask for
/// beyond [_act]: marks, lines, tuplets, voices and staves, runs of bars,
/// runs of notes, how notes look, and the player reading the result.
String _actMore(Random r, String xml, XmlNoteRef ref) {
  final p = ref.partIndex;
  final m = ref.measureIndex;
  XmlNoteRef near() => XmlNoteRef(
    partIndex: p,
    measureIndex: m + r.nextInt(3) - 1,
    noteIndex: ref.noteIndex + r.nextInt(5) - 2,
  );
  List<int> some() => [
    for (var n = r.nextInt(5) + 1; n > 0; n--) ref.noteIndex + r.nextInt(6) - 1,
  ];
  switch (r.nextInt(58)) {
    case 0:
      return _editor.splitNote(xml, ref).xml;
    case 1:
      return _editor.removeNote(xml, ref).xml;
    case 2:
      return _editor
          .insertEvent(
            xml,
            ref,
            before: r.nextBool(),
            rest: r.nextBool(),
            value: r.nextBool()
                ? null
                : (type: _types[r.nextInt(_types.length)], dots: r.nextInt(3)),
          )
          .xml;
    case 3:
      final choice = tupletChoices[r.nextInt(tupletChoices.length)];
      return _editor.makeTuplet(xml, ref, choice.actual, choice.normal).xml;
    case 4:
      return _editor.removeTuplet(xml, ref).xml;
    case 5:
      return _editor.toggleTie(xml, ref).xml;
    case 6:
      return _editor
          .toggleArticulation(xml, ref, _marks[r.nextInt(_marks.length)])
          .xml;
    case 7:
      return _editor
          .setDynamic(
            xml,
            ref,
            r.nextInt(4) == 0
                ? null
                : [...dynamicMarks, 'loud'][r.nextInt(dynamicMarks.length + 1)],
          )
          .xml;
    case 8:
      return _editor.addGraceNote(xml, ref).xml;
    case 9:
      return _editor.setKeySignature(xml, p, m, r.nextInt(17) - 8).xml;
    case 10:
      return _editor
          .setTimeSignature(
            xml,
            p,
            m,
            [2, 3, 4, 6, 7, 12, 0][r.nextInt(7)],
            [2, 4, 8, 16, 3][r.nextInt(5)],
          )
          .xml;
    case 11:
      return _editor
          .setClef(
            xml,
            p,
            m,
            1 + r.nextInt(3),
            ['G', 'F', 'C', 'X'][r.nextInt(4)],
            1 + r.nextInt(5),
          )
          .xml;
    case 12:
      return _editor.toggleRepeat(xml, p, m, start: r.nextBool()).xml;
    case 13:
      return _editor
          .setBarStyle(
            xml,
            p,
            m,
            [...barStyles, 'wavy'][r.nextInt(barStyles.length + 1)],
          )
          .xml;
    case 14:
      return _editor
          .toggleEnding(xml, p, m, r.nextInt(4), start: r.nextBool())
          .xml;
    case 15:
      return _editor
          .setNavigationSign(
            xml,
            p,
            m,
            NavigationSign.values[r.nextInt(NavigationSign.values.length)],
            on: r.nextBool(),
          )
          .xml;
    case 16:
      return _editor
          .setRehearsalMark(xml, p, m, ['A', '', 'Verse 2'][r.nextInt(3)])
          .xml;
    case 17:
      return _editor
          .setTempo(xml, p, m, r.nextInt(5) == 0 ? null : 30 + r.nextInt(300))
          .xml;
    case 18:
      return _editor.addWords(xml, p, m, _words[r.nextInt(_words.length)]).xml;
    case 19:
      return _editor
          .addSpan(
            xml,
            ref,
            near(),
            SpanKind.values[r.nextInt(SpanKind.values.length)],
          )
          .xml;
    case 20:
      return _editor
          .removeSpan(
            xml,
            ref,
            SpanKind.values[r.nextInt(SpanKind.values.length)],
          )
          .xml;
    case 21:
      return _editor
          .toggleOrnament(
            xml,
            ref,
            [...ornamentNames, 'wobble'][r.nextInt(ornamentNames.length + 1)],
          )
          .xml;
    case 22:
      return _editor.enterPitch(xml, ref, r.nextInt(140) - 5).xml;
    case 23:
      return _editor
          .placeNote(
            xml,
            ref,
            PitchStep.values[r.nextInt(7)],
            r.nextInt(11) - 1,
          )
          .xml;
    case 24:
      final from = m + r.nextInt(3) - 1;
      final clip = _editor.copyMeasures(xml, from, from + r.nextInt(3));
      return r.nextBool()
          ? _editor.pasteMeasures(xml, ref, clip).xml
          : _editor.overwriteMeasures(xml, ref, clip).xml;
    case 25:
      return _editor.deleteMeasures(xml, p, m, m + r.nextInt(3)).xml;
    case 26:
      return _editor.clearMeasures(xml, p, m, m + r.nextInt(3)).xml;
    case 27:
      return _editor
          .transposeMeasures(xml, p, m, m + r.nextInt(3), r.nextInt(27) - 13)
          .xml;
    case 28:
      return _editor.addVoice(xml, ref).xml;
    case 29:
      return _editor.removeVoice(xml, ref).xml;
    case 30:
      return r.nextBool()
          ? _editor.addStaff(xml, p).xml
          : _editor.removeStaff(xml, p).xml;
    case 31:
      final choice = partInstruments[r.nextInt(partInstruments.length)];
      return _editor.setInstrument(xml, p, choice.name, choice.program).xml;
    case 32:
      return _editor.toggleBreak(xml, p, m, page: r.nextBool()).xml;
    case 33:
      return _editor
          .setFingering(xml, ref, r.nextInt(8) == 0 ? null : r.nextInt(7))
          .xml;
    case 34:
      return _editor.respell(xml, ref).xml;
    case 35:
      return _editor.toggleGraceSlash(xml, ref).xml;
    case 36:
      return _editor.setPickup(xml, p, m, pickup: r.nextBool()).xml;
    case 37:
      return _editor.setBeam(xml, p, m, some(), join: r.nextBool()).xml;
    case 38:
      return _editor
          .groupTuplet(
            xml,
            p,
            m,
            some(),
            inTimeOf: r.nextBool() ? null : r.nextInt(9),
          )
          .xml;
    case 39:
      return _editor
          .setBarsPerLine(xml, p, r.nextInt(4) == 0 ? null : r.nextInt(18))
          .xml;
    case 40:
      return _editor.addChordPitch(xml, ref, r.nextInt(140) - 5).xml;
    case 41:
      final clip = _editor.copyNotes(xml, [ref, near(), near()]);
      return switch (r.nextInt(3)) {
        0 => _editor.pasteNotes(xml, near(), clip).xml,
        1 => _editor.pasteNotesFlowing(xml, near(), clip).xml,
        _ => _editor.duplicateNotes(xml, [ref, near()]).xml,
      };
    case 42:
      return _editor
          .setStem(xml, ref, [null, 'up', 'down', 'none', 'left'][r.nextInt(5)])
          .xml;
    case 43:
      return _editor
          .setNotehead(
            xml,
            ref,
            [null, 'slash', 'parentheses', 'x'][r.nextInt(4)],
          )
          .xml;
    case 44:
      return _editor.switchStaff(xml, ref).xml;
    case 45:
      return _editor.toggleHidden(xml, ref).xml;
    case 46:
      return _editor.toggleSignatureHidden(xml, p, m, key: r.nextBool()).xml;
    case 47:
      return _editor.insertMeasures(xml, p, m, r.nextInt(5)).xml;
    case 48:
      return _editor.swapVoices(xml, ref).xml;
    case 49:
      return r.nextBool()
          ? _editor
                .setMarkPlacement(
                  xml,
                  ref,
                  [null, 'above', 'below', 'aside'][r.nextInt(4)],
                )
                .xml
          : _editor.clearMarks(xml, ref).xml;
    case 50:
      return _editor.clearAccidental(xml, ref).xml;
    case 51:
      return _editor.doubleAt(xml, ref, r.nextInt(17) - 8).xml;
    case 52:
      return r.nextBool()
          ? _editor
                .setFermataShape(
                  xml,
                  ref,
                  ['normal', 'angled', 'square', 'round'][r.nextInt(4)],
                )
                .xml
          : _editor.setRepeatTimes(xml, p, m, r.nextInt(11)).xml;
    case 53:
      return _editor.fillWithSlashes(xml, p, m, m + r.nextInt(2)).xml;
    case 54:
      return r.nextBool()
          ? _editor.toggleTacet(xml, ref).xml
          : _editor.setQuarterTone(xml, ref, r.nextInt(5) - 2).xml;
    case 55:
      return _editor
          .setInstrumentChange(
            xml,
            p,
            m,
            r.nextInt(3) == 0
                ? null
                : partInstruments[r.nextInt(partInstruments.length)],
          )
          .xml;
    case 56:
      return _editor
          .setLyric(
            xml,
            ref,
            ['가-', '주_', '-', '_', '', '님'][r.nextInt(6)],
            verse: 1 + r.nextInt(3),
            typed: true,
          )
          .xml;
    default:
      // What the editor screen reads of any state of the score, and what
      // the player makes of it.
      final starts = writtenLineStarts(xml, p);
      final chunks = partChunks(xml, p, starts.isEmpty ? const [0] : starts);
      final alone = partAloneXml(xml, p);
      _editor.barSigns(xml, p, m);
      _editor.staffCount(xml, p);
      _editor.instrumentOf(xml, p);
      for (final chunk in chunks.take(2)) {
        chunkForDisplay(chunk, _codec.decodeXml(chunk).parts.first.measures, 0);
      }
      if (alone.length < 60000) {
        final sequence = playbackMidi(
          alone,
          options: const nm.MidiGenerationOptions(
            defaultBpm: 120,
            includeMetronome: false,
          ),
        );
        // Every note that begins ends, and never before it began.
        for (final track in sequence.tracks) {
          final open = <(int, int), int>{};
          for (final event in track.events) {
            final note = event.note;
            if (note == null) continue;
            final key = (event.channel, note);
            if (event.type == nm.MidiEventType.noteOn &&
                (event.velocity ?? 0) > 0) {
              open[key] = event.tick;
            } else if (open.remove(key) case final began?) {
              if (event.tick < began) {
                throw StateError('a note ends before it begins');
              }
            }
          }
        }
      }
      return xml;
  }
}

/// A standard MIDI file, read to the letter: its chunks are as long as they
/// say and fill the file, every event is whole, every track ends with the
/// end-of-track mark and nothing after it, and every note that begins
/// ends. Returns how many notes it holds.
int _strictMidi(Uint8List bytes, String where) {
  var at = 0;
  Never bad(String what) => fail('$where: MIDI file, $what (at byte $at)');
  int byte() => at < bytes.length ? bytes[at++] : bad('ends too early');
  int number(int length) {
    var value = 0;
    for (var i = 0; i < length; i++) {
      value = (value << 8) | byte();
    }
    return value;
  }

  String tag() => String.fromCharCodes([byte(), byte(), byte(), byte()]);
  int variable() {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      final next = byte();
      value = (value << 7) | (next & 0x7f);
      if (next & 0x80 == 0) return value;
    }
    return bad('a length of more than four bytes');
  }

  if (tag() != 'MThd') bad('no header');
  if (number(4) != 6) bad('a header of another length');
  final format = number(2);
  final tracks = number(2);
  final division = number(2);
  if (format > 1) bad('format $format');
  if (tracks == 0 || (format == 0 && tracks != 1)) bad('$tracks tracks');
  if (division == 0 || division & 0x8000 != 0) bad('division $division');
  var notes = 0;
  for (var track = 0; track < tracks; track++) {
    if (tag() != 'MTrk') bad('track $track does not begin');
    final end = number(4) + at;
    if (end > bytes.length) bad('track $track is longer than the file');
    final sounding = <int, int>{};
    int? status;
    var ended = false;
    while (at < end) {
      if (ended) bad('track $track goes on after its end');
      variable();
      var first = byte();
      if (first == 0xff) {
        final type = byte();
        final length = variable();
        if (type == 0x51) {
          if (length != 3) bad('a tempo of $length bytes');
          if (number(3) == 0) bad('a tempo of nothing');
        } else {
          at += length;
        }
        if (type == 0x2f) {
          if (length != 0) bad('an end of track with data');
          ended = true;
        }
        status = null;
        continue;
      }
      if (first == 0xf0 || first == 0xf7) {
        at += variable();
        status = null;
        continue;
      }
      if (first & 0x80 != 0) {
        status = first;
        first = byte();
      } else if (status == null) {
        bad('data without a status');
      }
      if (first > 127) bad('data byte $first');
      final kind = status & 0xf0;
      final second = kind == 0xc0 || kind == 0xd0 ? 0 : byte();
      if (second > 127) bad('data byte $second');
      final key = (status & 0x0f) << 8 | first;
      if (kind == 0x90 && second > 0) {
        sounding[key] = (sounding[key] ?? 0) + 1;
        notes++;
      } else if (kind == 0x80 || kind == 0x90) {
        final count = sounding[key] ?? 0;
        if (count == 0) bad('track $track: a note ends that never began');
        sounding[key] = count - 1;
      }
    }
    if (at != end) bad('track $track runs past its length');
    if (!ended) bad('track $track has no end');
    if (sounding.values.any((count) => count != 0)) {
      bad('track $track: a note never ends');
    }
  }
  if (at != bytes.length) bad('bytes after the last track');
  return notes;
}

/// The same with a playing order somebody set by hand: sections begun at
/// bars picked anyhow, named anyhow, played in any order and several
/// times, and steps that name a section that is no longer there.
void _exportsInOrder(String xml, MusicScore score, String where) {
  final r = Random(xml.hashCode);
  final bars = score.parts.first.measures.length;
  const names = ['Intro', 'Verse', 'Chorus', 'Bridge', 'A', '끝 2', ''];
  final starts = <int>{
    0,
    for (var i = r.nextInt(4); i > 0; i--) r.nextInt(bars),
  };
  final PlaybackSequence sequence;
  try {
    sequence = PlaybackSequence(
      marks: [
        for (final start in starts)
          SectionMark(
            startMeasureIndex: start,
            name: names[r.nextInt(names.length)],
            continued: r.nextInt(6) == 0,
          ),
      ],
      steps: [
        for (var i = r.nextInt(5); i > 0; i--)
          PlaybackStep(
            sectionId: sectionIdAt(
              r.nextInt(5) == 0
                  ? bars + 3
                  : starts.elementAt(r.nextInt(starts.length)),
            ),
            repeats: 1 + r.nextInt(3),
          ),
      ],
    );
  } on FormatException {
    return;
  }
  final order = '$where, order ${jsonEncode(sequence.toJson())}';
  try {
    final map = performanceMeasureMap(score, sequence);
    var out = expandMusicXml(xml, map);
    final played = _codec.decodeXml(out);
    final marked = PlaybackSequence(
      marks: performanceSectionMarks(score, sequence),
    );
    out = withSectionRehearsals(out, [
      for (final section in scoreSections(played, marked))
        if (section.name.isNotEmpty && !section.continued)
          (measureIndex: section.startMeasureIndex, label: section.name),
    ]);
    expect(
      _codec.decodeXml(out).parts.first.measures,
      hasLength(map.length),
      reason: '$order: MusicXML in the order set',
    );
    _strictMidi(
      playbackMidiFile(
        buildPlaybackMidi(
          engravingXml: xml,
          score: score,
          sequence: sequence,
          arrangement: ArrangementProfile.off,
          bpm: 96,
        ),
      ),
      '$order (as it plays)',
    );
    final performance = composePerformanceScore(score, sequence: sequence);
    _strictMidi(const MidiCodec().encode(performance), '$order (model)');
    _codec.decode(
      _codec.encode(performance, MusicXmlFileFormat.musicXml),
      fileName: 'export.musicxml',
    );
    final project = const ScoreProjectCodec().decode(
      const ScoreProjectCodec().encode(
        written: score,
        sequence: sequence,
        arrangement: ArrangementProfile.off,
        sourceXml: xml,
      ),
    );
    expect(
      jsonEncode(project.sequence.toJson()),
      jsonEncode(sequence.toJson()),
      reason: '$order: the project keeps the order',
    );
  } on FormatException {
    // An order that cannot be played is refused, in words.
  } on TestFailure {
    rethrow;
  } on Object catch (error, stack) {
    fail('$order: $error\n$stack');
  }
}

/// Everything the score screen can save a file of, made from a score as
/// editing left it: each must be a file of its kind that reads again.
void _exports(String xml, String where) {
  final score = _codec.decodeXml(xml);
  final bars = score.parts.first.measures.length;
  // MIDI as it plays, from the version's own file (the menu's MIDI).
  final Uint8List played;
  try {
    played = playbackMidiFile(
      buildPlaybackMidi(
        engravingXml: xml,
        score: score,
        sequence: PlaybackSequence.empty,
        arrangement: ArrangementProfile.off,
        bpm: (score.tempoBpm ?? 120).round(),
      ),
    );
  } on Object catch (error, stack) {
    fail('$where: MIDI as it plays: $error\n$stack');
  }
  _strictMidi(played, '$where (as it plays)');
  // MIDI, MusicXML and the project from what the editing model holds
  // (what is saved of a score with unsaved edits).
  final Uint8List model;
  final Uint8List written;
  final Uint8List project;
  try {
    final performance = composePerformanceScore(score);
    model = const MidiCodec().encode(performance);
    written = _codec.encode(performance, MusicXmlFileFormat.musicXml);
    project = const ScoreProjectCodec().encode(
      written: score,
      sequence: PlaybackSequence.empty,
      arrangement: ArrangementProfile.off,
      sourceXml: xml,
    );
  } on FormatException {
    // An order of repeats and signs that cannot be laid out is said so.
    return;
  } on Object catch (error, stack) {
    fail('$where: exporting the model: $error\n$stack');
  }
  _strictMidi(model, '$where (from the model)');
  final MusicScore again;
  final ScoreProject opened;
  try {
    again = _codec.decode(written, fileName: 'export.musicxml');
    opened = const ScoreProjectCodec().decode(project);
  } on Object catch (error) {
    fail('$where: an exported file does not read again: $error');
  }
  expect(again.parts, hasLength(score.parts.length), reason: where);
  expect(
    opened.score.parts.first.measures,
    hasLength(bars),
    reason: '$where: the project holds the score',
  );
  _exportsInOrder(xml, score, where);
  // In playing order, with its sections written in (the menu's MusicXML
  // when an order is set).
  try {
    final map = performanceMeasureMap(score, PlaybackSequence.empty);
    final unrolled = expandMusicXml(xml, map);
    final marked = withSectionRehearsals(unrolled, [
      (measureIndex: 0, label: 'Intro'),
      if (map.length > 2) (measureIndex: map.length ~/ 2, label: 'Verse 2'),
    ]);
    expect(
      _codec.decodeXml(marked).parts.first.measures,
      hasLength(map.length),
      reason: '$where: in playing order',
    );
  } on FormatException {
    // Repeats that cannot be followed are refused, in words.
  } on Object catch (error, stack) {
    fail('$where: in playing order: $error\n$stack');
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
  String Function(Random r, String xml, XmlNoteRef ref) act = _act,
  void Function(String xml, String where)? also,
  int alsoEvery = 0,
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
        next = act(Random(seed), xml, ref);
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
          afresh = act(Random(seed), String.fromCharCodes(xml.codeUnits), ref);
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
        if (also != null && alsoEvery > 0 && applied % alsoEvery == 0) {
          also(next, where);
        }
      }
      xml = next;
    }
    also?.call(xml, '$name round $round, at its end');
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

  // Everything the editor screen can ask for, the old edits and the new
  // ones mixed.
  String every(Random r, String xml, XmlNoteRef ref) =>
      r.nextInt(3) == 0 ? _act(r, xml, ref) : _actMore(r, xml, ref);

  test(
    'a lead sheet survives everything the editor screen can ask for',
    () => _chaos(
      'lead sheet, every tool',
      _leadSheet(),
      rounds: 80,
      steps: 60,
      act: every,
    ),
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'a piano score survives everything the editor screen can ask for',
    () => _chaos(
      'clair, every tool',
      _asset('assets/scores/clair-de-lune-claude-debussy.mxl'),
      rounds: 6,
      steps: 40,
      act: every,
    ),
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'a lead sheet edited any which way still exports files that read',
    () => _chaos(
      'lead sheet, exports',
      _leadSheet(),
      rounds: 40,
      steps: 60,
      act: every,
      also: _exports,
      alsoEvery: 6,
    ),
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'a score edited any which way still makes a PDF',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final left = <String>[];
      _chaos(
        'lead sheet, pdf',
        _leadSheet(),
        rounds: 12,
        steps: 50,
        act: every,
        also: (xml, _) => left.add(xml),
        alsoEvery: 10,
      );
      expect(left, isNotEmpty);
      for (final (index, xml) in left.indexed) {
        final Uint8List pdf;
        try {
          pdf = await const ScorePdfExporter().export(
            composePerformanceScore(_codec.decodeXml(xml), ignoreErrors: true),
          );
        } on Object catch (error, stack) {
          fail('score $index of ${left.length}: $error\n$stack\n$xml');
        }
        expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
        expect(
          String.fromCharCodes(pdf.skip(pdf.length - 32)),
          contains('%%EOF'),
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'a piano score edited any which way still exports files that read',
    () => _chaos(
      'clair, exports',
      _asset('assets/scores/clair-de-lune-claude-debussy.mxl'),
      rounds: 4,
      steps: 30,
      act: every,
      also: _exports,
      alsoEvery: 8,
    ),
    timeout: const Timeout(Duration(minutes: 20)),
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
