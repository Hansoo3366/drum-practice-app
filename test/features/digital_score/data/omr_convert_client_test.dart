import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_config.dart';

void main() {
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
