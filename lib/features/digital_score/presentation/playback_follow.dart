import 'dart:math' as math;
import 'dart:ui';

/// Where the score has to be moved so the bar being played is seen, or null
/// when it is in view already. A player's hands are on the keys: the page
/// has to follow the music by itself.
///
/// [bar] is in the score's own coordinates; [translation] and [scale] are
/// how the view shows the score now. The bar's line is put a little below
/// the top, so the line before it stays readable, and the view never moves
/// past the score's edges.
Offset? playbackFollowTranslation({
  required Rect bar,
  required Size viewport,
  required Size document,
  required double scale,
  required Offset translation,
}) {
  final left = bar.left * scale + translation.dx;
  final right = bar.right * scale + translation.dx;
  final top = bar.top * scale + translation.dy;
  final bottom = bar.bottom * scale + translation.dy;
  // A bar larger than the screen is in view when its start is.
  final seenAcross =
      left >= -0.5 && (right <= viewport.width + 0.5 || left <= 0.5);
  final seenDown =
      top >= -0.5 && (bottom <= viewport.height + 0.5 || top <= 0.5);
  if (seenAcross && seenDown) return null;

  var dx = translation.dx;
  var dy = translation.dy;
  if (!seenAcross) {
    final least = math.min(0.0, viewport.width - document.width * scale);
    dx = (viewport.width * 0.08 - bar.left * scale).clamp(least, 0.0);
  }
  if (!seenDown) {
    final least = math.min(0.0, viewport.height - document.height * scale);
    dy = (viewport.height * 0.15 - bar.top * scale).clamp(least, 0.0);
  }
  final next = Offset(dx, dy);
  return next == translation ? null : next;
}
