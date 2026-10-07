import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/blank_piano_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
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

  group('pointing at a place on the staff', () {
    // One bar of a single treble staff: its bottom line (E4) at y 100, the
    // lines 10 apart, a rest at x 60 and a chord (C5 over A4) at x 160.
    final score = const MusicXmlCodec().decodeXml(
      '<score-partwise version="4.0"><part-list><score-part id="P1">'
      '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
      '<measure number="1"><attributes><divisions>1</divisions>'
      '<time><beats>4</beats><beat-type>4</beat-type></time>'
      '<clef><sign>G</sign><line>2</line></clef></attributes>'
      '<note><rest/><duration>2</duration><type>half</type></note>'
      '<note><pitch><step>A</step><octave>4</octave></pitch><duration>2</duration><type>half</type></note>'
      '<note><chord/><pitch><step>C</step><octave>5</octave></pitch><duration>2</duration><type>half</type></note>'
      '</measure></part></score-partwise>',
    );
    const layout = NativeScoreLayout(
      contentSize: Size(240, 200),
      measures: [
        NativeMeasureBox(
          measureIndex: 0,
          rect: Rect.fromLTRB(20, 50, 220, 110),
          trebleStaffTop: 100,
          bassStaffTop: 200,
          lineGap: 10,
          contentLeft: 30,
          contentWidth: 180,
        ),
      ],
      notes: [
        NativeNotePlacement(
          partIndex: 0,
          measureIndex: 0,
          eventIndex: 0,
          staff: 1,
          onset: 0,
          midi: null,
          center: Offset(60, 80),
          isRest: true,
        ),
        NativeNotePlacement(
          partIndex: 0,
          measureIndex: 0,
          eventIndex: 1,
          staff: 1,
          onset: 2,
          midi: 69,
          center: Offset(160, 85),
          isRest: false,
        ),
        NativeNotePlacement(
          partIndex: 0,
          measureIndex: 0,
          eventIndex: 2,
          staff: 1,
          onset: 2,
          midi: 72,
          center: Offset(160, 75),
          isRest: false,
        ),
      ],
      systemStarts: [0],
    );

    test('the nearest note or rest in time is meant, on the line touched', () {
      // Near the rest, on the second line from the bottom: G4.
      final place = layout.placeAt(const Offset(70, 91), score: score)!;

      expect((place.eventIndex, place.step, place.octave), (0, PitchStep.g, 4));
      // The note is shown over the rest, on the line and not at the finger.
      expect(place.ghostCenter, const Offset(60, 90));
    });

    test('beside a note is not on the note: a new one is meant there', () {
      // The chord stands at x 160; lines are 10 apart.
      final on = layout.placeAt(const Offset(170, 85), score: score)!;
      final after = layout.placeAt(const Offset(190, 85), score: score)!;
      final before = layout.placeAt(const Offset(130, 85), score: score)!;

      expect((on.beside, on.ghostCenter.dx), (0, 160));
      // The note to come is shown where the finger is, not over the chord.
      expect((after.beside, after.ghostCenter.dx), (1, 190));
      expect((before.beside, before.ghostCenter.dx), (-1, 130));
      expect(after.eventIndex, on.eventIndex);
    });

    test('of a chord the note nearest in height is meant', () {
      final high = layout.placeAt(const Offset(150, 62), score: score)!;
      final low = layout.placeAt(const Offset(150, 96), score: score)!;

      expect((high.eventIndex, high.step, high.octave), (2, PitchStep.f, 5));
      expect((low.eventIndex, low.step, low.octave), (1, PitchStep.f, 4));
    });

    test('a rest that fills its bar takes the note, though it is not drawn', () {
      final empty = const MusicXmlCodec().decodeXml(
        '<score-partwise version="4.0"><part-list><score-part id="P1">'
        '<part-name>Voice</part-name></score-part></part-list><part id="P1">'
        '<measure number="1"><attributes><divisions>1</divisions>'
        '<time><beats>4</beats><beat-type>4</beat-type></time>'
        '<clef><sign>G</sign><line>2</line></clef></attributes>'
        '<harmony><root><root-step>C</root-step></root><kind>major</kind></harmony>'
        '<note><rest measure="yes"/><duration>4</duration><type>whole</type></note>'
        '</measure></part></score-partwise>',
      );
      final bare = NativeScoreLayout(
        contentSize: layout.contentSize,
        measures: layout.measures,
        notes: const [],
        systemStarts: const [0],
      );

      final place = bare.placeAt(const Offset(70, 80), score: empty)!;

      // The rest is the event after the chord symbol; B4 is the middle line.
      expect(
        empty.parts.first.measures.first.events[place.eventIndex],
        isA<MusicNote>(),
      );
      expect((place.step, place.octave), (PitchStep.b, 4));
      expect(place.ghostCenter.dy, 80);
    });

    test('ledger lines above and below the bar still belong to it', () {
      final above = layout.placeAt(const Offset(60, 20), score: score)!;
      final below = layout.placeAt(const Offset(60, 125), score: score)!;

      // Eight steps above the top line (F5).
      expect((above.step, above.octave), (PitchStep.g, 6));
      expect((below.step, below.octave), (PitchStep.g, 3));
      expect(layout.placeAt(const Offset(60, 400), score: score), isNull);
      expect(layout.placeAt(const Offset(400, 80), score: score), isNull);
    });
  });
}
