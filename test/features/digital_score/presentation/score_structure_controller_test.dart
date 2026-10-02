import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_structure_controller.dart';

void main() {
  late String version;
  late List<(String, PlaybackSequence)> saves;
  late List<Completer<void>> pending;
  var failures = 0;

  ScoreStructureController controller({bool hold = false}) {
    return ScoreStructureController(
      versionId: () => version,
      save: (versionId, sequence) {
        saves.add((versionId, sequence));
        if (!hold) return Future.value();
        final done = Completer<void>();
        pending.add(done);
        return done.future;
      },
      onSaveFailed: () => failures++,
    );
  }

  setUp(() {
    version = 'v1';
    saves = [];
    pending = [];
    failures = 0;
  });

  final verse = PlaybackSequence(
    marks: [SectionMark(startMeasureIndex: 0, name: 'VERSE')],
  );
  final chorus = PlaybackSequence(
    marks: [SectionMark(startMeasureIndex: 0, name: 'CHORUS')],
  );

  test('saves every change in order, to the version it was made on', () async {
    final structure = controller(hold: true)..load(PlaybackSequence.empty);

    structure
      ..update(verse)
      ..update(chorus);
    expect(structure.isSaved, isFalse);
    // The second save waits for the first.
    await Future<void>.delayed(Duration.zero);
    expect(saves.map((s) => s.$2), [verse]);
    version = 'v2';
    pending.first.complete();
    await Future<void>.delayed(Duration.zero);
    pending.last.complete();
    await structure.saving;

    expect(saves, [('v1', verse), ('v1', chorus)]);
    // Saved for v1 while v2 is on screen: not this version's saved order.
    expect(structure.isSaved, isFalse);
  });

  test('undo goes back and saves that too', () async {
    final structure = controller()..load(PlaybackSequence.empty);

    structure.update(verse);
    expect(structure.canUndo, isTrue);
    structure.undo();
    await structure.saving;

    expect(structure.sequence, PlaybackSequence.empty);
    expect(saves.last.$2, PlaybackSequence.empty);
    expect(structure.isSaved, isTrue);
  });

  test('a later line extends the pick; naming ends it', () {
    final structure = controller()
      ..load(PlaybackSequence.empty)
      ..pickLine(4, 7);
    expect((structure.pickStart, structure.pickEnd), (4, 7));

    structure.pickLine(8, 11);
    expect((structure.pickStart, structure.pickEnd), (4, 11));

    // An earlier line starts over.
    structure.pickLine(0, 3);
    expect((structure.pickStart, structure.pickEnd), (0, 3));

    structure.endPick();
    expect(structure.pickingEnd, isFalse);
    structure.pickLine(8, 8);
    expect((structure.pickStart, structure.pickEnd), (8, null));
  });

  test('tapping the line a pick began on takes the pick back', () {
    final structure = controller()
      ..load(PlaybackSequence.empty)
      ..pickLine(4, 7);
    expect(structure.pickStart, 4);
    expect(structure.pickExtended, isFalse);

    structure.pickLine(4, 7);
    expect(
      (structure.pickStart, structure.pickEnd, structure.pickingEnd),
      (null, null, false),
    );

    // Extended over a later line, the first line still takes it all back.
    structure
      ..pickLine(4, 7)
      ..pickLine(8, 11);
    expect(
      (structure.pickStart, structure.pickEnd, structure.pickExtended),
      (4, 11, true),
    );
    structure.pickLine(4, 7);
    expect(structure.pickStart, isNull);

    // After naming, the same line is a fresh pick, not a cancel.
    structure
      ..pickLine(4, 7)
      ..endPick();
    structure.pickLine(4, 7);
    expect((structure.pickStart, structure.pickEnd), (4, 7));
    structure.clearPick();
    expect(structure.pickStart, isNull);
  });

  test('bar edits move sections without saving them', () async {
    final structure = controller()..load(verse);

    structure.update(verse.copyWith(steps: [PlaybackStep(sectionId: 'm0')]));
    await structure.saving;
    saves.clear();
    expect(structure.canUndo, isTrue);
    structure.followMeasureEdits([0, 1], [5, 0, 1]);
    await structure.saving;
    // Undo would bring back an order for bars that moved.
    expect(structure.canUndo, isFalse);

    expect(structure.sequence.marks.single.startMeasureIndex, 1);
    expect(saves, isEmpty);
    expect(structure.isSaved, isFalse);
    structure.markSaved();
    expect(structure.isSaved, isTrue);
  });

  test('a failed save is reported', () async {
    final structure = ScoreStructureController(
      versionId: () => version,
      save: (_, _) => Future.error(StateError('disk full')),
      onSaveFailed: () => failures++,
    )..load(PlaybackSequence.empty);

    structure.update(verse);
    await structure.saving;

    expect(failures, 1);
    expect(structure.isSaved, isFalse);
  });
}
