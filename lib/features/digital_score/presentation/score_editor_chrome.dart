import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';

// The parts the score editor's screen is made of, after the entry palette
// of a notation program: a rail of tools beside the score, tools drawn with
// the signs they write, a keyboard under the score, and a bar of transport
// and cursor keys under that.

/// A sign of the music font: its code point and the box its ink fills, in
/// staff spaces from the sign's origin (x to the right, y up), as the font's
/// metadata gives them. A text line of this font is many times taller than
/// a sign, so a sign is placed by this box and not by its line.
@immutable
class MusicGlyphData {
  const MusicGlyphData(
    this.codePoint,
    this.left,
    this.bottom,
    this.right,
    this.top,
  );

  final int codePoint;
  final double left;
  final double bottom;
  final double right;
  final double top;

  double get width => right - left;
  double get height => top - bottom;
}

/// The signs the editor's tools show.
abstract final class MusicGlyphs {
  static const noteWhole = MusicGlyphData(0xE1D2, 0.0, -0.548, 1.836, 0.544);
  static const noteHalfUp = MusicGlyphData(0xE1D3, 0.0, -0.58, 1.364, 3.5);
  static const noteQuarterUp = MusicGlyphData(0xE1D5, 0.0, -0.564, 1.328, 3.5);
  static const note8thUp = MusicGlyphData(0xE1D7, 0.0, -0.552, 2.264, 3.492);
  static const note16thUp = MusicGlyphData(0xE1D9, 0.0, -0.552, 2.324, 3.492);
  static const note32ndUp = MusicGlyphData(0xE1DB, 0.0, -0.552, 2.252, 4.092);
  static const note64thUp = MusicGlyphData(0xE1DD, 0.0, -0.552, 2.252, 4.888);
  static const restWhole = MusicGlyphData(0xE4E3, 0.0, -0.54, 1.128, 0.036);
  static const restHalf = MusicGlyphData(0xE4E4, 0.0, -0.008, 1.128, 0.568);
  static const restQuarter = MusicGlyphData(0xE4E5, 0.004, -1.5, 1.08, 1.492);
  static const rest8th = MusicGlyphData(0xE4E6, 0.0, -1.004, 0.988, 0.696);
  static const rest16th = MusicGlyphData(0xE4E7, 0.0, -2.0, 1.28, 0.716);
  static const rest32nd = MusicGlyphData(0xE4E8, 0.0, -2.0, 1.452, 1.704);
  static const rest64th = MusicGlyphData(0xE4E9, 0.0, -3.012, 1.692, 1.72);
  static const augmentationDot = MusicGlyphData(0xE1E7, 0.0, -0.2, 0.4, 0.2);
  static const accidentalSharp = MusicGlyphData(
    0xE262,
    0.0,
    -1.392,
    0.996,
    1.4,
  );
  static const accidentalFlat = MusicGlyphData(0xE260, 0.0, -0.7, 0.904, 1.756);
  static const accidentalNatural = MusicGlyphData(
    0xE261,
    0.0,
    -1.34,
    0.672,
    1.364,
  );
  static const accidentalDoubleSharp = MusicGlyphData(
    0xE263,
    0.0,
    -0.5,
    0.988,
    0.508,
  );
  static const accidentalDoubleFlat = MusicGlyphData(
    0xE264,
    0.0,
    -0.7,
    1.644,
    1.748,
  );
  static const articStaccatoAbove = MusicGlyphData(
    0xE4A2,
    0.0,
    0.0,
    0.336,
    0.336,
  );
  static const articStaccatissimoAbove = MusicGlyphData(
    0xE4A6,
    0.004,
    -0.008,
    0.4,
    1.172,
  );
  static const articTenutoAbove = MusicGlyphData(
    0xE4A4,
    -0.004,
    0.0,
    1.352,
    0.192,
  );
  static const articAccentAbove = MusicGlyphData(
    0xE4A0,
    0.0,
    0.004,
    1.356,
    0.98,
  );
  static const articMarcatoAbove = MusicGlyphData(
    0xE4AC,
    -0.004,
    -0.004,
    0.94,
    1.012,
  );
  static const fermataAbove = MusicGlyphData(
    0xE4C0,
    0.012,
    -0.012,
    2.42,
    1.316,
  );
  static const breathMarkComma = MusicGlyphData(
    0xE4CE,
    0.004,
    0.008,
    0.608,
    1.004,
  );
  static const dynamicPPP = MusicGlyphData(
    0xE52A,
    -0.368,
    -0.568,
    4.292,
    1.096,
  );
  static const dynamicPP = MusicGlyphData(0xE52B, -0.328, -0.568, 2.912, 1.096);
  static const dynamicPiano = MusicGlyphData(
    0xE520,
    -0.356,
    -0.568,
    1.464,
    1.096,
  );
  static const dynamicMP = MusicGlyphData(0xE52C, -0.08, -0.568, 3.3, 1.096);
  static const dynamicMF = MusicGlyphData(0xE52D, -0.08, -0.66, 3.272, 1.724);
  static const dynamicForte = MusicGlyphData(
    0xE522,
    -0.564,
    -0.608,
    1.456,
    1.776,
  );
  static const dynamicFF = MusicGlyphData(0xE52F, -0.54, -0.608, 2.44, 1.776);
  static const dynamicFFF = MusicGlyphData(0xE530, -0.62, -0.608, 3.32, 1.776);
  static const dynamicSforzato = MusicGlyphData(
    0xE539,
    0.0,
    -0.608,
    2.932,
    1.776,
  );
  static const dynamicFortePiano = MusicGlyphData(
    0xE534,
    -0.564,
    -0.608,
    2.476,
    1.776,
  );
  static const ornamentTrill = MusicGlyphData(0xE566, 0.0, -0.04, 2.084, 1.56);
  static const ornamentMordent = MusicGlyphData(
    0xE56D,
    0.004,
    -0.292,
    2.916,
    1.276,
  );
  static const ornamentShortTrill = MusicGlyphData(0xE56C, 0.0, 0.0, 2.9, 0.98);
  static const ornamentTurn = MusicGlyphData(0xE567, 0.0, 0.0, 1.84, 0.872);
  static const tremolo3 = MusicGlyphData(0xE222, -0.6, -1.12, 0.6, 1.112);
  static const arpeggiatoUp = MusicGlyphData(
    0xE634,
    0.004,
    0.028,
    0.916,
    6.044,
  );
  static const wiggleArpeggiatoUp = MusicGlyphData(
    0xEAA9,
    -0.132,
    0.0,
    1.168,
    0.476,
  );
  static const gClef = MusicGlyphData(0xE050, 0.0, -2.632, 2.684, 4.392);
  static const fClef = MusicGlyphData(0xE062, -0.02, -2.54, 2.736, 1.048);
  static const cClef = MusicGlyphData(0xE05C, 0.0, -2.024, 2.796, 2.024);
  static const repeatLeft = MusicGlyphData(0xE040, 0.0, 0.0, 1.464, 4.0);
  static const repeatRight = MusicGlyphData(0xE041, 0.004, 0.0, 1.468, 4.0);
  static const segno = MusicGlyphData(0xE047, 0.016, -0.108, 2.2, 3.036);
  static const coda = MusicGlyphData(0xE048, -0.016, -0.632, 3.82, 3.592);
  static const keyboardPedalPed = MusicGlyphData(
    0xE650,
    0.0,
    -0.032,
    4.076,
    2.22,
  );
  static const ottavaAlta = MusicGlyphData(0xE511, 0.0, -0.04, 3.54, 1.852);
  static const ottavaBassaVb = MusicGlyphData(0xE51C, 0.0, -0.04, 3.184, 1.852);
  static const ottava = MusicGlyphData(0xE510, 0.0, -0.04, 1.544, 1.852);
  static const tuplet3 = MusicGlyphData(0xE883, 0.04, -0.032, 1.224, 1.5);
  static const tuplet5 = MusicGlyphData(0xE885, 0.04, -0.032, 1.308, 1.492);
  static const tuplet6 = MusicGlyphData(0xE886, 0.041, -0.032, 1.256, 1.5);
  static const tuplet7 = MusicGlyphData(0xE887, 0.12, -0.016, 1.332, 1.488);
  static const graceNoteAcciaccaturaStemUp = MusicGlyphData(
    0xE560,
    0.0,
    -0.332,
    1.428,
    2.096,
  );
  static const barlineSingle = MusicGlyphData(0xE030, 0.0, 0.0, 0.144, 4.0);
  static const barlineDouble = MusicGlyphData(0xE031, 0.0, 0.0, 0.576, 4.0);
  static const barlineFinal = MusicGlyphData(0xE032, 0.0, 0.0, 0.912, 4.0);
  static const timeSigCommon = MusicGlyphData(
    0xE08A,
    0.02,
    -0.996,
    1.696,
    1.004,
  );
  static const dynamicCrescendoHairpin = MusicGlyphData(
    0xE53E,
    0.016,
    0.372,
    2.944,
    1.424,
  );
  static const dynamicDiminuendoHairpin = MusicGlyphData(
    0xE53F,
    0.016,
    0.372,
    2.944,
    1.424,
  );
  static const wiggleGlissando = MusicGlyphData(
    0xEAAF,
    -0.1,
    0.0,
    1.124,
    0.444,
  );
  static const repeat1Bar = MusicGlyphData(0xE500, 0.0, -1.0, 2.128, 1.116);
  static const noteheadBlack = MusicGlyphData(0xE0A4, 0.0, -0.5, 1.18, 0.5);

  /// A note of [type] ("quarter", "16th"), or its rest.
  static MusicGlyphData duration(String type, {bool rest = false}) =>
      switch (type) {
        'whole' => rest ? restWhole : noteWhole,
        'half' => rest ? restHalf : noteHalfUp,
        'eighth' => rest ? rest8th : note8thUp,
        '16th' => rest ? rest16th : note16thUp,
        '32nd' => rest ? rest32nd : note32ndUp,
        '64th' => rest ? rest64th : note64thUp,
        _ => rest ? restQuarter : noteQuarterUp,
      };

  /// The sign for a pitch moved by [alter] semitones.
  static MusicGlyphData accidental(int alter) => switch (alter) {
    2 => accidentalDoubleSharp,
    1 => accidentalSharp,
    -1 => accidentalFlat,
    -2 => accidentalDoubleFlat,
    _ => accidentalNatural,
  };
}

/// A sign of the music font in a square of [size]: as it stands on a staff
/// whose lines are a fifth of the square apart, smaller when it is too
/// large for the square at that size, and larger (up to twice and a half)
/// when it would be too small to tell from another: a dot is still a dot
/// beside a clef, and an accent is still seen.
class MusicGlyph extends StatelessWidget {
  const MusicGlyph(this.glyph, {this.size = 30, this.color, super.key});

  final MusicGlyphData glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph,
          color ?? IconTheme.of(context).color ?? AppColors.ink,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color);

  final MusicGlyphData glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    // A staff space: as on a staff a fifth of the square apart, smaller
    // when the sign is too large for the square at that size.
    final extent = math.max(glyph.width, glyph.height);
    final space = math.min(
      side * 0.92 / extent,
      math.max(side / 5, math.min(side / 2, side * 0.44 / extent)),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: space * 4,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final centerX = (glyph.left + glyph.right) / 2 * space;
    final centerY = (glyph.bottom + glyph.top) / 2 * space;
    painter.paint(
      canvas,
      Offset(size.width / 2 - centerX, size.height / 2 + centerY - baseline),
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// An eraser, for the tool that takes notes away.
class EraserIcon extends StatelessWidget {
  const EraserIcon({this.size = 24, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _EraserPainter(
          color ?? IconTheme.of(context).color ?? AppColors.ink,
        ),
      ),
    );
  }
}

class _EraserPainter extends CustomPainter {
  const _EraserPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, s * 0.07)
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.46);
    canvas.rotate(-math.pi / 4.6);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.74, height: s * 0.4),
      Radius.circular(s * 0.07),
    );
    canvas.drawRRect(body, stroke);
    // The end that rubs.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(-s * 0.37, -s * 0.2, -s * 0.08, s * 0.2),
        topLeft: Radius.circular(s * 0.07),
        bottomLeft: Radius.circular(s * 0.07),
      ),
      fill,
    );
    canvas.restore();
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.88),
      Offset(size.width * 0.8, size.height * 0.88),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_EraserPainter oldDelegate) => oldDelegate.color != color;
}

/// A tie: the curve from one note to the next.
class TieIcon extends StatelessWidget {
  const TieIcon({this.size = 24, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _TiePainter(
          color ?? IconTheme.of(context).color ?? AppColors.ink,
        ),
      ),
    );
  }
}

class _TiePainter extends CustomPainter {
  const _TiePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    for (final x in [w * 0.2, w * 0.8]) {
      canvas.save();
      canvas.translate(x, h * 0.38);
      canvas.rotate(-0.35);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.3, height: h * 0.2),
        fill,
      );
      canvas.restore();
    }
    final curve = Path()
      ..moveTo(w * 0.2, h * 0.58)
      ..quadraticBezierTo(w * 0.5, h * 0.92, w * 0.8, h * 0.58)
      ..quadraticBezierTo(w * 0.5, h * 0.8, w * 0.2, h * 0.58);
    canvas.drawPath(curve, fill);
  }

  @override
  bool shouldRepaint(_TiePainter oldDelegate) => oldDelegate.color != color;
}

/// One tool of the rail or of a palette: a square to tap, with the sign of
/// what it does. The tool in use is marked; a tool that opens more has a
/// corner mark.
class EditorToolButton extends StatelessWidget {
  const EditorToolButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.selected = false,
    this.hasMore = false,
    this.onLongPress,
    this.width = 48,
    this.height = 46,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final bool selected;
  final bool hasMore;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? AppColors.border
        : selected
        ? AppColors.accent
        : AppColors.ink;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: selected
                ? const BorderSide(color: AppColors.accent, width: 1.4)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: width, minHeight: height),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: IconTheme.merge(
                      data: IconThemeData(color: color, size: 24),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                  if (hasMore)
                    Positioned(
                      right: 3,
                      bottom: 3,
                      child: CustomPaint(
                        size: const Size(6, 6),
                        painter: _CornerPainter(color),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) => oldDelegate.color != color;
}

/// The tools beside the score, one under the other. Where the screen is
/// not tall enough for all of them the rail scrolls.
class EditorRail extends StatelessWidget {
  const EditorRail({
    required this.children,
    this.onRight = false,
    this.compact = false,
    super.key,
  });

  final List<Widget> children;

  /// Whether the rail stands at the right of the score: for the hand that
  /// holds the phone, or the one that does not.
  final bool onRight;

  /// Smaller tools, for more of the score.
  final bool compact;

  static const width = 56.0;
  static const compactWidth = 46.0;

  @override
  Widget build(BuildContext context) {
    const line = BorderSide(color: AppColors.border);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Where the tools do not all fit at their size (a small phone
        // with a palette open under the score), they are made smaller
        // before any of them has to be scrolled to.
        final small =
            compact || constraints.maxHeight < children.length * 48.0 + 8;
        return Container(
          width: compact ? compactWidth : width,
          decoration: BoxDecoration(
            color: AppColors.canvas,
            border: onRight
                ? const Border(left: line)
                : const Border(right: line),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final child in children)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: small
                        ? SizedBox(
                            width: 40,
                            height: 38,
                            child: FittedBox(child: child),
                          )
                        : child,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A thin line between groups of tools in the rail.
class EditorRailDivider extends StatelessWidget {
  const EditorRailDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: SizedBox(
      width: 30,
      height: 1,
      child: ColoredBox(color: AppColors.border),
    ),
  );
}

/// Opens a row of choices beside the tool at [anchor] and completes with
/// the one that was picked, or null.
Future<T?> showToolFlyout<T>(
  BuildContext anchor, {
  required List<({T value, String tooltip, Widget child, bool selected})>
  choices,
}) {
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
  final at = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  return showGeneralDialog<T>(
    context: anchor,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 90),
    pageBuilder: (context, _, _) => CustomSingleChildLayout(
      delegate: _FlyoutLayout(at),
      child: Material(
        elevation: 6,
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Wrap(
            spacing: 2,
            runSpacing: 2,
            children: [
              for (final choice in choices)
                EditorToolButton(
                  tooltip: choice.tooltip,
                  selected: choice.selected,
                  onPressed: () => Navigator.of(context).pop(choice.value),
                  child: choice.child,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FlyoutLayout extends SingleChildLayoutDelegate {
  const _FlyoutLayout(this.anchor);

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(120, constraints.maxWidth - anchor.right - 16),
        maxHeight: constraints.maxHeight - 16,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Beside the tool, on the score; kept on the screen.
    final x = math.min(anchor.right + 6, size.width - childSize.width - 8);
    final y = (anchor.center.dy - childSize.height / 2).clamp(
      8.0,
      math.max(8.0, size.height - childSize.height - 8),
    );
    return Offset(math.max(8.0, x), y.toDouble());
  }

  @override
  bool shouldRelayout(_FlyoutLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}

/// A piano keyboard as wide as the screen, from the C of [octave] up. A key
/// names its pitch ("C4", "F#4", middle C being C4) and gives its MIDI
/// number. Two keys over the keys move the keyboard an octave down or up.
class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({
    required this.octave,
    required this.onKey,
    required this.onOctave,
    required this.lowerTooltip,
    required this.higherTooltip,
    this.enabled = true,
    this.height = 112,
    this.keyWidth = 44,
    this.buttons = const [],
    super.key,
  });

  final int octave;
  final ValueChanged<int> onKey;

  /// How wide a white key is at least: as many as fit are shown.
  final double keyWidth;

  /// More buttons after the two for the octave ([KeyboardButton]).
  final List<Widget> buttons;

  /// Asked to show the octave below (-1) or above (+1).
  final ValueChanged<int> onOctave;
  final String lowerTooltip;
  final String higherTooltip;
  final bool enabled;
  final double height;

  static const _white = [0, 2, 4, 5, 7, 9, 11];
  static const _names = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  /// Black keys by the white key they stand after, and their semitone.
  static const _black = [(0, 1), (1, 3), (3, 6), (4, 8), (5, 10)];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Over the keys, not on them: a button on a black key is a key
        // that cannot be played. The strip itself is swept to the side to
        // move the keys an octave.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final speed = details.primaryVelocity ?? 0;
            if (speed.abs() < 120) return;
            // The keys follow the finger: swept to the left, the higher
            // ones come in.
            final by = speed < 0 ? 1 : -1;
            if (octave + by >= 1 && octave + by <= 7) onOctave(by);
          },
          child: ColoredBox(
            color: AppColors.surfaceSoft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  KeyboardButton(
                    tooltip: lowerTooltip,
                    icon: Icons.remove_rounded,
                    onPressed: octave > 1 ? () => onOctave(-1) : null,
                  ),
                  const SizedBox(width: 6),
                  KeyboardButton(
                    tooltip: higherTooltip,
                    icon: Icons.add_rounded,
                    onPressed: octave < 7 ? () => onOctave(1) : null,
                  ),
                  const Spacer(),
                  for (final button in buttons) ...[
                    const SizedBox(width: 6),
                    button,
                  ],
                ],
              ),
            ),
          ),
        ),
        _keys(),
      ],
    );
  }

  Widget _keys() {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // As many white keys as have room to be hit, a whole octave at
          // least.
          final count = (constraints.maxWidth / keyWidth).floor().clamp(7, 22);
          final width = constraints.maxWidth / count;
          Widget key({
            required String name,
            required int midi,
            required bool black,
            Widget? child,
          }) => Tooltip(
            message: name,
            child: Semantics(
              button: true,
              enabled: enabled,
              label: name,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled && midi <= 127 ? () => onKey(midi) : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: black ? const Color(0xFF1B1B1F) : Colors.white,
                    border: Border.all(
                      color: const Color(0xFF8A8A92),
                      width: 0.6,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                  child: child ?? const SizedBox.expand(),
                ),
              ),
            ),
          );
          return Stack(
            children: [
              for (var i = 0; i < count; i++)
                Positioned(
                  left: width * i,
                  top: 0,
                  width: width,
                  height: height,
                  child: key(
                    name: '${_names[i % 7]}${octave + i ~/ 7}',
                    midi: (octave + i ~/ 7 + 1) * 12 + _white[i % 7],
                    black: false,
                    child: i % 7 == 0
                        ? Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'C${octave + i ~/ 7}',
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF55555C),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              for (var i = 0; i < count; i++)
                for (final (after, semitone) in _black)
                  if (i % 7 == after && i + 1 < count)
                    Positioned(
                      left: width * (i + 1) - width * 0.3,
                      top: 0,
                      width: width * 0.6,
                      height: height * 0.6,
                      child: key(
                        name: '${_names[after]}#${octave + i ~/ 7}',
                        midi: (octave + i ~/ 7 + 1) * 12 + semitone,
                        black: true,
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

/// A small button standing on the keyboard: the octave, and what the keys
/// do (a chord, the chord before, how wide they are).
class KeyboardButton extends StatelessWidget {
  const KeyboardButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.glyph,
    super.key,
  });

  final String tooltip;
  final IconData icon;

  /// A sign of the score drawn in place of [icon].
  final MusicGlyphData? glyph;
  final VoidCallback? onPressed;

  /// A mode that is on: drawn light on dark, the other way round.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: selected
              ? Colors.white
              : AppColors.accent.withValues(alpha: enabled ? 0.9 : 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: selected
                ? const BorderSide(color: AppColors.accent, width: 2)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 30,
              child: glyph != null
                  ? MusicGlyph(
                      glyph!,
                      size: 20,
                      color: selected ? AppColors.accent : Colors.white,
                    )
                  : Icon(
                      icon,
                      color: selected ? AppColors.accent : Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A key of the bar under the score: playback, or the cursor.
class TransportButton extends StatelessWidget {
  const TransportButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.selected = false,
    this.compact = false,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool selected;

  /// On a narrow screen the keys stand closer.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? AppColors.border
        : selected
        ? AppColors.accent
        : AppColors.ink;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: compact ? 36 : 44,
              minHeight: 44,
            ),
            child: Center(
              widthFactor: 1,
              child: IconTheme.merge(
                data: IconThemeData(color: color, size: 26),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
