import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:page_a_diddle/features/digital_score/data/omr_convert_config.dart';

class OmrConvertException implements Exception {
  const OmrConvertException(this.message);
  final String message;

  @override
  String toString() => message;
}

enum OmrRecognitionProfile { standard, chordsLyrics }

extension OmrRecognitionProfileWire on OmrRecognitionProfile {
  String get wireValue => switch (this) {
    OmrRecognitionProfile.standard => 'standard',
    OmrRecognitionProfile.chordsLyrics => 'chords_lyrics',
  };
}

class OmrRemoteJob {
  const OmrRemoteJob({
    required this.id,
    required this.status,
    required this.progress,
    this.step = '',
    this.error = '',
    this.profile = OmrRecognitionProfile.standard,
  });

  factory OmrRemoteJob.fromJson(Map<String, Object?> json) {
    return OmrRemoteJob(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      progress: (json['progress'] as num?)?.round() ?? 0,
      step: json['step']?.toString() ?? '',
      error: json['error']?.toString() ?? '',
      profile: json['profile'] == 'chords_lyrics'
          ? OmrRecognitionProfile.chordsLyrics
          : OmrRecognitionProfile.standard,
    );
  }

  final String id;
  final String status;
  final int progress;
  final String step;
  final String error;
  final OmrRecognitionProfile profile;

  bool get isDone => status == 'done';
  bool get isError => status == 'error';
  bool get isRunning => !isDone && !isError;
}

class OmrConvertClient {
  OmrConvertClient({
    OmrConvertConfig config = const OmrConvertConfig(),
    http.Client? httpClient,
    this.timeout = const Duration(minutes: 12),
  }) : _config = config,
       _http = httpClient ?? http.Client();

  final OmrConvertConfig _config;
  final http.Client _http;
  final Duration timeout;

  Map<String, String> get _headers => {'X-Omr-Token': _config.token};

  Future<bool> isReachable() async {
    try {
      final response = await _http
          .get(Uri.parse('${_config.baseUrl}/health'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } on Object {
      return false;
    }
  }

  Future<OmrRemoteJob> startConvert({
    required String fileName,
    required Uint8List bytes,
    OmrRecognitionProfile profile = OmrRecognitionProfile.standard,
  }) async {
    final uri = Uri.parse('${_config.baseUrl}/convert');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers)
      ..fields['profile'] = profile.wireValue
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    final streamed = await _http.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed).timeout(timeout);
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw OmrConvertException(_errorMessage(response));
    }
    final job = _jobFromBody(response.body);
    if (job.id.isEmpty) {
      throw const OmrConvertException('변환 작업 id가 없습니다.');
    }
    if (job.profile != profile) {
      throw const OmrConvertException('변환 서버를 최신 버전으로 갱신하세요.');
    }
    return job;
  }

  Future<OmrRemoteJob> jobStatus(String jobId) async {
    final response = await _http
        .get(Uri.parse('${_config.baseUrl}/jobs/$jobId'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) {
      throw const OmrConvertException('변환 작업을 찾을 수 없습니다.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OmrConvertException(_errorMessage(response));
    }
    return _jobFromBody(response.body);
  }

  Future<Uint8List> jobResult(String jobId) async {
    final response = await _http
        .get(
          Uri.parse('${_config.baseUrl}/jobs/$jobId/result'),
          headers: _headers,
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OmrConvertException(_errorMessage(response));
    }
    if (response.bodyBytes.isEmpty) {
      throw const OmrConvertException('변환 결과가 비어 있습니다.');
    }
    return response.bodyBytes;
  }

  OmrRemoteJob _jobFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const OmrConvertException('변환 서버 응답을 읽지 못했습니다.');
    }
    return OmrRemoteJob.fromJson(Map<String, Object?>.from(decoded));
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } on Object {
      // Fall through to the raw body.
    }
    if (response.body.trim().isNotEmpty) return response.body.trim();
    return '변환 서버가 ${response.statusCode}을 반환했습니다.';
  }
}
