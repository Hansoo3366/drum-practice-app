import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_playback_bar.dart';

void main() {
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
    expect(find.byTooltip('반주'), findsNothing);
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

    await tester.tap(find.byTooltip('반주'));
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
