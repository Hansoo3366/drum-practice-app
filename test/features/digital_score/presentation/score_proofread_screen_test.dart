import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_proofread_screen.dart';

const _xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
<part id="P1">
<measure number="1"><attributes><divisions>1</divisions><key><fifths>1</fifths></key>
<time><beats>4</beats><beat-type>4</beat-type></time><staves>2</staves>
<clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef></attributes>
<direction><direction-type><dynamics><mf/></dynamics></direction-type><staff>1</staff></direction>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
<note><pitch><step>D</step><octave>5</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
<note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
<note><pitch><step>F</step><alter>1</alter><octave>5</octave></pitch><duration>1</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
<backup><duration>4</duration></backup>
<note><pitch><step>G</step><octave>2</octave></pitch><duration>4</duration><voice>5</voice><type>whole</type><staff>2</staff></note>
</measure>
<measure number="2">
<note><rest/><duration>4</duration><voice>1</voice><type>whole</type><staff>1</staff></note>
<backup><duration>4</duration></backup>
<note><pitch><step>G</step><octave>2</octave></pitch><duration>4</duration><voice>5</voice><type>whole</type><staff>2</staff></note>
</measure>
</part></score-partwise>''';

class _MemoryStorage extends SongFileStorage {
  String? manifest;
  final versions = <String, List<int>>{};

  @override
  Future<String?> loadScoreVersionManifest(String id) async => manifest;

  @override
  Future<void> saveScoreVersionManifest(String id, String json) async {
    manifest = json;
  }

  @override
  Future<void> saveScoreVersionBytes(
    String id,
    String versionId,
    List<int> bytes,
  ) async {
    versions[versionId] = bytes;
  }

  @override
  Future<List<int>?> loadScoreVersionBytes(String id, String versionId) async =>
      versions[versionId];

  /// Playback sequences by version id ('' for the original's).
  final sequences = <String, String>{};

  @override
  Future<String?> loadPlaybackSequence(
    String songId, {
    String? versionId,
  }) async => sequences[versionId ?? ''];

  @override
  Future<void> savePlaybackSequence(
    String songId,
    String jsonContent, {
    String? versionId,
  }) async {
    sequences[versionId ?? ''] = jsonContent;
  }

  @override
  Future<void> replaceFile(String relativePath, List<int> bytes) async {
    throw StateError('The source score must not be overwritten');
  }
}

Future<List<bool?>> _open(
  WidgetTester tester,
  _MemoryStorage storage, {
  String musicXml = _xml,
  PlaybackSequence? sequence,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final results = <bool?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [songFileStorageProvider.overrideWithValue(storage)],
      child: MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: appLocalizationDelegates,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              results.add(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ScoreProofreadScreen(
                      songId: 'song',
                      musicXml: musicXml,
                      catalog: ScoreVersionCatalog.empty,
                      sequence: sequence,
                    ),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  return results;
}

/// The Verovio view keeps a spinner while the native engine is unavailable
/// in tests, so settle with fixed pumps instead of pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Unmounts the screen and lets the Verovio timeout timers run out.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

Future<void> _tapTool(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await _settle(tester);
}

void main() {
  testWidgets('edits one bar and saves it as a new raw XML version', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final results = await _open(tester, storage);

    expect(find.text('1 / 2마디'), findsOneWidget);
    await _tapTool(tester, '한 칸 위');
    await _tapTool(tester, '샤프');
    await _tapTool(tester, '코드');
    await tester.enterText(find.byType(TextField), 'Am7');
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);
    expect(find.widgetWithText(FilledButton, 'Am7'), findsNothing);
    expect(find.text('Am7'), findsOneWidget);

    await _tapTool(tester, '다음 마디');
    expect(find.text('2 / 2마디'), findsOneWidget);
    await _tapTool(tester, '음표로');

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    expect(find.text('교정 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);

    expect(results, [true]);
    final service = DigitalScoreEditorService(storage: storage);
    final catalog = await service.loadVersionCatalog('song');
    expect(catalog.versions.single.name, '교정 1');
    expect(catalog.activeId, catalog.versions.single.id);
    final saved = utf8.decode(storage.versions.values.single);
    final score = const MusicXmlCodec().decodeXml(saved);
    final first = score.parts.first.measures.first;
    final notes = first.notes.toList();
    expect(notes.first.pitch?.step, PitchStep.d);
    expect(notes.first.pitch?.alter, 1);
    expect(first.events.whereType<MusicHarmony>().single.kind, 'minor-seventh');
    expect(saved, contains('<mf/>'));
    expect(score.parts.first.measures[1].notes.first.pitch?.step, PitchStep.b);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('undo, redo and leaving without saving keep the source', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final results = await _open(tester, storage);

    await _tapTool(tester, '음표 삭제');
    await _tapTool(tester, '실행 취소');
    await _tapTool(tester, '다시 실행');
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('저장하지 않은 악보'), findsOneWidget);
    await tester.tap(find.text('버리기'));
    await _settle(tester);

    expect(results, [false]);
    expect(storage.versions, isEmpty);
    expect(storage.manifest, isNull);
    await _close(tester);
  });

  testWidgets('undo and redo go back to the bar and note of the edit', (
    tester,
  ) async {
    await _open(tester, _MemoryStorage());
    bool enabled(String tooltip) =>
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byTooltip(tooltip),
                matching: find.byType(InkWell),
              ),
            )
            .onTap !=
        null;

    // Bar 1: make a chord on the first note; the new tone is picked.
    await _tapTool(tester, '화음');
    await _tapTool(tester, '다음 마디');
    expect(find.text('2 / 2마디'), findsOneWidget);

    await _tapTool(tester, '실행 취소');
    // Back in bar 1, on the note the chord was added to (a note, not the
    // rest of bar 2 and not the neighbour that took the added tone's place).
    expect(find.text('1 / 2마디'), findsOneWidget);
    expect(enabled('이전 음'), isFalse);
    expect(enabled('한 칸 위'), isTrue);

    await _tapTool(tester, '다음 마디');
    await _tapTool(tester, '다시 실행');
    expect(find.text('1 / 2마디'), findsOneWidget);
    // The added chord tone is picked again: there is a note before it.
    expect(enabled('이전 음'), isTrue);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    await tester.tap(find.text('버리기'));
    await _settle(tester);
    await _close(tester);
  });

  testWidgets('a generated piano part follows the chord that was edited', (
    tester,
  ) async {
    // A melody with a C chord, and the piano part made for it.
    const lead =
        '<score-partwise version="4.0"><part-list><score-part id="P1">'
        '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
        '<measure number="1"><attributes><divisions>1</divisions>'
        '<key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>'
        '<harmony><root><root-step>C</root-step></root><kind>major</kind></harmony>'
        '<note><pitch><step>E</step><octave>5</octave></pitch><duration>4</duration>'
        '<voice>1</voice><type>whole</type></note></measure></part></score-partwise>';
    final storage = _MemoryStorage();
    final results = await _open(
      tester,
      storage,
      musicXml: threeStaffMusicXml(
        lead,
        plan: const AccompanimentPlan(
          base: AccompanimentStyle(pattern: AccompanimentPattern.beats),
        ),
      ),
    );

    await _tapTool(tester, '코드');
    await tester.enterText(find.byType(TextField), 'F');
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);

    expect(results, [true]);
    final saved = utf8.decode(storage.versions.values.single);
    final piano = const MusicXmlCodec().decodeXml(saved).parts[1];
    final notes = piano.measures.single.events.whereType<MusicNote>();
    // F major on every beat, as the part was made, and F in the bass.
    expect(notes.where((n) => n.staff == 1).map((n) => n.pitch!.step).toSet(), {
      PitchStep.f,
      PitchStep.a,
      PitchStep.c,
    });
    expect(notes.where((n) => n.staff == 1 && !n.isChord), hasLength(4));
    expect(notes.where((n) => n.staff == 2).map((n) => n.pitch!.step), [
      PitchStep.f,
    ]);
    expect(
      generatedPianoPart(saved)?.plan.base.pattern,
      AccompanimentPattern.beats,
    );
    await _close(tester);
  });

  testWidgets('duration and pitch tools follow the selected event', (
    tester,
  ) async {
    await _open(tester, _MemoryStorage());

    await _tapTool(tester, '다음 마디');
    final up = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('한 칸 위'),
        matching: find.byType(InkWell),
      ),
    );
    expect(up.onTap, isNull);
    final makeNote = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('음표로'),
        matching: find.byType(InkWell),
      ),
    );
    expect(makeNote.onTap, isNotNull);
    await _tapTool(tester, '음가 1/2');
    expect(find.byType(SnackBar), findsNothing);
    await _close(tester);
  });

  testWidgets('removes a misread text of the bar', (tester) async {
    final storage = _MemoryStorage();
    await _open(
      tester,
      storage,
      musicXml: _xml.replaceFirst(
        '<direction>',
        '<direction placement="above"><direction-type><words>rn?</words></direction-type></direction><direction>',
      ),
    );

    await _tapTool(tester, '이 마디의 글자');
    expect(find.text('rn?'), findsOneWidget);
    await tester.tap(find.byTooltip('제거'));
    await _settle(tester);
    // Nothing left to remove: the tool is off.
    final tool = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('이 마디의 글자'),
        matching: find.byType(InkWell),
      ),
    );
    expect(tool.onTap, isNull);

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);

    final saved = utf8.decode(storage.versions.values.single);
    expect(saved, isNot(contains('rn?')));
    expect(saved, contains('<mf/>'));
    await _close(tester);
  });

  testWidgets('adds, copies and removes bars, with undo', (tester) async {
    final storage = _MemoryStorage();
    await _open(tester, storage);

    await _tapTool(tester, '다음 마디 추가');
    expect(find.text('2 / 3마디'), findsOneWidget);
    await _tapTool(tester, '이전 마디');
    await _tapTool(tester, '마디 복제');
    expect(find.text('2 / 4마디'), findsOneWidget);
    await _tapTool(tester, '마디 삭제');
    expect(find.text('2 / 3마디'), findsOneWidget);

    await tester.tap(find.byTooltip('실행 취소'));
    await _settle(tester);
    expect(find.text('2 / 4마디'), findsOneWidget);
    await tester.tap(find.byTooltip('실행 취소'));
    await _settle(tester);
    expect(find.text('1 / 3마디'), findsOneWidget);
    await tester.tap(find.byTooltip('다시 실행'));
    await _settle(tester);
    expect(find.text('2 / 4마디'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);

    final saved = const MusicXmlCodec().decodeXml(
      utf8.decode(storage.versions.values.single),
    );
    // Bar 1, its copy, the added empty bar, bar 2.
    final measures = saved.parts.first.measures;
    expect(measures, hasLength(4));
    expect(measures[0].notes.first.pitch?.step, PitchStep.c);
    expect(measures[1].notes.first.pitch?.step, PitchStep.c);
    expect(measures[2].notes.every((note) => note.pitch == null), isTrue);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('sections move with their bars when a bar is added', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await _open(
      tester,
      storage,
      sequence: PlaybackSequence(
        marks: [
          SectionMark(startMeasureIndex: 0, name: 'INTRO'),
          SectionMark(startMeasureIndex: 1, name: 'VERSE'),
        ],
        steps: [
          PlaybackStep(sectionId: sectionIdAt(1), repeats: 2),
          PlaybackStep(sectionId: sectionIdAt(0)),
        ],
      ),
    );

    await _tapTool(tester, '다음 마디 추가');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);

    final versionId = storage.versions.keys.single;
    final sequence = PlaybackSequence.fromJson(
      jsonDecode(storage.sequences[versionId]!),
    );
    // The verse still starts at the old second bar, now the third.
    expect(sequence.marks.map((m) => (m.startMeasureIndex, m.name)), [
      (0, 'INTRO'),
      (2, 'VERSE'),
    ]);
    expect(sequence.steps.map((s) => (s.sectionId, s.repeats)), [
      (sectionIdAt(2), 2),
      (sectionIdAt(0), 1),
    ]);
    await _close(tester);
  });

  testWidgets(
    'a version with the same bars keeps the playback order as it is',
    (tester) async {
      final storage = _MemoryStorage();
      final order = PlaybackSequence(
        marks: [SectionMark(startMeasureIndex: 1, name: 'VERSE')],
        steps: [PlaybackStep(sectionId: sectionIdAt(1))],
      );
      storage.sequences[''] = jsonEncode(order.toJson());
      // No sequence handed in: the stored one of the edited version is used.
      await _open(tester, storage);

      await _tapTool(tester, '한 칸 위');
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);

      final versionId = storage.versions.keys.single;
      expect(jsonDecode(storage.sequences[versionId]!), order.toJson());
      await _close(tester);
    },
  );
}
