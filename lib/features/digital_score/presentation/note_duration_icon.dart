import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

/// Compact note or rest glyph for duration chips.
class NoteDurationIcon extends StatelessWidget {
  const NoteDurationIcon({
    required this.durationType,
    this.rest = false,
    this.size = 22,
    this.color = AppColors.ink,
    super.key,
  });

  final String durationType;
  final bool rest;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DurationPainter(
          durationType: durationType,
          rest: rest,
          color: color,
        ),
      ),
    );
  }
}

class _DurationPainter extends CustomPainter {
  const _DurationPainter({
    required this.durationType,
    required this.rest,
    required this.color,
  });

  final String durationType;
  final bool rest;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    if (rest) {
      _paintRest(canvas, size, paint);
    } else {
      _paintNote(canvas, size, paint);
    }
  }

  void _paintNote(Canvas canvas, Size size, Paint paint) {
    final cx = size.width * 0.38;
    final cy = size.height * 0.62;
    final rx = size.width * 0.22;
    final ry = size.height * 0.16;
    final open = durationType == 'whole' || durationType == 'half';
    if (open) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.8;
    } else {
      paint.style = PaintingStyle.fill;
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2),
      paint,
    );
    if (durationType == 'whole') return;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.6;
    final stemTop = size.height * 0.12;
    canvas.drawLine(
      Offset(cx + rx * 0.85, cy),
      Offset(cx + rx * 0.85, stemTop),
      paint,
    );
    if (durationType == 'eighth' || durationType == '16th') {
      paint.style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(cx + rx * 0.85, stemTop)
        ..quadraticBezierTo(
          cx + rx * 2.1,
          stemTop + size.height * 0.12,
          cx + rx * 0.95,
          stemTop + size.height * 0.28,
        )
        ..quadraticBezierTo(
          cx + rx * 1.7,
          stemTop + size.height * 0.16,
          cx + rx * 0.85,
          stemTop + size.height * 0.08,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
    if (durationType == '16th') {
      final path2 = Path()
        ..moveTo(cx + rx * 0.85, stemTop + size.height * 0.14)
        ..quadraticBezierTo(
          cx + rx * 2.0,
          stemTop + size.height * 0.24,
          cx + rx * 0.95,
          stemTop + size.height * 0.38,
        )
        ..quadraticBezierTo(
          cx + rx * 1.6,
          stemTop + size.height * 0.26,
          cx + rx * 0.85,
          stemTop + size.height * 0.2,
        )
        ..close();
      canvas.drawPath(path2, paint);
    }
  }

  void _paintRest(Canvas canvas, Size size, Paint paint) {
    paint.style = PaintingStyle.fill;
    switch (durationType) {
      case 'whole':
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.25,
            size.height * 0.28,
            size.width * 0.5,
            size.height * 0.14,
          ),
          paint,
        );
      case 'half':
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.25,
            size.height * 0.48,
            size.width * 0.5,
            size.height * 0.14,
          ),
          paint,
        );
      case 'quarter':
        final path = Path()
          ..moveTo(size.width * 0.45, size.height * 0.15)
          ..lineTo(size.width * 0.58, size.height * 0.32)
          ..lineTo(size.width * 0.42, size.height * 0.48)
          ..lineTo(size.width * 0.58, size.height * 0.64)
          ..lineTo(size.width * 0.4, size.height * 0.82)
          ..lineTo(size.width * 0.52, size.height * 0.7)
          ..lineTo(size.width * 0.36, size.height * 0.54)
          ..lineTo(size.width * 0.52, size.height * 0.38)
          ..close();
        canvas.drawPath(path, paint);
      case 'eighth':
        canvas.drawCircle(
          Offset(size.width * 0.38, size.height * 0.62),
          size.width * 0.1,
          paint,
        );
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(size.width * 0.45, size.height * 0.55),
          Offset(size.width * 0.62, size.height * 0.22),
          paint,
        );
      default:
        canvas.drawCircle(
          Offset(size.width * 0.34, size.height * 0.68),
          size.width * 0.08,
          paint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.42, size.height * 0.52),
          size.width * 0.08,
          paint,
        );
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(size.width * 0.48, size.height * 0.48),
          Offset(size.width * 0.64, size.height * 0.18),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _DurationPainter oldDelegate) {
    return oldDelegate.durationType != durationType ||
        oldDelegate.rest != rest ||
        oldDelegate.color != color;
  }
}
