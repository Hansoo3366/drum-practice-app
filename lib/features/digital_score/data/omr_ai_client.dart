import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:page_a_diddle/features/digital_score/data/omr_ai_config.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_review.dart';

class OmrAiClient {
  OmrAiClient({
    OmrAiConfig config = const OmrAiConfig(),
    http.Client? httpClient,
  }) : _config = config,
       _http = httpClient ?? http.Client();

  final OmrAiConfig _config;
  final http.Client _http;

  bool get isConfigured => _config.isConfigured;

  Future<OmrAiReview> review({
    required Uint8List pngBytes,
    required String prompt,
  }) async {
    if (!_config.isConfigured) {
      throw const FormatException('XAI_API_KEY가 없습니다.');
    }
    final imageUrl = 'data:image/png;base64,${base64Encode(pngBytes)}';
    final body = jsonEncode({
      'model': _config.model,
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_image', 'image_url': imageUrl, 'detail': 'high'},
            {'type': 'input_text', 'text': prompt},
          ],
        },
      ],
    });
    final response = await _http
        .post(
          Uri.parse('${_config.baseUrl}/responses'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${_config.apiKey}',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'AI 검수 실패 (${response.statusCode}): ${response.body}',
      );
    }
    final text = _outputText(response.body);
    return OmrAiReview.parseModelText(text);
  }

  String _outputText(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return raw;
    final output = decoded['output'];
    if (output is List) {
      final buffer = StringBuffer();
      for (final item in output) {
        if (item is! Map) continue;
        final content = item['content'];
        if (content is! List) continue;
        for (final block in content) {
          if (block is Map && block['text'] != null) {
            buffer.writeln(block['text']);
          }
        }
      }
      if (buffer.isNotEmpty) return buffer.toString();
    }
    final outputText = decoded['output_text'];
    if (outputText is String && outputText.isNotEmpty) return outputText;
    return raw;
  }
}
