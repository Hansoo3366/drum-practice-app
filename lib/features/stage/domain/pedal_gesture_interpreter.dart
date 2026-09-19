import 'package:page_a_diddle/features/stage/domain/performance_action.dart';

class PedalGestureInterpreter {
  PedalGestureInterpreter({
    this.longPress = const Duration(milliseconds: 500),
    this.doublePress = const Duration(milliseconds: 350),
  });

  final Duration longPress;
  final Duration doublePress;
  final Map<PedalSlot, _PedalState> _states = {
    for (final slot in PedalSlot.values) slot: _PedalState(),
  };

  PerformanceAction? onDown(PedalSlot slot, DateTime now) {
    final state = _states[slot]!;
    if (state.pendingAt != null &&
        now.difference(state.pendingAt!) <= doublePress) {
      state.resetPress();
      state.pendingAt = null;
      state.ignoreUp = true;
      return PerformanceAction.toggleLoop;
    }
    state.downAt = now;
    state.longFired = false;
    state.ignoreUp = false;
    return null;
  }

  PerformanceAction? onHeld(PedalSlot slot, DateTime now) {
    final state = _states[slot]!;
    final downAt = state.downAt;
    if (downAt == null || state.longFired || state.ignoreUp) {
      return null;
    }
    if (now.difference(downAt) < longPress) {
      return null;
    }
    state.longFired = true;
    state.ignoreUp = true;
    state.pendingAt = null;
    return PerformanceAction.playPause;
  }

  PerformanceAction? onUp(PedalSlot slot, DateTime now) {
    final state = _states[slot]!;
    final downAt = state.downAt;
    state.downAt = null;
    if (state.ignoreUp || state.longFired) {
      state.ignoreUp = false;
      state.longFired = false;
      return null;
    }
    if (downAt != null && now.difference(downAt) >= longPress) {
      return PerformanceAction.playPause;
    }
    state.pendingAt = now;
    return null;
  }

  PerformanceAction? flushPending(PedalSlot slot, DateTime now) {
    final state = _states[slot]!;
    final pendingAt = state.pendingAt;
    if (pendingAt == null || now.difference(pendingAt) < doublePress) {
      return null;
    }
    state.pendingAt = null;
    return slot == PedalSlot.left
        ? PerformanceAction.previousPage
        : PerformanceAction.nextPage;
  }
}

class _PedalState {
  DateTime? downAt;
  DateTime? pendingAt;
  bool longFired = false;
  bool ignoreUp = false;

  void resetPress() {
    downAt = null;
    longFired = false;
  }
}
