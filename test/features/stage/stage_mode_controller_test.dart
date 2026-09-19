import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/stage/data/stage_mode_controller.dart';

void main() {
  test('여러 Stage Viewer 사이에서 화면 유지 상태를 공유한다', () async {
    var wakeEnabled = 0;
    var wakeDisabled = 0;
    var fullscreenEntered = 0;
    var fullscreenExited = 0;
    final controller = StageModeController(
      enableWakeLock: () async => wakeEnabled++,
      disableWakeLock: () async => wakeDisabled++,
      enterFullscreen: () async => fullscreenEntered++,
      exitFullscreen: () async => fullscreenExited++,
    );

    await controller.enter();
    await controller.enter();
    await controller.exit();

    expect(wakeEnabled, 1);
    expect(fullscreenEntered, 1);
    expect(wakeDisabled, 0);
    expect(fullscreenExited, 0);

    await controller.exit();

    expect(wakeDisabled, 1);
    expect(fullscreenExited, 1);
  });

  test('진입 실패 뒤에도 종료 정리를 실행한다', () async {
    var disabled = false;
    var exited = false;
    final controller = StageModeController(
      enableWakeLock: () async => throw StateError('failed'),
      disableWakeLock: () async => disabled = true,
      enterFullscreen: () async {},
      exitFullscreen: () async => exited = true,
    );

    await expectLater(controller.enter(), throwsStateError);
    await controller.exit();

    expect(disabled, isTrue);
    expect(exited, isTrue);
  });
}
