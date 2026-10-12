import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/midi_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/score_project_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';
import 'package:xml/xml.dart';

// A score that came from somewhere else is not the score the app would
// have written: a converter that lost half a bar, a file cut off on the
// way, a number where no number belongs. Whatever it is, the app either
// reads it and then works with it, or says in words that it cannot. It
// never falls over.

const _codec = MusicXmlCodec();
const _editor = XmlMeasureEditor();

String _asset(String path) => _codec.xmlString(
  Uint8List.fromList(File(path).readAsBytesSync()),
  fileName: path,
);

const _numbers = ['0', '-1', '1', '7', '255', '99999', '1.5', 'x', '', ' 4 '];
const _leaves = {
  'duration',
  'divisions',
  'fifths',
  'beats',
  'beat-type',
  'octave',
  'alter',
  'staff',
  'voice',
  'staves',
  'line',
  'actual-notes',
  'normal-notes',
  'per-minute',
  'midi-program',
  'midi-channel',
  'volume',
  'clef-octave-change',
};

/// [xml] with something wrong with it, as [r] has it.
String _spoiled(Random r, String xml) {
  final document = XmlDocument.parse(xml);
  final elements = document.descendants.whereType<XmlElement>().toList();
  XmlElement any(bool Function(XmlElement) test) {
    final found = elements.where(test).toList();
    return found.isEmpty
        ? elements[r.nextInt(elements.length)]
        : found[r.nextInt(found.length)];
  }

  for (var n = 1 + r.nextInt(4); n > 0; n--) {
    switch (r.nextInt(12)) {
      case 0:
        // A number that is no number, or not one that fits.
        any((e) => _leaves.contains(e.name.local)).innerText =
            _numbers[r.nextInt(_numbers.length)];
      case 1:
        // Something that is simply gone.
        final gone = any((e) => e.parent is XmlElement && e.depth > 2);
        if (gone.parent != null) gone.parent!.children.remove(gone);
      case 2:
        // Something that is there twice.
        final twice = any(
          (e) => const {
            'note',
            'backup',
            'forward',
            'attributes',
            'direction',
            'harmony',
            'barline',
          }.contains(e.name.local),
        );
        final parent = twice.parent;
        if (parent != null) {
          parent.children.insert(parent.children.indexOf(twice), twice.copy());
        }
      case 3:
        // A note without what makes it one.
        final note = any((e) => e.name.local == 'note');
        final part = ['pitch', 'duration', 'type', 'voice', 'rest', 'step'];
        final name = part[r.nextInt(part.length)];
        note.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == name)
            .toList()
            .forEach((e) => e.parent?.children.remove(e));
      case 4:
        // A whole bar of one part gone: the parts no longer agree.
        final bar = any((e) => e.name.local == 'measure');
        bar.parent?.children.remove(bar);
      case 5:
        // An empty bar.
        any((e) => e.name.local == 'measure').children.clear();
      case 6:
        // Ties, slurs and beams that begin and never end, or the reverse.
        final mark = any(
          (e) => const {
            'tie',
            'tied',
            'slur',
            'beam',
            'tuplet',
            'wedge',
          }.contains(e.name.local),
        );
        if (mark.name.local == 'beam') {
          mark.innerText = ['begin', 'end', 'continue', 'hook'][r.nextInt(4)];
        } else {
          mark.setAttribute('type', ['start', 'stop', 'both'][r.nextInt(3)]);
        }
      case 7:
        // A step that is no step, a type that is no type.
        final leaf = any(
          (e) => const {'step', 'type', 'sign', 'mode'}.contains(e.name.local),
        );
        leaf.innerText = [
          'H',
          'c',
          '',
          'quarter note',
          '128th',
          'TAB',
        ][r.nextInt(6)];
      case 8:
        // A repeat or an ending without its other half.
        final bar = any((e) => e.name.local == 'measure');
        bar.children.add(
          XmlElement(
            XmlName('barline'),
            [
              XmlAttribute(
                XmlName('location'),
                r.nextBool() ? 'left' : 'right',
              ),
            ],
            [
              if (r.nextBool())
                XmlElement(XmlName('repeat'), [
                  XmlAttribute(
                    XmlName('direction'),
                    r.nextBool() ? 'forward' : 'backward',
                  ),
                ])
              else
                XmlElement(XmlName('ending'), [
                  XmlAttribute(
                    XmlName('number'),
                    ['1', '2', '1,2', ''][r.nextInt(4)],
                  ),
                  XmlAttribute(
                    XmlName('type'),
                    ['start', 'stop', 'discontinue'][r.nextInt(3)],
                  ),
                ]),
            ],
          ),
        );
      case 9:
        // A jump to a sign that is not there.
        final bar = any((e) => e.name.local == 'measure');
        final sound = XmlElement(XmlName('sound'), [
          XmlAttribute(
            XmlName(
              ['dalsegno', 'tocoda', 'dacapo', 'fine', 'coda'][r.nextInt(5)],
            ),
            r.nextBool() ? 'yes' : 'nowhere',
          ),
        ]);
        bar.children.add(
          XmlElement(XmlName('direction'), [], [
            XmlElement(XmlName('direction-type'), [], [
              XmlElement(XmlName('words'), [], [XmlText('D.S. al Coda')]),
            ]),
            sound,
          ]),
        );
      case 10:
        // A part that is in the list and not in the score, or the reverse.
        final part = any(
          (e) => e.name.local == 'score-part' || e.name.local == 'part',
        );
        if (r.nextBool()) {
          part.setAttribute('id', 'P${r.nextInt(4)}');
        } else {
          part.parent?.children.remove(part);
        }
      default:
        // Words nobody expects where words go.
        final words = any(
          (e) => const {
            'words',
            'text',
            'part-name',
            'rehearsal',
          }.contains(e.name.local),
        );
        words.innerText = [
          '',
          '   ',
          'rit. accel. a tempo Swing',
          '<&>"\'',
          '𝄞🎹' * 40,
          'x' * 5000,
        ][r.nextInt(6)];
    }
  }
  final out = document.toXmlString();
  // And now and then the file simply stops.
  return r.nextInt(25) == 0 ? out.substring(0, r.nextInt(out.length)) : out;
}

/// Whether [error] is a refusal the user can be told of, in words.
bool _refusal(Object error) =>
    error is FormatException && error.message.isNotEmpty;

void _spoil(String name, String start, {required int rounds}) {
  final scale = int.tryParse(Platform.environment['CHAOS_SCALE'] ?? '') ?? 1;
  var read = 0;
  var refused = 0;
  for (var round = 0; round < rounds * scale; round++) {
    final r = Random(name.hashCode ^ (round * 104729));
    final String xml;
    try {
      xml = _spoiled(r, start);
    } on Object {
      continue;
    }
    final where = '$name round $round';
    T? attempt<T>(String what, T Function() body) {
      try {
        return body();
      } on Object catch (error, stack) {
        if (_refusal(error)) return null;
        fail('$where: $what: $error\n$stack');
      }
    }

    final score = attempt<MusicScore>('reading', () => _codec.decodeXml(xml));
    if (score == null) {
      refused++;
      continue;
    }
    read++;
    if (score.parts.isEmpty || score.parts.first.measures.isEmpty) continue;
    // What the score screen does with any score it is given.
    attempt('lines', () {
      final starts = writtenLineStarts(xml, 0);
      final chunks = partChunks(xml, 0, starts.isEmpty ? const [0] : starts);
      for (final chunk in chunks.take(3)) {
        chunkForDisplay(chunk, _codec.decodeXml(chunk).parts.first.measures, 0);
      }
    });
    attempt(
      'playing',
      () => playbackMidiFile(
        buildPlaybackMidi(
          engravingXml: xml,
          score: score,
          sequence: PlaybackSequence.empty,
          arrangement: ArrangementProfile.off,
          bpm: 100,
        ),
      ),
    );
    attempt(
      'the player\'s copy',
      () => playbackMidi(
        partAloneXml(xml, 0),
        options: const nm.MidiGenerationOptions(
          defaultBpm: 100,
          includeMetronome: false,
        ),
      ),
    );
    attempt('exporting', () {
      final performance = composePerformanceScore(score);
      const MidiCodec().encode(performance);
      _codec.decode(
        _codec.encode(performance, MusicXmlFileFormat.musicXml),
        fileName: 'export.musicxml',
      );
      const ScoreProjectCodec().decode(
        const ScoreProjectCodec().encode(
          written: score,
          sequence: PlaybackSequence.empty,
          arrangement: ArrangementProfile.off,
          sourceXml: xml,
        ),
      );
    });
    attempt('playing order', () {
      expandMusicXml(xml, performanceMeasureMap(score, PlaybackSequence.empty));
    });
    // And the editor, on a bar and a note of it.
    final bars = score.parts.first.measures;
    final bar = r.nextInt(bars.length);
    final notes = bars[bar].notes.length;
    final ref = XmlNoteRef(
      partIndex: 0,
      measureIndex: bar,
      noteIndex: notes == 0 ? 0 : r.nextInt(notes),
    );
    attempt('inspecting', () {
      _editor.inspect(xml, 0, bar);
      _editor.barSigns(xml, 0, bar);
      _editor.staffCount(xml, 0);
    });
    for (final (what, edit) in <(String, XmlEditResult Function())>[
      ('a step up', () => _editor.moveDiatonic(xml, ref, 1)),
      ('a length', () => _editor.setDuration(xml, ref, 'eighth', 0)),
      ('a rest', () => _editor.deleteNote(xml, ref)),
      (
        'a note more',
        () => _editor.insertEvent(xml, ref, before: false, rest: false),
      ),
      ('a note less', () => _editor.removeNote(xml, ref)),
      ('a tie', () => _editor.toggleTie(xml, ref)),
      ('a bar more', () => _editor.insertMeasures(xml, 0, bar, 1)),
      ('a bar less', () => _editor.deleteMeasures(xml, 0, bar, bar)),
      ('a bar cleared', () => _editor.clearMeasures(xml, 0, bar, bar)),
      ('a key', () => _editor.setKeySignature(xml, 0, bar, 2)),
      ('a transposition', () => _editor.transposeMeasures(xml, 0, bar, bar, 3)),
      ('a lyric', () => _editor.setLyric(xml, ref, '가', verse: 1)),
      (
        'a paste',
        () {
          final clip = _editor.copyMeasures(xml, bar, bar);
          return _editor.pasteMeasures(xml, ref, clip);
        },
      ),
    ]) {
      final result = attempt(what, edit);
      if (result == null) continue;
      // What it wrote is a score again, or it said it could not.
      attempt('$what, read again', () => _codec.decodeXml(result.xml));
    }
  }
  // Both happen: the test spoils scores, it does not destroy them all.
  expect(read, greaterThan(rounds ~/ 4), reason: '$name read');
  expect(refused, greaterThan(0), reason: '$name refused');
}

void main() {
  test(
    'a spoiled lead sheet is read and worked with, or refused in words',
    () => _spoil('lead sheet', _leadSheet(), rounds: 400),
    timeout: const Timeout(Duration(minutes: 15)),
  );

  test(
    'a spoiled piano score is read and worked with, or refused in words',
    () => _spoil(
      'clair',
      _asset('assets/scores/clair-de-lune-claude-debussy.mxl'),
      rounds: 25,
    ),
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

String _leadSheet() {
  String note(String step, {int duration = 2, String type = 'quarter'}) =>
      '<note><pitch><step>$step</step><octave>4</octave></pitch>'
      '<duration>$duration</duration><voice>1</voice><type>$type</type>'
      '<lyric number="1"><syllabic>single</syllabic><text>가</text></lyric>'
      '</note>';
  String harmony(String root) =>
      '<harmony><root><root-step>$root</root-step></root>'
      '<kind>major</kind></harmony>';
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<score-partwise version="4.0"><part-list>'
    '<score-part id="P1"><part-name>Voice</part-name></score-part>'
    '</part-list><part id="P1">',
  );
  for (var i = 0; i < 12; i++) {
    buffer.write('<measure number="${i + 1}">');
    if (i == 0) {
      buffer.write(
        '<attributes><divisions>2</divisions><key><fifths>1</fifths></key>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>'
        '<direction placement="above"><direction-type>'
        '<metronome><beat-unit>quarter</beat-unit><per-minute>96</per-minute>'
        '</metronome></direction-type><sound tempo="96"/></direction>',
      );
    }
    if (i == 4) {
      buffer.write(
        '<barline location="left"><repeat direction="forward"/></barline>',
      );
    }
    buffer
      ..write(harmony(const ['G', 'C', 'D', 'E'][i % 4]))
      ..write(note('G'))
      ..write(note('A', duration: 1, type: 'eighth'))
      ..write(
        '<note><pitch><step>B</step><octave>4</octave></pitch>'
        '<duration>1</duration><tie type="start"/><voice>1</voice>'
        '<type>eighth</type><notations><tied type="start"/></notations>'
        '</note>',
      )
      ..write(
        '<note><pitch><step>B</step><octave>4</octave></pitch>'
        '<duration>2</duration><tie type="stop"/><voice>1</voice>'
        '<type>quarter</type><notations><tied type="stop"/></notations>'
        '</note>',
      )
      ..write(
        '<note><rest/><duration>2</duration><voice>1</voice>'
        '<type>quarter</type></note>',
      );
    if (i == 7) {
      buffer.write(
        '<barline location="right"><repeat direction="backward"/></barline>',
      );
    }
    buffer.write('</measure>');
  }
  buffer.write('</part></score-partwise>');
  return buffer.toString();
}
