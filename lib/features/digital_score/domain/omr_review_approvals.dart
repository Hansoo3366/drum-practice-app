import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';

const _editor = XmlMeasureEditor();

/// [xml] with the approved AI suggestions written in: [approved] holds, by
/// bar key, the indices of the suggestions of that bar the user took.
///
/// Always made from the version before any of them, so what comes out does
/// not depend on the order they were approved in. Bars without an approval
/// are not touched. Throws a [FormatException] with a message for the user
/// when a suggestion cannot be written (it does not fit the bar, or the bar
/// has changed since the suggestion was made).
String withReviewApprovals(
  String xml,
  List<OmrReviewBar> bars,
  Map<String, Set<int>> approved,
) {
  var result = xml;
  for (final bar in bars) {
    final chosen = approved[bar.key];
    if (chosen == null || chosen.isEmpty) continue;
    final index = _barIndexIn(result, bar);
    if (index == null) {
      throw const FormatException('이 버전에는 없는 마디입니다.');
    }
    // A whole melody first: single notes are then addressed in it. The
    // lengths go in together, so each names the note it was made for and
    // the bar closes up behind them.
    final order = chosen.toList()
      ..sort((a, b) {
        int rank(int i) => bar.suggestions[i].field == 'melody' ? 0 : 1;
        return rank(a) != rank(b) ? rank(a) - rank(b) : a - b;
      });
    final lengths = <int, ({String type, int dots})>{};
    for (final i in order) {
      final suggestion = bar.suggestions[i];
      final note = XmlNoteRef(
        partIndex: bar.partIndex,
        measureIndex: index,
        noteIndex: (suggestion.note ?? 1) - 1,
      );
      switch (suggestion.field) {
        case 'melody':
          result = _editor
              .replaceMelody(result, bar.partIndex, index, suggestion.suggested)
              .xml;
        case 'pitch' when suggestion.note != null:
          result = _editor.setNotePitch(result, note, suggestion.suggested).xml;
        case 'duration' when suggestion.note != null:
          lengths[note.noteIndex] = _suggestedLength(result, note, suggestion);
        default:
          throw const FormatException('이 제안은 바로 넣을 수 없습니다.');
      }
    }
    if (lengths.isNotEmpty) {
      result = _editor
          .setNoteLengths(result, bar.partIndex, index, lengths)
          .xml;
    }
  }
  return result;
}

/// The length a duration suggestion asks for ("8.", "q", "D5 8": its last
/// token). It names a note of the bar as converted. When that note no
/// longer has the length the suggestion saw, the bar has changed since (an
/// earlier approval or a fix), and writing it would change some other note.
({String type, int dots}) _suggestedLength(
  String xml,
  XmlNoteRef ref,
  OmrReviewSuggestion suggestion,
) {
  MelodyToken length(String text) =>
      parseMelodyTokens('C4 ${text.trim().split(RegExp(r'\s+')).last}').single;
  final token = length(suggestion.suggested);
  MelodyToken? seen;
  try {
    seen = length(suggestion.current);
  } on FormatException {
    // No length to compare with.
  }
  if (seen != null) {
    final now = _editor.describe(xml, ref);
    if (now.type != seen.type || now.dots != seen.dots) {
      throw const FormatException('마디가 바뀌어 이 제안은 넣을 수 없습니다.');
    }
  }
  return (type: token.type, dots: token.dots);
}

/// Where [bar] is in [xml], by the bar origins written in it.
int? _barIndexIn(String xml, OmrReviewBar bar) {
  final origins = barOrigins(xml);
  if (origins == null) return bar.measureIndex;
  final index = origins.indexOf(bar.measureIndex);
  return index < 0 ? null : index;
}
