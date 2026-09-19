import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/stage/domain/pedal_gesture_interpreter.dart';
import 'package:page_a_diddle/features/stage/domain/performance_action.dart';

void main() {
  late PedalGestureInterpreter interpreter;
  final start = DateTime(2026, 8, 20, 14, 40);

  setUp(() {
    interpreter = PedalGestureInterpreter();
  });

  test('짧은 왼쪽 입력은 이전 페이지가 된다', () {
    expect(interpreter.onDown(PedalSlot.left, start), isNull);
    expect(
      interpreter.onUp(
        PedalSlot.left,
        start.add(const Duration(milliseconds: 80)),
      ),
      isNull,
    );
    expect(
      interpreter.flushPending(
        PedalSlot.left,
        start.add(const Duration(milliseconds: 430)),
      ),
      PerformanceAction.previousPage,
    );
  });

  test('짧은 오른쪽 입력은 다음 페이지가 된다', () {
    expect(interpreter.onDown(PedalSlot.right, start), isNull);
    expect(
      interpreter.onUp(
        PedalSlot.right,
        start.add(const Duration(milliseconds: 80)),
      ),
      isNull,
    );
    expect(
      interpreter.flushPending(
        PedalSlot.right,
        start.add(const Duration(milliseconds: 430)),
      ),
      PerformanceAction.nextPage,
    );
  });

  test('같은 페달 두 번은 반복이다', () {
    interpreter.onDown(PedalSlot.right, start);
    interpreter.onUp(
      PedalSlot.right,
      start.add(const Duration(milliseconds: 80)),
    );
    expect(
      interpreter.onDown(
        PedalSlot.right,
        start.add(const Duration(milliseconds: 200)),
      ),
      PerformanceAction.toggleLoop,
    );
    expect(
      interpreter.flushPending(
        PedalSlot.right,
        start.add(const Duration(milliseconds: 600)),
      ),
      isNull,
    );
  });

  test('길게 누르면 재생/일시정지다', () {
    interpreter.onDown(PedalSlot.left, start);
    expect(
      interpreter.onHeld(
        PedalSlot.left,
        start.add(const Duration(milliseconds: 500)),
      ),
      PerformanceAction.playPause,
    );
    expect(
      interpreter.onUp(
        PedalSlot.left,
        start.add(const Duration(milliseconds: 560)),
      ),
      isNull,
    );
  });

  test('길게 누른 채 떼도 재생/일시정지다', () {
    interpreter.onDown(PedalSlot.right, start);
    expect(
      interpreter.onUp(
        PedalSlot.right,
        start.add(const Duration(milliseconds: 620)),
      ),
      PerformanceAction.playPause,
    );
  });
}
