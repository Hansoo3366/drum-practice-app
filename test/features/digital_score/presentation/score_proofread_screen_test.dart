import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/native_score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_original_crop.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_editor_chrome.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_proofread_screen.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';
import 'package:xml/xml.dart';

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

  /// The unsaved pass the editor keeps while it is used: a file among the
  /// versions, but not one of them.
  List<int>? draft;

  @override
  Future<void> saveScoreVersionBytes(
    String id,
    String versionId,
    List<int> bytes,
  ) async {
    if (versionId == scoreDraftId) {
      draft = bytes;
    } else {
      versions[versionId] = bytes;
    }
  }

  @override
  Future<List<int>?> loadScoreVersionBytes(String id, String versionId) async =>
      versionId == scoreDraftId ? draft : versions[versionId];

  @override
  Future<void> deleteScoreVersion(String id, String versionId) async {
    if (versionId == scoreDraftId) {
      draft = null;
    } else {
      versions.remove(versionId);
    }
  }

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

/// The originals of a converted song, as the conversion service has them.
class _Originals implements OmrConvertService {
  _Originals([this.places]);

  final List<List<OmrBarPlace?>>? places;
  final asked = <String>[];

  @override
  Future<List<List<OmrBarPlace?>>?> barPlaces(String songId) async => places;

  @override
  Future<Uint8List?> systemImage(String songId, String name) async {
    asked.add(name);
    return _png;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A one-pixel PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<List<bool?>> _open(
  WidgetTester tester,
  _MemoryStorage storage, {
  String musicXml = _xml,
  PlaybackSequence? sequence,
  _Originals? originals,
  List<int>? lineStarts,
  Size size = const Size(900, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final results = <bool?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songFileStorageProvider.overrideWithValue(storage),
        omrConvertServiceProvider.overrideWithValue(originals ?? _Originals()),
      ],
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
                      lineStarts: lineStarts,
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

/// What is done to a bar as a whole is in the bar menu, by name.
const _barTools = {'다음 마디 추가', '마디 복제', '마디 삭제', '마디 앞으로', '마디 뒤로', '이 마디의 글자'};

/// The palette a tool is in; it is opened before the tool is tapped.
const _paletteOf = {
  '화음': '음표',
  '음표로': '음표',
  '쉼표로': '음표',
  '음표 삭제': '음표',
  '나누기': '음표',
  '한 칸 위': '높이',
  '한 칸 아래': '높이',
  '샤프': '높이',
  '플랫': '높이',
  '제자리표': '높이',
  '코드': '코드 · 가사',
  '가사': '코드 · 가사',
};

/// Opens a palette from the list of palettes: its tools then stand under
/// the score.
Future<void> _openPalette(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('팔레트'));
  await _settle(tester);
  // The list lies over the screen: its entry is the last of that name.
  await tester.tap(find.text(name).last);
  await _settle(tester);
}

Future<void> _tapTool(WidgetTester tester, String tooltip) async {
  if (_barTools.contains(tooltip)) {
    await tester.tap(find.byTooltip('마디 편집'));
    await _settle(tester);
    await tester.tap(find.text(tooltip));
  } else {
    final palette =
        _paletteOf[tooltip] ?? (tooltip.startsWith('음가') ? '길이' : null);
    if (palette != null) await _openPalette(tester, palette);
    await tester.tap(find.byTooltip(tooltip));
  }
  await _settle(tester);
}

void main() {
  testWidgets('bar operations are a menu by name; the bar can be heard', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await _open(tester, storage);

    // Not five more arrows in the tool rows.
    for (final name in _barTools) {
      expect(find.byTooltip(name), findsNothing);
    }
    expect(find.byTooltip('여기부터 듣기'), findsOneWidget);

    await tester.tap(find.byTooltip('마디 편집'));
    await _settle(tester);
    for (final name in _barTools) {
      expect(find.text(name), findsOneWidget);
    }
    // Pressing outside closes it and changes nothing.
    await tester.tapAt(const Offset(4, 4));
    await _settle(tester);
    expect(find.text('마디 삭제'), findsNothing);
    expect(find.text('1 / 2마디'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a word is corrected under its note, and the next one after', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await _open(tester, storage);

    await _tapTool(tester, '가사');
    expect(find.widgetWithText(AlertDialog, '가사'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '주');
    // The keyboard's Next writes the word and opens the next note's.
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await _settle(tester);
    expect(find.widgetWithText(AlertDialog, '가사'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '님');
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);
    expect(find.byType(AlertDialog), findsNothing);

    // Saved as a version, with both words in it.
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);
    final saved = utf8.decode(storage.versions.values.single);
    expect(saved, contains('<text>주</text>'));
    expect(saved, contains('<text>님</text>'));
    await _close(tester);
  });

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
    await _openPalette(tester, '높이');
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
    await _openPalette(tester, '높이');
    final up = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('한 칸 위'),
        matching: find.byType(InkWell),
      ),
    );
    expect(up.onTap, isNull);
    await _openPalette(tester, '음표');
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
    await tester.tap(find.byTooltip('마디 편집'));
    await _settle(tester);
    final tool = tester.widget<PopupMenuItem<int>>(
      find.ancestor(
        of: find.text('이 마디의 글자'),
        matching: find.byType(PopupMenuItem<int>),
      ),
    );
    expect(tool.enabled, isFalse);
    await tester.tapAt(const Offset(4, 4));
    await _settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);

    final saved = utf8.decode(storage.versions.values.single);
    expect(saved, isNot(contains('rn?')));
    expect(saved, contains('<mf/>'));
    await _close(tester);
  });

  testWidgets('rewrites a misread text of the bar', (tester) async {
    final storage = _MemoryStorage();
    await _open(
      tester,
      storage,
      musicXml: _xml.replaceFirst(
        '<direction>',
        '<direction placement="above"><direction-type><words>Uerse</words></direction-type></direction><direction>',
      ),
    );

    await _tapTool(tester, '이 마디의 글자');
    await tester.enterText(find.byType(TextField), 'Verse');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);

    final saved = utf8.decode(storage.versions.values.single);
    expect(saved, contains('<words>Verse</words>'));
    expect(saved, isNot(contains('Uerse')));
    await _close(tester);
  });

  testWidgets('shows each bar as it is on the original', (tester) async {
    final originals = _Originals([
      [
        (image: 'p1-s1.jpg', focus: (0.1, 0.5)),
        (image: 'p1-s2.jpg', focus: (0.0, 0.4)),
      ],
    ]);
    await _open(tester, _MemoryStorage(), originals: originals);

    OmrOriginalCrop crop() =>
        tester.widget<OmrOriginalCrop>(find.byType(OmrOriginalCrop));
    expect(crop().focus, (0.1, 0.5));
    expect(originals.asked, ['p1-s1.jpg']);

    await _tapTool(tester, '다음 마디');
    expect(crop().focus, (0.0, 0.4));
    expect(originals.asked, ['p1-s1.jpg', 'p1-s2.jpg']);

    // A bar added now is not on the original; the bars after it still are.
    await _tapTool(tester, '이전 마디');
    await _tapTool(tester, '다음 마디 추가');
    expect(find.byType(OmrOriginalCrop), findsNothing);
    expect(find.text('원본에 없는 마디입니다.'), findsOneWidget);
    await _tapTool(tester, '다음 마디');
    expect(crop().focus, (0.0, 0.4));

    // The strip can be put away.
    await tester.tap(find.byTooltip('원본 보기'));
    await _settle(tester);
    expect(find.byType(OmrOriginalCrop), findsNothing);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('a bar finds its original after bars were removed earlier', (
    tester,
  ) async {
    // The first bar of the conversion is gone in this version.
    final edited = const XmlMeasureEditor()
        .deleteMeasure(
          _xml,
          const XmlNoteRef(partIndex: 0, measureIndex: 0, noteIndex: 0),
        )
        .xml;
    await _open(
      tester,
      _MemoryStorage(),
      musicXml: edited,
      originals: _Originals([
        [
          (image: 'p1-s1.jpg', focus: (0.1, 0.5)),
          (image: 'p1-s2.jpg', focus: (0.0, 0.4)),
        ],
      ]),
    );

    expect(tester.widget<OmrOriginalCrop>(find.byType(OmrOriginalCrop)).focus, (
      0.0,
      0.4,
    ));
    await _close(tester);
  });

  testWidgets('on a phone the original stands above the engraving', (
    tester,
  ) async {
    await _open(
      tester,
      _MemoryStorage(),
      size: const Size(400, 800),
      originals: _Originals([
        [(image: 'p1-s1.jpg', focus: (0.1, 0.5)), null],
      ]),
    );

    final crop = tester.getRect(find.byType(OmrOriginalCrop));
    final engraving = tester.getRect(find.byType(VerovioScoreView));
    expect(crop.bottom, lessThanOrEqualTo(engraving.top));
    expect(crop.width, greaterThan(300));
    // Beside it where there is room.
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('on a tablet the original stands beside the engraving', (
    tester,
  ) async {
    await _open(
      tester,
      _MemoryStorage(),
      originals: _Originals([
        [(image: 'p1-s1.jpg', focus: (0.1, 0.5)), null],
      ]),
    );

    final crop = tester.getRect(find.byType(OmrOriginalCrop));
    final engraving = tester.getRect(find.byType(VerovioScoreView));
    expect(crop.right, lessThanOrEqualTo(engraving.left));
    // The second bar was not placed on the page by the conversion.
    await _tapTool(tester, '다음 마디');
    expect(find.text('원본에 없는 마디입니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('a score that was not converted has no original strip', (
    tester,
  ) async {
    await _open(tester, _MemoryStorage());

    expect(find.byType(OmrOriginalCrop), findsNothing);
    expect(find.byTooltip('원본 보기'), findsNothing);
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

  testWidgets('a bar read without any note can still be removed', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await _open(
      tester,
      storage,
      musicXml: _xml.replaceFirst(
        '</part>',
        '<measure number="3"></measure></part>',
      ),
    );

    await _tapTool(tester, '다음 마디');
    await _tapTool(tester, '다음 마디');
    expect(find.text('3 / 3마디'), findsOneWidget);
    await _tapTool(tester, '마디 삭제');
    expect(find.text('2 / 2마디'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('moves a bar and takes its section along', (tester) async {
    final storage = _MemoryStorage();
    await _open(
      tester,
      storage,
      sequence: PlaybackSequence(
        marks: [
          SectionMark(startMeasureIndex: 0, name: 'INTRO'),
          SectionMark(startMeasureIndex: 1, name: 'VERSE'),
        ],
      ),
    );

    await _tapTool(tester, '마디 뒤로');
    expect(find.text('2 / 2마디'), findsOneWidget);
    await tester.tap(find.byTooltip('실행 취소'));
    await _settle(tester);
    expect(find.text('1 / 2마디'), findsOneWidget);
    await tester.tap(find.byTooltip('다시 실행'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '저장').last);
    await _settle(tester);

    final versionId = storage.versions.keys.single;
    final saved = const MusicXmlCodec().decodeXml(
      utf8.decode(storage.versions[versionId]!),
    );
    // The whole-rest bar now comes first, the bar with the tune second.
    expect(saved.parts.first.measures[0].notes.first.pitch, isNull);
    expect(saved.parts.first.measures[1].notes.first.pitch?.step, PitchStep.c);
    final sequence = PlaybackSequence.fromJson(
      jsonDecode(storage.sequences[versionId]!),
    );
    expect(sequence.marks.map((m) => (m.startMeasureIndex, m.name)), [
      (0, 'VERSE'),
      (1, 'INTRO'),
    ]);
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

  group('lines, ornaments, keys and the pen', () {
    Future<void> palette(WidgetTester tester, String name) async {
      if (name == '건반') {
        // The keyboard is a key of the rail, not a palette of the list.
        await tester.tap(find.byTooltip(name));
        await _settle(tester);
      } else {
        await _openPalette(tester, name);
      }
    }

    Future<void> pick(WidgetTester tester, String menu, String item) async {
      await tester.tap(find.byTooltip(menu));
      await _settle(tester);
      await tester.tap(find.text(item).last);
      await _settle(tester);
    }

    /// Saves the edits as a version and returns its MusicXML.
    Future<String> save(WidgetTester tester, _MemoryStorage storage) async {
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);
      return utf8.decode(storage.versions.values.single);
    }

    List<XmlElement> firstBar(String xml) => XmlDocument.parse(
      xml,
    ).findAllElements('measure').first.findElements('note').toList();

    testWidgets('a slur is drawn from the picked note to the next one picked', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      await palette(tester, '기호');
      await tester.tap(find.byTooltip('이음줄'));
      await _settle(tester);
      expect(find.text('이음줄: 끝나는 음을 누르세요'), findsOneWidget);

      await palette(tester, '음표');
      await _tapTool(tester, '다음 음');
      await _tapTool(tester, '다음 음');
      await tester.tap(find.text('선택한 음까지'));
      await _settle(tester);
      expect(find.text('이음줄: 끝나는 음을 누르세요'), findsNothing);

      final notes = firstBar(await save(tester, storage));
      String? slur(int index) => notes[index]
          .getElement('notations')
          ?.getElement('slur')
          ?.getAttribute('type');
      expect([slur(0), slur(1), slur(2)], ['start', null, 'stop']);
      await _close(tester);
    });

    testWidgets('a line being drawn can be given up; a drawn one is removed', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      await palette(tester, '기호');
      await pick(tester, '선', '크레셴도');
      expect(find.text('크레셴도: 끝나는 음을 누르세요'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await _settle(tester);
      expect(find.text('크레셴도: 끝나는 음을 누르세요'), findsNothing);

      // A pedal on the one note, then off again from the same menu.
      await pick(tester, '선', '페달');
      await tester.tap(find.text('선택한 음까지'));
      await _settle(tester);
      await pick(tester, '선', '페달');
      await pick(tester, '꾸밈', '트릴');

      final saved = await save(tester, storage);
      expect(saved, isNot(contains('<pedal')));
      expect(saved, isNot(contains('<wedge')));
      expect(firstBar(saved).first.findAllElements('trill-mark'), hasLength(1));
      await _close(tester);
    });

    testWidgets('keys give the picked note its pitch and go on to the next', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      await palette(tester, '건반');
      await tester.tap(find.byTooltip('건반 한 옥타브 위'));
      await _settle(tester);
      await tester.tap(find.byTooltip('A5'));
      await _settle(tester);
      await tester.tap(find.byTooltip('F#5'));
      await _settle(tester);

      final score = const MusicXmlCodec().decodeXml(
        await save(tester, storage),
      );
      final notes = score.parts.first.measures.first.notes.toList();
      expect((notes[0].pitch?.step, notes[0].pitch?.octave), (PitchStep.a, 5));
      expect(
        (notes[1].pitch?.step, notes[1].pitch?.alter, notes[1].pitch?.octave),
        (PitchStep.f, 1, 5),
      );
      expect(notes[2].pitch?.step, PitchStep.e);
      await _close(tester);
    });

    testWidgets('a key turns a rest into a note', (tester) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      await _tapTool(tester, '다음 마디');
      await palette(tester, '건반');
      await tester.tap(find.byTooltip('G4'));
      await _settle(tester);

      final score = const MusicXmlCodec().decodeXml(
        await save(tester, storage),
      );
      final note = score.parts.first.measures[1].notes.first;
      expect((note.pitch?.step, note.pitch?.octave), (PitchStep.g, 4));
      expect(note.type, 'whole');
      await _close(tester);
    });

    testWidgets('the words of a second verse are written under the first', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      await palette(tester, '코드 · 가사');
      await pick(tester, '절', '2절');
      await tester.tap(find.byTooltip('가사'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '나');
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);

      final lyric = firstBar(
        await save(tester, storage),
      ).first.findElements('lyric').single;
      expect(lyric.getAttribute('number'), '2');
      expect(lyric.getElement('text')?.innerText, '나');
      await _close(tester);
    });

    testWidgets('on a small phone every palette shows all of its tools', (
      tester,
    ) async {
      await _open(tester, _MemoryStorage(), size: const Size(360, 720));

      // A tool that is there by name in each palette: the last one, which a
      // row that scrolled sideways would have kept off the screen.
      for (final (name, lastTool) in const [
        ('음표', '성부'),
        ('길이', '잇단음표'),
        ('높이', '겹내림표'),
        ('기호', '꾸밈'),
        ('코드 · 가사', '절'),
        ('마디 기호', '쪽나눔'),
        ('악보', '보표'),
      ]) {
        await _openPalette(tester, name);
        final tool = tester.getRect(find.byTooltip(lastTool));
        expect(tool.right, lessThanOrEqualTo(360), reason: '$name: $lastTool');
        expect(tool.bottom, lessThanOrEqualTo(720), reason: '$name: $lastTool');
        expect(tester.takeException(), isNull, reason: name);
      }
      // The keyboard takes the whole width, an octave and more, with keys
      // wide enough to hit.
      await tester.tap(find.byTooltip('건반'));
      await _settle(tester);
      expect(tester.getRect(find.byTooltip('C4')).left, 0);
      expect(tester.getRect(find.byTooltip('C4')).width, greaterThan(40));
      expect(tester.getRect(find.byTooltip('C5')).right, 360);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('tools work on every note of a run that was picked', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);
      VerovioScoreView view() =>
          tester.widget<VerovioScoreView>(find.byType(VerovioScoreView));
      final bar = view().score.parts.first.measures.first;

      await palette(tester, '음표');
      await tester.tap(find.byTooltip('범위'));
      await _settle(tester);
      expect(find.text('끝 음을 눌러 여러 음 고르기'), findsOneWidget);
      // From the first note (picked) to the third.
      view().onEventTapped!(
        ScoreEventAddress(
          partIndex: 0,
          measureIndex: 0,
          eventIndex: eventIndexForXmlNote(bar, 2)!,
        ),
      );
      await _settle(tester);
      expect(view().alsoSelectedNotes, hasLength(2));

      await _tapTool(tester, '한 칸 위');
      // The run is still picked: the next tool works on it too.
      expect(view().alsoSelectedNotes, hasLength(2));
      await palette(tester, '기호');
      await tester.tap(find.byTooltip('스타카토'));
      await _settle(tester);

      final saved = await save(tester, storage);
      final notes = const MusicXmlCodec()
          .decodeXml(saved)
          .parts
          .first
          .measures
          .first
          .notes
          .toList();
      expect(
        [for (final note in notes.take(4)) note.pitch!.step],
        [PitchStep.d, PitchStep.e, PitchStep.f, PitchStep.f],
      );
      expect(
        [
          for (final note in firstBar(saved).take(4))
            note.findAllElements('staccato').length,
        ],
        [1, 1, 1, 0],
      );
      await _close(tester);
    });

    testWidgets('a run of bars is copied, pasted and moved to another key', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);
      Future<void> range(String from, String to, String action) async {
        await tester.tap(find.byTooltip('마디 편집'));
        await _settle(tester);
        await tester.tap(find.text('마디 범위…'));
        await _settle(tester);
        await tester.enterText(find.byType(TextField).first, from);
        await tester.enterText(find.byType(TextField).last, to);
        await tester.tap(find.text(action).last);
        await _settle(tester);
      }

      // A range that is not in the score is refused where it is asked.
      await range('1', '9', '복사');
      expect(find.text('마디 번호를 확인하세요'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await _settle(tester);

      await range('1', '2', '복사');
      expect(find.text('2마디를 복사했습니다'), findsOneWidget);
      await tester.tap(find.byTooltip('마디 편집'));
      await _settle(tester);
      await tester.tap(find.text('복사한 2마디 끼워 넣기'));
      await _settle(tester);
      expect(find.text('2 / 4마디'), findsOneWidget);

      // The first bar a whole tone up: G major becomes A major, for it only.
      await range('1', '1', '조옮김');

      final score = const MusicXmlCodec().decodeXml(
        await save(tester, storage),
      );
      final bars = score.parts.first.measures;
      expect(bars, hasLength(4));
      expect([for (final bar in bars) bar.attributes.keyFifths], [3, 1, 1, 1]);
      expect(bars[0].notes.first.pitch?.step, PitchStep.d);
      expect(bars[1].notes.first.pitch?.step, PitchStep.c);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('a voice, an instrument, a staff and a line break', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      await palette(tester, '음표');
      await pick(tester, '성부', '성부 추가');
      await _tapTool(tester, '다음 마디');
      await palette(tester, '마디 기호');
      // This score writes no line breaks: the break is forced here all the
      // same, the lines the score is shown in being written with it.
      await tester.tap(find.byTooltip('줄바꿈'));
      await _settle(tester);
      expect(find.textContaining('화면 너비에 맞춰'), findsNothing);
      await palette(tester, '악보');
      await pick(tester, '악기', 'Strings');
      await pick(tester, '보표', '아래 보표 지우기');
      // The staff was removed from bar 2: that bar is still the one shown.
      expect(find.text('2 / 2마디'), findsOneWidget);

      final saved = await save(tester, storage);
      final document = XmlDocument.parse(saved);
      final bars = document.findAllElements('measure').toList();
      expect(document.findAllElements('midi-program').single.innerText, '49');
      expect(document.findAllElements('staves'), isEmpty);
      expect(bars[1].getElement('print')?.getAttribute('new-system'), 'yes');
      // The lower staff is gone; the voice added to the upper one is not.
      final voices = {
        for (final note in bars[0].findElements('note'))
          note.getElement('voice')?.innerText,
      };
      expect(voices, {'1', '2'});
      expect(() => const MusicXmlCodec().decodeXml(saved), returnsNormally);
      await _close(tester);
    });

    testWidgets('with the pen a tap on the staff puts the note on that line', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);
      VerovioScoreView view() =>
          tester.widget<VerovioScoreView>(find.byType(VerovioScoreView));

      expect(view().inputMode, 'select');
      await tester.tap(find.byTooltip('음표 넣기'));
      await _settle(tester);
      expect(view().inputMode, 'place');
      // One finger still moves the page: a tap places, a held finger aims.
      expect(view().oneFingerPan, isTrue);
      expect(find.text('눌러서 음 놓기 · 꾹 누르면 높이를 맞춤'), findsOneWidget);

      // The second note (D5) is put on the F line: F♯ in this key.
      final bar = view().score.parts.first.measures.first;
      view().onNotePlaced!(
        NativeStaffPlace(
          measureIndex: 0,
          eventIndex: eventIndexForXmlNote(bar, 1)!,
          staff: 1,
          step: PitchStep.f,
          octave: 4,
          ghostCenter: Offset.zero,
          lineGap: 10,
        ),
      );
      await _settle(tester);

      final score = const MusicXmlCodec().decodeXml(
        await save(tester, storage),
      );
      final note = score.parts.first.measures.first.notes.elementAt(1);
      expect(
        (note.pitch?.step, note.pitch?.alter, note.pitch?.octave),
        (PitchStep.f, 1, 4),
      );
      await _close(tester);
    });
  });

  group('the score, a rail of tools, and what a tap does', () {
    VerovioScoreView view(WidgetTester tester) =>
        tester.widget<VerovioScoreView>(find.byType(VerovioScoreView));

    ScoreEventAddress note(WidgetTester tester, int bar, int index) {
      final measure = view(tester).score.parts.first.measures[bar];
      return ScoreEventAddress(
        partIndex: 0,
        measureIndex: bar,
        eventIndex: eventIndexForXmlNote(measure, index)!,
      );
    }

    NativeStaffPlace place(
      WidgetTester tester,
      int bar,
      int index,
      PitchStep step,
      int octave,
    ) => NativeStaffPlace(
      measureIndex: bar,
      eventIndex: note(tester, bar, index).eventIndex,
      staff: 1,
      step: step,
      octave: octave,
      ghostCenter: Offset.zero,
      lineGap: 10,
    );

    Future<List<MusicNote>> savedBar(
      WidgetTester tester,
      _MemoryStorage storage,
      int bar,
    ) async {
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);
      final saved = utf8.decode(storage.versions.values.single);
      return const MusicXmlCodec()
          .decodeXml(saved)
          .parts
          .first
          .measures[bar]
          .notes
          .toList();
    }

    testWidgets('the whole part is on screen and a tap picks a note anywhere', (
      tester,
    ) async {
      await _open(tester, _MemoryStorage());

      // Every bar is engraved, not the one being worked on alone.
      expect(view(tester).score.parts.first.measures, hasLength(2));
      expect(view(tester).inputMode, 'select');
      expect(view(tester).oneFingerPan, isTrue);
      expect(view(tester).selectedNoteAddress?.measureIndex, 0);
      expect(find.text('1 / 2마디'), findsOneWidget);

      view(tester).onEventTapped!(note(tester, 1, 0));
      await _settle(tester);
      expect(find.text('2 / 2마디'), findsOneWidget);
      expect(view(tester).selectedNoteAddress?.measureIndex, 1);
      expect(view(tester).highlightedMeasureIndex, 1);
      await _close(tester);
    });

    testWidgets('the cursor keys go from note to note, over the barline', (
      tester,
    ) async {
      await _open(tester, _MemoryStorage());

      for (var i = 0; i < 4; i++) {
        await _tapTool(tester, '다음 음');
      }
      expect(find.text('1 / 2마디'), findsOneWidget);
      await _tapTool(tester, '다음 음');
      expect(find.text('2 / 2마디'), findsOneWidget);
      // Back from the first note of bar 2 is the last note of bar 1.
      await _tapTool(tester, '이전 음');
      expect(find.text('1 / 2마디'), findsOneWidget);
      expect(
        view(tester).selectedNoteAddress?.eventIndex,
        note(tester, 0, 4).eventIndex,
      );
      await _tapTool(tester, '다음 마디');
      await _tapTool(tester, '처음으로');
      expect(find.text('1 / 2마디'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('the eraser makes a tapped note a rest and leaves rests', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      await tester.tap(find.byTooltip('지우개'));
      await _settle(tester);
      expect(find.text('지울 음을 누르세요'), findsOneWidget);
      view(tester).onEventTapped!(note(tester, 0, 1));
      await _settle(tester);
      // A rest stays a rest: the bar after has nothing to undo.
      view(tester).onEventTapped!(note(tester, 1, 0));
      await _settle(tester);

      final notes = await savedBar(tester, storage, 0);
      expect(
        [for (final note in notes.take(4)) note.isRest],
        [false, true, false, false],
      );
      expect(notes.take(4).map((n) => n.onset), [0, 1, 2, 3]);
      await _close(tester);
    });

    testWidgets('the note tool writes a note of the value in hand', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      // The first tap takes the tool up, the second opens its values.
      await tester.tap(find.byTooltip('음표 넣기'));
      await _settle(tester);
      expect(view(tester).inputMode, 'place');
      expect(view(tester).oneFingerPan, isTrue);
      await tester.tap(find.byTooltip('음표 넣기'));
      await _settle(tester);
      await tester.tap(find.byTooltip('음가 1/8'));
      await _settle(tester);

      // On the third note (E5, a quarter): an eighth on the A space.
      view(tester).onNotePlaced!(place(tester, 0, 2, PitchStep.a, 4));
      await _settle(tester);
      // On the rest of bar 2: a note where there was none.
      view(tester).onNotePlaced!(place(tester, 1, 0, PitchStep.g, 4));
      await _settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);
      final saved = utf8.decode(storage.versions.values.single);
      final bars = const MusicXmlCodec().decodeXml(saved).parts.first.measures;
      final first = bars[0].notes.where((n) => n.staff == 1).toList();
      // C5 D5 | A4 eighth, eighth rest | F♯5.
      expect(
        [
          for (final note in first)
            '${note.isRest ? 'r' : note.pitch!.step.name}${note.type}',
        ],
        ['cquarter', 'dquarter', 'aeighth', 'reighth', 'fquarter'],
      );
      final second = bars[1].notes.where((n) => n.staff == 1).first;
      expect((second.pitch?.step, second.type), (PitchStep.g, 'eighth'));
      await _close(tester);
    });

    testWidgets('beside a note the note tool adds one, where the bar is short', (
      tester,
    ) async {
      // Three quarters in a bar of four: a beat is missing.
      String q(String step) =>
          '<note><pitch><step>$step</step><octave>4</octave></pitch>'
          '<duration>1</duration><voice>1</voice><type>quarter</type></note>';
      final short =
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
          '<measure number="1"><attributes><divisions>1</divisions>'
          '<key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>${q('F')}${q('G')}${q('A')}${q('B')}</measure>'
          '<measure number="2">${q('C')}${q('D')}${q('E')}</measure>'
          '</part></score-partwise>';
      final storage = _MemoryStorage();
      await _open(tester, storage, musicXml: short);
      // The second bar: a first bar may be a pickup and is not called short.
      await _tapTool(tester, '다음 마디');
      expect(find.textContaining('짧음'), findsOneWidget);
      NativeStaffPlace beside(int bar, int index, int side) => NativeStaffPlace(
        measureIndex: bar,
        eventIndex: note(tester, bar, index).eventIndex,
        staff: 1,
        step: PitchStep.g,
        octave: 4,
        ghostCenter: Offset.zero,
        lineGap: 10,
        beside: side,
      );

      await tester.tap(find.byTooltip('음표 넣기'));
      await _settle(tester);
      // After the second note of the short bar: a new quarter, on G.
      view(tester).onNotePlaced!(beside(1, 1, 1));
      await _settle(tester);
      expect(find.textContaining('짧음'), findsNothing);
      // Beside a note of the full bar there is no room: that note is meant.
      view(tester).onNotePlaced!(beside(0, 0, 1));
      await _settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);
      final bars = const MusicXmlCodec()
          .decodeXml(utf8.decode(storage.versions.values.single))
          .parts
          .first
          .measures;
      expect(
        [for (final n in bars[1].notes) n.pitch!.step],
        [PitchStep.c, PitchStep.d, PitchStep.g, PitchStep.e],
      );
      expect(bars[1].notes.map((n) => n.onset), [0, 1, 2, 3]);
      expect(
        [for (final n in bars[0].notes) n.pitch!.step],
        [PitchStep.g, PitchStep.g, PitchStep.a, PitchStep.b],
      );
      await _close(tester);
    });

    testWidgets('the keys go on into what a short bar is missing', (
      tester,
    ) async {
      // Bar 2 has two quarters in a bar of four: two beats are missing.
      String q(String step) =>
          '<note><pitch><step>$step</step><octave>4</octave></pitch>'
          '<duration>1</duration><voice>1</voice><type>quarter</type></note>';
      final short =
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
          '<measure number="1"><attributes><divisions>1</divisions>'
          '<key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>${q('F')}${q('G')}${q('A')}${q('B')}</measure>'
          '<measure number="2">${q('C')}${q('D')}</measure>'
          '<measure number="3">${q('E')}${q('E')}${q('E')}${q('E')}</measure>'
          '</part></score-partwise>';
      await _open(tester, _MemoryStorage(), musicXml: short);
      List<String> bar(int index) => [
        for (final n in view(tester).score.parts.first.measures[index].notes)
          n.isRest ? 'r' : n.pitch!.step.name,
      ];
      Future<void> key(String name) async {
        final keys = tester.widget<PianoKeyboard>(find.byType(PianoKeyboard));
        keys.onKey(
          12 * (keys.octave + 1) +
              const {
                'c': 0,
                'd': 2,
                'e': 4,
                'f': 5,
                'g': 7,
                'a': 9,
                'b': 11,
              }[name]!,
        );
        await _settle(tester);
      }

      await tester.tap(find.byTooltip('음표 넣기'));
      await _settle(tester);
      await tester.tap(find.byTooltip('건반'));
      await _settle(tester);
      view(tester).onNotePlaced!(place(tester, 1, 1, PitchStep.d, 4));
      await _settle(tester);

      // The last note of the short bar is written; the keys stay in the bar.
      await key('g');
      expect(bar(1), ['c', 'g']);
      expect(find.text('다음 건반은 이 음 뒤에 새 음으로 들어갑니다'), findsOneWidget);
      // Two more keys fill the two beats that were missing…
      await key('a');
      expect(bar(1), ['c', 'g', 'a']);
      await key('b');
      expect(bar(1), ['c', 'g', 'a', 'b']);
      expect(find.textContaining('짧음'), findsNothing);
      expect(find.text('다음 건반은 이 음 뒤에 새 음으로 들어갑니다'), findsNothing);
      // …and the next one is the first note of the bar after.
      await key('f');
      expect(bar(1), ['c', 'g', 'a', 'b']);
      expect(bar(2), ['f', 'e', 'e', 'e']);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.tap(find.text('버리기'));
      await _settle(tester);
      await _close(tester);
    });

    testWidgets('a finger moved to the side places the note with a sharp', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);
      await tester.tap(find.byTooltip('음표 넣기'));
      await _settle(tester);

      // The second note (D) on the line of A, a sharp asked for with it.
      view(tester).onNotePlaced!(
        place(tester, 0, 1, PitchStep.a, 4).withAlter(1),
      );
      await _settle(tester);
      // The first note where it is (C), only flattened: nothing else of it
      // changes.
      view(tester).onNotePlaced!(
        place(tester, 0, 0, PitchStep.c, 5).withAlter(-1),
      );
      await _settle(tester);

      final bar = await savedBar(tester, storage, 0);
      expect(
        [for (final n in bar.take(2)) (n.pitch!.step, n.pitch!.alter)],
        [(PitchStep.c, -1), (PitchStep.a, 1)],
      );
      await _close(tester);
    });

    testWidgets('what was being corrected is kept, and offered next time', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);
      expect(storage.draft, isNull);

      await _tapTool(tester, '한 칸 위');
      // A moment after the edit it is kept, without being asked.
      await tester.pump(const Duration(seconds: 3));
      expect(storage.draft, isNotNull);
      expect(storage.versions, isEmpty);
      // The app is closed without saving.
      await _close(tester);

      // Next time the corrections are offered, and taken up.
      await _open(tester, storage);
      expect(find.text('저장하지 않은 수정이 있습니다'), findsOneWidget);
      await tester.tap(find.text('이어서 하기'));
      await _settle(tester);
      expect(
        view(tester).score.parts.first.measures.first.notes.first.pitch?.step,
        PitchStep.d,
      );
      // It is one step of undo back to the score as it was.
      await tester.tap(find.byTooltip('실행 취소'));
      await _settle(tester);
      expect(
        view(tester).score.parts.first.measures.first.notes.first.pitch?.step,
        PitchStep.c,
      );
      await tester.tap(find.byTooltip('다시 실행'));
      await _settle(tester);

      // Saved, nothing is left to offer.
      await tester.tap(find.widgetWithText(FilledButton, '저장'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);
      expect(storage.versions, hasLength(1));
      expect(storage.draft, isNull);
      await _close(tester);

      // Thrown away on purpose, it is not offered again either.
      final other = _MemoryStorage();
      await _open(tester, other);
      await _tapTool(tester, '한 칸 위');
      await tester.pump(const Duration(seconds: 3));
      expect(other.draft, isNotNull);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.tap(find.text('버리기'));
      await _settle(tester);
      expect(other.draft, isNull);
      await _close(tester);
      await _open(tester, other);
      expect(find.text('저장하지 않은 수정이 있습니다'), findsNothing);
      await _close(tester);
    });

    testWidgets('words of the score are tapped to be corrected', (
      tester,
    ) async {
      await _open(tester, _MemoryStorage());
      expect(view(tester).onTextTapped, isNotNull);

      // A chord symbol, above the second note.
      view(tester).onTextTapped!(note(tester, 0, 1), true);
      await _settle(tester);
      expect(view(tester).selectedNoteAddress, note(tester, 0, 1));
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Am7');
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);
      expect(view(tester).playbackXml!(), contains('<harmony'));

      // A syllable, under the third.
      view(tester).onTextTapped!(note(tester, 0, 2), false);
      await _settle(tester);
      expect(view(tester).selectedNoteAddress, note(tester, 0, 2));
      await tester.enterText(find.byType(TextField), '주_');
      await tester.tap(find.widgetWithText(FilledButton, '저장').last);
      await _settle(tester);
      expect(view(tester).playbackXml!(), contains('<text>주</text><extend'));

      // The other tools keep their taps to themselves.
      await tester.tap(find.byTooltip('지우개'));
      await _settle(tester);
      expect(view(tester).onTextTapped, isNull);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.tap(find.text('버리기'));
      await _settle(tester);
      await _close(tester);
    });

    testWidgets('a tap on the bare page lets a run of notes go', (
      tester,
    ) async {
      await _open(tester, _MemoryStorage());
      view(tester).onRangeDragged!(note(tester, 0, 0), note(tester, 0, 2));
      await _settle(tester);
      expect(view(tester).alsoSelectedNotes, hasLength(2));

      view(tester).onBlankTapped!();
      await _settle(tester);
      expect(view(tester).alsoSelectedNotes, isEmpty);
      // The note the run began on stays the picked one.
      expect(view(tester).selectedNoteAddress, note(tester, 0, 0));

      // The rest tool, tapped again, is the note tool.
      await tester.tap(find.byTooltip('쉼표 넣기'));
      await _settle(tester);
      await tester.tap(find.byTooltip('쉼표 넣기'));
      await _settle(tester);
      expect(
        tester
            .widget<EditorToolButton>(
              find
                  .ancestor(
                    of: find.byTooltip('음표 넣기'),
                    matching: find.byType(EditorToolButton),
                  )
                  .first,
            )
            .selected,
        isTrue,
      );
      await _close(tester);
    });

    testWidgets('the rest tool writes a rest where it is tapped', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      await tester.tap(find.byTooltip('쉼표 넣기'));
      await _settle(tester);
      view(tester).onNotePlaced!(place(tester, 0, 0, PitchStep.b, 4));
      await _settle(tester);

      final notes = await savedBar(tester, storage, 0);
      expect((notes[0].isRest, notes[0].type), (true, 'quarter'));
      expect(notes[1].pitch?.step, PitchStep.d);
      await _close(tester);
    });

    testWidgets('the dot and the accidentals of the rail work on the note', (
      tester,
    ) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);

      // The last note of the upper staff, so the dot has nothing to cover.
      view(tester).onEventTapped!(note(tester, 0, 3));
      await _settle(tester);
      await tester.tap(find.byTooltip('임시표'));
      await _settle(tester);
      await tester.tap(find.byTooltip('제자리표'));
      await _settle(tester);
      view(tester).onEventTapped!(note(tester, 0, 1));
      await _settle(tester);
      await tester.tap(find.byTooltip('점음표'));
      await _settle(tester);

      final notes = await savedBar(tester, storage, 0);
      expect(notes[3].pitch?.alter ?? notes[2].pitch?.alter, 0);
      expect((notes[1].type, notes[1].dots), ('quarter', 1));
      await _close(tester);
    });

    group('what a finger does with the select tool', () {
      // Four bars of one staff: C D E F, then G A B C three times.
      String bar(String steps) => [
        for (final step in steps.split(''))
          '<note><pitch><step>$step</step><octave>4</octave></pitch>'
              '<duration>1</duration><voice>1</voice><type>quarter</type></note>',
      ].join();
      final four =
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
          '<measure number="1"><attributes><divisions>1</divisions>'
          '<key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>${bar('CDEF')}</measure>'
          '${[for (var i = 2; i <= 4; i++) '<measure number="$i">${bar('GABC')}</measure>'].join()}'
          '</part></score-partwise>';
      List<String> steps(WidgetTester tester, int index) => [
        for (final note in view(tester).score.parts.first.measures[index].notes)
          note.isRest
              ? 'r'
              : '${note.pitch!.step.name}${note.pitch!.alter > 0 ? '#' : ''}',
      ];

      testWidgets('it carries the picked note up the staff, and sharpens it', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: four);
        view(tester).onEventTapped!(note(tester, 0, 1));
        await _settle(tester);

        // Two lines and spaces up: D becomes F.
        view(tester).onSelectionDragged!(2, 0);
        await _settle(tester);
        expect(steps(tester, 0), ['c', 'f', 'e', 'f']);
        // To the right: a sharp.
        view(tester).onSelectionDragged!(0, 1);
        await _settle(tester);
        expect(steps(tester, 0), ['c', 'f#', 'e', 'f']);
        // Each is one step of undo.
        await tester.tap(find.byTooltip('실행 취소'));
        await _settle(tester);
        expect(steps(tester, 0), ['c', 'f', 'e', 'f']);

        // Other tools leave the carrying to the select tool.
        await tester.tap(find.byTooltip('지우개'));
        await _settle(tester);
        expect(view(tester).onSelectionDragged, isNull);
        expect(view(tester).onRangeDragged, isNull);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        await tester.tap(find.text('버리기'));
        await _settle(tester);
        await _close(tester);
      });

      testWidgets('held and moved, it picks a run of notes over the barline', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: four);
        expect(view(tester).rangeHandles, isFalse);

        // From the third note of bar 1 to the second of bar 2.
        view(tester).onRangeDragged!(note(tester, 0, 2), note(tester, 1, 1));
        await _settle(tester);
        expect(view(tester).selectedNoteAddress, note(tester, 0, 2));
        expect(view(tester).alsoSelectedNotes, [
          note(tester, 0, 3),
          note(tester, 1, 0),
          note(tester, 1, 1),
        ]);
        expect(view(tester).rangeHandles, isTrue);

        // What is done to a note is done to all of them, in both bars.
        await _tapTool(tester, '한 칸 위');
        expect(steps(tester, 0), ['c', 'd', 'f', 'g']);
        expect(steps(tester, 1), ['a', 'b', 'b', 'c']);
        // The run stays picked, and the finger carries all of it.
        expect(view(tester).alsoSelectedNotes, hasLength(3));
        view(tester).onSelectionDragged!(-1, 0);
        await _settle(tester);
        expect(steps(tester, 0), ['c', 'd', 'e', 'f']);
        expect(steps(tester, 1), ['g', 'a', 'b', 'c']);

        // A handle moves an end: the run now begins where it ended and
        // goes back to the first note.
        view(tester).onRangeDragged!(note(tester, 1, 1), note(tester, 0, 0));
        await _settle(tester);
        expect(view(tester).selectedNoteAddress, note(tester, 1, 1));
        expect(view(tester).alsoSelectedNotes, hasLength(5));

        // A tap on one note lets the run go.
        view(tester).onEventTapped!(note(tester, 2, 0));
        await _settle(tester);
        expect(view(tester).alsoSelectedNotes, isEmpty);
        expect(view(tester).rangeHandles, isFalse);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        await tester.tap(find.text('버리기'));
        await _settle(tester);
        await _close(tester);
      });

      testWidgets('a run of notes takes one value and closes up', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: four);
        view(tester).onRangeDragged!(note(tester, 0, 0), note(tester, 0, 3));
        await _settle(tester);

        await _tapTool(tester, '음가 1/8');
        final notes = view(tester).score.parts.first.measures[0].notes.toList();
        // Four eighths one after the other, and rests for the half bar
        // they no longer fill.
        expect(
          [for (final note in notes.take(4)) note.pitch?.step],
          [PitchStep.c, PitchStep.d, PitchStep.e, PitchStep.f],
        );
        expect(notes.take(4).map((note) => note.type), everyElement('eighth'));
        expect(notes.take(4).map((note) => note.onset), [0, 1, 2, 3]);
        expect(
          notes.skip(4),
          everyElement(predicate<MusicNote>((n) => n.isRest)),
        );
        await tester.binding.handlePopRoute();
        await _settle(tester);
        await tester.tap(find.text('버리기'));
        await _settle(tester);
        await _close(tester);
      });

      testWidgets('a bar tapped twice is picked whole, with what bars take', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: four);
        int bars() => view(tester).score.parts.first.measures.length;

        view(tester).onMeasureDoubleTapped!(0);
        await _settle(tester);
        expect(find.text('1마디'), findsOneWidget);
        expect(view(tester).highlightedMeasureRange, (start: 0, end: 0));
        // Every note of the bar is picked.
        expect(view(tester).alsoSelectedNotes, hasLength(3));
        // Nothing copied yet.
        expect(
          tester
              .widget<TextButton>(
                find.ancestor(
                  of: find.text('붙여넣기'),
                  matching: find.bySubtype<TextButton>(),
                ),
              )
              .onPressed,
          isNull,
        );

        // A handle takes in the next bar: whole bars stay whole bars.
        view(tester).onRangeDragged!(note(tester, 0, 0), note(tester, 1, 1));
        await _settle(tester);
        expect(find.text('1~2마디'), findsOneWidget);
        expect(view(tester).highlightedMeasureRange, (start: 0, end: 1));
        expect(view(tester).alsoSelectedNotes, hasLength(7));

        // Once more, right after themselves.
        await tester.tap(find.text('복제'));
        await _settle(tester);
        expect(bars(), 6);
        expect(steps(tester, 2), ['c', 'd', 'e', 'f']);
        expect(steps(tester, 3), ['g', 'a', 'b', 'c']);
        expect(find.text('1~2마디'), findsNothing);

        // Copy the first bar, paste it after the last.
        view(tester).onMeasureDoubleTapped!(0);
        await _settle(tester);
        await tester.tap(find.text('복사'));
        await _settle(tester);
        view(tester).onMeasureDoubleTapped!(5);
        await _settle(tester);
        expect(find.text('6마디'), findsOneWidget);
        // Put in after the picked bar, nothing is taken away…
        await tester.tap(find.text('끼워 넣기'));
        await _settle(tester);
        expect(bars(), 7);
        expect(steps(tester, 6), ['c', 'd', 'e', 'f']);
        // …pasted, the copied bar is written over the picked one.
        view(tester).onMeasureDoubleTapped!(1);
        await _settle(tester);
        expect(steps(tester, 1), ['g', 'a', 'b', 'c']);
        await tester.tap(find.text('붙여넣기'));
        await _settle(tester);
        expect(bars(), 7);
        expect(steps(tester, 1), ['c', 'd', 'e', 'f']);
        expect(steps(tester, 2), ['c', 'd', 'e', 'f']);
        // The bar written over is the picked one still.
        expect(view(tester).highlightedMeasureRange, (start: 1, end: 1));

        // Cut empties the bar and leaves it standing, with what was in it
        // ready to be pasted; the bar itself is taken out by name.
        view(tester).onMeasureDoubleTapped!(6);
        await _settle(tester);
        await tester.tap(find.text('잘라내기'));
        await _settle(tester);
        expect(bars(), 7);
        expect(steps(tester, 6), ['r']);
        expect(find.text('7마디'), findsOneWidget);
        await tester.tap(find.text('마디 삭제').last);
        await _settle(tester);
        expect(bars(), 6);
        view(tester).onMeasureDoubleTapped!(1);
        await _settle(tester);
        await tester.tap(find.byTooltip('닫기').last);
        await _settle(tester);
        expect(find.text('2마디'), findsNothing);
        expect(view(tester).highlightedMeasureRange, isNull);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        await tester.tap(find.text('버리기'));
        await _settle(tester);
        await _close(tester);
      });
    });

    group('the finer tools of a notation program', () {
      String n(String step, {bool eighth = false}) =>
          '<note><pitch><step>$step</step><octave>4</octave></pitch>'
          '<duration>${eighth ? 1 : 2}</duration><voice>1</voice>'
          '<type>${eighth ? 'eighth' : 'quarter'}</type></note>';
      // Bar 1: eight eighths. Bar 2: three quarters (a beat short). Bars 3
      // and 4: four quarters.
      final fine =
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
          '<measure number="1"><attributes><divisions>2</divisions>'
          '<key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>'
          '${[for (final s in 'CDEFGABC'.split('')) n(s, eighth: true)].join()}</measure>'
          '<measure number="2">${n('C')}${n('D')}${n('E')}</measure>'
          '<measure number="3">${n('F')}${n('G')}${n('A')}${n('B')}</measure>'
          '<measure number="4">${n('C')}${n('C')}${n('C')}${n('C')}</measure>'
          '</part></score-partwise>';
      List<String> names(WidgetTester tester, int index) {
        final out = <String>[];
        for (final note in view(
          tester,
        ).score.parts.first.measures[index].notes) {
          final name = note.isRest
              ? 'r'
              : '${note.pitch!.step.name}${note.pitch!.alter > 0
                    ? '#'
                    : note.pitch!.alter < 0
                    ? 'b'
                    : ''}';
          if (note.isChord && out.isNotEmpty) {
            out[out.length - 1] = '${out.last}+$name';
          } else {
            out.add(name);
          }
        }
        return out;
      }

      Future<void> menu(WidgetTester tester, String button, String item) async {
        await tester.tap(find.byTooltip(button));
        await _settle(tester);
        await tester.tap(find.text(item).last);
        await _settle(tester);
      }

      Future<void> leave(WidgetTester tester) async {
        await tester.binding.handlePopRoute();
        await _settle(tester);
        await tester.tap(find.text('버리기'));
        await _settle(tester);
        await _close(tester);
      }

      String xmlNow(WidgetTester tester) => view(tester).playbackXml!();

      testWidgets('a finger, the other spelling, a tie from the rail', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        view(tester).onEventTapped!(note(tester, 2, 0));
        await _settle(tester);

        await _openPalette(tester, '기호');
        await menu(tester, '손가락 번호', '3');
        expect(xmlNow(tester), contains('<fingering>3</fingering>'));
        expect(find.text('손가락 번호 3'), findsOneWidget);
        await menu(tester, '손가락 번호', '제거');
        expect(xmlNow(tester), isNot(contains('<fingering>')));

        // F as E sharp: the same key of the piano.
        await _openPalette(tester, '높이');
        await tester.tap(find.byTooltip('이명동음으로 바꾸기'));
        await _settle(tester);
        expect(names(tester, 2).first, 'e#');

        // The tie stands on the rail, as in the main palette.
        view(tester).onEventTapped!(note(tester, 3, 0));
        await _settle(tester);
        await tester.tap(find.byTooltip('붙임줄').first);
        await _settle(tester);
        expect(xmlNow(tester), contains('<tied type="start"/>'));
        await leave(tester);
      });

      testWidgets('picked notes are made a tuplet', (tester) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        // The first three eighths of bar 1.
        view(tester).onRangeDragged!(note(tester, 0, 0), note(tester, 0, 2));
        await _settle(tester);

        await _openPalette(tester, '길이');
        await menu(tester, '잇단음표', '고른 음을 잇단음표로');

        final bar = view(tester).score.parts.first.measures.first;
        expect('<time-modification>'.allMatches(xmlNow(tester)), hasLength(3));
        // The bar was full: the eighth that was freed is a rest at its end.
        expect(bar.durationDivisions / bar.attributes.divisions, 4);
        expect(bar.notes.last.isRest, isTrue);
        await leave(tester);
      });

      testWidgets('a held finger asks, the keys write rests, a line of words', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);

        // Held and lifted on a note: the note is picked and the palettes
        // are offered.
        view(tester).onRangeDragged!(note(tester, 2, 1), note(tester, 2, 1));
        view(tester).onLongPressed!(note(tester, 2, 1));
        await _settle(tester);
        expect(view(tester).selectedNoteAddress, note(tester, 2, 1));
        expect(view(tester).alsoSelectedNotes, isEmpty);
        expect(find.text('모양'), findsOneWidget);
        await tester.tap(find.text('코드 · 가사').last);
        await _settle(tester);

        // A line of words goes onto the notes from the picked one on, and
        // over the barline.
        await tester.tap(find.byTooltip('가사'));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), '주 님- 의 사랑');
        await tester.tap(find.widgetWithText(FilledButton, '저장').last);
        await _settle(tester);
        final written = XmlDocument.parse(
          xmlNow(tester),
        ).findAllElements('measure').toList();
        final sung = [
          for (final bar in [2, 3])
            for (final n in written[bar].findElements('note'))
              n.getElement('lyric')?.getElement('text')?.innerText ?? '',
        ];
        expect(sung, ['', '주', '님', '의', '사랑', '', '', '']);
        expect(xmlNow(tester), contains('<syllabic>begin</syllabic><text>님'));
        expect(xmlNow(tester), contains('<syllabic>end</syllabic><text>의'));

        // The rest key writes a rest where the cursor is and goes on.
        view(tester).onEventTapped!(note(tester, 3, 0));
        await _settle(tester);
        await tester.tap(find.byTooltip('건반'));
        await _settle(tester);
        await tester.tap(find.byTooltip('쉼표 넣고 다음으로'));
        await _settle(tester);
        expect(names(tester, 3), ['r', 'c', 'c', 'c']);
        expect(view(tester).selectedNoteAddress, note(tester, 3, 1));
        await leave(tester);
      });

      testWidgets('flats for sharps, and the words the tempo changes by', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        view(tester).onEventTapped!(note(tester, 2, 0));
        await _settle(tester);
        await _openPalette(tester, '높이');
        await tester.tap(find.byTooltip('샤프'));
        await _settle(tester);
        expect(names(tester, 2).first, 'f#');
        // Sharps are asked for: it is one already, and stays.
        await tester.tap(find.byTooltip('샵으로 적기'));
        await _settle(tester);
        expect(names(tester, 2).first, 'f#');
        await tester.pump(const Duration(seconds: 5));
        await tester.tap(find.byTooltip('플랫으로 적기'));
        await _settle(tester);
        expect(names(tester, 2).first, 'gb');

        await _openPalette(tester, '마디 기호');
        await menu(tester, '빠르기 변화', 'rit.');
        expect(xmlNow(tester), contains('<words>rit.</words>'));
        await leave(tester);
      });

      testWidgets('beams are joined and taken off', (tester) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        view(tester).onRangeDragged!(note(tester, 0, 0), note(tester, 0, 3));
        await _settle(tester);

        await _openPalette(tester, '음표');
        await menu(tester, '빔', '빔으로 묶기');
        expect('<beam number="1">'.allMatches(xmlNow(tester)), hasLength(4));
        expect(xmlNow(tester), contains('<beam number="1">begin</beam>'));
        // The run is still picked.
        expect(view(tester).alsoSelectedNotes, hasLength(3));
        await menu(tester, '빔', '빔 풀기');
        expect(xmlNow(tester), isNot(contains('<beam')));
        await leave(tester);
      });

      testWidgets('a run of notes is copied, pasted and written again', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        // F and G of bar 3.
        view(tester).onRangeDragged!(note(tester, 2, 0), note(tester, 2, 1));
        await _settle(tester);
        await _openPalette(tester, '음표');
        await menu(tester, '음 복사 · 붙여넣기', '고른 음 복사');
        expect(find.text('2개를 복사했습니다'), findsOneWidget);

        // Over the second and third notes of bar 4.
        view(tester).onEventTapped!(note(tester, 3, 1));
        await _settle(tester);
        await menu(tester, '음 복사 · 붙여넣기', '여기부터 붙여넣기 (2개)');
        expect(names(tester, 3), ['c', 'f', 'g', 'c']);

        // The first two notes of bar 3 once more, over the two after them.
        view(tester).onRangeDragged!(note(tester, 2, 0), note(tester, 2, 1));
        await _settle(tester);
        await menu(tester, '음 복사 · 붙여넣기', '바로 뒤에 복제');
        expect(names(tester, 2), ['f', 'g', 'f', 'g']);
        await leave(tester);
      });

      testWidgets('a bar said to be a pickup is not warned of', (tester) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        await _tapTool(tester, '다음 마디');
        expect(find.textContaining('짧음'), findsOneWidget);

        await _openPalette(tester, '마디 기호');
        await tester.tap(find.byTooltip('못갖춘마디'));
        await _settle(tester);
        expect(find.textContaining('짧음'), findsNothing);
        expect(xmlNow(tester), contains('implicit="yes"'));
        await tester.tap(find.byTooltip('못갖춘마디'));
        await _settle(tester);
        expect(find.textContaining('짧음'), findsOneWidget);
        await leave(tester);
      });

      testWidgets('the lines take as many bars as they are told to', (
        tester,
      ) async {
        await _open(
          tester,
          _MemoryStorage(),
          musicXml: fine,
          lineStarts: const [0],
        );
        List<int> barsPerLine() => [
          for (final chunk in view(tester).engravingChunks!)
            XmlDocument.parse(chunk).findAllElements('measure').length,
        ];
        expect(barsPerLine(), [4]);

        await _openPalette(tester, '악보');
        await menu(tester, '한 줄 마디 수', '2마디');
        expect(barsPerLine(), [2, 2]);
        // The notes are engraved larger on the same lines, and as they
        // were again.
        expect(view(tester).engravingPageSize, isNull);
        await menu(tester, '음표 크기', '크게');
        expect(view(tester).engravingPageSize, const Size(1750, 2475));
        expect(barsPerLine(), [2, 2]);
        await menu(tester, '음표 크기', '보통');
        expect(view(tester).engravingPageSize, isNull);
        await menu(tester, '한 줄 마디 수', '3마디');
        expect(barsPerLine(), [3, 1]);
        await leave(tester);
      });

      testWidgets('stems, noteheads, doubling and the notes of a run', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        view(tester).onEventTapped!(note(tester, 2, 0));
        await _settle(tester);

        await _openPalette(tester, '모양');
        await menu(tester, '기둥', '아래로');
        expect(xmlNow(tester), contains('<stem>down</stem>'));
        await menu(tester, '음표 머리', '슬래시');
        expect(xmlNow(tester), contains('<notehead>slash</notehead>'));
        await menu(tester, '음표 머리', '보통');
        expect(xmlNow(tester), isNot(contains('<notehead')));
        // A part of one staff has no other staff: the editor says so.
        await tester.tap(find.byTooltip('다른 보표로'));
        await _settle(tester);
        expect(find.textContaining('보표가 둘인'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));

        // A third on every note of the bar.
        view(tester).onMeasureDoubleTapped!(2);
        await _settle(tester);
        await menu(tester, '음정 겹치기', '3도 위');
        expect(names(tester, 2), ['f+a', 'g+b', 'a+c', 'b+d']);

        // Of those chords only the top notes: a step up moves the melody
        // and leaves the notes under it.
        await _openPalette(tester, '음표');
        await menu(tester, '선택 범위', '가장 높은 음만');
        // The four top notes; the low note the bar was picked from is
        // not one of them.
        expect(view(tester).alsoSelectedNotes, hasLength(4));
        expect(view(tester).selectedNoteAddress, isNull);
        await _openPalette(tester, '높이');
        await tester.tap(find.byTooltip('한 칸 위'));
        await _settle(tester);
        expect(names(tester, 2), ['f+b', 'g+c', 'a+d', 'b+e']);

        // Everything is picked with one entry of the menu.
        await _openPalette(tester, '음표');
        await menu(tester, '선택 범위', '전체 선택');
        expect(find.text('1~4마디'), findsOneWidget);
        expect(view(tester).highlightedMeasureRange, (start: 0, end: 3));
        await leave(tester);
      });

      testWidgets('picked bars play alone', (tester) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        view(tester).onMeasureDoubleTapped!(1);
        await _settle(tester);
        final asked = <int>[];
        var stops = 0;
        view(tester).playback.attach(
          playPause: () async => true,
          stop: () async {
            stops++;
            return true;
          },
          seek: (_) async => true,
          playFromMeasure: (bar) async {
            asked.add(bar);
            return true;
          },
        );

        await tester.tap(find.byTooltip('여기부터 듣기'));
        await _settle(tester);
        expect(asked, [1]);
        final before = stops;
        // The player comes to the bar after the picked one: it is stopped.
        final playback = view(tester).playback;
        playback.replaceState(
          playback.state.copyWith(playing: true, measureNumber: 2),
        );
        await _settle(tester);
        expect(stops, before);
        playback.replaceState(
          playback.state.copyWith(playing: true, measureNumber: 3),
        );
        await _settle(tester);
        expect(stops, before + 1);
        playback.replaceState(playback.state.copyWith(playing: false));
        await _settle(tester);
        await _close(tester);
      });

      testWidgets('the tools stand on the right, small, on a dark page', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        Future<void> option(String name) async {
          await tester.tap(find.byTooltip('마디 편집'));
          await _settle(tester);
          await tester.tap(find.text(name));
          await _settle(tester);
        }

        final score = find.byType(VerovioScoreView);
        final rail = find.byType(EditorRail);
        expect(
          tester.getTopLeft(rail).dx,
          lessThan(tester.getTopLeft(score).dx),
        );

        await option('도구를 오른쪽에');
        expect(
          tester.getTopLeft(rail).dx,
          greaterThan(tester.getTopLeft(score).dx),
        );
        await option('작은 단추');
        expect(tester.getSize(rail).width, EditorRail.compactWidth);
        await option('어두운 악보');
        expect(
          find.ancestor(of: score, matching: find.byType(ColorFiltered)),
          findsOneWidget,
        );
        // Back as it was: the choices are kept for the next time the
        // editor is opened.
        await option('도구를 오른쪽에');
        await option('작은 단추');
        await option('어두운 악보');
        expect(tester.getSize(rail).width, EditorRail.width);
        await _close(tester);
      });

      testWidgets('an attached keyboard works the editor', (tester) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        view(tester).onEventTapped!(note(tester, 2, 0));
        await _settle(tester);
        Future<void> press(
          LogicalKeyboardKey key, {
          bool control = false,
        }) async {
          if (control) {
            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          }
          await tester.sendKeyEvent(key);
          if (control) {
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          }
          await _settle(tester);
        }

        // Up a step, on to the next note, down a step.
        await press(LogicalKeyboardKey.arrowUp);
        await press(LogicalKeyboardKey.arrowRight);
        await press(LogicalKeyboardKey.arrowDown);
        expect(names(tester, 2), ['g', 'f', 'a', 'b']);
        // 3 is a half note; the note after it gives way.
        await press(LogicalKeyboardKey.digit3);
        expect(
          view(tester).score.parts.first.measures[2].notes.elementAt(1).type,
          'half',
        );
        await press(LogicalKeyboardKey.keyZ, control: true);
        expect(
          view(tester).score.parts.first.measures[2].notes.elementAt(1).type,
          'quarter',
        );
        // Delete makes the note a rest; N takes the note tool, Escape the
        // select tool again.
        await press(LogicalKeyboardKey.delete);
        expect(names(tester, 2), ['g', 'r', 'a', 'b']);
        await press(LogicalKeyboardKey.keyN);
        expect(view(tester).inputMode, 'place');
        await press(LogicalKeyboardKey.escape);
        expect(view(tester).inputMode, 'select');
        await leave(tester);
      });

      testWidgets('the keys build a chord, and write the chord again', (
        tester,
      ) async {
        await _open(tester, _MemoryStorage(), musicXml: fine);
        view(tester).onEventTapped!(note(tester, 2, 0));
        await _settle(tester);
        await tester.tap(find.byTooltip('건반'));
        await _settle(tester);
        Future<void> key(String name) async {
          await tester.tap(find.byTooltip(name));
          await _settle(tester);
        }

        expect(
          tester
              .widget<KeyboardButton>(
                find.widgetWithIcon(KeyboardButton, Icons.replay_rounded),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('화음 쌓기'));
        await _settle(tester);
        // C, then E and G on it: the cursor stays on the note.
        await key('C4');
        await key('E4');
        await key('G4');
        expect(names(tester, 2), ['c+e+g', 'g', 'a', 'b']);
        expect(view(tester).selectedNoteAddress, note(tester, 2, 0));

        // The arrow goes on; the chord built is written again there.
        await tester.tap(find.byTooltip('다음 음'));
        await _settle(tester);
        await tester.tap(find.byTooltip('직전 화음 다시 넣기'));
        await _settle(tester);
        expect(names(tester, 2), ['c+e+g', 'c+e+g', 'a', 'b']);

        // The keys are wider and narrower by one button.
        final before = tester.widget<PianoKeyboard>(find.byType(PianoKeyboard));
        await tester.tap(find.byTooltip('건반 폭'));
        await _settle(tester);
        expect(
          tester.widget<PianoKeyboard>(find.byType(PianoKeyboard)).keyWidth,
          isNot(before.keyWidth),
        );
        await leave(tester);
      });
    });

    testWidgets('an edit engraves the line it is in and no other', (
      tester,
    ) async {
      // Six bars of a single staff, written as three lines of two bars.
      String bar(String steps) => [
        for (final step in steps.split(''))
          '<note><pitch><step>$step</step><octave>4</octave></pitch>'
              '<duration>1</duration><voice>1</voice><type>quarter</type></note>',
      ].join();
      final long =
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
          '<measure number="1"><attributes><divisions>1</divisions>'
          '<key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>${bar('CDEF')}</measure>'
          '${[for (var i = 2; i <= 6; i++) '<measure number="$i">${i.isOdd ? '<print new-system="yes"/>' : ''}${bar('GABC')}</measure>'].join()}'
          '</part></score-partwise>';
      await _open(
        tester,
        _MemoryStorage(),
        musicXml: long,
        size: const Size(400, 800),
      );

      final before = view(tester).engravingChunks!;
      expect(before, hasLength(3));
      expect(view(tester).engravingXml, isNull);
      expect(view(tester).score.parts.first.measures, hasLength(6));

      // A note of bar 4, in the second line.
      view(tester).onEventTapped!(note(tester, 3, 0));
      await _settle(tester);
      await _tapTool(tester, '한 칸 위');

      final after = view(tester).engravingChunks!;
      expect(identical(after[0], before[0]), isTrue);
      expect(identical(after[2], before[2]), isTrue);
      expect(after[1], isNot(before[1]));
      expect(
        view(tester).score.parts.first.measures[3].notes.first.pitch?.step,
        PitchStep.a,
      );
      // Undo brings the line back as it was read before.
      await tester.tap(find.byTooltip('실행 취소'));
      await _settle(tester);
      expect(view(tester).engravingChunks![1], before[1]);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await _close(tester);
    });

    testWidgets('the lines are those of the score, not the editor\'s own', (
      tester,
    ) async {
      String bar(String steps) => [
        for (final step in steps.split(''))
          '<note><pitch><step>$step</step><octave>4</octave></pitch>'
              '<duration>1</duration><voice>1</voice><type>quarter</type></note>',
      ].join();
      String score({required bool written}) =>
          '<score-partwise version="4.0"><part-list><score-part id="P1">'
          '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
          '<measure number="1"><attributes><divisions>1</divisions>'
          '<key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>'
          '<clef><sign>G</sign><line>2</line></clef></attributes>${bar('CDEF')}</measure>'
          '${[for (var i = 2; i <= 8; i++) '<measure number="$i">${written && i == 5 ? '<print new-system="yes"/>' : ''}${bar('GABC')}</measure>'].join()}'
          '</part></score-partwise>';
      List<int> barsPerLine(WidgetTester tester) => [
        for (final chunk in view(tester).engravingChunks!)
          XmlDocument.parse(chunk).findAllElements('measure').length,
      ];

      // A score that writes its lines (four bars each) keeps them on a
      // phone too: the page is the viewer's, not a narrower one.
      await _open(
        tester,
        _MemoryStorage(),
        musicXml: score(written: true),
        size: const Size(400, 800),
      );
      expect(barsPerLine(tester), [4, 4]);
      expect(view(tester).engravingPageSize, isNull);
      await _close(tester);

      // A score that writes none has the lines it had where it was read.
      await _open(
        tester,
        _MemoryStorage(),
        musicXml: score(written: false),
        lineStarts: const [0, 3, 6],
        size: const Size(400, 800),
      );
      expect(barsPerLine(tester), [3, 3, 2]);
      // With a bar more, as many bars to a line as before.
      await _tapTool(tester, '다음 마디 추가');
      expect(barsPerLine(tester), [3, 3, 3]);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await tester.tap(find.text('버리기'));
      await _settle(tester);
      await _close(tester);
    });

    testWidgets('the tools of one palette stand under the score, or the keys', (
      tester,
    ) async {
      await _open(tester, _MemoryStorage());

      expect(find.byType(PianoKeyboard), findsNothing);
      expect(find.byTooltip('스타카토'), findsNothing);
      await _openPalette(tester, '기호');
      expect(find.byTooltip('스타카토'), findsOneWidget);
      // The keyboard takes the palette's place, and goes with its key.
      await tester.tap(find.byTooltip('건반'));
      await _settle(tester);
      expect(find.byType(PianoKeyboard), findsOneWidget);
      expect(find.byTooltip('스타카토'), findsNothing);
      await tester.tap(find.byTooltip('건반'));
      await _settle(tester);
      expect(find.byType(PianoKeyboard), findsNothing);
      // A palette is put away with its own key.
      await _openPalette(tester, '높이');
      await tester.tap(find.byTooltip('닫기'));
      await _settle(tester);
      expect(find.byTooltip('한 칸 위'), findsNothing);
      await _close(tester);
    });
  });
}
