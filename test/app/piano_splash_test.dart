import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/piano_splash.dart';

void main() {
  Widget gate({Duration hold = const Duration(seconds: 2)}) => PianoSplashGate(
    hold: hold,
    fade: const Duration(milliseconds: 300),
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(onPressed: () {}, child: const Text('앱')),
        ),
      ),
    ),
  );

  Finder picture() => find.byKey(const ValueKey('piano-splash'));

  testWidgets('the picture covers the app, then fades away by itself', (
    tester,
  ) async {
    await tester.pumpWidget(gate());

    expect(picture(), findsOneWidget);
    // The app is already built under it.
    expect(find.text('앱'), findsOneWidget);
    final size = tester.getSize(picture());
    expect(size, tester.getSize(find.byType(PianoSplashGate)));

    await tester.pump(const Duration(milliseconds: 1900));
    expect(picture(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(picture(), findsNothing);
  });

  testWidgets('a tap sends it away, and the next tap reaches the app', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      PianoSplashGate(
        hold: const Duration(seconds: 30),
        fade: const Duration(milliseconds: 300),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => pressed++,
                child: const Text('앱'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('앱'), warnIfMissed: false);
    expect(pressed, 0, reason: 'the picture takes the first tap');
    // While it fades it no longer takes taps.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('앱'));
    expect(pressed, 1);
    await tester.pumpAndSettle();
    expect(picture(), findsNothing);
  });

  testWidgets('the picture stays its time from when it is painted', (
    tester,
  ) async {
    // A picture that takes a second to decode must not lose that second.
    final slow = _SlowPicture();
    await tester.pumpWidget(
      PianoSplashGate(
        hold: const Duration(seconds: 2),
        fade: const Duration(milliseconds: 300),
        picture: slow,
        child: const SizedBox(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(slow.arrive);
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 1900));
    expect(picture(), findsOneWidget, reason: 'still inside its time');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(picture(), findsNothing);
  });

  test('warming gives up instead of holding the app back', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // No such asset in tests: it must still return.
    await warmPianoSplash(limit: const Duration(milliseconds: 200));
  });

  testWidgets('leaving before it fades leaves no timer behind', (tester) async {
    await tester.pumpWidget(gate(hold: const Duration(seconds: 30)));
    await tester.pumpWidget(const SizedBox());
    // A pending timer would fail the test at teardown.
  });
}

/// An image that arrives when the test says so.
class _SlowPicture extends ImageProvider<_SlowPicture> {
  final _completer = Completer<ImageInfo>();

  Future<void> arrive() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawPaint(Paint()..color = const Color(0xFFFFAA00));
    final image = await recorder.endRecording().toImage(4, 4);
    _completer.complete(ImageInfo(image: image));
  }

  @override
  Future<_SlowPicture> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _SlowPicture key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_completer.future);
}
