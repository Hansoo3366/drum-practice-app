import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/piano/domain/app_score_element.dart';
import 'package:page_a_diddle/features/piano/domain/lomse_editor_contract.dart';

void main() {
  test('serializes an edit request without engine-owned identifiers', () {
    final target = AppScoreElementKey(
      id: 'note-8f21',
      locator: ScoreEventLocator(
        partId: 'P1',
        measureUid: 'm-0023',
        staff: 2,
        voice: '1',
        onsetTicks: 960,
        elementKind: 'note',
      ),
    );
    final request = LomseEditRequest(
      action: 'set_pitch',
      target: target,
      values: const {'step': 'D', 'octave': 4},
    );

    final decoded = LomseEditRequest.fromJson(request.toJson());

    expect(decoded.action, request.action);
    expect(decoded.target, target);
    expect(decoded.values, request.values);
    expect(request.toJson(), isNot(contains('xml:id')));
    expect(request.toJson(), isNot(contains('imoId')));
  });

  test('rejects an empty command action', () {
    expect(
      () => LomseEditRequest.fromJson({'action': '  '}),
      throwsFormatException,
    );
  });
}
