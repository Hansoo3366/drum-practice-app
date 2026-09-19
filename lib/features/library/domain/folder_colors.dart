import 'package:flutter/material.dart';

/// Fixed palette for library folders.
abstract final class FolderColors {
  static const palette = <int>[
    0xFFE85D4C, // coral
    0xFFF0A202, // amber
    0xFF2A9D8F, // teal
    0xFF3D7EA6, // steel blue
    0xFF6B5B95, // violet
    0xFFD45D79, // rose
    0xFF4A7C59, // moss
    0xFF8B6F47, // brown
    0xFF5C6B73, // slate
    0xFFC45C26, // rust
  ];

  static int get defaultColor => palette.first;

  static Color toColor(int argb) => Color(argb);

  static int normalize(int? value) {
    if (value == null) return defaultColor;
    for (final color in palette) {
      if (color == value) return color;
    }
    return defaultColor;
  }
}
