import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/score_export_service.dart';
import 'package:page_a_diddle/features/digital_score/data/score_project_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const exporter = ScoreExportService();

  test('offers only PDF, MusicXML, project, and MIDI exports', () {
    expect(ScoreExportKind.values, [
      ScoreExportKind.musicXml,
      ScoreExportKind.midi,
      ScoreExportKind.pdf,
      ScoreExportKind.project,
    ]);
  });

  test('unfolds sequence and accompaniment for MusicXML export', () async {
    final written = _score(sections: true);
    final exported = await exporter.encode(
      written: written,
      title: 'Demo',
      sequence: PlaybackSequence(
        steps: [
          PlaybackStep(sectionId: sectionIdAt(0), repeats: 4),
          PlaybackStep(sectionId: sectionIdAt(1), repeats: 2),
          PlaybackStep(sectionId: sectionIdAt(2)),
        ],
      ),
      arrangement: const ArrangementProfile(style: ArrangementStyle.block),
      kind: ScoreExportKind.musicXml,
    );

    expect(exported.fileName, 'Demo.musicxml');
    final decoded = const MusicXmlCodec().decode(
      exported.bytes,
      fileName: exported.fileName,
    );
    expect(decoded.measureCount, 7);
    expect(
      decoded.parts.first.measures.first.notes.any(
        (note) => note.voice == arrangementVoice,
      ),
      isTrue,
    );
    expect(written.measureCount, 3);
    expect(
      written.parts.first.measures.first.notes.any(
        (note) => note.voice == arrangementVoice,
      ),
      isFalse,
    );
  });

  test('writes a Standard MIDI File from the performance score', () async {
    final exported = await exporter.encode(
      written: _score(),
      title: 'Midi',
      kind: ScoreExportKind.midi,
    );
    expect(ascii.decode(exported.bytes.take(4).toList()), 'MThd');
    expect(exported.bytes, containsAllInOrder([0x90, 60, 80]));
    expect(exported.fileName, 'Midi.mid');
  });

  test(
    'typesets a multi-page Grand Staff PDF without changing the source',
    () async {
      final written = _score(measureCount: 13);
      final exported = await exporter.encode(
        written: written,
        title: 'Print',
        kind: ScoreExportKind.pdf,
      );
      final text = String.fromCharCodes(exported.bytes);
      expect(text.startsWith('%PDF-'), isTrue);
      expect(text, contains('%%EOF'));
      expect(text, contains('Print'));
      expect(
        RegExp(r'/Type\s*/Page(?!s)').allMatches(text).length,
        greaterThanOrEqualTo(2),
      );
      expect(written.measureCount, 13);
    },
  );

  test('keeps the written score inside an editable project zip', () async {
    final written = _score(sections: true);
    final sequence = PlaybackSequence(
      steps: [PlaybackStep(sectionId: sectionIdAt(0), repeats: 2)],
    );
    const arrangement = ArrangementProfile(style: ArrangementStyle.pulse);
    final exported = await exporter.encode(
      written: written,
      title: '  My / Score:*  ',
      sequence: sequence,
      arrangement: arrangement,
      kind: ScoreExportKind.project,
    );

    expect(exported.fileName, 'My Score.zip');
    final project = const ScoreProjectCodec().decode(exported.bytes);
    expect(project.score.measureCount, 3);
    expect(project.sequence, sequence);
    expect(project.arrangement, arrangement);
    expect(
      project.score.parts.first.measures.first.notes.any(
        (note) => note.voice == arrangementVoice,
      ),
      isFalse,
    );
  });

  test(
    'composePerformanceScore leaves the written instance alone when idle',
    () {
      final written = _score();
      expect(identical(composePerformanceScore(written), written), isTrue);
    },
  );

  test(
    'project export preserves the version file and its instrument metadata',
    () async {
      const xml = '''<score-partwise version="4.0">
<part-list><score-part id="P1"><part-name>Strings</part-name>
<midi-instrument id="I1"><midi-channel>1</midi-channel><midi-program>49</midi-program></midi-instrument>
</score-part></part-list><part id="P1"><measure number="1">
<attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
<direction><direction-type><dynamics><p/></dynamics></direction-type></direction>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type>
<notations><articulations><staccato/></articulations></notations>
<lyric><syllabic>single</syllabic><text>가사</text></lyric></note>
</measure></part></score-partwise>''';
      final score = const MusicXmlCodec().decodeXml(xml);
      final sequence = PlaybackSequence(
        steps: [PlaybackStep(sectionId: sectionIdAt(0), repeats: 2)],
      );
      final exported = await exporter.encode(
        written: score,
        title: 'Strings',
        sequence: sequence,
        kind: ScoreExportKind.project,
        sourceXml: xml,
      );
      final archive = ZipDecoder().decodeBytes(exported.bytes);
      expect(
        utf8.decode(archive.findFile('score.musicxml')!.content as List<int>),
        xml,
      );
      final project = const ScoreProjectCodec().decode(exported.bytes);
      expect(project.sequence, sequence);
      expect(project.arrangement.isOff, isTrue);
    },
  );
}

MusicScore _score({bool sections = false, int measureCount = 1}) {
  MusicMeasure measure(int number, {String? section}) {
    return MusicMeasure(
      number: '$number',
      attributes: MusicAttributes(
        divisions: 4,
        time: const MusicTimeSignature(beats: 4, beatType: 4),
        staves: 2,
      ),
      events: [
        if (section != null)
          MusicDirection(onset: 0, staff: 1, rehearsal: section),
        MusicNote(
          onset: 0,
          duration: 4,
          voice: '1',
          staff: 1,
          pitch: const MusicPitch(step: PitchStep.c, octave: 4),
          type: 'quarter',
        ),
        const MusicHarmony(
          onset: 0,
          staff: 1,
          rootStep: PitchStep.c,
          kind: 'major',
        ),
      ],
    );
  }

  final labels = sections
      ? const ['INTRO', 'VERSE', 'CHORUS']
      : List<String?>.filled(measureCount, null);
  return MusicScore(
    title: 'Print',
    tempoBpm: 100,
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          for (var index = 0; index < labels.length; index++)
            measure(index + 1, section: labels[index]),
        ],
      ),
    ],
  );
}
