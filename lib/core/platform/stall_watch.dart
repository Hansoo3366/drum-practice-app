import 'dart:async';

import 'package:flutter/foundation.dart';

/// Says in the log when the app stood still: a tick that should come every
/// tenth of a second came much later, so nothing was drawn and no touch was
/// answered in between. Debug builds only; QA reads the lines
/// (`[stall] 1840 ms`), and a stall of five seconds is what the system
/// reports as "not responding".
void watchForStalls({Duration report = const Duration(milliseconds: 700)}) {
  if (!kDebugMode) return;
  const tick = Duration(milliseconds: 100);
  var last = DateTime.now();
  Timer.periodic(tick, (_) {
    final now = DateTime.now();
    final late = now.difference(last) - tick;
    last = now;
    if (late >= report) debugPrint('[stall] ${late.inMilliseconds} ms');
  });
}
