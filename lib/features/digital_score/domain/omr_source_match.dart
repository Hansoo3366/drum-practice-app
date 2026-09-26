import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';

class OmrSourceMatch {
  const OmrSourceMatch({
    required this.chordRefCount,
    required this.chordHitCount,
    required this.lyricRefCount,
    required this.lyricHitCount,
  });

  factory OmrSourceMatch.fromJson(Map<String, Object?> json) {
    return OmrSourceMatch(
      chordRefCount: (json['chordRefCount'] as num?)?.round() ?? 0,
      chordHitCount: (json['chordHitCount'] as num?)?.round() ?? 0,
      lyricRefCount: (json['lyricRefCount'] as num?)?.round() ?? 0,
      lyricHitCount: (json['lyricHitCount'] as num?)?.round() ?? 0,
    );
  }

  factory OmrSourceMatch.compare({
    required String referenceText,
    required MusicScore score,
    required String musicXml,
  }) {
    final refChords = extractReferenceChords(referenceText);
    final hypChords = extractScoreChords(score, musicXml);
    final refLyrics = extractReferenceLyrics(referenceText);
    final hypLyrics = extractScoreLyrics(musicXml);
    return OmrSourceMatch(
      chordRefCount: refChords.length,
      chordHitCount: _bagHits(refChords, hypChords),
      lyricRefCount: refLyrics.length,
      lyricHitCount: _lcs(refLyrics, hypLyrics),
    );
  }

  final int chordRefCount;
  final int chordHitCount;
  final int lyricRefCount;
  final int lyricHitCount;

  bool get hasReference => chordRefCount + lyricRefCount > 0;

  int? get chordRecall => _pct(chordHitCount, chordRefCount);
  int? get lyricRecall => _pct(lyricHitCount, lyricRefCount);

  int? get combined {
    final parts = [chordRecall, lyricRecall].whereType<int>().toList();
    if (parts.isEmpty) return null;
    return (parts.reduce((a, b) => a + b) / parts.length).round();
  }

  Map<String, Object?> toJson() => {
    'chordRefCount': chordRefCount,
    'chordHitCount': chordHitCount,
    'lyricRefCount': lyricRefCount,
    'lyricHitCount': lyricHitCount,
  };
}

int? _pct(int hit, int total) {
  if (total <= 0) return null;
  return ((100 * hit) / total).round().clamp(0, 100);
}

int _bagHits(List<String> reference, List<String> hypothesis) {
  final pool = List<String>.of(hypothesis);
  var hits = 0;
  for (final token in reference) {
    final index = pool.indexOf(token);
    if (index < 0) continue;
    pool.removeAt(index);
    hits++;
  }
  return hits;
}

int _lcs(List<String> left, List<String> right) {
  if (left.isEmpty || right.isEmpty) return 0;
  final rows = left.length;
  final cols = right.length;
  final prev = List<int>.filled(cols + 1, 0);
  final curr = List<int>.filled(cols + 1, 0);
  for (var i = 1; i <= rows; i++) {
    for (var j = 1; j <= cols; j++) {
      curr[j] = left[i - 1] == right[j - 1]
          ? prev[j - 1] + 1
          : (prev[j] > curr[j - 1] ? prev[j] : curr[j - 1]);
    }
    for (var j = 0; j <= cols; j++) {
      prev[j] = curr[j];
      curr[j] = 0;
    }
  }
  return prev[cols];
}

final _chordPattern = RegExp(
  r'\b([A-G](?:#|b)?)(m|maj|min|dim|aug|sus|add)?(\d*)(?:\([^)]+\))?(?:/([A-G](?:#|b)?))?\b',
);

const _lyricStop = {
  'tempo',
  'piano',
  'tutorial',
  'song',
  'composed',
  'lyrics',
  'arranged',
  'roadpiano',
  'copyright',
  'newjeans',
  'ditto',
  'stay',
  'like',
  'dont',
  'don',
  'want',
  'say',
  'the',
  'and',
  'you',
  'for',
  'by',
};

String _normalizePdfGlyphs(String raw) {
  return raw
      .replaceAll('©', '#')
      .replaceAll('‹', 'm')
      .replaceAll(RegExp('[ÞßÝ„ˆ]'), '')
      .replaceAll('♭', 'b')
      .replaceAll('♯', '#');
}

String _canonChord(String root, String quality, String digits, String bass) {
  var q = quality.toLowerCase();
  if (q == 'min') q = 'm';
  if (q == 'maj') q = '';
  final token = '$root$q$digits${bass.isEmpty ? '' : '/$bass'}';
  return token;
}

List<String> extractReferenceChords(String text) {
  final normalized = _normalizePdfGlyphs(text);
  final found = <String>[];
  for (final match in _chordPattern.allMatches(normalized)) {
    final root = match.group(1)!;
    final quality = match.group(2) ?? '';
    final digits = match.group(3) ?? '';
    final bass = match.group(4) ?? '';
    if (quality.isEmpty && digits.isEmpty && bass.isEmpty) continue;
    found.add(_canonChord(root, quality, digits, bass));
  }
  // RoadPiano "DM" / "AM" after glyph strip → D / A major.
  for (final match in RegExp(r'\b([A-G](?:#|b)?)M\b').allMatches(normalized)) {
    found.add(match.group(1)!);
  }
  return found;
}

List<String> extractReferenceLyrics(String text) {
  final tokens = <String>[];
  for (final match in RegExp(r'[A-Za-z]{2,}').allMatches(text)) {
    final word = match.group(0)!.toLowerCase();
    if (_lyricStop.contains(word)) continue;
    tokens.add(word);
  }
  for (final match in RegExp(r'[가-힣]+').allMatches(text)) {
    final syllable = match.group(0)!;
    if (syllable == 'ㅡ') continue;
    tokens.add(syllable);
  }
  return tokens;
}

List<String> extractScoreChords(MusicScore score, String musicXml) {
  final found = <String>[];
  for (final part in score.parts) {
    for (final measure in part.measures) {
      for (final event in measure.events) {
        if (event is! MusicHarmony) continue;
        found.add(_harmonyToken(event));
      }
    }
  }
  if (found.isNotEmpty) return found;
  for (final match in RegExp(
    r'<root-step>([A-G])</root-step>(?:\s*<root-alter>(-?\d)</root-alter>)?',
  ).allMatches(musicXml)) {
    final alter = int.tryParse(match.group(2) ?? '') ?? 0;
    final acc = alter == 1
        ? '#'
        : alter == -1
        ? 'b'
        : '';
    found.add('${match.group(1)}$acc');
  }
  return found;
}

String _harmonyToken(MusicHarmony harmony) {
  final acc = harmony.rootAlter == 1
      ? '#'
      : harmony.rootAlter == -1
      ? 'b'
      : '';
  final root = '${harmony.rootStep.musicXmlName}$acc';
  final printed = (harmony.kindText ?? '').trim();
  if (printed.isNotEmpty) {
    return _normalizePdfGlyphs(printed).replaceAll(' ', '');
  }
  final quality = switch (harmony.kind) {
    'minor' => 'm',
    'dominant' => '7',
    'major-seventh' => 'maj7',
    'minor-seventh' => 'm7',
    'half-diminished' => 'm7b5',
    'diminished' => 'dim',
    'augmented' => 'aug',
    'suspended-fourth' => 'sus4',
    'suspended-second' => 'sus2',
    'dominant-ninth' => '9',
    _ => '',
  };
  return '$root$quality';
}

List<String> extractScoreLyrics(String musicXml) {
  final tokens = <String>[];
  for (final match in RegExp(
    r'<lyric[\s>][\s\S]*?<text>([^<]*)</text>',
  ).allMatches(musicXml)) {
    final raw = match.group(1)!.trim();
    if (raw.isEmpty) continue;
    tokens.addAll(extractReferenceLyrics(raw));
  }
  return tokens;
}
