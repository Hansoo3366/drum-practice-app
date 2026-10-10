import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

/// A chord symbol or lyric syllable engraved by Verovio, in root SVG viewBox
/// units.
///
/// flutter_svg drops the positions of Verovio text, so the viewer removes all
/// SVG text and redraws chord symbols and lyrics from these labels. Lyric
/// hyphens and extender lines are shapes and stay in the SVG.
@immutable
class VerovioTextLabel {
  const VerovioTextLabel({
    required this.text,
    required this.x,
    required this.baselineY,
    required this.fontSize,
    this.anchor = TextAlign.left,
    this.kind,
  });

  final String text;
  final double x;
  final double baselineY;
  final double fontSize;
  final TextAlign anchor;

  /// What the text is, by the group Verovio drew it in: `harm` (a chord
  /// symbol), `verse` (a syllable), `tempo`, `dir` (written words), `reh`
  /// (a section box); null for anything else (bar and ending numbers,
  /// tuplet numbers).
  final String? kind;

  VerovioTextLabel copyWith({
    String? text,
    double? baselineY,
    double? fontSize,
  }) => VerovioTextLabel(
    text: text ?? this.text,
    x: x,
    baselineY: baselineY ?? this.baselineY,
    fontSize: fontSize ?? this.fontSize,
    anchor: anchor,
    kind: kind,
  );
}

// Verovio writes chord accidentals as Leipzig private-use glyphs.
const _leipzigChordGlyphs = <int, String>{
  0xEA64: '♭',
  0xEA65: '♮',
  0xEA66: '♯',
  // Metronome marks ("♩ = 115") write their note as a SMuFL glyph: the
  // note glyphs, or the smaller ones made for metronome marks.
  0xE1D2: '𝅝',
  0xE1D3: '𝅗𝅥',
  0xE1D5: '♩',
  0xE1D7: '♪',
  0xE1E7: '.',
  0xECA2: '𝅝',
  0xECA3: '𝅗𝅥',
  0xECA4: '𝅗𝅥',
  0xECA5: '♩',
  0xECA6: '♩',
  0xECA7: '♪',
  0xECA8: '♪',
  0xECB7: '.',
  // Dynamics letters inside a written direction ("sf", "fz", "rfz").
  0xE520: 'p',
  0xE521: 'm',
  0xE522: 'f',
  0xE523: 'r',
  0xE524: 's',
  0xE525: 'z',
  0xE526: 'n',
};

/// Groups whose text the viewer leaves out: the part name printed before
/// the first system ("Voice", "Piano") only takes room on a phone.
const _hiddenTextGroups = {'label', 'labelAbbr'};

/// How chord symbols are shown: as written, or as the numbers a band
/// reads in any key.
enum ChordDisplay { symbols, nashville, roman }

/// The chord symbol [text] ("Am7", "B♭/D", "C(sus4)") as a number in the
/// major key of [fifths] sharps (flats when negative): the Nashville way
/// ("3m7", "4/6", "5(sus4)") or in Roman numerals ("iii7", "IV/VI"). A
/// text that is not a chord symbol ("N.C.") comes back as it is.
String chordAsNumber(String text, int fifths, {required bool roman}) {
  final parts = text.split('/');
  if (parts.length > 2) return text;
  final chord = _chordRoot(parts.first);
  if (chord == null) return text;
  final bass = parts.length == 2 ? _chordRoot(parts[1]) : null;
  if (parts.length == 2 && (bass == null || bass.rest.isNotEmpty)) return text;
  // The key's first note: every fifth up is four letters on, seven
  // semitones up.
  final tonicLetter = ((fifths * 4) % 7 + 7) % 7;
  final tonicPitch = ((fifths * 7) % 12 + 12) % 12;
  const major = [0, 2, 4, 5, 7, 9, 11];
  ({int degree, String sign}) place(({int letter, int pitch, String rest}) of) {
    final degree = ((of.letter - tonicLetter) % 7 + 7) % 7;
    final off = ((of.pitch - tonicPitch - major[degree]) % 12 + 12) % 12;
    return (
      degree: degree,
      sign: switch (off) {
        1 => '♯',
        11 => '♭',
        2 => '♯♯',
        10 => '♭♭',
        _ => '',
      },
    );
  }

  const numerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];
  final at = place(chord);
  final minor =
      chord.rest.startsWith('m') &&
      !chord.rest.startsWith('maj') &&
      !chord.rest.startsWith('M');
  final String root;
  if (roman) {
    final numeral = numerals[at.degree];
    // A minor chord is its numeral in small letters, without the "m".
    root = minor
        ? '${at.sign}${numeral.toLowerCase()}${chord.rest.substring(1)}'
        : '${at.sign}$numeral${chord.rest}';
  } else {
    root = '${at.sign}${at.degree + 1}${chord.rest}';
  }
  if (bass == null) return root;
  final under = place(bass);
  return roman
      ? '$root/${under.sign}${numerals[under.degree]}'
      : '$root/${under.sign}${under.degree + 1}';
}

/// The root of a chord symbol: its letter (C is 0), its pitch (C is 0) and
/// what follows it; null when [text] does not begin with a note name.
({int letter, int pitch, String rest})? _chordRoot(String text) {
  final match = RegExp(r'^([A-G])(♯|#|♭|b)?(.*)$').firstMatch(text.trim());
  if (match == null) return null;
  final letter = 'CDEFGAB'.indexOf(match.group(1)!);
  final alter = switch (match.group(2)) {
    '♯' || '#' => 1,
    '♭' || 'b' => -1,
    _ => 0,
  };
  return (
    letter: letter,
    pitch: (const [0, 2, 4, 5, 7, 9, 11][letter] + alter + 12) % 12,
    rest: match.group(3)!,
  );
}

/// The groups a text is told apart by ([VerovioTextLabel.kind]).
const _kindGroups = ['harm', 'verse', 'tempo', 'dir', 'reh', 'mNum'];

/// Where bar numbers are written: at the start of every line, on every
/// bar, or nowhere.
enum BarNumbers { lines, every, none }

/// [labels] as they are drawn with the reader's choices: chord symbols as
/// numbers ([keyOf] gives the key a chord symbol stands in), chord symbols
/// and lyrics [wordScale] times their size, the chord symbols of a line on
/// one level ([alignChords]), and no bar numbers ([hideBarNumbers]).
List<VerovioTextLabel> shownLabels(
  List<VerovioTextLabel> labels, {
  ChordDisplay chords = ChordDisplay.symbols,
  int Function(VerovioTextLabel chord)? keyOf,
  double wordScale = 1,
  bool alignChords = false,
  bool hideBarNumbers = false,
}) {
  var shown = [
    for (final label in labels)
      if (!(hideBarNumbers && label.kind == 'mNum'))
        switch (label.kind) {
          'harm' => label.copyWith(
            text: chords == ChordDisplay.symbols
                ? null
                : chordAsNumber(
                    label.text,
                    keyOf?.call(label) ?? 0,
                    roman: chords == ChordDisplay.roman,
                  ),
            fontSize: label.fontSize * wordScale,
          ),
          'verse' => label.copyWith(fontSize: label.fontSize * wordScale),
          _ => label,
        },
  ];
  if (alignChords) {
    // The chord symbols of one line of the score: those whose baselines
    // are within a couple of text heights of one another. They are put on
    // the highest of them.
    final harm = [
      for (final label in shown)
        if (label.kind == 'harm') label,
    ]..sort((a, b) => a.baselineY.compareTo(b.baselineY));
    final level = Map<VerovioTextLabel, double>.identity();
    var start = 0;
    for (var i = 1; i <= harm.length; i++) {
      if (i < harm.length &&
          harm[i].baselineY - harm[i - 1].baselineY <
              harm[start].fontSize * 2.5) {
        continue;
      }
      for (var j = start; j < i; j++) {
        level[harm[j]] = harm[start].baselineY;
      }
      start = i;
    }
    shown = [
      for (final label in shown)
        if (level[label] case final y? when y != label.baselineY)
          label.copyWith(baselineY: y)
        else
          label,
    ];
  }
  return shown;
}

/// Groups whose texts are single words: a space inside a chord symbol or a
/// lyric syllable is the converter's ("B ♭", "예 수"), not written.
const _compactTextGroups = {'harm', 'verse'};

/// The five lines of one staff in one bar as Verovio drew them, in root SVG
/// viewBox units: where the pitches of that staff are, exactly. (The box
/// of a staff also holds its clef and notes, so its height says nothing
/// about the distance between the lines.)
@immutable
class VerovioStaffLines {
  const VerovioStaffLines({
    required this.left,
    required this.right,
    required this.lines,
  });

  final double left;
  final double right;

  /// The lines from the top one down.
  final List<double> lines;

  double get top => lines.first;
  double get bottom => lines.last;
  double get gap => (bottom - top) / (lines.length - 1);
  Offset get center => Offset((left + right) / 2, (top + bottom) / 2);
}

final _straightLine = RegExp(
  r'^\s*M\s*(-?[\d.]+)[\s,]+(-?[\d.]+)\s*L\s*(-?[\d.]+)[\s,]+(-?[\d.]+)\s*$',
);

/// Reads every text of a raw Verovio page before text is stripped: chord
/// symbols, lyrics, bar numbers, ending numbers, tempo, rehearsal marks,
/// tuplet numbers and written directions.
List<VerovioTextLabel> extractVerovioTextLabels(String svg) =>
    readVerovioPage(svg).labels;

/// The texts ([extractVerovioTextLabels]) and the staff lines of a raw
/// Verovio page, from one reading of it.
({List<VerovioTextLabel> labels, List<VerovioStaffLines> staves})
readVerovioPage(String svg) {
  const nothing = (labels: <VerovioTextLabel>[], staves: <VerovioStaffLines>[]);
  final XmlDocument document;
  try {
    document = XmlDocument.parse(svg);
  } on XmlException {
    return nothing;
  }
  final root = document.rootElement;
  final rootSize = _viewBoxSize(root.getAttribute('viewBox'));
  if (rootSize == null) return nothing;

  final labels = <VerovioTextLabel>[];
  final staves = <VerovioStaffLines>[];
  void readStaff(XmlElement staff, _Affine transform) {
    final lines = <double>[];
    var left = double.infinity;
    var right = double.negativeInfinity;
    // The lines are the staff group's own paths; ledger lines, stems and
    // beams are in groups below it.
    for (final path in staff.childElements) {
      if (path.name.local != 'path') continue;
      final match = _straightLine.firstMatch(path.getAttribute('d') ?? '');
      if (match == null) continue;
      final from = transform.apply(
        double.parse(match.group(1)!),
        double.parse(match.group(2)!),
      );
      final to = transform.apply(
        double.parse(match.group(3)!),
        double.parse(match.group(4)!),
      );
      if ((from.dy - to.dy).abs() > 0.5) continue;
      lines.add(from.dy);
      left = math.min(left, math.min(from.dx, to.dx));
      right = math.max(right, math.max(from.dx, to.dx));
    }
    if (lines.length != 5) return;
    lines.sort();
    staves.add(VerovioStaffLines(left: left, right: right, lines: lines));
  }

  void visit(
    XmlElement element,
    _Affine transform,
    bool compact, [
    String? kind,
  ]) {
    var current = transform;
    if (element.name.local == 'svg' && element != root) {
      final size = _viewBoxSize(element.getAttribute('viewBox'));
      if (size != null && size.width > 0 && size.height > 0) {
        current = current.multiply(
          _Affine.scale(
            rootSize.width / size.width,
            rootSize.height / size.height,
          ),
        );
      }
    }
    current = current.multiply(
      _parseTransform(element.getAttribute('transform')),
    );
    if (element.name.local == 'g' &&
        _hiddenTextGroups.any((name) => _hasClass(element, name))) {
      return;
    }
    if (element.name.local == 'g' && _hasClass(element, 'staff')) {
      readStaff(element, current);
    }
    if (element.name.local == 'text') {
      final label = _chordLabel(element, current, compact: compact, kind: kind);
      if (label != null) labels.add(label);
      return;
    }
    var kindBelow = kind;
    if (element.name.local == 'g') {
      for (final name in _kindGroups) {
        if (_hasClass(element, name)) kindBelow = name;
      }
    }
    final compactBelow =
        compact ||
        (element.name.local == 'g' &&
            _compactTextGroups.any((name) => _hasClass(element, name)));
    for (final child in element.childElements) {
      visit(child, current, compactBelow, kindBelow);
    }
  }

  final rootValues = root
      .getAttribute('viewBox')!
      .trim()
      .split(RegExp(r'[\s,]+'))
      .map(double.parse)
      .toList();
  // Labels are relative to the page's top-left corner, like the HitMap.
  visit(root, _Affine.translate(-rootValues[0], -rootValues[1]), false);
  return (labels: labels, staves: staves);
}

VerovioTextLabel? _chordLabel(
  XmlElement text,
  _Affine parent, {
  required bool compact,
  String? kind,
}) {
  final transform = parent.multiply(
    _parseTransform(text.getAttribute('transform')),
  );
  final x = _parseLength(text.getAttribute('x')) ?? 0;
  final y = _parseLength(text.getAttribute('y')) ?? 0;
  final buffer = StringBuffer();
  double? fontSize;
  // The size of engraving-font text: it is written larger than the words
  // around it, at 16/9 of their size.
  double? glyphSize;
  void collect(XmlNode node, double? inheritedSize, bool inheritedGlyphFont) {
    if (node is XmlText) {
      if (node.value.trim().isEmpty) return;
      // Line breaks and indentation are the file's layout; a space within a
      // line is written ("Verse 1", "D.S. al Fine", "♩ = 115").
      final value = node.value
          .replaceAll(RegExp(r'\s*\n\s*'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      for (final rune in value.runes) {
        final glyph = _leipzigChordGlyphs[rune];
        if (glyph != null) {
          buffer.write(glyph);
        } else if (rune >= 0xE000 && rune <= 0xF8FF) {
          // Unknown engraving glyph: leave it out rather than draw tofu.
        } else {
          buffer.writeCharCode(rune);
        }
      }
      if (inheritedSize != null && inheritedSize > 0) {
        if (inheritedGlyphFont) {
          glyphSize = math.max(glyphSize ?? 0, inheritedSize);
        } else {
          fontSize = math.max(fontSize ?? 0, inheritedSize);
        }
      }
      return;
    }
    if (node is! XmlElement) return;
    final size = _parseLength(node.getAttribute('font-size')) ?? inheritedSize;
    final family = node.getAttribute('font-family');
    final glyphFont = family == null
        ? inheritedGlyphFont
        : family.contains('Leipzig') || family.contains('Bravura');
    for (final child in node.children) {
      collect(child, size, glyphFont);
    }
  }

  collect(text, null, false);
  var value = buffer
      .toString()
      .replaceAll(RegExp(' +'), compact ? '' : ' ')
      .trim();
  // A dotted metronome note is written as two glyphs: the dot belongs to
  // the note ("♩. = 50", not "♩ . = 50").
  for (final note in const ['♩', '♪', '𝅗𝅥', '𝅝']) {
    value = value.replaceAll('$note .', '$note.');
  }
  // A text of engraving glyphs alone ("sf") has no word size of its own.
  final size = fontSize ?? (glyphSize == null ? null : glyphSize! * 9 / 16);
  if (value.isEmpty || size == null) return null;
  final origin = transform.apply(x, y);
  return VerovioTextLabel(
    text: value,
    x: origin.dx,
    baselineY: origin.dy,
    fontSize: size * transform.scaleY.abs(),
    anchor: switch (text.getAttribute('text-anchor')) {
      'middle' => TextAlign.center,
      'end' => TextAlign.right,
      _ => TextAlign.left,
    },
    kind: kind,
  );
}

/// Verovio sizes text for its own serif font. Drawn in the device font, and
/// Hangul in its CJK fallback, the same size reads about 15% larger and
/// crowds the lines, so labels are drawn a little smaller.
const verovioTextScale = 0.85;

/// Accidentals in a chord name, as the bundled engraving font draws them
/// beside text. The device's own "♭" comes from whatever symbol font it
/// falls back to, with a gap before it ("B ♭").
const _accidentalGlyphs = {'♭': '\uED60', '♮': '\uED61', '♯': '\uED62'};
final _accidentals = RegExp('[♭♮♯]');

/// [text] at [style], its accidentals in the engraving font.
InlineSpan verovioLabelSpan(String text, TextStyle style) {
  if (!text.contains(_accidentals)) return TextSpan(text: text, style: style);
  final glyphStyle = style.copyWith(
    fontFamily: 'Bravura',
    fontSize: style.fontSize! * verovioAccidentalScale,
  );
  final children = <InlineSpan>[];
  var from = 0;
  for (final match in _accidentals.allMatches(text)) {
    if (match.start > from) {
      children.add(TextSpan(text: text.substring(from, match.start)));
    }
    children.add(
      TextSpan(text: _accidentalGlyphs[match[0]], style: glyphStyle),
    );
    from = match.end;
  }
  if (from < text.length) children.add(TextSpan(text: text.substring(from)));
  return TextSpan(style: style, children: children);
}

/// The engraving font's chord accidentals stand taller than a capital:
/// this much of the text size sets them level with the letters beside.
const verovioAccidentalScale = 0.9;

/// Paints chord symbols and lyrics for one page. [scale] maps viewBox units to pixels.
class VerovioTextLabelPainter extends CustomPainter {
  const VerovioTextLabelPainter({
    required this.labels,
    required this.scale,
    required this.color,
  });

  final List<VerovioTextLabel> labels;
  final double scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final label in labels) {
      final painter = TextPainter(
        text: verovioLabelSpan(
          label.text,
          TextStyle(
            color: color,
            fontSize: label.fontSize * scale * verovioTextScale,
            fontFamily: 'serif',
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final baseline = painter.computeDistanceToActualBaseline(
        TextBaseline.alphabetic,
      );
      final left = switch (label.anchor) {
        TextAlign.center => label.x * scale - painter.width / 2,
        TextAlign.right => label.x * scale - painter.width,
        _ => label.x * scale,
      };
      painter.paint(canvas, Offset(left, label.baselineY * scale - baseline));
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(VerovioTextLabelPainter oldDelegate) =>
      oldDelegate.labels != labels ||
      oldDelegate.scale != scale ||
      oldDelegate.color != color;
}

bool _hasClass(XmlElement element, String name) =>
    (element.getAttribute('class') ?? '').split(RegExp(r'\s+')).contains(name);

Size? _viewBoxSize(String? value) {
  if (value == null) return null;
  final parts = value.trim().split(RegExp(r'[\s,]+')).map(double.tryParse);
  final values = parts.toList();
  if (values.length != 4 || values.any((v) => v == null)) return null;
  return Size(values[2]!, values[3]!);
}

double? _parseLength(String? value) {
  if (value == null) return null;
  return double.tryParse(value.trim().replaceAll(RegExp(r'px$'), ''));
}

_Affine _parseTransform(String? value) {
  if (value == null || value.trim().isEmpty) return _Affine.identity;
  var result = _Affine.identity;
  for (final match in RegExp(r'(\w+)\s*\(([^)]*)\)').allMatches(value)) {
    final args = match
        .group(2)!
        .trim()
        .split(RegExp(r'[\s,]+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();
    final step = switch (match.group(1)) {
      'translate' when args.isNotEmpty => _Affine.translate(
        args[0],
        args.length > 1 ? args[1] : 0,
      ),
      'scale' when args.isNotEmpty => _Affine.scale(
        args[0],
        args.length > 1 ? args[1] : args[0],
      ),
      'matrix' when args.length == 6 => _Affine(
        args[0],
        args[1],
        args[2],
        args[3],
        args[4],
        args[5],
      ),
      _ => _Affine.identity,
    };
    result = result.multiply(step);
  }
  return result;
}

/// 2D affine matrix [a c e; b d f; 0 0 1], as in SVG.
class _Affine {
  const _Affine(this.a, this.b, this.c, this.d, this.e, this.f);

  factory _Affine.translate(double x, double y) => _Affine(1, 0, 0, 1, x, y);

  factory _Affine.scale(double x, double y) => _Affine(x, 0, 0, y, 0, 0);

  static const identity = _Affine(1, 0, 0, 1, 0, 0);

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  double get scaleY => math.sqrt(c * c + d * d);

  _Affine multiply(_Affine o) => _Affine(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.e + c * o.f + e,
    b * o.e + d * o.f + f,
  );

  Offset apply(double x, double y) =>
      Offset(a * x + c * y + e, b * x + d * y + f);
}
