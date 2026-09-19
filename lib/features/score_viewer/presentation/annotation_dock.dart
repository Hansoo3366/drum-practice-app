import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/features/score_viewer/domain/annotation_stroke.dart';

/// Apple Markup / Adobe Acrobat style — one slim toolbar row.
class AnnotationDock extends StatelessWidget {
  const AnnotationDock({
    required this.color,
    required this.pen,
    required this.canUndo,
    required this.canClear,
    required this.onColor,
    required this.onPen,
    required this.onUndo,
    required this.onClear,
    required this.onDone,
    super.key,
  });

  final Color color;
  final AnnotationPen pen;
  final bool canUndo;
  final bool canClear;
  final ValueChanged<Color> onColor;
  final ValueChanged<AnnotationPen> onPen;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final drawPens = AnnotationPen.values
        .where((option) => !option.isEraser)
        .toList();
    return Material(
      color: const Color(0xF21C1E22),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TinyIcon(
                tooltip: l10n.done,
                icon: Icons.check_rounded,
                onPressed: onDone,
                accent: true,
              ),
              _Divider(),
              for (final option in drawPens)
                _PenNib(
                  pen: option,
                  ink: color,
                  selected: pen == option,
                  onTap: () => onPen(option),
                ),
              _TinyIcon(
                tooltip: l10n.strokeEraser,
                icon: Icons.auto_fix_off_rounded,
                selected: pen.isEraser,
                onPressed: () => onPen(AnnotationPen.eraser),
              ),
              _Divider(),
              for (final swatch in annotationPalette)
                _ColorDot(
                  color: swatch,
                  selected: !pen.isEraser && color == swatch,
                  onTap: () {
                    onColor(swatch);
                    if (pen.isEraser) onPen(AnnotationPen.medium);
                  },
                ),
              _Divider(),
              _TinyIcon(
                tooltip: l10n.undo,
                icon: Icons.undo_rounded,
                onPressed: canUndo ? onUndo : null,
              ),
              _TinyIcon(
                tooltip: l10n.clearAll,
                icon: Icons.delete_outline_rounded,
                onPressed: canClear ? onClear : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0x33FFFFFF),
    );
  }
}

class _TinyIcon extends StatelessWidget {
  const _TinyIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.accent = false,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Keep disabled actions visible on the dark viewer surface. IconButton's
    // inherited disabled color comes from the app's light theme otherwise.
    final foreground = accent || selected
        ? AppColors.accent
        : enabled
        ? Colors.white
        : AppColors.stageMuted;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: selected
            ? AppColors.accent.withValues(alpha: 0.22)
            : Colors.transparent,
        minimumSize: const Size(32, 32),
        maximumSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      // Explicitly set the icon color so a parent light-theme IconTheme cannot
      // turn undo/clear into black glyphs while the dock is disabled.
      icon: Icon(icon, color: foreground),
    );
  }
}

class _PenNib extends StatelessWidget {
  const _PenNib({
    required this.pen,
    required this.ink,
    required this.selected,
    required this.onTap,
  });

  final AnnotationPen pen;
  final Color ink;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = pen.label(context.l10n);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 30,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: CustomPaint(
              size: const Size(16, 18),
              painter: _NibPainter(
                color: ink,
                width: pen.width.clamp(1.2, 8),
                opacity: pen.opacity,
                marker: pen == AnnotationPen.marker,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: context.l10n.color,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : const Color(0x55FFFFFF),
                width: selected ? 2 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NibPainter extends CustomPainter {
  const _NibPainter({
    required this.color,
    required this.width,
    required this.opacity,
    required this.marker,
  });

  final Color color;
  final double width;
  final double opacity;
  final bool marker;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.85)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.35,
        size.width * 0.8,
        size.height * 0.2,
      );
    canvas.drawPath(path, paint);
    if (marker) {
      canvas.drawLine(
        Offset(size.width * 0.15, size.height * 0.72),
        Offset(size.width * 0.55, size.height * 0.72),
        paint..strokeWidth = width * 0.85,
      );
    }
  }

  @override
  bool shouldRepaint(_NibPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.opacity != opacity ||
      oldDelegate.marker != marker;
}
