import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/blank_piano_score.dart';
import 'package:page_a_diddle/features/piano/domain/app_score_element_registry.dart';

void main() {
  test('creates a deterministic measure uid without using the index', () {
    final score = blankPianoScore();
    final part = score.parts.single;

    final first = AppScoreElementRegistry.measureUidFor(
      part: part,
      measureIndex: 0,
    );
    final second = AppScoreElementRegistry.measureUidFor(
      part: part,
      measureIndex: 0,
    );

    expect(first, startsWith('measure:'));
    expect(first, second);
  });

  test('resolves an empty staff position to a Lomse insertion target', () {
    final registry = AppScoreElementRegistry(blankPianoScore());

    final target = registry.resolveStaffPosition(
      partIndex: 0,
      measureIndex: 0,
      staff: 2,
      onsetTicks: 960,
      midi: 48,
    );

    expect(target, isNotNull);
    expect(target!.key.locator.elementKind, 'insertion');
    expect(target.key.locator.partId, 'P1');
    expect(target.key.locator.staff, 2);
    expect(target.key.locator.onsetTicks, 960);
    expect(target.lomseTimeUnits, 64);
    expect(target.nativeCursor, {'instrument': 0, 'staff': 1, 'time': 64});
  });

  test('indexes an existing event through its semantic locator', () {
    final registry = AppScoreElementRegistry(blankPianoScore());
    final key = registry.keyForEvent(
      partIndex: 0,
      measureIndex: 0,
      eventIndex: 0,
    );

    expect(key.id, startsWith('score:'));
    expect(key.locator.elementKind, 'rest');
    expect(key.locator.voice, '1');
    expect(key.locator.onsetTicks, 0);
    expect(key.toJson(), isNot(contains('xml:id')));
    expect(key.toJson(), isNot(contains('imoId')));
  });
}
