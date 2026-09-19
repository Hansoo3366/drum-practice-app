import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

import 'package:page_a_diddle/l10n/app_localizations.dart';

enum AnnotationPen {
  fine(1.6, 1),
  medium(3, 1),
  bold(6, 1),
  marker(14, 0.38),
  eraser(22, 1);

  const AnnotationPen(this.width, this.opacity);

  final double width;
  final double opacity;

  bool get isEraser => this == AnnotationPen.eraser;

  String label(AppLocalizations l10n) => switch (this) {
    AnnotationPen.fine => l10n.strokeThin,
    AnnotationPen.medium => l10n.strokeMedium,
    AnnotationPen.bold => l10n.strokeThick,
    AnnotationPen.marker => l10n.strokeHighlight,
    AnnotationPen.eraser => l10n.strokeEraser,
  };
}

const annotationPalette = <Color>[
  AppColors.accent,
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
  Color(0xFF212121),
  Color(0xFFFFFFFF),
];

class AnnotationStroke {
  const AnnotationStroke({
    required this.points,
    required this.color,
    required this.width,
    this.opacity = 1,
    this.eraser = false,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final double opacity;
  final bool eraser;

  AnnotationStroke copyWithPoints(List<Offset> points) {
    return AnnotationStroke(
      points: points,
      color: color,
      width: width,
      opacity: opacity,
      eraser: eraser,
    );
  }

  Map<String, dynamic> toJson() => {
    'c': color.toARGB32(),
    'w': width,
    'o': opacity,
    'e': eraser,
    'p': points.map((p) => [p.dx, p.dy]).toList(),
  };

  static Offset? _parsePoint(Object? raw) {
    if (raw is! List || raw.length < 2) {
      return null;
    }
    final x = raw[0];
    final y = raw[1];
    if (x is! num || y is! num) {
      return null;
    }
    final dx = x.toDouble();
    final dy = y.toDouble();
    if (!dx.isFinite || !dy.isFinite) {
      return null;
    }
    return Offset(dx, dy);
  }

  static List<Offset>? _parsePoints(Object? raw) {
    if (raw is! List) {
      return null;
    }
    final points = [
      for (final point in raw)
        if (_parsePoint(point) case final parsed?) parsed,
    ];
    return points.isEmpty ? null : points;
  }

  static AnnotationStroke? tryParse(Object? raw) {
    if (raw is List) {
      final points = _parsePoints(raw);
      if (points == null) {
        return null;
      }
      return AnnotationStroke(
        points: points,
        color: AppColors.accent,
        width: AnnotationPen.medium.width,
      );
    }
    if (raw is! Map) {
      return null;
    }
    final map = raw;
    final points = _parsePoints(raw['p']);
    if (points == null) {
      return null;
    }
    final colorValue = map['c'];
    final colorNumber = colorValue is num ? colorValue.toDouble() : null;
    final color = colorNumber == null || !colorNumber.isFinite
        ? AppColors.accent
        : Color(colorNumber.toInt() & 0xFFFFFFFF);
    final rawWidth = map['w'] is num ? map['w'] as num : null;
    final widthValue = rawWidth?.toDouble();
    final width = widthValue == null || !widthValue.isFinite
        ? AnnotationPen.medium.width
        : widthValue.clamp(0.5, 64).toDouble();
    final rawOpacity = map['o'];
    final opacityValue = rawOpacity is num ? rawOpacity.toDouble() : 1.0;
    final opacity = opacityValue.isFinite ? opacityValue : 1.0;
    final eraser = map['e'] == true;
    return AnnotationStroke(
      points: points,
      color: color,
      width: width,
      opacity: opacity.clamp(0.05, 1),
      eraser: eraser,
    );
  }
}
