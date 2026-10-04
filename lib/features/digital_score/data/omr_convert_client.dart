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

/// The server no longer has the job (kept for six hours after it finished).
class OmrJobNotFoundException extends OmrConvertException {
  const OmrJobNotFoundException() : super('변환 작업을 찾을 수 없습니다.');
}

/// The server counts conversions and AI calls per install and per day; this
/// install has used up today's.
class OmrRateLimitedException extends OmrConvertException {
  const OmrRateLimitedException()
    : super('오늘 쓸 수 있는 횟수를 모두 썼습니다. 내일 다시 시도하세요.');
}

/// Keeps the secret the server gave this install when it registered.
abstract class OmrClientSecretStore {
  Future<String?> read();
  Future<void> write(String secret);
  Future<void> clear();
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
    this.ai = 'off',
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
      ai: json['ai']?.toString() ?? 'off',
    );
  }

  final String id;
  final String status;
  final int progress;
  final String step;
  final String error;
  final OmrRecognitionProfile profile;

  /// AI review: off, running, done (AI version ready), unchanged, error.
  final String ai;

  bool get isDone => status == 'done';
  bool get isError => status == 'error';
  bool get isRunning => !isDone && !isError;
}

class OmrConvertClient {
  OmrConvertClient({
    OmrConvertConfig config = const OmrConvertConfig(),
    http.Client? httpClient,
    OmrClientSecretStore? secrets,
    this.timeout = const Duration(minutes: 12),
  }) : _config = config,
       _http = httpClient ?? http.Client(),
       _secrets = secrets;

  final OmrConvertConfig _config;
  final http.Client _http;
  final Duration timeout;

  /// Where this install's secret is kept. Without it the client only has
  /// the app key, as builds before registration did.
  final OmrClientSecretStore? _secrets;
  String? _secret;

  /// The server has no registration (an older one): asked once per run.
  var _noRegistration = false;

  /// The key every build carries. It only says "this is the app".
  Map<String, String> get _appKey => {'X-Omr-Token': _config.token};

  /// Sends a request as this install. The install registers the first time
  /// and keeps its secret; a server that no longer knows the secret (it was
  /// set up again) is registered with once more.
  Future<http.Response> _authed(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final response = await send(await _identity());
    if (response.statusCode != 401 || _secret == null) return response;
    _secret = null;
    await _secrets?.clear();
    return send(await _identity());
  }

  Future<Map<String, String>> _identity() async {
    final store = _secrets;
    if (store == null) return _appKey;
    var secret = _secret ??= await store.read();
    if (secret == null && !_noRegistration) {
      secret = _secret = await _register();
      if (secret != null) await store.write(secret);
    }
    return {..._appKey, if (secret != null) 'Authorization': 'Bearer $secret'};
  }

  /// The secret of a new registration, or null when the server gave none:
  /// the request then goes with the app key alone, and the server decides.
  Future<String?> _register() async {
    try {
      final response = await _http
          .post(Uri.parse('${_config.baseUrl}/clients'), headers: _appKey)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404 || response.statusCode == 405) {
        _noRegistration = true;
        return null;
      }
      if (response.statusCode != 201) return null;
      final decoded = jsonDecode(response.body);
      final secret = decoded is Map ? decoded['secret'] : null;
      return secret is String && secret.isNotEmpty ? secret : null;
    } on Object {
      return null;
    }
  }

  Future<bool> isReachable() async {
    try {
      final response = await _http
          .get(Uri.parse('${_config.baseUrl}/health'), headers: _appKey)
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
    final response = await _authed((headers) async {
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers)
        ..fields['profile'] = profile.wireValue
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );
      final streamed = await _http.send(request).timeout(timeout);
      return http.Response.fromStream(streamed).timeout(timeout);
    });
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw _failure(response);
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
    final response = await _authed(
      (headers) => _http
          .get(Uri.parse('${_config.baseUrl}/jobs/$jobId'), headers: headers)
          .timeout(const Duration(seconds: 15)),
    );
    if (response.statusCode == 404) throw const OmrJobNotFoundException();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(response);
    }
    return _jobFromBody(response.body);
  }

  /// Runs the job's AI review again (it failed, e.g. for lack of API credit)
  /// and returns the job with `ai == 'running'`.
  Future<OmrRemoteJob> retryAiReview(String jobId) async {
    final response = await _authed(
      (headers) => _http
          .post(
            Uri.parse('${_config.baseUrl}/jobs/$jobId/ai-review'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15)),
    );
    // "not available": the job has no book to review (not a lead sheet).
    if (response.statusCode == 404 && _errorMessage(response) == 'not found') {
      throw const OmrJobNotFoundException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(response);
    }
    return _jobFromBody(response.body);
  }

  /// Accompaniment advice for the lead sheet [brief] describes: a style per
  /// section and chord symbols to look at again, as the server's JSON.
  Future<Map<String, Object?>> arrangementAdvice({
    required String brief,
    required int bars,
    int firstBar = 1,
  }) async {
    final response = await _authed(
      (headers) => _http
          .post(
            Uri.parse('${_config.baseUrl}/arrange/advice'),
            headers: {...headers, 'Content-Type': 'application/json'},
            // "first": the number the brief gives the first bar.
            body: jsonEncode({'brief': brief, 'bars': bars, 'first': firstBar}),
          )
          .timeout(const Duration(seconds: 90)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(response);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const OmrConvertException('변환 서버 응답을 읽지 못했습니다.');
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<Uint8List> jobResult(String jobId) async {
    final response = await _authed(
      (headers) => _http
          .get(
            Uri.parse('${_config.baseUrl}/jobs/$jobId/result'),
            headers: headers,
          )
          .timeout(timeout),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(response);
    }
    if (response.bodyBytes.isEmpty) {
      throw const OmrConvertException('변환 결과가 비어 있습니다.');
    }
    return response.bodyBytes;
  }

  /// MusicXML exactly as the OMR engine exported it, before the server's
  /// automatic corrections. Null when the server does not keep it.
  Future<Uint8List?> jobRawResult(String jobId) async {
    final response = await _optional('/jobs/$jobId/raw');
    if (response == null || response.bodyBytes.isEmpty) return null;
    return response.bodyBytes;
  }

  /// The server's automatic corrections as before/after items, or null.
  Future<String?> jobCorrections(String jobId) async {
    final response = await _optional('/jobs/$jobId/corrections');
    return response == null ? null : utf8.decode(response.bodyBytes);
  }

  /// Colour pen and highlighter the server took out of the upload before
  /// reading it, with their place on the page, or null when it found none.
  Future<String?> jobAnnotations(String jobId) async {
    final response = await _optional('/jobs/$jobId/annotations');
    return response == null ? null : utf8.decode(response.bodyBytes);
  }

  /// Rule-based suspect measures found on the server, or null.
  Future<String?> jobValidation(String jobId) async {
    final response = await _optional('/jobs/$jobId/validation');
    return response == null ? null : utf8.decode(response.bodyBytes);
  }

  /// The original crop around one suspect measure, named in the validation
  /// report, or null.
  Future<Uint8List?> jobSuspectImage(String jobId, String name) async {
    final response = await _optional(
      '/jobs/$jobId/suspects/${Uri.encodeComponent(name)}',
    );
    if (response == null || response.bodyBytes.isEmpty) return null;
    return response.bodyBytes;
  }

  /// Where every measure is on the original (its staff-line image and place
  /// in it), or null.
  Future<String?> jobLayout(String jobId) async {
    final response = await _optional('/jobs/$jobId/layout');
    return response == null ? null : utf8.decode(response.bodyBytes);
  }

  /// One staff line of the original page, named in the layout, or null.
  Future<Uint8List?> jobSystemImage(String jobId, String name) async {
    final response = await _optional(
      '/jobs/$jobId/systems/${Uri.encodeComponent(name)}',
    );
    if (response == null || response.bodyBytes.isEmpty) return null;
    return response.bodyBytes;
  }

  /// The server's AI version (chord and lyric suggestions applied), or null
  /// when the server made none.
  Future<Uint8List?> jobAiResult(String jobId) async {
    final response = await _optional('/jobs/$jobId/ai');
    if (response == null || response.bodyBytes.isEmpty) return null;
    return response.bodyBytes;
  }

  /// Every AI suggestion per measure, applied or listed only, or null.
  Future<String?> jobAiReview(String jobId) async {
    final response = await _optional('/jobs/$jobId/ai-review');
    return response == null ? null : utf8.decode(response.bodyBytes);
  }

  Future<http.Response?> _optional(String path) async {
    try {
      final response = await _authed(
        (headers) => _http
            .get(Uri.parse('${_config.baseUrl}$path'), headers: headers)
            .timeout(timeout),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return response;
    } on Object {
      // An older server has neither file; the corrected result still imports.
      return null;
    }
  }

  OmrRemoteJob _jobFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const OmrConvertException('변환 서버 응답을 읽지 못했습니다.');
    }
    return OmrRemoteJob.fromJson(Map<String, Object?>.from(decoded));
  }

  OmrConvertException _failure(http.Response response) =>
      switch (response.statusCode) {
        429 => const OmrRateLimitedException(),
        // Registering again did not help: the server does not take this
        // build's app key any more.
        401 => const OmrConvertException('이 버전의 앱으로는 변환할 수 없습니다. 앱을 업데이트하세요.'),
        _ => OmrConvertException(_errorMessage(response)),
      };

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
