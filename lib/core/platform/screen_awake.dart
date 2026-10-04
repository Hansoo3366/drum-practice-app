import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while something in the app needs it: a score that is
/// being read or played (hands are on the instrument), a conversion that is
/// running. The screen may sleep again when the last holder lets go, so one
/// holder ending does not turn the screen off under another.
abstract final class ScreenAwake {
  static final _holders = <Object>{};

  static Future<void> hold(Object holder) async {
    final first = _holders.isEmpty;
    _holders.add(holder);
    if (first) await _set(true);
  }

  static Future<void> release(Object holder) async {
    if (!_holders.remove(holder)) return;
    if (_holders.isEmpty) await _set(false);
  }

  static Future<void> _set(bool on) async {
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } on Object {
      // No screen to keep on (tests, a platform without the plugin).
    }
  }
}
