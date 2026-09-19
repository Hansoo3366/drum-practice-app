import 'package:flutter/material.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';

class MetronomeSubdivisionIcon extends StatelessWidget {
  const MetronomeSubdivisionIcon({
    required this.subdivision,
    required this.color,
    super.key,
  });

  final MetronomeSubdivision subdivision;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 28,
      child: Center(
        child: SizedBox(
          width: subdivision.stepsPerBeat >= 4 ? 52 : 40,
          height: 26,
          child: CustomPaint(
            painter: _MetronomeSubdivisionPainter(
              notes: subdivision.stepsPerBeat,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetronomeSubdivisionPainter extends CustomPainter {
  const _MetronomeSubdivisionPainter({
    required this.notes,
    required this.color,
  });

  final int notes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final notePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final beamPaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final baseline = size.height * .78;
    final stemTop = size.height * .20;
    final firstX = notes == 1 ? size.width * .36 : size.width * .12;
    final lastX = notes == 1 ? firstX : size.width * .88;
    final gap = notes == 1 ? 0 : (lastX - firstX) / (notes - 1);
    final stemXs = [
      for (var index = 0; index < notes; index++) firstX + gap * index,
    ];

    for (final stemX in stemXs) {
      canvas.drawLine(
        Offset(stemX + 2.5, baseline - 1),
        Offset(stemX + 2.5, stemTop),
        beamPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(stemX, baseline), width: 8, height: 5.5),
        notePaint,
      );
    }

    if (notes > 1) {
      canvas.drawLine(
        Offset(stemXs.first + 2.5, stemTop),
        Offset(stemXs.last + 2.5, stemTop),
        beamPaint,
      );
      if (notes >= 4) {
        canvas.drawLine(
          Offset(stemXs.first + 2.5, stemTop + 4),
          Offset(stemXs.last + 2.5, stemTop + 4),
          beamPaint,
        );
      }
    }

    if (notes == 3) {
      final bracketPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final bracketY = stemTop - 3;
      canvas.drawLine(
        Offset(stemXs.first, bracketY),
        Offset(stemXs.last + 3, bracketY),
        bracketPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_MetronomeSubdivisionPainter oldDelegate) =>
      oldDelegate.notes != notes || oldDelegate.color != color;
}
