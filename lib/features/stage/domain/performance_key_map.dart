import 'package:flutter/services.dart';
import 'package:page_a_diddle/features/stage/domain/performance_action.dart';

class PerformanceKeyMap {
  const PerformanceKeyMap({
    required this.leftKeyIds,
    required this.rightKeyIds,
    required this.playPauseKeyIds,
    required this.loopKeyIds,
  });

  factory PerformanceKeyMap.defaults() {
    return PerformanceKeyMap(
      leftKeyIds: {
        LogicalKeyboardKey.arrowLeft.keyId,
        LogicalKeyboardKey.pageUp.keyId,
      },
      rightKeyIds: {
        LogicalKeyboardKey.arrowRight.keyId,
        LogicalKeyboardKey.pageDown.keyId,
        LogicalKeyboardKey.space.keyId,
      },
      playPauseKeyIds: {
        LogicalKeyboardKey.keyP.keyId,
        LogicalKeyboardKey.mediaPlayPause.keyId,
      },
      loopKeyIds: {LogicalKeyboardKey.keyL.keyId},
    );
  }

  factory PerformanceKeyMap.fromJson(Map<String, dynamic> json) {
    final defaults = PerformanceKeyMap.defaults();
    return PerformanceKeyMap(
      leftKeyIds: _readIds(json['left']) ?? defaults.leftKeyIds,
      rightKeyIds: _readIds(json['right']) ?? defaults.rightKeyIds,
      playPauseKeyIds: _readIds(json['playPause']) ?? defaults.playPauseKeyIds,
      loopKeyIds: _readIds(json['loop']) ?? defaults.loopKeyIds,
    );
  }

  final Set<int> leftKeyIds;
  final Set<int> rightKeyIds;
  final Set<int> playPauseKeyIds;
  final Set<int> loopKeyIds;

  PedalSlot? slotFor(int keyId) {
    if (leftKeyIds.contains(keyId)) {
      return PedalSlot.left;
    }
    if (rightKeyIds.contains(keyId)) {
      return PedalSlot.right;
    }
    return null;
  }

  PerformanceAction? directActionFor(int keyId) {
    if (playPauseKeyIds.contains(keyId)) {
      return PerformanceAction.playPause;
    }
    if (loopKeyIds.contains(keyId)) {
      return PerformanceAction.toggleLoop;
    }
    return null;
  }

  PerformanceKeyMap assign({
    required int keyId,
    PedalSlot? slot,
    PerformanceAction? action,
  }) {
    final left = slot == PedalSlot.left
        ? {keyId}
        : ({...leftKeyIds}..remove(keyId));
    final right = slot == PedalSlot.right
        ? {keyId}
        : ({...rightKeyIds}..remove(keyId));
    final playPause = action == PerformanceAction.playPause
        ? {keyId}
        : ({...playPauseKeyIds}..remove(keyId));
    final loop = action == PerformanceAction.toggleLoop
        ? {keyId}
        : ({...loopKeyIds}..remove(keyId));
    return PerformanceKeyMap(
      leftKeyIds: left,
      rightKeyIds: right,
      playPauseKeyIds: playPause,
      loopKeyIds: loop,
    );
  }

  String labelFor(Set<int> keyIds) {
    if (keyIds.isEmpty) {
      return '없음';
    }
    return keyIds.map(_labelForId).join(', ');
  }

  Map<String, Object> toJson() {
    return {
      'left': leftKeyIds.toList(),
      'right': rightKeyIds.toList(),
      'playPause': playPauseKeyIds.toList(),
      'loop': loopKeyIds.toList(),
    };
  }

  static bool isModifier(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.fn;
  }

  static Set<int>? _readIds(Object? value) {
    if (value is! Iterable<dynamic>) {
      return null;
    }
    return {
      for (final item in value)
        if (item is int) item,
    };
  }

  static String _labelForId(int keyId) {
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    final label = key?.keyLabel.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
    return key?.debugName ?? '키';
  }
}
