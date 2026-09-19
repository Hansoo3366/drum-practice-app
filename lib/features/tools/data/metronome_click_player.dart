import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';

/// Shared one-shot metronome clicks + spoken English count-in.
class MetronomeClickPlayer {
  AudioSource? _accent;
  AudioSource? _normal;
  AudioSource? _sub;
  final List<AudioSource?> _counts = List<AudioSource?>.filled(12, null);
  SoundHandle? _handle;
  Future<void>? _loading;
  var _playRequest = 0;

  bool get isReady => _accent != null && _normal != null && _sub != null;

  Future<void> ensureLoaded(SoLoud engine) async {
    if (isReady) {
      return;
    }
    final inFlight = _loading;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final completer = Completer<void>();
    _loading = completer.future;
    try {
      _accent ??= await engine.loadAsset('assets/sounds/click_accent.wav');
      _normal ??= await engine.loadAsset('assets/sounds/click_normal.wav');
      _sub ??= await engine.loadAsset('assets/sounds/click_sub.wav');
      // Load count-in speech before the first tick so a slow disk/network
      // decode cannot drop beat 1 while the periodic timer is already live.
      for (var index = 0; index < _counts.length; index++) {
        try {
          _counts[index] ??= await engine.loadAsset(
            'assets/sounds/count_${index + 1}.wav',
          );
        } on Object catch (_) {
          // Speech is optional; the click assets above remain usable.
        }
      }
      completer.complete();
    } on Object catch (error, stack) {
      completer.completeError(error, stack);
      rethrow;
    } finally {
      _loading = null;
    }
  }

  Future<void> play(
    SoLoud engine,
    MetronomeBeat beat, {
    bool haptics = true,
  }) async {
    final request = ++_playRequest;
    if (beat.accentLevel == MetronomeAccentLevel.mute) {
      return;
    }
    // Count-in: spoken beat numbers only (no click / no subdivisions).
    if (beat.isCountIn) {
      if (beat.isSubdivision) {
        return;
      }
      await ensureLoaded(engine);
      final index = (beat.number - 1).clamp(0, _counts.length - 1);
      try {
        _counts[index] ??= await engine.loadAsset(
          'assets/sounds/count_${index + 1}.wav',
        );
      } on Object {
        // Count-in speech is optional; keep the metronome click available.
      }
      final source = _counts[index];
      if (source == null) {
        return;
      }
      try {
        await _stopPrevious(engine);
        if (request != _playRequest) {
          return;
        }
        final handle = await engine.play(source, volume: 1.0);
        if (request != _playRequest) {
          await _stopHandle(engine, handle);
          return;
        }
        _handle = handle;
        if (haptics) {
          unawaited(
            beat.number == 1
                ? HapticFeedback.mediumImpact()
                : HapticFeedback.selectionClick(),
          );
        }
      } on Object catch (_) {
        // Ignore clicks that finish after stop/dispose.
      }
      return;
    }

    await ensureLoaded(engine);
    final source = beat.isSubdivision
        ? _sub
        : beat.accentLevel == MetronomeAccentLevel.strong
        ? _accent
        : _normal;
    if (source == null) {
      return;
    }

    try {
      await _stopPrevious(engine);
      if (request != _playRequest) {
        return;
      }

      final volume = beat.isSubdivision
          ? 0.45
          : beat.accentLevel == MetronomeAccentLevel.strong
          ? 1.0
          : 0.72;
      final handle = await engine.play(source, volume: volume);
      if (request != _playRequest) {
        await _stopHandle(engine, handle);
        return;
      }
      _handle = handle;

      if (haptics && !beat.isSubdivision) {
        if (beat.accentLevel == MetronomeAccentLevel.strong) {
          unawaited(HapticFeedback.mediumImpact());
        } else {
          unawaited(HapticFeedback.selectionClick());
        }
      }
    } on Object catch (_) {
      // Ignore clicks that finish after stop/dispose.
    }
  }

  Future<void> _stopPrevious(SoLoud engine) async {
    final previous = _handle;
    _handle = null;
    if (previous != null) {
      await _stopHandle(engine, previous);
    }
  }

  Future<void> _stopHandle(SoLoud engine, SoundHandle handle) async {
    if (engine.isInitialized) {
      try {
        if (engine.getIsValidVoiceHandle(handle)) {
          await engine.stop(handle);
        }
      } on Object catch (_) {
        // The voice may finish between validity check and stop.
      }
    }
  }

  Future<void> stop(SoLoud engine) async {
    _playRequest++;
    await _stopPrevious(engine);
  }

  Future<void> dispose(SoLoud engine) async {
    _playRequest++;
    final loading = _loading;
    if (loading != null) {
      try {
        await loading;
      } on Object catch (_) {}
    }
    await _stopPrevious(engine);
    for (final source in [_accent, _normal, _sub, ..._counts]) {
      if (source != null) {
        try {
          await engine.disposeSource(source);
        } on Object catch (_) {}
      }
    }
    _accent = null;
    _normal = null;
    _sub = null;
    for (var i = 0; i < _counts.length; i++) {
      _counts[i] = null;
    }
    _loading = null;
  }
}
