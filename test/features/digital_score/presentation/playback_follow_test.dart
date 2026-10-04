import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/presentation/playback_follow.dart';

void main() {
  const viewport = Size(400, 800);
  const document = Size(400, 3000);

  Offset? follow(Rect bar, {double scale = 1, Offset at = Offset.zero}) {
    return playbackFollowTranslation(
      bar: bar,
      viewport: viewport,
      document: document,
      scale: scale,
      translation: at,
    );
  }

  test('a bar on screen leaves the score where the reader put it', () {
    expect(follow(const Rect.fromLTWH(20, 100, 150, 120)), isNull);
    // Scrolled by the reader, still seen.
    expect(
      follow(const Rect.fromLTWH(20, 900, 150, 120), at: const Offset(0, -700)),
      isNull,
    );
  });

  test('a bar below the screen is brought to just under the top', () {
    final next = follow(const Rect.fromLTWH(20, 1000, 150, 120))!;
    expect(next.dx, 0);
    // The line starts 15% down: the line before it stays readable.
    expect(1000 + next.dy, closeTo(120, 0.01));
  });

  test('a bar above the screen is brought back (a repeat, a seek)', () {
    final next = follow(
      const Rect.fromLTWH(20, 300, 150, 120),
      at: const Offset(0, -2000),
    )!;
    expect(300 + next.dy, closeTo(120, 0.01));
  });

  test('the score never moves past its own edges', () {
    // The first line: the top of the score stays at the top.
    expect(
      follow(const Rect.fromLTWH(20, 40, 150, 120), at: const Offset(0, -500)),
      Offset.zero,
    );
    // The last line: the end of the score stays at the bottom.
    final last = follow(const Rect.fromLTWH(20, 2850, 150, 120))!;
    expect(last.dy, 800 - 3000);
  });

  test('zoomed in, the bar is followed across as well as down', () {
    final next = follow(const Rect.fromLTWH(120, 100, 120, 120), scale: 2)!;
    // On screen the bar starts a little in from the left edge.
    expect(120 * 2 + next.dx, closeTo(400 * 0.08, 0.01));
    expect(next.dy, 0);
  });

  test('a bar taller than the screen is in view when its start is', () {
    expect(follow(const Rect.fromLTWH(0, 0, 400, 500), scale: 2), isNull);
  });
}
