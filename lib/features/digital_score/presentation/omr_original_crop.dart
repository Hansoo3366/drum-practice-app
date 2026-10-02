import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

/// A piece of the original page with one measure marked in it: its
/// neighbours are faded and its edges drawn.
///
/// The piece shows more than the measure ([focus] is where the measure is,
/// as fractions of the width). With [around], only the measure and that
/// share of its own width on either side are shown, so one bar of a whole
/// staff line fills the space.
class OmrOriginalCrop extends StatelessWidget {
  const OmrOriginalCrop({
    required this.bytes,
    this.focus,
    this.around,
    this.semanticLabel = '원본 악보 조각',
    this.missing,
    super.key,
  });

  final Uint8List bytes;
  final (double, double)? focus;
  final double? around;
  final String semanticLabel;

  /// Shown when the image cannot be decoded.
  final Widget? missing;

  /// The part of the width to show: all of it, or the measure with margins.
  (double, double) get _window {
    final focus = this.focus;
    final around = this.around;
    if (focus == null || around == null) return (0, 1);
    final margin = (focus.$2 - focus.$1) * around;
    return (
      (focus.$1 - margin).clamp(0.0, 1.0),
      (focus.$2 + margin).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (left, right) = _window;
    final width = right - left;
    final focus = this.focus;
    Widget image = Image.memory(
      bytes,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      errorBuilder: (_, _, _) => missing ?? const SizedBox.shrink(),
    );
    if (width < 1) {
      // Only the window: the image is laid out whole and clipped to it.
      image = FittedBox(
        child: ClipRect(
          child: Align(
            alignment: Alignment(left / (1 - width) * 2 - 1, 0),
            widthFactor: width,
            child: Image.memory(
              bytes,
              semanticLabel: semanticLabel,
              errorBuilder: (_, _, _) => missing ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }
    return InteractiveViewer(
      maxScale: 5,
      // The image takes its own shape inside the space, so what is drawn
      // over it lines up with the bars.
      child: Center(
        child: Stack(
          children: [
            image,
            if (focus != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _NeighbourDimmer((
                      (focus.$1 - left) / width,
                      (focus.$2 - left) / width,
                    )),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fades what is beside the measure and marks its edges.
class _NeighbourDimmer extends CustomPainter {
  const _NeighbourDimmer(this.focus);

  final (double, double) focus;

  @override
  void paint(Canvas canvas, Size size) {
    final left = focus.$1 * size.width;
    final right = focus.$2 * size.width;
    final veil = Paint()..color = AppColors.canvas.withValues(alpha: 0.62);
    canvas
      ..drawRect(Rect.fromLTRB(0, 0, left, size.height), veil)
      ..drawRect(Rect.fromLTRB(right, 0, size.width, size.height), veil);
    final edge = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.5;
    canvas
      ..drawLine(Offset(left, 0), Offset(left, size.height), edge)
      ..drawLine(Offset(right, 0), Offset(right, size.height), edge);
  }

  @override
  bool shouldRepaint(_NeighbourDimmer old) => old.focus != focus;
}
