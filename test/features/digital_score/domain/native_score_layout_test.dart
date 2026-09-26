import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/blank_piano_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/native_score_layout.dart';

void main() {
  test('layouts grand staff measures and hit-tests matching ghost points', () {
    final score = blankPianoScore(title: 'Native');
    final layout = layoutNativeScore(score);
    expect(layout.measures, hasLength(1));
    expect(layout.notes, isNotEmpty);

    final box = layout.measures.first;
    final point = Offset(
      box.contentLeft + box.contentWidth * 0.25,
      box.trebleStaffTop + box.lineGap * 2,
    );
    final hit = layout.hitStaff(point, durationType: 'quarter', score: score);
    expect(hit, isNotNull);
    expect(hit!.staff, 1);
    expect(
      hit.ghostCenter.dy,
      closeTo(
        staffYForMidi(
          hit.midi,
          staffTop: box.trebleStaffTop,
          lineGap: box.lineGap,
          bass: false,
        ),
        0.01,
      ),
    );

    final bassPoint = Offset(
      box.contentLeft + box.contentWidth * 0.5,
      box.bassStaffTop + box.lineGap * 2,
    );
    final bassHit = layout.hitStaff(
      bassPoint,
      durationType: 'quarter',
      score: score,
    );
    expect(bassHit?.staff, 2);
  });

  test('maps a higher touch on the staff to a higher pitch', () {
    final score = blankPianoScore(title: 'Native');
    final layout = layoutNativeScore(score);
    final box = layout.measures.first;

    final higher = midiAtStaffY(
      box.trebleStaffTop - box.lineGap,
      staffTop: box.trebleStaffTop,
      lineGap: box.lineGap,
      bass: false,
    );
    final lower = midiAtStaffY(
      box.trebleStaffTop + box.lineGap,
      staffTop: box.trebleStaffTop,
      lineGap: box.lineGap,
      bass: false,
    );

    expect(higher, greaterThan(lower));
    expect(
      staffYForMidi(
        higher,
        staffTop: box.trebleStaffTop,
        lineGap: box.lineGap,
        bass: false,
      ),
      lessThan(
        staffYForMidi(
          lower,
          staffTop: box.trebleStaffTop,
          lineGap: box.lineGap,
          bass: false,
        ),
      ),
    );
  });

  test('uses the rendered gap midpoint to choose the lower staff', () {
    final score = blankPianoScore(title: 'Native');
    final layout = layoutNativeScore(score);
    final box = layout.measures.first;
    final gapMidpoint = (box.trebleStaffTop + box.bassStaffTop) / 2;

    final hit = layout.hitStaff(
      Offset(box.contentLeft + 12, gapMidpoint + 1),
      durationType: 'quarter',
      score: score,
    );

    expect(hit?.staff, 2);
  });

  test('keeps onset mapping inside rendered measure boundaries', () {
    final box = NativeMeasureBox(
      measureIndex: 0,
      rect: const Rect.fromLTWH(10, 0, 100, 80),
      trebleStaffTop: 20,
      bassStaffTop: 60,
      lineGap: 8,
      contentLeft: 10,
      contentWidth: 100,
      onsetAnchors: const [
        NativeOnsetAnchor(onset: 0, x: 10),
        NativeOnsetAnchor(onset: 16, x: 110),
      ],
    );

    expect(box.onsetForX(10, 16), 0);
    expect(box.onsetForX(60, 16), 8);
    expect(box.onsetForX(110, 16), 16);
    expect(box.xForOnset(0, 16), 10);
    expect(box.xForOnset(16, 16), 110);
  });

  test('fallback treble top line is F5 and bottom line is E4', () {
    const measure = Rect.fromLTWH(0, 0, 200, 200);
    final frame = fallbackGrandStaffFrame(measure);
    final e4 = midiAtStaffY(
      frame.trebleStaffTop,
      staffTop: frame.trebleStaffTop,
      lineGap: frame.lineGap,
      bass: false,
    );
    final f5 = midiAtStaffY(
      frame.trebleStaffTop - 4 * frame.lineGap,
      staffTop: frame.trebleStaffTop,
      lineGap: frame.lineGap,
      bass: false,
    );

    expect(e4, 64);
    expect(f5, 77);
  });

  test('staff hit boxes pin treble E4 and bass A3', () {
    const treble = Rect.fromLTWH(0, 10, 100, 40);
    const bass = Rect.fromLTWH(0, 80, 100, 40);
    final frame = grandStaffFrameFromStaffRects(const [
      treble,
      bass,
    ], const Rect.fromLTWH(0, 0, 100, 140));

    expect(frame.lineGap, 10);
    expect(frame.trebleStaffTop, 50);
    expect(frame.bassStaffTop, 80);
    expect(
      midiAtStaffY(
        frame.bassStaffTop,
        staffTop: frame.bassStaffTop,
        lineGap: frame.lineGap,
        bass: true,
      ),
      57,
    );
  });

  test('onset 0 keeps the first note x instead of averaging with the clef', () {
    final anchors = buildOnsetAnchors(
      contentLeft: 10,
      contentWidth: 100,
      capacity: 4,
      noteXs: {
        0: [40],
        2: [70],
      },
    );

    expect(anchors.firstWhere((anchor) => anchor.onset == 0).x, 40);
    expect(anchors.firstWhere((anchor) => anchor.onset == 2).x, 70);
  });

  test('a tap in the first quarter of the bar stays on beat one', () {
    final score = blankPianoScore(title: 'Beat');
    final layout = NativeScoreLayout(
      contentSize: const Size(200, 120),
      measures: const [
        NativeMeasureBox(
          measureIndex: 0,
          rect: Rect.fromLTWH(0, 0, 200, 120),
          trebleStaffTop: 40,
          bassStaffTop: 90,
          lineGap: 8,
          contentLeft: 0,
          contentWidth: 200,
          onsetAnchors: [
            NativeOnsetAnchor(onset: 0, x: 0),
            NativeOnsetAnchor(onset: 4, x: 200),
          ],
        ),
      ],
      notes: const [],
      systemStarts: const [0],
    );

    final hit = layout.hitStaff(
      const Offset(40, 40),
      durationType: 'quarter',
      score: score,
    );

    expect(hit, isNotNull);
    expect(hit!.onsetTicks, 0);
    expect(hit.staff, 1);
  });
}
