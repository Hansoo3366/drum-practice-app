import 'dart:convert';

import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';

/// One reason the conversion server doubts a measure (its validation report).
class OmrReviewIssue {
  const OmrReviewIssue({
    required this.rule,
    required this.severity,
    required this.detail,
  });

  final String rule;
  final OmrIssueSeverity severity;

  /// The server's own wording, in English.
  final String detail;

  /// The text a leftover-text issue (L001) is about, as the server read it.
  String? get leftover {
    if (rule != 'L001') return null;
    final match =
        RegExp(r"leftover text '(.*)'$").firstMatch(detail) ??
        RegExp(r'leftover text "(.*)"$').firstMatch(detail);
    return match?[1];
  }

  /// What is wrong, for the user.
  String get text {
    RegExpMatch? match(String pattern) => RegExp(pattern).firstMatch(detail);
    switch (rule) {
      case 'V001':
        final m = match(r'lasts ([\d.]+) quarters.*wants ([\d.]+)');
        return m == null
            ? '마디 길이가 박자표와 다릅니다.'
            : '마디 길이가 4분음표 ${m[1]}개인데 박자표는 ${m[2]}개입니다.';
      case 'V002':
        final m = match(r'voice (.+) does not fill');
        return m == null
            ? '마디를 다 채우지 않는 성부가 있습니다.'
            : '성부 ${m[1]}이(가) 마디를 다 채우지 않습니다.';
      case 'V003':
        return '붙임줄이 다음 음으로 이어지지 않습니다.';
      case 'V004':
        final m = match(r'(\d+) notes in (\d+)-tuplets');
        return m == null
            ? '잇단음표의 음 수가 맞지 않습니다.'
            : '${m[2]}잇단음표인데 음이 ${m[1]}개입니다.';
      case 'V006':
        final m = match(r'is (\d+) semitones');
        return m == null
            ? '주변 음에서 멀리 떨어진 음이 있습니다.'
            : '주변 음에서 ${m[1]}반음 떨어진 음이 있습니다.';
      case 'V007':
        final m = match(r'(\d+) heads on the page');
        return m == null
            ? '음표가 없는 마디입니다.'
            : '음표가 없는 마디인데 원본에는 음표 머리가 ${m[1]}개 보입니다.';
      case 'V008':
        return '조표가 잠깐 바뀌었다가 돌아옵니다. 잘못 읽은 조표일 수 있습니다.';
      case 'V009':
        return '오선 밖에 그려진 쉼표가 있습니다. 이음줄을 쉼표로 읽었을 수 있습니다.';
      case 'S001':
        return '이 줄의 마디가 원본과 맞지 않아 코드와 가사를 읽지 못했습니다.';
      case 'L001':
        return leftover == null
            ? '읽다 남은 글자가 있습니다.'
            : '읽다 남은 글자가 있습니다: $leftover';
      case 'A001':
        return '색 필기가 겹친 마디입니다. 가려진 부분은 읽지 못했습니다.';
    }
    return detail.isEmpty ? rule : detail;
  }
}

/// One change the AI review proposed for a measure.
class OmrReviewSuggestion {
  const OmrReviewSuggestion({
    required this.field,
    required this.current,
    required this.suggested,
    required this.confidence,
    required this.applied,
    this.verse,
    this.note,
  });

  /// chords, lyrics, pitch, duration or other.
  final String field;
  final String current;
  final String suggested;

  /// The model's own probability (0–1) that the suggestion is right.
  final double? confidence;

  /// Whether the "AI 보정" version already has it; the rest is advice only.
  final bool applied;
  final String? verse;
  final int? note;

  String get label => switch (field) {
    'chords' => '코드',
    'lyrics' => verse == null ? '가사' : '가사 $verse절',
    'pitch' => note == null ? '음높이' : '$note번째 음 높이',
    'duration' => note == null ? '음 길이' : '$note번째 음 길이',
    _ => '기타',
  };
}

/// A measure to look at again, with everything known about it.
class OmrReviewBar {
  const OmrReviewBar({
    required this.partIndex,
    required this.measureIndex,
    required this.measure,
    required this.issues,
    required this.suggestions,
    required this.uncertain,
    this.image,
    this.focus,
  });

  final int partIndex;
  final int measureIndex;

  /// The measure number as printed.
  final String measure;
  final List<OmrReviewIssue> issues;
  final List<OmrReviewSuggestion> suggestions;

  /// What the AI could not read (hidden or unclear on the page).
  final List<String> uncertain;

  /// Name of the server's crop of the original around this measure.
  final String? image;

  /// Where the measure itself is in the crop, which shows its neighbours
  /// too: left and right edge as fractions of the crop's width.
  final (double, double)? focus;

  String get key => '$partIndex:$measureIndex';

  OmrIssueSeverity get severity => issues.isEmpty
      ? OmrIssueSeverity.low
      : issues
            .map((issue) => issue.severity)
            .reduce((a, b) => a.index <= b.index ? a : b);
}

Map<String, Object?>? _object(String? source) {
  if (source == null || source.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(source);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}

Iterable<Map<String, Object?>> _maps(Object? list) sync* {
  if (list is! List) return;
  for (final item in list) {
    if (item is Map) yield Map<String, Object?>.from(item);
  }
}

/// The crops a validation report refers to.
Set<String> omrSuspectImageNames(String validationJson) => {
  for (final issue in _maps(_object(validationJson)?['issues']))
    if (issue['image'] case final String name when name.isNotEmpty) name,
};

/// The measures worth a second look, in score order: those the server's rules
/// flag ([validationJson]) and those its AI review has something to say about
/// ([aiReviewJson]).
List<OmrReviewBar> omrReviewBars({
  String? validationJson,
  String? aiReviewJson,
}) {
  final issues = <String, List<OmrReviewIssue>>{};
  final images = <String, String>{};
  final focuses = <String, (double, double)>{};
  final numbers = <String, String>{};
  final places = <String, (int, int)>{};

  String place(int part, int index, Object? number) {
    final key = '$part:$index';
    places[key] = (part, index);
    numbers.putIfAbsent(key, () => number?.toString() ?? '${index + 1}');
    return key;
  }

  for (final issue in _maps(_object(validationJson)?['issues'])) {
    final index = issue['measureIndex'];
    if (index is! num) continue;
    final key = place(
      (issue['part'] as num?)?.toInt() ?? 0,
      index.toInt(),
      issue['measure'],
    );
    final found = OmrReviewIssue(
      rule: issue['rule']?.toString() ?? '',
      severity:
          OmrIssueSeverity.values.asNameMap()[issue['severity']] ??
          OmrIssueSeverity.medium,
      detail: issue['detail']?.toString() ?? '',
    );
    final list = issues.putIfAbsent(key, () => []);
    // The same rule can fire twice in one bar; one line says it.
    if (!list.any((other) => other.text == found.text)) list.add(found);
    if (issue['image'] case final String name when name.isNotEmpty) {
      images.putIfAbsent(key, () => name);
      if (issue['focus'] case [
        final num left,
        final num right,
      ] when left >= 0 && right <= 1 && left < right) {
        focuses.putIfAbsent(key, () => (left.toDouble(), right.toDouble()));
      }
    }
  }

  final review = _object(aiReviewJson);
  final applied = <String>{
    for (final item in _maps(review?['applied']))
      '0:${item['measureIndex']}:${item['field']}:${item['verse'] ?? ''}',
  };
  final suggestions = <String, List<OmrReviewSuggestion>>{};
  final uncertain = <String, List<String>>{};
  for (final item in _maps(review?['suggestions'])) {
    final index = item['measureIndex'];
    if (index is! num) continue;
    final key = place(0, index.toInt(), item['measure']);
    for (final fix in _maps(item['corrections'])) {
      final field = fix['field']?.toString() ?? 'other';
      final verse = fix['verse']?.toString();
      suggestions
          .putIfAbsent(key, () => [])
          .add(
            OmrReviewSuggestion(
              field: field,
              current: fix['current']?.toString() ?? '',
              suggested: fix['suggested']?.toString() ?? '',
              confidence: (fix['confidence'] as num?)?.toDouble(),
              verse: field == 'lyrics' ? (verse ?? '1') : null,
              note: (fix['note'] as num?)?.toInt(),
              applied:
                  applied.contains('$key:$field:${verse ?? ''}') ||
                  (field == 'lyrics' && applied.contains('$key:$field:1')),
            ),
          );
    }
    for (final doubt in _maps(item['uncertain'])) {
      final reason = doubt['reason']?.toString().trim() ?? '';
      if (reason.isNotEmpty) uncertain.putIfAbsent(key, () => []).add(reason);
    }
  }

  final bars = [
    for (final MapEntry(:key, value: (part, index)) in places.entries)
      if (issues.containsKey(key) ||
          suggestions.containsKey(key) ||
          uncertain.containsKey(key))
        OmrReviewBar(
          partIndex: part,
          measureIndex: index,
          measure: numbers[key]!,
          issues: issues[key] ?? const [],
          suggestions: suggestions[key] ?? const [],
          uncertain: uncertain[key] ?? const [],
          image: images[key],
          focus: focuses[key],
        ),
  ];
  bars.sort((a, b) {
    final byMeasure = a.measureIndex.compareTo(b.measureIndex);
    return byMeasure != 0 ? byMeasure : a.partIndex.compareTo(b.partIndex);
  });
  return bars;
}

/// Where a measure is on the original: the image of its staff line, and its
/// left and right edge in it as fractions of the width.
typedef OmrBarPlace = ({String image, (double, double) focus});

/// The place of every measure of every part, as the conversion found them
/// (`layout.json`): `[part][measure]`, null for a measure it could not place.
List<List<OmrBarPlace?>> omrLayout(String? layoutJson) {
  final parts = _object(layoutJson)?['parts'];
  if (parts is! List) return const [];
  return [
    for (final part in parts)
      [
        if (part is List)
          for (final measure in part)
            switch (measure) {
              {
                'image': final String image,
                'focus': [final num left, final num right],
              }
                  when image.isNotEmpty &&
                      left >= 0 &&
                      right <= 1 &&
                      left < right =>
                (image: image, focus: (left.toDouble(), right.toDouble())),
              _ => null,
            },
      ],
  ];
}

/// The staff-line images a layout refers to.
Set<String> omrSystemImageNames(String? layoutJson) => {
  for (final part in omrLayout(layoutJson))
    for (final place in part)
      if (place != null) place.image,
};

/// A colour annotation the server took out of the upload before reading it.
class OmrAnnotation {
  const OmrAnnotation({
    required this.page,
    required this.highlight,
    required this.colour,
    this.text,
  });

  final int page;

  /// Highlighter (the print under it was kept) rather than pen.
  final bool highlight;
  final String colour;

  /// What the writing says, where it could be read.
  final String? text;

  String get label {
    final name = switch (colour) {
      'red' => '빨간',
      'orange' => '주황',
      'yellow' => '노란',
      'green' => '초록',
      'blue' => '파란',
      'purple' => '보라',
      _ => '색',
    };
    return '$name ${highlight ? '형광펜' : '펜'}';
  }
}

List<OmrAnnotation> omrAnnotations(String? annotationsJson) => [
  for (final item in _maps(_object(annotationsJson)?['items']))
    OmrAnnotation(
      page: (item['page'] as num?)?.toInt() ?? 1,
      highlight: item['type'] == 'highlight',
      colour: item['color']?.toString() ?? '',
      text: switch (item['text']) {
        final String text when text.trim().isNotEmpty => text.trim(),
        _ => null,
      },
    ),
];

/// The suspect measures the user has accepted as they are.
Set<String> omrReviewChecked(String? stateJson) => {
  if (_object(stateJson)?['checked'] case final List<Object?> keys)
    for (final key in keys) key.toString(),
};

String omrReviewStateJson(Set<String> checked) =>
    jsonEncode({'checked': checked.toList()..sort()});
