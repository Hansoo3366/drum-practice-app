import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

/// An articulation as it is printed: the mark above a notehead. [name] is a
/// MusicXML articulation name (`staccato`, `staccatissimo`, `tenuto`,
/// `accent`, `strong-accent`) or `fermata`.
class ArticulationIcon extends StatelessWidget {
  const ArticulationIcon({
    required this.name,
    this.size = 22,
    this.color = AppColors.ink,
    super.key,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArticulationPainter(name, color)),
    );
  }
}

class _ArticulationPainter extends CustomPainter {
  const _ArticulationPainter(this.name, this.color);

  final String name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, w * 0.08)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // The notehead the mark belongs to, low in the box.
    canvas.save();
    canvas.translate(w * 0.5, h * 0.8);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.42, height: h * 0.28),
      fill,
    );
    canvas.restore();
    final cx = w * 0.5;
    final top = h * 0.14;
    final mid = h * 0.36;
    switch (name) {
      case 'staccato':
        canvas.drawCircle(Offset(cx, mid), w * 0.09, fill);
      case 'staccatissimo':
        final wedge = Path()
          ..moveTo(cx - w * 0.1, top)
          ..lineTo(cx + w * 0.1, top)
          ..lineTo(cx, h * 0.5)
          ..close();
        canvas.drawPath(wedge, fill);
      case 'tenuto':
        canvas.drawLine(
          Offset(cx - w * 0.24, mid),
          Offset(cx + w * 0.24, mid),
          stroke,
        );
      case 'accent':
        canvas.drawLine(
          Offset(cx - w * 0.26, top),
          Offset(cx + w * 0.26, mid - h * 0.04),
          stroke,
        );
        canvas.drawLine(
          Offset(cx - w * 0.26, h * 0.5),
          Offset(cx + w * 0.26, mid - h * 0.04),
          stroke,
        );
      case 'strong-accent':
        canvas.drawLine(
          Offset(cx - w * 0.22, h * 0.5),
          Offset(cx, top),
          stroke,
        );
        canvas.drawLine(
          Offset(cx + w * 0.22, h * 0.5),
          Offset(cx, top),
          stroke,
        );
      case 'fermata':
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(cx, h * 0.52),
            width: w * 0.64,
            height: h * 0.64,
          ),
          math.pi,
          math.pi,
          false,
          stroke,
        );
        canvas.drawCircle(Offset(cx, h * 0.42), w * 0.07, fill);
    }
  }

  @override
  bool shouldRepaint(_ArticulationPainter oldDelegate) =>
      oldDelegate.name != name || oldDelegate.color != color;
}
