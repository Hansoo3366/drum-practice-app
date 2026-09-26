import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_config.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_page_crop.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_patch.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OmrAiReviewer {
  OmrAiReviewer({
    required SongFileStorage storage,
    OmrAiClient? client,
    OmrPageCrop crop = const OmrPageCrop(),
    this.maxCalls = 5,
  }) : _storage = storage,
       _client = client ?? OmrAiClient(),
       _crop = crop;

  final SongFileStorage _storage;
  final OmrAiClient _client;
  final OmrPageCrop _crop;
  final int maxCalls;

  Future<OmrAiClient> _clientWithKey() async {
    if (_client.isConfigured) return _client;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('xai_api_key')?.trim() ?? '';
    if (stored.isEmpty) return _client;
    return OmrAiClient(config: OmrAiConfig(apiKey: stored));
  }

  Future<bool> get hasKey async {
    if (_client.isConfigured) return true;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('xai_api_key') ?? '').trim().isNotEmpty;
  }

  Future<void> saveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('xai_api_key', key.trim());
  }

  /// The caller must first show and confirm the exact source crop.
  Future<OmrAiReview> reviewRegion({
    required Uint8List pngBytes,
    required OmrAiPatch target,
  }) async {
    final client = await _clientWithKey();
    if (!client.isConfigured) {
      throw const FormatException('XAI_API_KEY를 저장하세요.');
    }
    return client.review(pngBytes: pngBytes, prompt: target.prompt);
  }

  Future<OmrQualityReport> review({
    required String songId,
    required MusicScore score,
    required String musicXml,
    required OmrQualityReport report,
  }) async {
    final client = await _clientWithKey();
    if (!client.isConfigured) {
      throw const FormatException('XAI_API_KEY가 없습니다.');
    }
    final original = await _storage.loadOmrSource(songId);
    if (original == null) {
      throw const FormatException('원본 PDF가 없습니다. 다시 변환하세요.');
    }
    if (!original.fileName.toLowerCase().endsWith('.pdf')) {
      throw const FormatException('원본이 PDF일 때만 페이지를 잘라 AI에 보냅니다.');
    }
    final targets = _pick(report);
    var issues = [...report.issues];
    for (final issue in targets) {
      final measureIndex = _measureIndex(score, issue.measureNumber);
      if (measureIndex < 0) continue;
      final png = await _crop.renderMeasurePage(
        pdfBytes: Uint8List.fromList(original.bytes),
        measureIndex: measureIndex,
        musicXml: musicXml,
      );
      final prompt = _prompt(
        issue: issue,
        score: score,
        musicXml: musicXml,
        measureIndex: measureIndex,
      );
      final ai = await client.review(pngBytes: png, prompt: prompt);
      issues = [
        for (final item in issues)
          if (item.rule == issue.rule &&
              item.measureNumber == issue.measureNumber)
            item.copyWith(ai: ai)
          else
            item,
      ];
    }
    return report.copyWith(issues: issues);
  }

  List<OmrQualityIssue> _pick(OmrQualityReport report) {
    final picked = <OmrQualityIssue>[];
    final seenMeasures = <String>{};
    final ordered = [
      ...report.issues.where(
        (issue) => issue.severity == OmrIssueSeverity.high,
      ),
      ...report.issues.where(
        (issue) => issue.severity == OmrIssueSeverity.medium,
      ),
    ];
    for (final issue in ordered) {
      if (picked.length >= maxCalls) break;
      if (issue.measureNumber == null) continue;
      final key = '${issue.rule}:${issue.measureNumber}';
      if (!seenMeasures.add(key)) continue;
      if (issue.rule == 'V001' &&
          picked.where((item) => item.rule == 'V001').length >= 3) {
        continue;
      }
      picked.add(issue);
    }
    return picked;
  }

  int _measureIndex(MusicScore score, String? number) {
    if (number == null) return 0;
    for (final part in score.parts) {
      final index = part.measures.indexWhere((m) => m.number == number);
      if (index >= 0) return index;
    }
    return -1;
  }

  String _prompt({
    required OmrQualityIssue issue,
    required MusicScore score,
    required String musicXml,
    required int measureIndex,
  }) {
    final part = score.parts.first;
    final measures = part.measures;
    if (measures.isEmpty) {
      return 'Inspect the score image. Return JSON only: {"hasError":false,"corrections":[],"overallConfidence":0}';
    }
    final current = measureIndex.clamp(0, measures.length - 1);
    final prev = current > 0 ? measures[current - 1] : null;
    final next = current + 1 < measures.length ? measures[current + 1] : null;
    final time = measures
        .map((m) => m.attributes.time)
        .whereType<MusicTimeSignature>()
        .firstOrNull;
    final key = measures.first.attributes.keyFifths;
    final currentXml = _measureXml(musicXml, measures[current].number);
    return '''
Inspect the full source PDF page. Locate the target measure by its number and
neighboring notes. If you cannot locate it reliably, return no corrections.

TIME_SIGNATURE:
${time == null ? 'unknown' : '${time.beats}/${time.beatType}'}

KEY_FIFTHS:
$key

VALIDATION_ERROR:
${issue.rule}
${issue.message}

PREVIOUS_MEASURE:
${prev == null ? 'none' : _summarize(prev)}

CURRENT_MEASURE:
${_summarize(measures[current])}

NEXT_MEASURE:
${next == null ? 'none' : _summarize(next)}

CURRENT_MUSICXML:
$currentXml

Determine whether any recognized element is incorrect.
Do not rewrite the entire measure.
Only return corrections for elements that can be visually verified.
Allowed properties: pitch, duration, accidental, rest, beam, tie, slur, tuplet, voice, clef, key_signature, time_signature, measure, repeat, unknown, harmony, lyric.

Return JSON only:
{"hasError":true,"corrections":[{"elementId":"note_1","property":"duration","currentValue":"eighth","suggestedValue":"quarter","confidence":0.97}],"overallConfidence":0.95}
''';
  }

  String _summarize(MusicMeasure measure) {
    final notes = [
      for (final note in measure.notes)
        '${note.isRest ? 'rest' : '${note.pitch?.step.musicXmlName}${note.pitch?.octave}'} ${note.type ?? note.duration}',
    ];
    return 'measure ${measure.number}: ${notes.join(', ')}';
  }

  String _measureXml(String musicXml, String number) {
    final pattern = RegExp(
      '<measure[^>]*number="$number"[^>]*>[\\s\\S]*?</measure>',
    );
    return pattern.firstMatch(musicXml)?.group(0) ?? '';
  }
}

final omrAiReviewerProvider = Provider<OmrAiReviewer>((ref) {
  return OmrAiReviewer(storage: ref.watch(songFileStorageProvider));
});
