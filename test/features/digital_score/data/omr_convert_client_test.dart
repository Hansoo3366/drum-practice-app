import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_config.dart';

void main() {
  test('asks for accompaniment advice with the brief as JSON', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decodeStream(request));
      if (request.uri.path != '/arrange/advice' ||
          request.method != 'POST' ||
          request.headers.value('x-omr-token') != 'test-token' ||
          body is! Map ||
          body['bars'] != 36) {
        request.response.statusCode = 400;
      } else if (body['brief'] == 'no credit') {
        request.response
          ..statusCode = 502
          ..write(jsonEncode({'error': 'ai failed'}));
      } else {
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'base': {'pattern': 'held', 'register': 'low'},
              'sections': <Object>[],
              'chords': <Object>[],
              'note': '잔잔한 곡',
              'echo': body['brief'],
            }),
          );
      }
      await request.response.close();
    });
    final client = OmrConvertClient(
      config: OmrConvertConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 'test-token',
      ),
    );

    final advice = await client.arrangementAdvice(brief: '1: G | 솔', bars: 36);

    expect(advice['base'], {'pattern': 'held', 'register': 'low'});
    expect(advice['note'], '잔잔한 곡');
    expect(advice['echo'], '1: G | 솔');
    expect(
      () => client.arrangementAdvice(brief: 'no credit', bars: 36),
      throwsA(
        isA<OmrConvertException>().having(
          (e) => e.message,
          'message',
          'ai failed',
        ),
      ),
    );
  });

  test('starts a convert job and returns its id', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      expect(request.uri.path, '/convert');
      expect(request.headers.value('x-omr-token'), 'test-token');
      final body = await request.fold<List<int>>(<int>[], (prior, chunk) {
        prior.addAll(chunk);
        return prior;
      });
      expect(latin1.decode(body), contains('name="profile"\r\n\r\nstandard'));
      request.response
        ..statusCode = 202
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 'job-1',
            'status': 'queued',
            'progress': 1,
            'step': 'queued',
          }),
        )
        ..close();
    });

    final client = OmrConvertClient(
      config: OmrConvertConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 'test-token',
      ),
    );
    final job = await client.startConvert(
      fileName: 'score.jpg',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
    expect(job.id, 'job-1');
    expect(job.isRunning, isTrue);
  });

  test('sends the chord and lyric recognition profile', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      final body = await request.fold<List<int>>(<int>[], (prior, chunk) {
        prior.addAll(chunk);
        return prior;
      });
      expect(
        latin1.decode(body),
        contains('name="profile"\r\n\r\nchords_lyrics'),
      );
      request.response
        ..statusCode = 202
        ..headers.contentType = ContentType.json
        ..write(
          '{"id":"job-2","status":"queued","progress":1,"profile":"chords_lyrics"}',
        )
        ..close();
    });

    final client = OmrConvertClient(
      config: OmrConvertConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 'test-token',
      ),
    );
    final job = await client.startConvert(
      fileName: 'score.pdf',
      bytes: Uint8List.fromList(const [1, 2, 3]),
      profile: OmrRecognitionProfile.chordsLyrics,
    );
    expect(job.id, 'job-2');
  });

  test('reads job progress from /jobs/:id', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) {
      expect(request.uri.path, '/jobs/job-1');
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'id': 'job-1',
            'status': 'running',
            'progress': 42,
            'step': 'BEAMS',
          }),
        )
        ..close();
    });

    final client = OmrConvertClient(
      config: OmrConvertConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 'test-token',
      ),
    );
    final job = await client.jobStatus('job-1');
    expect(job.progress, 42);
    expect(job.step, 'BEAMS');
  });

  test('reads the uncorrected export and the correction history', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) {
      switch (request.uri.path) {
        case '/jobs/job-1/raw':
          request.response.add([1, 2, 3]);
        case '/jobs/job-1/corrections':
          request.response.write('{"items":[]}');
        case '/jobs/job-1/validation':
          request.response.write('{"issues":[]}');
        case '/jobs/job-1/ai':
          request.response.add([4, 5]);
        case '/jobs/job-1/ai-review':
          request.response.write('{"applied":[]}');
        default:
          request.response.statusCode = 404;
      }
      request.response.close();
    });
    final client = OmrConvertClient(
      config: OmrConvertConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 'test-token',
      ),
    );

    expect(await client.jobRawResult('job-1'), [1, 2, 3]);
    expect(await client.jobCorrections('job-1'), '{"items":[]}');
    expect(await client.jobValidation('job-1'), '{"issues":[]}');
    expect(await client.jobAiResult('job-1'), [4, 5]);
    expect(await client.jobAiReview('job-1'), '{"applied":[]}');
    expect(await client.jobAiResult('job-2'), isNull);
    // An older server has neither: the import falls back to the result.
    expect(await client.jobRawResult('job-2'), isNull);
    expect(await client.jobCorrections('job-2'), isNull);
  });

  test('isReachable is true when /health returns 200', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) {
      expect(request.uri.path, '/health');
      request.response
        ..statusCode = 200
        ..write('{"ok":true}')
        ..close();
    });

    final client = OmrConvertClient(
      config: OmrConvertConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 'test-token',
      ),
    );
    expect(await client.isReachable(), isTrue);
  });
}
