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
}
