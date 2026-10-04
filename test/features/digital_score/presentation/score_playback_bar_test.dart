import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_playback_bar.dart';

void main() {
  testWidgets('the practice tempo is a number to press, on a phone too', (
    tester,
  ) async {
    // A narrow phone: the bar with every control still fits.
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final asked = <int>[];
    var percent = 100;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Align(
            alignment: Alignment.bottomCenter,
            child: ScorePlaybackBar(
              state: const ScorePlaybackState(ready: true, durationMs: 10000),
              onPlayPause: _noop,
              onStop: _noop,
              onSeek: _noopSeek,
              onEditSequence: _noop,
              onEditArrangement: _noop,
              tempoPercent: percent,
              onTempo: (value) => setState(() {
                asked.add(value);
                percent = value;
              }),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('100%'));
    await tester.pumpAndSettle();
    expect(find.text('재생 속도'), findsOneWidget);

    await tester.tap(find.byTooltip('-5%'));
    await tester.tap(find.byTooltip('-5%'));
    await tester.pumpAndSettle();
    expect(asked, [95, 90]);
    // The bar behind the sheet shows the tempo that plays.
    expect(find.text('90%'), findsWidgets);

    // Back to the written tempo with one press.
    await tester.tap(find.widgetWithText(TextButton, '100%'));
    await tester.pumpAndSettle();
    expect(asked.last, 100);
  });

  testWidgets('a bar without a tempo callback has no tempo control', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ScorePlaybackBar(
          state: ScorePlaybackState(ready: true),
          onPlayPause: _noop,
          onStop: _noop,
          onSeek: _noopSeek,
        ),
      ),
    );
    expect(find.text('100%'), findsNothing);
  });

  testWidgets('keeps transport controls disabled until the player is ready', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        const ScorePlaybackBar(
          state: ScorePlaybackState(),
          onPlayPause: _noop,
          onStop: _noop,
          onSeek: _noopSeek,
        ),
      ),
    );

    IconButton buttonWithTooltip(String tooltip) {
      return tester
          .widgetList<IconButton>(find.byType(IconButton))
          .singleWhere((button) => button.tooltip == tooltip);
    }

    expect(buttonWithTooltip('재생').onPressed, isNull);
    expect(buttonWithTooltip('정지').onPressed, isNull);
    expect(find.byTooltip('조옮김'), findsNothing);
    expect(find.byTooltip('재생 반주'), findsNothing);
    expect(find.byTooltip('연주 순서'), findsNothing);
    expect(find.text('1 · 1'), findsOneWidget);
  });

  testWidgets('plays, stops, and seeks on the shared alphaTab timeline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var playPauseCount = 0;
    var stopCount = 0;
    double? seekMs;

    await tester.pumpWidget(
      _app(
        ScorePlaybackBar(
          state: const ScorePlaybackState(
            ready: true,
            playing: true,
            currentTimeMs: 4000,
            durationMs: 10000,
            measureNumber: 3,
            beatIndex: 1,
          ),
          onPlayPause: () => playPauseCount++,
          onStop: () => stopCount++,
          onSeek: (value) => seekMs = value,
        ),
      ),
    );

    expect(find.byTooltip('일시정지'), findsOneWidget);
    expect(find.text('3 · 2'), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);
    expect(find.text('0:10'), findsOneWidget);

    await tester.tap(find.byTooltip('일시정지'));
    await tester.tap(find.byTooltip('정지'));
    await tester.tap(find.byType(Slider));

    expect(playPauseCount, 1);
    expect(stopCount, 1);
    expect(seekMs, isNotNull);
  });

  testWidgets('exposes transpose from the playback bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var transposeCount = 0;

    await tester.pumpWidget(
      _app(
        ScorePlaybackBar(
          state: const ScorePlaybackState(ready: true),
          onPlayPause: _noop,
          onStop: _noop,
          onSeek: _noopSeek,
          onTranspose: () => transposeCount++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('조옮김'));
    expect(transposeCount, 1);
  });

  testWidgets('exposes accompaniment from the playback bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var arrangementCount = 0;

    await tester.pumpWidget(
      _app(
        ScorePlaybackBar(
          state: const ScorePlaybackState(ready: true),
          onPlayPause: _noop,
          onStop: _noop,
          onSeek: _noopSeek,
          onEditArrangement: () => arrangementCount++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('재생 반주'));
    expect(arrangementCount, 1);
  });
}

void _noop() {}

void _noopSeek(double _) {}

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: appLocalizationDelegates,
    home: Scaffold(body: home),
  );
}
