import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

final audioEngineProvider = FutureProvider<SoLoud>((ref) async {
  final engine = SoLoud.instance;
  var initialized = false;
  ref.onDispose(() {
    if (initialized) {
      engine.deinit();
    }
  });
  if (!engine.isInitialized) {
    // Smaller buffers keep metronome clicks from being swallowed by the
    // default ~46 ms output buffer while retaining the shared stereo stream.
    await engine.init(bufferSize: 512);
  }
  initialized = true;
  return engine;
});
