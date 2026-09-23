import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/piano/domain/app_score_element.dart';

void main() {
  test('round-trips an app key without engine ids', () {
    final key = AppScoreElementKey(
      id: 'note-8f21',
      locator: ScoreEventLocator(
        partId: 'P1',
        measureUid: 'm-0023',
        staff: 2,
        voice: '1',
        onsetTicks: 960,
        elementKind: 'note',
        chordIndex: 0,
      ),
    );

    expect(AppScoreElementKey.fromJson(key.toJson()), key);
    expect(key.toJson(), isNot(contains('xml:id')));
    expect(key.toJson(), isNot(contains('imoId')));
  });

  test('locator distinguishes chord members at the same onset', () {
    final first = ScoreEventLocator(
      partId: 'P1',
      measureUid: 'm-1',
      staff: 1,
      voice: '1',
      onsetTicks: 0,
      elementKind: 'chordMember',
      chordIndex: 0,
    );
    final second = ScoreEventLocator(
      partId: 'P1',
      measureUid: 'm-1',
      staff: 1,
      voice: '1',
      onsetTicks: 0,
      elementKind: 'chordMember',
      chordIndex: 1,
    );

    expect(first, isNot(second));
  });

  test('rejects an index-shaped locator without a stable measure uid', () {
    expect(
      () => ScoreEventLocator(
        partId: 'P1',
        measureUid: '',
        staff: 1,
        voice: '1',
        onsetTicks: 0,
        elementKind: 'note',
      ),
      throwsFormatException,
    );
  });
}
