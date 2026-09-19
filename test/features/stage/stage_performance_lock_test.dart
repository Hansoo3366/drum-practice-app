import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/stage/domain/stage_performance_lock.dart';

void main() {
  test('좌우 가장자리만 페이지 이동을 허용한다', () {
    expect(stagePageDeltaForTap(x: 20, width: 100), -1);
    expect(stagePageDeltaForTap(x: 50, width: 100), isNull);
    expect(stagePageDeltaForTap(x: 80, width: 100), 1);
    expect(stagePageDeltaForTap(x: 0, width: 0), isNull);
  });

  test('Stage에서는 편집만 잠그고 메뉴·Zoom은 허용한다', () {
    expect(stageAllowsMenu(true), isTrue);
    expect(stageAllowsEditing(true), isFalse);
    expect(stageAllowsTwoFingerZoom(true), isTrue);

    expect(stageAllowsMenu(false), isTrue);
    expect(stageAllowsEditing(false), isTrue);
    expect(stageAllowsTwoFingerZoom(false), isTrue);
  });
}
