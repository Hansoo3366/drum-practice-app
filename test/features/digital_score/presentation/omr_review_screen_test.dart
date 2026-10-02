import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_review_screen.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_proofread_screen.dart';

const _xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
<part id="P1">
<measure number="1"><attributes><divisions>1</divisions><key><fifths>0</fifths></key>
<time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
<note><pitch><step>C</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note>
</measure>
<measure number="2">
<note><pitch><step>D</step><octave>5</octave></pitch><duration>3</duration><voice>1</voice><type>half</type><dot/></note>
</measure>
<measure number="3">
<direction placement="above"><direction-type><words>rn?</words></direction-type></direction>
<note><pitch><step>E</step><octave>5</octave></pitch><duration>4</duration><voice>1</voice><type>whole</type></note>
</measure>
</part></score-partwise>''';

/// A one-pixel PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _bars = [
  OmrReviewBar(
    partIndex: 0,
    measureIndex: 1,
    measure: '2',
    image: 'p1-s1-m2.png',
    focus: (0.3, 0.7),
    issues: [
      OmrReviewIssue(
        rule: 'V001',
        severity: OmrIssueSeverity.high,
        detail: 'measure lasts 3 quarters, time signature wants 4',
      ),
    ],
    suggestions: [
      OmrReviewSuggestion(
        field: 'chords',
        current: 'G',
        suggested: 'G/B',
        confidence: 0.92,
        applied: true,
      ),
    ],
    uncertain: [],
  ),
  OmrReviewBar(
    partIndex: 0,
    measureIndex: 2,
    measure: '3',
    issues: [
      OmrReviewIssue(
        rule: 'A001',
        severity: OmrIssueSeverity.medium,
        detail: 'a colour annotation lay over the measure',
      ),
    ],
    suggestions: [],
    uncertain: [],
  ),
  OmrReviewBar(
    partIndex: 0,
    measureIndex: 0,
    measure: '1',
    issues: [
      // Reported at conversion; this text is no longer in the bar.
      OmrReviewIssue(
        rule: 'L001',
        severity: OmrIssueSeverity.low,
        detail: "leftover text 'DIE'",
      ),
    ],
    suggestions: [],
    uncertain: [],
  ),
  OmrReviewBar(
    partIndex: 0,
    measureIndex: 2,
    measure: '3b',
    issues: [
      OmrReviewIssue(
        rule: 'L001',
        severity: OmrIssueSeverity.low,
        detail: "leftover text 'rn?'",
      ),
    ],
    suggestions: [],
    uncertain: [],
  ),
];

class _MemoryStorage extends SongFileStorage {
  String? reviewState;

  @override
  Future<void> saveOmrReviewState(String songId, String jsonContent) async {
    reviewState = jsonContent;
  }
}

class _Crops implements OmrConvertService {
  final asked = <String>[];

  @override
  Future<Uint8List?> suspectImage(String songId, String name) async {
    asked.add(name);
    return _png;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<List<bool?>> _open(
  WidgetTester tester,
  _MemoryStorage storage,
  _Crops crops, {
  Set<String> checked = const {},
  List<OmrAnnotation> annotations = const [],
  String musicXml = _xml,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final results = <bool?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songFileStorageProvider.overrideWithValue(storage),
        omrConvertServiceProvider.overrideWithValue(crops),
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
                    builder: (_) => OmrReviewScreen(
                      songId: 'song',
                      musicXml: musicXml,
                      catalog: ScoreVersionCatalog.empty,
                      bars: _bars,
                      checked: checked,
                      annotations: annotations,
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

void main() {
  testWidgets('shows a doubted bar with its reasons and the AI suggestion', (
    tester,
  ) async {
    final crops = _Crops();
    await _open(tester, _MemoryStorage(), crops);

    expect(find.text('마디 2'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('확인 0/4'), findsOneWidget);
    expect(find.text('마디 길이가 4분음표 3개인데 박자표는 4개입니다.'), findsOneWidget);
    expect(find.text('코드: G → G/B'), findsOneWidget);
    expect(find.text('확신 92% · AI 보정 버전에 반영됨'), findsOneWidget);
    expect(crops.asked, ['p1-s1-m2.png']);
    // The bar itself is marked in the crop, which shows its neighbours too.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            '${widget.painter.runtimeType}' == '_NeighbourDimmer',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('마디 2 현재 인식'), findsOneWidget);

    await _close(tester);
  });

  testWidgets('accepting a bar remembers it and moves to the next open one', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await _open(tester, storage, _Crops());

    await tester.tap(find.text('문제 없음'));
    await _settle(tester);

    expect(omrReviewChecked(storage.reviewState), {'0:1'});
    expect(find.text('마디 3'), findsOneWidget);
    expect(find.text('확인 1/4'), findsOneWidget);
    expect(find.text('색 필기가 겹친 마디입니다. 가려진 부분은 읽지 못했습니다.'), findsOneWidget);
    // This bar has no crop from the server.
    expect(find.text('원본 조각이 없습니다.'), findsOneWidget);

    await tester.tap(find.byTooltip('이전 마디'));
    await _settle(tester);
    expect(find.text('마디 2'), findsOneWidget);
    await tester.tap(find.text('확인 취소'));
    await _settle(tester);
    expect(omrReviewChecked(storage.reviewState), isEmpty);
    expect(find.text('마디 2'), findsOneWidget);

    await _close(tester);
  });

  testWidgets('opens on the first bar not accepted yet', (tester) async {
    await _open(tester, _MemoryStorage(), _Crops(), checked: {'0:1'});

    expect(find.text('마디 3'), findsOneWidget);
    expect(find.text('확인 1/4'), findsOneWidget);

    await _close(tester);
  });

  testWidgets('a leftover text removed since is no longer a reason', (
    tester,
  ) async {
    await _open(tester, _MemoryStorage(), _Crops());

    await tester.tap(find.byTooltip('다음 마디'));
    await _settle(tester);
    await tester.tap(find.byTooltip('다음 마디'));
    await _settle(tester);
    expect(find.text('마디 1'), findsOneWidget);
    expect(find.text('남은 확인 사항이 없습니다.'), findsOneWidget);
    expect(find.textContaining('DIE'), findsNothing);

    await tester.tap(find.byTooltip('다음 마디'));
    await _settle(tester);
    expect(find.text('읽다 남은 글자가 있습니다: rn?'), findsOneWidget);

    await _close(tester);
  });

  testWidgets('finds a doubted bar again after bars were added or removed', (
    tester,
  ) async {
    const editor = XmlMeasureEditor();
    // The first bar is gone: the conversion's second bar is now the first.
    final edited = editor
        .deleteMeasure(
          _xml,
          const XmlNoteRef(partIndex: 0, measureIndex: 0, noteIndex: 0),
        )
        .xml;
    await _open(tester, _MemoryStorage(), _Crops(), musicXml: edited);

    expect(find.text('마디 2'), findsOneWidget);
    expect(find.bySemanticsLabel('마디 2 현재 인식'), findsOneWidget);
    await tester.tap(find.text('고치기'));
    await _settle(tester);
    expect(
      tester
          .widget<ScoreProofreadScreen>(find.byType(ScoreProofreadScreen))
          .measureIndex,
      0,
    );
    await tester.binding.handlePopRoute();
    await _settle(tester);

    // The bar that was removed has nothing to show.
    await tester.tap(find.byTooltip('다음 마디'));
    await _settle(tester);
    await tester.tap(find.byTooltip('다음 마디'));
    await _settle(tester);
    expect(find.text('마디 1'), findsOneWidget);
    expect(find.text('이 버전에는 없는 마디입니다.'), findsOneWidget);

    await _close(tester);
  });

  testWidgets('lists the annotations taken out of the upload', (tester) async {
    await _open(
      tester,
      _MemoryStorage(),
      _Crops(),
      annotations: const [
        OmrAnnotation(page: 1, highlight: false, colour: 'red', text: '도돌이 무시'),
        OmrAnnotation(page: 2, highlight: true, colour: 'yellow'),
      ],
    );

    await tester.tap(find.byTooltip('분리한 필기'));
    await _settle(tester);

    expect(find.text('분리한 필기 2개'), findsOneWidget);
    expect(find.text('도돌이 무시'), findsOneWidget);
    expect(find.text('빨간 펜 · 1쪽'), findsOneWidget);
    expect(find.text('노란 형광펜'), findsOneWidget);

    await _close(tester);
  });

  testWidgets('fixing opens the proofreading editor on that bar', (
    tester,
  ) async {
    final results = await _open(tester, _MemoryStorage(), _Crops());

    await tester.tap(find.byTooltip('다음 마디'));
    await _settle(tester);
    await tester.tap(find.text('고치기'));
    await _settle(tester);

    expect(find.byType(ScoreProofreadScreen), findsOneWidget);
    final editor = tester.widget<ScoreProofreadScreen>(
      find.byType(ScoreProofreadScreen),
    );
    expect(editor.measureIndex, 2);

    // Leaving both without saving reports that nothing changed.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(results, [false]);

    await _close(tester);
  });
}
