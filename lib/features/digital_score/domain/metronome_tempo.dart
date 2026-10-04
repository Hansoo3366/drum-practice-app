/// Quarter notes in one beat of a metronome mark, by its MusicXML beat unit.
const _unitQuarters = <String, double>{
  'long': 16,
  'breve': 8,
  'whole': 4,
  'half': 2,
  'quarter': 1,
  'eighth': 0.5,
  '16th': 0.25,
  '32nd': 0.125,
};

/// The quarter notes per minute a metronome mark asks for: [perMinute] beats
/// of [beatUnit] with [dots] dots. A player's tempo is always in quarters, so
/// "♩. = 50" is 75 and "half = 84" is 168. Null when the mark names no beat
/// unit this reads.
double? quarterTempo(String? beatUnit, int dots, double? perMinute) {
  if (perMinute == null || perMinute <= 0) return null;
  final unit = _unitQuarters[(beatUnit ?? 'quarter').trim()];
  if (unit == null) return null;
  // One dot adds half, two add three quarters.
  final dotted = 2 - 1 / (1 << dots.clamp(0, 3));
  return perMinute * unit * dotted;
}

final _metronome = RegExp(r'<metronome\b[^>]*>([\s\S]*?)</metronome>');
final _beatUnit = RegExp(r'<beat-unit>\s*([^<\s]+)\s*</beat-unit>');
final _dot = RegExp(r'<beat-unit-dot\s*/>|<beat-unit-dot>\s*</beat-unit-dot>');
final _perMinute = RegExp(
  r'<per-minute>\s*([0-9]+(?:\.[0-9]+)?)\s*</per-minute>',
);

/// [xml] with every metronome mark written as quarters per minute, for a
/// reader of marks that knows the beat unit but not its dot: without this a
/// piece in 6/8 marked "♩. = 50" plays at two thirds of its tempo.
///
/// A mark this cannot read (a metric modulation, words for a number) is
/// left as it is.
String metronomesInQuarters(String xml) {
  if (!xml.contains('<metronome')) return xml;
  return xml.replaceAllMapped(_metronome, (match) {
    final inner = match[1]!;
    final units = _beatUnit.allMatches(inner).toList();
    final perMinute = _perMinute.firstMatch(inner);
    if (units.length != 1 || perMinute == null) return match[0]!;
    final dots = _dot.allMatches(inner).length;
    final tempo = quarterTempo(
      units.single[1],
      dots,
      double.tryParse(perMinute[1]!),
    );
    if (tempo == null) return match[0]!;
    final open = match[0]!.substring(0, match[0]!.indexOf('>') + 1);
    return '$open<beat-unit>quarter</beat-unit>'
        '<per-minute>${tempo.round()}</per-minute></metronome>';
  });
}
