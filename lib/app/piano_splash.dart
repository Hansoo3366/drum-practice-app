import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The picture the piano app opens with.
const pianoSplashAsset = 'assets/piano/splash.jpg';

/// Reads [pianoSplashAsset] into the image cache, so the first frame of the app
/// already has it. Until this returns the system's launch screen stays up.
/// Gives up after [limit] (or if the picture cannot be read): the app must
/// start either way.
Future<void> warmPianoSplash({
  Duration limit = const Duration(milliseconds: 1500),
}) {
  final done = Completer<void>();
  final stream = const AssetImage(
    pianoSplashAsset,
  ).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  void finish() {
    if (done.isCompleted) return;
    stream.removeListener(listener);
    done.complete();
  }

  listener = ImageStreamListener(
    (_, _) => finish(),
    onError: (_, _) => finish(),
  );
  stream.addListener(listener);
  return done.future.timeout(limit, onTimeout: finish);
}

/// Shows [pianoSplashAsset] over the whole screen while the app starts, then
/// fades it away. The system's own launch screen can only show an icon, so
/// the picture is drawn here, over [child], which builds underneath it.
///
/// A tap sends it away at once.
class PianoSplashGate extends StatefulWidget {
  const PianoSplashGate({
    super.key,
    required this.child,
    this.hold = const Duration(milliseconds: 1800),
    this.fade = const Duration(milliseconds: 350),
    this.picture = const AssetImage(pianoSplashAsset),
  });

  final Widget child;

  /// How long the picture stays, once it is on the screen, before it starts
  /// to fade. Without a picture the gate opens after this long too.
  final Duration hold;
  final Duration fade;
  final ImageProvider picture;

  @override
  State<PianoSplashGate> createState() => _PianoSplashGateState();
}

class _PianoSplashGateState extends State<PianoSplashGate> {
  var _shown = true;
  var _gone = false;
  var _pictureSeen = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.hold, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    _timer?.cancel();
    if (mounted && _shown) setState(() => _shown = false);
  }

  /// The picture has just been painted: it stays [PianoSplashGate.hold] from
  /// now, however long decoding it took.
  Widget _whenPainted(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (frame != null && !_pictureSeen) {
      _pictureSeen = true;
      _timer?.cancel();
      _timer = Timer(widget.hold, _dismiss);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (!_gone)
            IgnorePointer(
              // Faded out, it must not swallow the first tap on the app.
              ignoring: !_shown,
              child: AnimatedOpacity(
                opacity: _shown ? 1 : 0,
                duration: widget.fade,
                onEnd: () {
                  if (mounted && !_shown) setState(() => _gone = true);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _dismiss,
                  // The picture's own light, until the picture is decoded.
                  child: ColoredBox(
                    key: const ValueKey('piano-splash'),
                    color: const Color(0xFFFFE9C4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The picture is drawn whole on any screen: what a
                        // wide or a very tall screen leaves free is filled
                        // with the picture itself, blurred.
                        ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 28,
                            sigmaY: 28,
                            tileMode: TileMode.clamp,
                          ),
                          child: Image(
                            image: widget.picture,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: _noPicture,
                          ),
                        ),
                        Image(
                          image: widget.picture,
                          fit: BoxFit.contain,
                          frameBuilder: _whenPainted,
                          // A decoration: a screen reader goes straight to
                          // the app.
                          excludeFromSemantics: true,
                          // Without the picture the light alone is shown;
                          // the app must still start.
                          errorBuilder: _noPicture,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _noPicture(BuildContext context, Object error, StackTrace? stack) =>
    const SizedBox.expand();
