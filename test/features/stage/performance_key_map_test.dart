import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/stage/domain/performance_action.dart';
import 'package:page_a_diddle/features/stage/domain/performance_key_map.dart';

void main() {
  test('기본 키는 왼쪽·오른쪽·재생·반복으로 나뉜다', () {
    final map = PerformanceKeyMap.defaults();

    expect(map.slotFor(LogicalKeyboardKey.arrowLeft.keyId), PedalSlot.left);
    expect(map.slotFor(LogicalKeyboardKey.pageDown.keyId), PedalSlot.right);
    expect(
      map.directActionFor(LogicalKeyboardKey.keyP.keyId),
      PerformanceAction.playPause,
    );
    expect(
      map.directActionFor(LogicalKeyboardKey.keyL.keyId),
      PerformanceAction.toggleLoop,
    );
  });

  test('슬롯 키를 바꾸고 JSON으로 복원한다', () {
    final map = PerformanceKeyMap.defaults().assign(
      keyId: LogicalKeyboardKey.keyA.keyId,
      slot: PedalSlot.left,
    );
    final restored = PerformanceKeyMap.fromJson(
      Map<String, dynamic>.from(map.toJson()),
    );

    expect(restored.slotFor(LogicalKeyboardKey.keyA.keyId), PedalSlot.left);
    expect(restored.slotFor(LogicalKeyboardKey.arrowLeft.keyId), isNull);
  });

  test('같은 키는 한 동작에만 남는다', () {
    final map = PerformanceKeyMap.defaults().assign(
      keyId: LogicalKeyboardKey.space.keyId,
      action: PerformanceAction.playPause,
    );

    expect(map.slotFor(LogicalKeyboardKey.space.keyId), isNull);
    expect(
      map.directActionFor(LogicalKeyboardKey.space.keyId),
      PerformanceAction.playPause,
    );
  });
}
