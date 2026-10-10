part of 'verovio_score_view.dart';

// Selection, play position, ghost note and key names drawn over the score.

class _VerovioOverlayPainter extends CustomPainter {
  const _VerovioOverlayPainter({
    required this.layout,
    required this.chordRects,
    required this.keyNames,
    required this.highlightedMeasureIndex,
    required this.highlightedRange,
    required this.selectedNoteAddress,
    this.alsoSelected = const [],
    required this.playbackMeasure,
    required this.ghostCenter,
    required this.ghostRest,
    required this.ghostLineGap,
    required this.ghostDurationType,
    required this.ghostAlter,
    required this.ghostDots,
    this.ghostLabel,
    this.soundingRange,
    this.viewScale = 1,
    this.handles,
    this.handleRadius = 9,
    required this.caret,
    required this.measureDragTo,
  });

  final NativeScoreLayout layout;
  final List<Rect> chordRects;

  /// Key of each written bar, e.g. "B♭" or "Gm", drawn above the bar.
  final List<String> keyNames;
  final int? highlightedMeasureIndex;
  final ({int start, int end})? highlightedRange;
  final ScoreEventAddress? selectedNoteAddress;

  /// More notes picked along with the selected one: a run of notes.
  final List<ScoreEventAddress> alsoSelected;
  final int? playbackMeasure;
  final Offset? ghostCenter;
  final bool ghostRest;
  final double ghostLineGap;
  final String ghostDurationType;
  final int ghostAlter;
  final int ghostDots;

  /// The pitch of the ghost note, written above the finger over it.
  final String? ghostLabel;

  /// Notes lower or higher than this are marked in red: out of the reach
  /// of the instrument or the voice.
  final ({int low, int high})? soundingRange;

  /// How much the page is magnified, so that what is drawn for a finger
  /// (label, handles) has the same size on screen at any zoom.
  final double viewScale;

  /// The two ends of a run of picked notes, each with a handle to drag.
  final ({
    ScoreEventAddress first,
    Offset firstAt,
    ScoreEventAddress last,
    Offset lastAt,
  })?
  handles;
  final double handleRadius;
  final Rect? caret;
  final int? measureDragTo;

  @override
  void paint(Canvas canvas, Size size) {
    final range = highlightedRange;
    final marked = [
      // A run of bars (picked lines, a section) is one box per line, the
      // lines joined into a block; a single bar is its own box.
      if (range != null)
        ...lineBoxes([
          for (final measure in [
            ...layout.measures,
          ]..sort((a, b) => a.measureIndex.compareTo(b.measureIndex)))
            if (measure.measureIndex >= range.start &&
                measure.measureIndex <= range.end)
              measure.rect,
        ]),
      for (final measure in layout.measures)
        if (measure.measureIndex == highlightedMeasureIndex ||
            measure.measureIndex == playbackMeasure ||
            measure.measureIndex == measureDragTo)
          measure.rect,
    ];
    if (marked.isNotEmpty) {
      // One even tint over all of them: bars next to each other overlap a
      // little, and tinted one by one they would show a darker stripe at
      // every barline.
      final bounds = marked.reduce((a, b) => a.expandToInclude(b));
      canvas.saveLayer(
        bounds,
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
      final fill = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill;
      for (final rect in marked) {
        canvas.drawRect(rect, fill);
      }
      canvas.restore();
    }
    _paintKeyNames(canvas);
    final picked = [?selectedNoteAddress, ...alsoSelected];
    if (picked.isNotEmpty) {
      for (final note in layout.notes) {
        if (!picked.any(
          (address) =>
              note.partIndex == address.partIndex &&
              note.measureIndex == address.measureIndex &&
              note.eventIndex == address.eventIndex,
        )) {
          continue;
        }
        NativeMeasureBox? measure;
        for (final candidate in layout.measures) {
          if (candidate.measureIndex == note.measureIndex) {
            measure = candidate;
            break;
          }
        }
        final gap = measure?.lineGapFor(note.staff) ?? nativeStaffLineGap;
        // Chord members have head-sized boxes; outline exactly that note so
        // a selected chord tone is distinguishable from its neighbours.
        final bounds = note.bounds;
        final rect = bounds != null
            ? bounds.inflate(gap * 0.35)
            : Rect.fromCenter(
                center: note.center,
                width: gap * 3.4,
                height: gap * 2.8,
              );
        final paint = Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, gap * 0.18);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(gap * 0.45)),
          paint,
        );
        if (picked.length == 1) break;
      }
    }
    final inputCaret = caret;
    if (inputCaret != null) {
      final caretPaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(inputCaret, Radius.circular(inputCaret.width)),
        caretPaint,
      );
    }
    _paintOutOfRange(canvas);
    _paintHandles(canvas);
    final ghost = ghostCenter;
    if (ghost == null) return;
    if (ghostRest) {
      _drawGhostRest(canvas, ghost);
    } else {
      _drawGhostNote(canvas, ghost);
      _paintGhostGuide(canvas, ghost);
    }
  }

  /// A red wash over every note the instrument or voice cannot reach.
  void _paintOutOfRange(Canvas canvas) {
    final range = soundingRange;
    if (range == null) return;
    final wash = Paint()..color = const Color(0x66E53935);
    for (final note in layout.notes) {
      final midi = note.midi;
      if (note.isRest || midi == null) continue;
      if (midi >= range.low && midi <= range.high) continue;
      final bounds = note.bounds;
      final rect = bounds != null
          ? bounds.inflate(1.5)
          : Rect.fromCenter(center: note.center, width: 10, height: 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        wash,
      );
    }
  }

  /// A round handle under each end of the run of picked notes, on a stalk
  /// from the staff: what a finger takes to make the run longer or shorter.
  void _paintHandles(Canvas canvas) {
    final ends = handles;
    if (ends == null) return;
    final fill = Paint()..color = AppColors.accent;
    final stalk = Paint()
      ..color = AppColors.accent
      ..strokeWidth = math.max(1.0, handleRadius * 0.22);
    for (final at in [ends.firstAt, ends.lastAt]) {
      final center = at.translate(0, handleRadius);
      canvas.drawLine(at.translate(0, -handleRadius), center, stalk);
      canvas.drawCircle(center, handleRadius, fill);
    }
  }

  /// The line the note to come is on, drawn out to both sides of the
  /// finger, and its name above: the finger covers the note itself.
  void _paintGhostGuide(Canvas canvas, Offset center) {
    final scale = viewScale <= 0 ? 1.0 : viewScale;
    final reach = 36 / scale;
    canvas.drawLine(
      center.translate(-reach, 0),
      center.translate(reach, 0),
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.55)
        ..strokeWidth = 1 / scale,
    );
    final label = ghostLabel;
    if (label == null) return;
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13 / scale,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pad = 5 / scale;
    final box = Rect.fromCenter(
      center: center.translate(0, -52 / scale),
      width: text.width + pad * 2,
      height: text.height + pad,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(6 / scale)),
      Paint()..color = AppColors.accent,
    );
    text.paint(
      canvas,
      Offset(box.center.dx - text.width / 2, box.center.dy - text.height / 2),
    );
  }

  void _drawGhostNote(Canvas canvas, Offset center) {
    final gap = ghostLineGap.clamp(4.0, 18.0).toDouble();
    final color = AppColors.accent.withValues(alpha: 0.78);
    final noteHeadCodePoint = switch (ghostDurationType) {
      'whole' => 0xE0A2,
      'half' => 0xE0A3,
      _ => 0xE0A4,
    };
    final noteHead = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(noteHeadCodePoint),
        style: TextStyle(
          color: color,
          fontFamily: 'Bravura',
          fontSize: gap * 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final noteWidth = math.max(gap, noteHead.width);
    noteHead.paint(
      canvas,
      Offset(center.dx - noteHead.width / 2, center.dy - noteHead.height / 2),
    );

    if (ghostDurationType != 'whole') {
      final stem = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, gap * 0.16)
        ..strokeCap = StrokeCap.square;
      final stemX = center.dx + noteWidth * 0.45;
      final stemTop = center.dy - gap * 3.4;
      canvas.drawLine(Offset(stemX, center.dy), Offset(stemX, stemTop), stem);
      if (ghostDurationType == 'eighth' || ghostDurationType == '16th') {
        final flag = Path()
          ..moveTo(stemX, stemTop)
          ..quadraticBezierTo(
            stemX + gap * 1.15,
            stemTop + gap * 0.35,
            stemX + gap * 0.25,
            stemTop + gap * 0.95,
          );
        canvas.drawPath(flag, stem);
        if (ghostDurationType == '16th') {
          final second = Path()
            ..moveTo(stemX, stemTop + gap * 0.65)
            ..quadraticBezierTo(
              stemX + gap * 1.05,
              stemTop + gap,
              stemX + gap * 0.25,
              stemTop + gap * 1.6,
            );
          canvas.drawPath(second, stem);
        }
      }
    }

    if (ghostDots > 0) {
      canvas.drawCircle(
        Offset(center.dx + noteWidth * 0.85, center.dy),
        math.max(1.4, gap * 0.18),
        Paint()..color = color,
      );
    }

    if (ghostAlter != 0) {
      final accidental = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(ghostAlter > 0 ? 0xE262 : 0xE260),
          style: TextStyle(
            color: color,
            fontFamily: 'Bravura',
            fontSize: gap * 1.65,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      accidental.paint(
        canvas,
        Offset(
          center.dx - noteWidth * 0.9 - accidental.width,
          center.dy - accidental.height * 0.58,
        ),
      );
    }
  }

  void _drawGhostRest(Canvas canvas, Offset center) {
    final gap = ghostLineGap.clamp(4.0, 18.0).toDouble();
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, gap * 0.2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(center.dx - gap * 0.7, center.dy - gap * 0.7)
      ..lineTo(center.dx + gap * 0.6, center.dy - gap * 0.05)
      ..lineTo(center.dx - gap * 0.35, center.dy + gap * 0.55)
      ..lineTo(center.dx + gap * 0.75, center.dy + gap * 0.85);
    canvas.drawPath(path, paint);
  }

  /// Writes the key in a small grey box above the start of the first bar and
  /// of every bar where the key changes. Written on every bar it crowded the
  /// chord line and read as part of the chord before it ("Gm7 F"). It moves
  /// up past a chord symbol it would cover.
  void _paintKeyNames(Canvas canvas) {
    // Bars are in reading order; a line starts where x jumps back. Every
    // name on a line sits above the tallest bar of that line.
    final lineTops = <int, double>{};
    var line = <NativeMeasureBox>[];
    void closeLine() {
      if (line.isEmpty) return;
      final top = line.map((m) => m.rect.top).reduce(math.min);
      for (final m in line) {
        lineTops[m.measureIndex] = top;
      }
      line = [];
    }

    for (final measure in layout.measures) {
      if (line.isNotEmpty && measure.rect.left < line.last.rect.left) {
        closeLine();
      }
      line.add(measure);
    }
    closeLine();
    for (final measure in layout.measures) {
      final index = measure.measureIndex;
      if (index < 0 || index >= keyNames.length) continue;
      if (index > 0 && keyNames[index] == keyNames[index - 1]) continue;
      final text = TextPainter(
        text: TextSpan(
          text: keyNames[index],
          style: const TextStyle(
            color: AppColors.mutedInk,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      const pad = 3.0;
      var box = Rect.fromLTWH(
        measure.rect.left + 2,
        (lineTops[index] ?? measure.rect.top) - text.height - pad * 2 - 2,
        text.width + pad * 2,
        text.height + pad * 2,
      );
      for (var pass = 0; pass < 3; pass++) {
        Rect? hit;
        for (final chord in chordRects) {
          // With room around a text: a section name sits in a frame.
          if (chord.inflate(4).overlaps(box)) {
            hit = chord;
            break;
          }
        }
        if (hit == null) break;
        box = box.shift(Offset(0, hit.top - box.bottom - 1));
      }
      if (box.top < 0) box = box.shift(Offset(0, -box.top));
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(3)),
        Paint()
          ..color = AppColors.mutedInk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      text.paint(canvas, box.topLeft + const Offset(pad, pad));
    }
  }

  @override
  bool shouldRepaint(covariant _VerovioOverlayPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.chordRects != chordRects ||
        !listEquals(oldDelegate.keyNames, keyNames) ||
        oldDelegate.highlightedRange != highlightedRange ||
        oldDelegate.highlightedMeasureIndex != highlightedMeasureIndex ||
        oldDelegate.selectedNoteAddress != selectedNoteAddress ||
        !listEquals(oldDelegate.alsoSelected, alsoSelected) ||
        oldDelegate.playbackMeasure != playbackMeasure ||
        oldDelegate.ghostCenter != ghostCenter ||
        oldDelegate.ghostRest != ghostRest ||
        oldDelegate.ghostLineGap != ghostLineGap ||
        oldDelegate.ghostDurationType != ghostDurationType ||
        oldDelegate.ghostAlter != ghostAlter ||
        oldDelegate.ghostDots != ghostDots ||
        oldDelegate.ghostLabel != ghostLabel ||
        oldDelegate.soundingRange != soundingRange ||
        oldDelegate.viewScale != viewScale ||
        oldDelegate.handles != handles ||
        oldDelegate.handleRadius != handleRadius ||
        oldDelegate.caret != caret ||
        oldDelegate.measureDragTo != measureDragTo;
  }
}

class _ScoreError extends StatelessWidget {
  const _ScoreError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.ink),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
