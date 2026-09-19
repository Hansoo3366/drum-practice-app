import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

typedef StageAction = Future<void> Function();

class StageModeController {
  StageModeController({
    required StageAction enableWakeLock,
    required StageAction disableWakeLock,
    required StageAction enterFullscreen,
    required StageAction exitFullscreen,
  }) : _enableWakeLock = enableWakeLock,
       _disableWakeLock = disableWakeLock,
       _enterFullscreen = enterFullscreen,
       _exitFullscreen = exitFullscreen;

  final StageAction _enableWakeLock;
  final StageAction _disableWakeLock;
  final StageAction _enterFullscreen;
  final StageAction _exitFullscreen;
  Future<void> _pending = Future.value();
  int _users = 0;

  Future<void> enter() {
    _users++;
    if (_users > 1) return _pending;
    return _enqueue(() async {
      await _enableWakeLock();
      await _enterFullscreen();
    });
  }

  Future<void> exit() {
    if (_users == 0) return _pending;
    _users--;
    if (_users > 0) return _pending;
    return _enqueue(() async {
      await _exitFullscreen();
      await _disableWakeLock();
    });
  }

  Future<void> _enqueue(StageAction action) {
    final operation = _pending.then(
      (_) => action(),
      onError: (_, _) => action(),
    );
    _pending = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}

final stageModeControllerProvider = Provider<StageModeController>((ref) {
  return StageModeController(
    enableWakeLock: WakelockPlus.enable,
    disableWakeLock: WakelockPlus.disable,
    // 뷰어 UI는 일반 악보와 동일하게 두고, 공연 모드에서는 화면만 꺼지지 않게 한다.
    enterFullscreen: () async {},
    exitFullscreen: () async {},
  );
});
