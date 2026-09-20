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
    final hit = layout.hitStaff(
      point,
      durationType: 'quarter',
      score: score,
    );
    expect(hit, isNotNull);
    expect(hit!.staff, 1);
    expect(hit.ghostCenter.dy, closeTo(
      staffYForMidi(
        hit.midi,
        staffTop: box.trebleStaffTop,
        lineGap: box.lineGap,
        bass: false,
      ),
      0.01,
    ));

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
}
