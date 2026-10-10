part of 'verovio_score_view.dart';

// Rendered pages and the geometry read from them: bars, staves, notes.

class _VerovioPage {
  _VerovioPage({
    required this.svg,
    required this.hitMap,
    required this.chords,
    this.staves = const [],
  }) : visibleHeight = visiblePageHeight(hitMap.viewBox.height, [
         for (final hit in hitMap.byType)
           if (hit.type == 'measure') hit.bbox.bottom,
       ]);

  final String svg;
  final PageHitMap hitMap;
  final List<VerovioTextLabel> chords;

  /// The staff lines of every bar of the page, as they were drawn.
  final List<VerovioStaffLines> staves;

  /// Page height in viewBox units, trimmed below the last system.
  final double visibleHeight;
}

/// The boxes that mark a run of bars, one per staff line instead of one per
/// bar: bars of a line differ in height (a high note, a chord above), and
/// marked one by one they make a ragged row of boxes. [bars] are the bars'
/// boxes in playing order.
///
/// Lines that follow one another are joined: the box of a line reaches down
/// to the next, so several lines read as one block, like selected text. A
/// wide gap (the next page) is left open.
@visibleForTesting
List<Rect> lineBoxes(List<Rect> bars) {
  if (bars.isEmpty) return const [];
  final lines = <Rect>[bars.first];
  for (final bar in bars.skip(1)) {
    final line = lines.last;
    // A bar that starts left of where the line has got to, or below it, is on
    // the next line.
    final sameLine = bar.left >= line.left && bar.top < line.bottom;
    if (sameLine) {
      lines[lines.length - 1] = line.expandToInclude(bar);
    } else {
      lines.add(bar);
    }
  }
  for (var i = 0; i + 1 < lines.length; i++) {
    final line = lines[i];
    final next = lines[i + 1];
    final gap = next.top - line.bottom;
    if (gap > 0 && gap <= math.min(line.height, next.height)) {
      lines[i] = Rect.fromLTRB(line.left, line.top, line.right, next.top);
    }
  }
  return lines;
}

/// The screen shows pages as one continuous document. Verovio fills A4
/// pages, so a page whose systems end early would leave a blank band before
/// the next page; stop each page a small margin below its last system.
@visibleForTesting
double visiblePageHeight(double pageHeight, Iterable<double> systemBottoms) {
  if (systemBottoms.isEmpty) return pageHeight;
  final bottom = systemBottoms.reduce(math.max);
  return math.min(pageHeight, bottom + pageHeight * 0.03);
}

@visibleForTesting
String normalizeVerovioSvgForFlutter(String source) {
  final rootViewBox = RegExp(
    r'<svg\b[^>]*\bviewBox="([^"]+)"',
  ).firstMatch(source)?.group(1);
  final definitionMatch = RegExp(
    r'<svg\b(?=[^>]*\bclass="definition-scale")([^>]*)>',
  ).firstMatch(source);
  if (rootViewBox == null || definitionMatch == null) return source;

  final rootSize = _parseSvgViewBoxSize(rootViewBox);
  final definitionViewBox = RegExp(
    r'\bviewBox="([^"]+)"',
  ).firstMatch(definitionMatch.group(0)!)?.group(1);
  final definitionSize = definitionViewBox == null
      ? null
      : _parseSvgViewBoxSize(definitionViewBox);
  if (rootSize == null || definitionSize == null) return source;
  if (definitionSize.width <= 0 || definitionSize.height <= 0) return source;

  final openStart = definitionMatch.start;
  final openEnd = definitionMatch.end;
  final closeStart = source.indexOf('</svg>', openEnd);
  if (closeStart < 0) return source;
  final scaleX = rootSize.width / definitionSize.width;
  final scaleY = rootSize.height / definitionSize.height;
  final opening = '<g transform="scale($scaleX $scaleY)">';
  final normalizedBuffer = StringBuffer()
    ..write(source.substring(0, openStart))
    ..write(opening)
    ..write(source.substring(openEnd, closeStart))
    ..write('</g>')
    ..write(source.substring(closeStart + '</svg>'.length));
  var normalized = normalizedBuffer.toString();

  // Verovio uses a small CSS rule to make open paths inherit the page color.
  // flutter_svg does not apply that stylesheet, so carry the stroke onto
  // shapes that explicitly declare a stroke width.
  normalized = normalized.replaceAllMapped(
    RegExp(
      r"""<(path|ellipse|polygon|polyline|rect)\b[^>]*\bstroke-width\s*=\s*["'][^"']+["'][^>]*>""",
    ),
    (match) {
      final element = match.group(0)!;
      if (RegExp(r'\bstroke\s*=').hasMatch(element)) return element;
      final insertAt = element.endsWith('/>')
          ? element.length - 2
          : element.length - 1;
      return '${element.substring(0, insertAt)} stroke="black"${element.substring(insertAt)}';
    },
  );
  // flutter_svg cannot load Verovio's embedded SMuFL WOFF2 font into the
  // device font registry.  Symbols embedded in text (most notably the
  // metronome note) would otherwise fall back to an unrelated private-use
  // glyph and appear as a large, overlapping block in the top-left corner.
  // Keep the engraving intact and use the platform music-note glyph for this
  // small class of inline symbols.
  normalized = normalized.replaceAllMapped(
    RegExp(r'[\uE000-\uF8FF]'),
    (_) => '♩',
  );
  normalized = normalized.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (
    match,
  ) {
    final codePoint = int.tryParse(match.group(1)!, radix: 16);
    if (codePoint == null || codePoint < 0xE000 || codePoint > 0xF8FF) {
      return match.group(0)!;
    }
    return '♩';
  });
  // flutter_svg does not preserve the positions of Verovio text inside the
  // flattened definition-scale viewport: every bar number would land on the
  // first clef. All text is removed here and redrawn at the right place from
  // [extractVerovioTextLabels]; the notation itself is path-based.
  normalized = normalized.replaceAll(
    // An empty `<text ... />` is matched on its own: the paired pattern
    // would otherwise run on to the next `</text>` and delete whole systems.
    RegExp(r'<text\b[^>]*/>|<text\b(?:[^>]*[^/>])?>[\s\S]*?</text>'),
    '',
  );
  return normalized.replaceAll(
    RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true),
    '',
  );
}

Size? _parseSvgViewBoxSize(String value) {
  final values = value
      .trim()
      .split(RegExp(r'[ ,]+'))
      .map(double.tryParse)
      .toList();
  if (values.length != 4 || values.any((value) => value == null)) return null;
  return Size(values[2]!, values[3]!);
}

/// A rendered page made ready to draw: the SVG as flutter_svg can draw it
/// and its text as labels. Both read the whole SVG several times, so they
/// run off the UI isolate: pages arrive while the first is already on screen
/// and being scrolled.
Future<
  ({String svg, List<VerovioTextLabel> labels, List<VerovioStaffLines> staves})
>
prepareVerovioPage(String svg) => Isolate.run(() {
  final read = readVerovioPage(svg);
  return (
    svg: normalizeVerovioSvgForFlutter(svg),
    labels: read.labels,
    staves: read.staves,
  );
});

/// The steps from middle C of the bottom line of a staff with [clef]: the
/// G of a G clef, the F of an F clef and the C of a C clef are on the line
/// the clef names. Without a clef the first staff is a treble staff and a
/// second one a bass staff.
@visibleForTesting
int bottomLineSteps(MusicClef? clef, {required int staff}) {
  if (clef == null) return staff >= 2 ? -10 : 2;
  final onLine = switch (clef.sign) {
    'F' => -4,
    'C' => 0,
    _ => 4,
  };
  final line = clef.sign == 'G' || clef.sign == 'F' || clef.sign == 'C'
      ? clef.line
      : 2;
  return onLine - (line - 1) * 2 + clef.octaveChange * 7;
}

/// Where the pitch a staff is measured from is, given its drawn lines:
/// E4 for the first staff and A3 for a second one, whatever the clef (the
/// same references [midiAtStaffY] counts from).
@visibleForTesting
double staffAnchorFromLines({
  required double bottomLine,
  required double lineGap,
  required MusicClef? clef,
  required int staff,
}) {
  final reference = staff >= 2 ? -2 : 2;
  return bottomLine -
      (reference - bottomLineSteps(clef, staff: staff)) * lineGap / 2;
}

class _VerovioPages extends StatelessWidget {
  const _VerovioPages({
    required this.pages,
    required this.width,
    required this.onHeightChanged,
  });

  final List<_VerovioPage> pages;
  final double width;
  final ValueChanged<double> onHeightChanged;

  @override
  Widget build(BuildContext context) {
    var top = 0.0;
    final children = <Widget>[];
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      final viewBox = page.hitMap.viewBox;
      final fullHeight = viewBox.width <= 0
          ? 0.0
          : width * viewBox.height / viewBox.width;
      final height = viewBox.width <= 0
          ? 0.0
          : width * page.visibleHeight / viewBox.width;
      children.add(
        Positioned(
          left: 0,
          top: top,
          width: width,
          height: height,
          // Draw the full page and clip the blank area below the last system.
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: fullHeight,
              maxHeight: fullHeight,
              child: SvgPicture.string(
                page.svg,
                width: width,
                height: fullHeight,
                fit: BoxFit.fill,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
        ),
      );
      if (page.chords.isNotEmpty && viewBox.width > 0) {
        children.add(
          Positioned(
            left: 0,
            top: top,
            width: width,
            height: height,
            child: IgnorePointer(
              // Laying out every chord and syllable is the costly part of a
              // page: on its own layer it is not done again while the score
              // is panned, zoomed or the playing bar moves.
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: VerovioTextLabelPainter(
                    labels: page.chords,
                    scale: width / viewBox.width,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        );
      }
      top += height;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeightChanged(top));
    return Stack(children: children);
  }
}

class _MeasureGeometry {
  const _MeasureGeometry({
    required this.measureIndex,
    required this.element,
    required this.box,
  });

  final int measureIndex;
  final ElementHit element;
  final NativeMeasureBox box;
}

_MeasureGeometry? _measureForHit(
  ElementHit hit,
  List<_MeasureGeometry> measures,
) {
  if (hit.parentId != null) {
    for (final measure in measures) {
      if (measure.element.id == hit.parentId) return measure;
    }
  }
  final center = hit.bbox.center;
  for (final measure in measures) {
    if (measure.element.bbox.contains(center)) return measure;
  }
  return null;
}

List<_RenderedNoteMatch> _matchRenderedNotes({
  required List<ElementHit> hits,
  required List<(int, MusicNote)> sourceNotes,
  required int partIndex,
  required int measureIndex,
}) {
  final sourceByIndex = <int, MusicNote>{
    for (final source in sourceNotes) source.$1: source.$2,
  };
  final used = <int>{};
  final matches = <_RenderedNoteMatch>[];

  // MusicXML ids are added by MusicXmlCodec before Verovio renders the score.
  // Prefer them over visual sorting so chords and multiple voices keep their
  // actual event addresses.
  for (final hit in hits) {
    final encoded = _parseNoteEventId(hit.id);
    if (encoded == null ||
        encoded.partIndex != partIndex ||
        encoded.measureIndex != measureIndex ||
        used.contains(encoded.eventIndex)) {
      continue;
    }
    final note = sourceByIndex[encoded.eventIndex];
    if (note == null) continue;
    used.add(encoded.eventIndex);
    matches.add(
      _RenderedNoteMatch(eventIndex: encoded.eventIndex, note: note, hit: hit),
    );
  }

  // Imported MusicXML may not carry a usable id through Verovio's MusicXML
  // converter. Fall back to horizontal engraving order, which is the correct
  // order for onset mapping (the old top-first order put later chord notes in
  // front of earlier beats).
  final remainingHits =
      hits
          .where((hit) => !matches.any((match) => identical(match.hit, hit)))
          .toList()
        ..sort(_compareNotePosition);
  final remainingSources =
      sourceNotes.where((source) => !used.contains(source.$1)).toList()
        ..sort((a, b) {
          final onset = a.$2.onset.compareTo(b.$2.onset);
          if (onset != 0) return onset;
          final staff = a.$2.staff.compareTo(b.$2.staff);
          return staff == 0 ? a.$1.compareTo(b.$1) : staff;
        });
  final count = math.min(remainingHits.length, remainingSources.length);
  for (var index = 0; index < count; index++) {
    final source = remainingSources[index];
    matches.add(
      _RenderedNoteMatch(
        eventIndex: source.$1,
        note: source.$2,
        hit: remainingHits[index],
      ),
    );
  }
  return matches;
}

({int partIndex, int measureIndex, int eventIndex})? _parseNoteEventId(
  String id,
) {
  final match = RegExp(r'(?:^|-)p(\d+)-m(\d+)-e(\d+)(?:-|$)').firstMatch(id);
  if (match == null) return null;
  return (
    partIndex: int.parse(match.group(1)!),
    measureIndex: int.parse(match.group(2)!),
    eventIndex: int.parse(match.group(3)!),
  );
}

_StaffGeometry _fitStaffGeometry(
  List<_StaffMetricPoint> points, {
  required double fallbackTop,
  required double fallbackGap,
  required bool bass,
}) {
  final reference = bass ? -2 : 2;
  if (points.isEmpty) {
    return _StaffGeometry(top: fallbackTop, lineGap: fallbackGap);
  }

  // A measure can contain a single pitched event (or the hit map can expose
  // only one reliable note box). Keep that note on its rendered pitch instead
  // of falling back to a guessed position that may move the ghost several
  // staff steps away from the touch.
  if (points.length == 1) {
    final point = points.single;
    final top = point.y + (point.steps - reference) * fallbackGap / 2;
    return _StaffGeometry(top: top, lineGap: fallbackGap);
  }

  // Fit all note boxes instead of using only the two most distant notes.
  // Stem/flag extents can move an individual hit-box centre; least-squares
  // fitting makes the staff estimate stable across mixed rhythms and chords.
  final meanSteps =
      points.fold<double>(0, (sum, point) => sum + point.steps) / points.length;
  final meanY =
      points.fold<double>(0, (sum, point) => sum + point.y) / points.length;
  var covariance = 0.0;
  var variance = 0.0;
  for (final point in points) {
    final stepsDelta = point.steps - meanSteps;
    covariance += stepsDelta * (point.y - meanY);
    variance += stepsDelta * stepsDelta;
  }
  if (variance <= 0) {
    final point = points.first;
    final top = point.y + (point.steps - reference) * fallbackGap / 2;
    return _StaffGeometry(top: top, lineGap: fallbackGap);
  }
  final slope = covariance / variance;
  if (!slope.isFinite || slope.abs() < 0.1) {
    final point = points.first;
    final top = point.y + (point.steps - reference) * fallbackGap / 2;
    return _StaffGeometry(top: top, lineGap: fallbackGap);
  }
  final lineGap = (slope.abs() * 2).clamp(
    math.max(2.0, fallbackGap * 0.55),
    math.max(4.0, fallbackGap * 1.8),
  );
  final intercept = meanY - slope * meanSteps;
  final top = intercept + slope * reference;
  return _StaffGeometry(top: top, lineGap: lineGap.toDouble());
}

int _diatonicStepsForPitch(MusicPitch pitch) {
  return (pitch.octave - 4) * 7 + pitch.step.index;
}

/// Orders measure boxes in reading order: line by line, left to right.
///
/// A bar with high notes or a chord symbol has a taller box, so its top can
/// sit above the first bar of the same line. Sorting by top alone scrambled
/// bar numbers; bars that overlap vertically belong to one line instead.
@visibleForTesting
List<T> orderMeasureBoxes<T>(List<T> items, Rect Function(T item) boxOf) {
  final byTop = items.toList()
    ..sort((a, b) => boxOf(a).top.compareTo(boxOf(b).top));
  final rows = <({Rect bounds, List<T> items})>[];
  for (final item in byTop) {
    final box = boxOf(item);
    var placed = false;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final overlap =
          math.min(row.bounds.bottom, box.bottom) -
          math.max(row.bounds.top, box.top);
      final shorter = math.min(row.bounds.height, box.height);
      if (shorter > 0 && overlap >= shorter * 0.5) {
        rows[index] = (
          bounds: row.bounds.expandToInclude(box),
          items: [...row.items, item],
        );
        placed = true;
        break;
      }
    }
    if (!placed) rows.add((bounds: box, items: [item]));
  }
  rows.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
  return [
    for (final row in rows)
      ...(row.items..sort((a, b) => boxOf(a).left.compareTo(boxOf(b).left))),
  ];
}

int _compareNotePosition(ElementHit a, ElementHit b) {
  final left = a.bbox.left.compareTo(b.bbox.left);
  if (left != 0) return left;
  return a.bbox.top.compareTo(b.bbox.top);
}

class _RenderedNoteMatch {
  const _RenderedNoteMatch({
    required this.eventIndex,
    required this.note,
    required this.hit,
  });

  final int eventIndex;
  final MusicNote note;
  final ElementHit hit;
}

class _StaffMetricPoint {
  const _StaffMetricPoint({required this.steps, required this.y});

  final int steps;
  final double y;
}

class _StaffGeometry {
  const _StaffGeometry({required this.top, required this.lineGap});

  final double top;
  final double lineGap;
}

Rect _scaledRect(Rect rect, double scale, double pageTop) {
  return Rect.fromLTRB(
    rect.left * scale,
    pageTop + rect.top * scale,
    rect.right * scale,
    pageTop + rect.bottom * scale,
  );
}

Offset _scaledPoint(Offset point, double scale, double pageTop) {
  return Offset(point.dx * scale, pageTop + point.dy * scale);
}

/// What a finger that has moved by [moved] (in screen pixels) since it went
/// down on a note asks for: the note [steps] lines and spaces higher (up is
/// positive), or with an accidental ([alter]: +1 to the right, -1 to the
/// left). One or the other, by the way the finger went mostly.
///
/// On a score that fits a phone a line or space is a pixel or two: the
/// finger moves the note by a distance it can keep to, never less than
/// seven pixels a step, and asks for an accidental only well to the side.
({int steps, int alter}) fingerCarry(
  Offset moved, {
  required double lineGap,
  required double scale,
}) {
  if (moved.dx.abs() > moved.dy.abs()) {
    final far = math.max(lineGap * 2 * scale, 28.0);
    return (steps: 0, alter: moved.dx > far ? 1 : (moved.dx < -far ? -1 : 0));
  }
  final step = math.max(lineGap / 2 * scale, 7.0);
  return (steps: (-moved.dy / step).round(), alter: 0);
}

/// How far above or below a staff, in staff spaces, a quick tap still
/// writes a note: up to the third ledger line or so. Chord symbols and
/// lyrics stand further off.
const tapReachSpaces = 3.5;
