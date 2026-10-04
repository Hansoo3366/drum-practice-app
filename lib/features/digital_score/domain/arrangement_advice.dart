import 'dart:math' as math;

import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:xml/xml.dart';

/// A chord symbol the adviser would change: the [chordIndex]th symbol of bar
/// [measureIndex] (both from 0), now [current], to [suggested].
class ChordCorrection {
  const ChordCorrection({
    required this.measureIndex,
    required this.chordIndex,
    required this.current,
    required this.suggested,
    this.reason = '',
  });

  final int measureIndex;
  final int chordIndex;
  final String current;
  final String suggested;
  final String reason;
}

/// What the adviser recommends for the piano part of a lead sheet: a style
/// for the score and for sections of it, and chord symbols to look at again.
class ArrangementAdvice {
  const ArrangementAdvice({
    required this.plan,
    this.roles = const {},
    this.corrections = const [],
    this.note = '',
  });

  /// Reads the adviser's answer for [xml], dropping whatever does not fit the
  /// score: bars that do not exist, unknown styles, chords that are not at
  /// the place named or cannot be read.
  factory ArrangementAdvice.fromJson(Map<String, Object?> json, String xml) {
    final bars = _bars(xml);
    AccompanimentStyle? style(Object? raw) {
      if (raw is! Map) return null;
      final pattern = AccompanimentPattern.values.asNameMap()[raw['pattern']];
      final register = AccompanimentRegister.values
          .asNameMap()[raw['register']];
      if (pattern == null || register == null) return null;
      return AccompanimentStyle(pattern: pattern, register: register);
    }

    // Bars come back in the numbers the brief used.
    final first = xmlFirstBarNumber(xml);
    final last = first + bars.length - 1;
    final sections = <int, AccompanimentStyle>{};
    final roles = <int, SectionRole>{};
    for (final raw in json['sections'] as List? ?? const []) {
      final bar = raw is Map ? raw['bar'] : null;
      final parsed = style(raw);
      if (bar is! int || bar < first || bar > last || parsed == null) {
        continue;
      }
      sections[bar - first] = parsed;
      final role = _roleNames[(raw as Map)['role']];
      if (role != null) roles[bar - first] = role;
    }
    final corrections = <ChordCorrection>[];
    for (final raw in json['chords'] as List? ?? const []) {
      if (raw is! Map) continue;
      final bar = raw['bar'];
      final index = raw['index'];
      final suggested = raw['suggested']?.toString().trim() ?? '';
      if (bar is! int || index is! int || bar < first || bar > last) {
        continue;
      }
      final chords = bars[bar - first];
      if (index < 1 || index > chords.length) continue;
      final current = harmonyText(chords[index - 1]);
      try {
        parseChordSymbol(suggested);
      } on FormatException {
        continue;
      }
      if (suggested == current) continue;
      corrections.add(
        ChordCorrection(
          measureIndex: bar - first,
          chordIndex: index - 1,
          current: current,
          suggested: suggested,
          reason: raw['reason']?.toString() ?? '',
        ),
      );
    }
    return ArrangementAdvice(
      plan: AccompanimentPlan(
        base: style(json['base']) ?? const AccompanimentStyle(),
        sections: sections,
      ),
      roles: roles,
      corrections: corrections,
      note: json['note']?.toString() ?? '',
    );
  }

  final AccompanimentPlan plan;

  /// What the adviser takes each stretch of the song for, by first bar.
  final Map<int, SectionRole> roles;
  final List<ChordCorrection> corrections;

  /// The adviser's reasoning in a sentence.
  final String note;
}

/// The adviser's names for what a section is.
const _roleNames = <Object?, SectionRole>{
  'intro': SectionRole.intro,
  'verse': SectionRole.verse,
  'prechorus': SectionRole.preChorus,
  'chorus': SectionRole.chorus,
  'bridge': SectionRole.bridge,
  'interlude': SectionRole.interlude,
  'solo': SectionRole.solo,
  'outro': SectionRole.outro,
};

/// The chord symbols of each bar of the first part, in written order.
List<List<XmlElement>> _bars(String xml) => _barsOf(XmlDocument.parse(xml));

List<List<XmlElement>> _barsOf(XmlDocument document) {
  final part = document.rootElement.getElement('part');
  if (part == null) return const [];
  return [
    for (final measure in part.findElements('measure'))
      measure.findElements('harmony').toList(),
  ];
}

/// [xml] with the chord symbols of [corrections] rewritten. Nothing else in
/// the score changes; a correction that no longer fits is passed over.
String applyChordCorrections(String xml, List<ChordCorrection> corrections) {
  if (corrections.isEmpty) return xml;
  final document = XmlDocument.parse(xml);
  final bars = _barsOf(document);
  var changed = false;
  for (final correction in corrections) {
    if (correction.measureIndex < 0 || correction.measureIndex >= bars.length) {
      continue;
    }
    final chords = bars[correction.measureIndex];
    if (correction.chordIndex < 0 || correction.chordIndex >= chords.length) {
      continue;
    }
    final old = chords[correction.chordIndex];
    final ChordSymbol symbol;
    try {
      symbol = parseChordSymbol(correction.suggested);
    } on FormatException {
      continue;
    }
    final staff = int.tryParse(old.getElement('staff')?.innerText.trim() ?? '');
    final replacement = symbol.toXml(staff: staff);
    for (final attribute in old.attributes) {
      replacement.attributes.add(attribute.copy());
    }
    // The symbol stays on its beat.
    final offset = old.getElement('offset');
    if (offset != null) {
      final kind = replacement.getElement('kind');
      final bass = replacement.getElement('bass');
      final after = bass ?? kind;
      replacement.children.insert(
        after == null
            ? replacement.children.length
            : replacement.children.indexOf(after) + 1,
        offset.copy(),
      );
    }
    old.replace(replacement);
    changed = true;
  }
  return changed ? document.toXmlString() : xml;
}

/// A short text description of a lead sheet for the adviser: key, time,
/// sections, and for every bar its chord symbols and melody notes.
///
/// Bars are numbered as the screens number them ([xmlFirstBarNumber]: from
/// 1, or from 0 when the score opens with a pickup), so what the adviser
/// writes about "bar 11" is the bar the user sees as 11. [sections] are
/// (name, first bar, last bar) in the same numbers.
String arrangementBrief(
  String xml, {
  List<({String name, int start, int end})> sections = const [],
  double? tempoBpm,
}) {
  final document = XmlDocument.parse(xml);
  final part = document.rootElement.getElement('part');
  final measures = part?.findElements('measure').toList() ?? const [];
  final analysis = analyzeLeadSheet(xml);
  final first = xmlFirstBarNumber(xml);
  final out = StringBuffer()
    ..writeln('key signature: ${_keyName(analysis.keyFifths)}')
    ..writeln('time: ${analysis.beats}/${analysis.beatType}');
  if (tempoBpm != null) out.writeln('tempo: ${tempoBpm.round()} bpm');
  out.writeln(
    first == 0
        ? 'bars: 0-${measures.length - 1} (bar 0 is a pickup)'
        : 'bars: ${measures.length}',
  );
  if (sections.isNotEmpty) {
    out.writeln(
      'sections: ${sections.map((s) => '${s.name} ${s.start}-${s.end}').join(', ')}',
    );
  }
  out.writeln('bar: chords (in order) | melody notes');
  var divisions = 1;
  for (var index = 0; index < measures.length; index++) {
    final measure = measures[index];
    final chords = <String>[];
    final notes = <String>[];
    var shortest = 0;
    for (final child in measure.childElements) {
      switch (child.name.local) {
        case 'attributes':
          divisions =
              int.tryParse(
                child.getElement('divisions')?.innerText.trim() ?? '',
              ) ??
              divisions;
        case 'harmony':
          chords.add(
            child.getElement('kind')?.innerText.trim() == 'none'
                ? 'N.C.'
                : harmonyText(child),
          );
        case 'note':
          final pitch = child.getElement('pitch');
          if (pitch == null || child.getElement('grace') != null) continue;
          // A note tied from the one before is the same note going on.
          if (child
              .findElements('tie')
              .any((tie) => tie.getAttribute('type') == 'stop')) {
            continue;
          }
          final alter =
              double.tryParse(
                pitch.getElement('alter')?.innerText.trim() ?? '',
              )?.round() ??
              0;
          notes.add(
            '${pitch.getElement('step')?.innerText.trim()}'
            '${alter > 0 ? '#' * alter : 'b' * -alter}'
            '${pitch.getElement('octave')?.innerText.trim()}',
          );
          final duration =
              int.tryParse(
                child.getElement('duration')?.innerText.trim() ?? '',
              ) ??
              0;
          if (duration > 0) {
            shortest = shortest == 0 ? duration : math.min(shortest, duration);
          }
      }
    }
    out.write(
      '${index + first}: ${chords.isEmpty ? '-' : chords.join(' ')} | ',
    );
    if (notes.isEmpty) {
      out.writeln('rest');
    } else {
      // The shortest note as a fraction of a quarter tells how busy the bar is.
      final value = shortest / math.max(1, divisions);
      final busy = value <= 0.25
          ? '16ths'
          : value <= 0.5
          ? '8ths'
          : value <= 1
          ? 'quarters'
          : 'long notes';
      out.writeln('${notes.join(' ')} ($busy)');
    }
  }
  return out.toString();
}

String _keyName(int fifths) {
  const major = [
    'Cb', 'Gb', 'Db', 'Ab', 'Eb', 'Bb', 'F', 'C', 'G', 'D', 'A', 'E', 'B',
    'F#', 'C#', //
  ];
  const minor = [
    'Ab', 'Eb', 'Bb', 'F', 'C', 'G', 'D', 'A', 'E', 'B', 'F#', 'C#', 'G#',
    'D#', 'A#', //
  ];
  final index = fifths.clamp(-7, 7) + 7;
  final count = fifths == 0
      ? 'no sharps or flats'
      : '${fifths.abs()} ${fifths > 0 ? 'sharps' : 'flats'}';
  return '$count (${major[index]} major or ${minor[index]} minor)';
}

/// The chord a `<harmony>` names as text, empty for "N.C.".
String harmonyTextOf(XmlElement harmony) =>
    harmony.getElement('kind')?.innerText.trim() == 'none'
    ? ''
    : harmonyText(harmony);
