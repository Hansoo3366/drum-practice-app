import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_playback_bar.dart';

void main() {
  testWidgets('large text keeps the seek control and clocks visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        const ScorePlaybackBar(
          state: ScorePlaybackState(
            ready: true,
            currentTimeMs: 65000,
            durationMs: 125000,
          ),
          onPlayPause: _noop,
          onStop: _noop,
          onSeek: _noopSeek,
          onEditSequence: _noop,
          onTempo: _noopTempo,
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(Slider)).width,
      greaterThanOrEqualTo(100),
    );
    for (final label in ['1:05', '2:05', '100%']) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      final rect = tester.getRect(text);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
  });

  testWidgets('transport and seek remain usable on a 320px phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        const ScorePlaybackBar(
          state: ScorePlaybackState(ready: true, durationMs: 10000),
          onPlayPause: _noop,
          onStop: _noop,
          onSeek: _noopSeek,
          onEditSequence: _noop,
          onTempo: _noopTempo,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(Slider)).width,
      greaterThanOrEqualTo(100),
    );
  });

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

  testWidgets('playback bar has no accompaniment menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        ScorePlaybackBar(
          state: const ScorePlaybackState(ready: true),
          onPlayPause: _noop,
          onStop: _noop,
          onSeek: _noopSeek,
        ),
      ),
    );

    expect(find.byTooltip('재생 반주'), findsNothing);
    expect(find.byIcon(Icons.piano_rounded), findsNothing);
  });
}

void _noop() {}

void _noopSeek(double _) {}

void _noopTempo(int _) {}

Widget _app(Widget home, {double textScale = 1}) {
  return MaterialApp(
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: appLocalizationDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: home),
  );
}
