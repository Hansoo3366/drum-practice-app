import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_config.dart';

class _MemorySecrets implements OmrClientSecretStore {
  _MemorySecrets([this.secret]);

  String? secret;

  @override
  Future<String?> read() async => secret;

  @override
  Future<void> write(String secret) async => this.secret = secret;

  @override
  Future<void> clear() async => secret = null;
}

/// A server that registers installs and answers job status to those it knows.
Future<({HttpServer server, List<String> log, Set<String> known})> _registry({
  bool registers = true,
  bool limited = false,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final log = <String>[];
  final known = <String>{};
  var next = 0;
  server.listen((request) async {
    final bearer = request.headers.value('authorization') ?? '';
    final appKey = request.headers.value('x-omr-token') == 'app-key';
    log.add('${request.method} ${request.uri.path}');
    final response = request.response..headers.contentType = ContentType.json;
    if (request.uri.path == '/clients') {
      if (!registers) {
        response.statusCode = 404;
      } else if (!appKey) {
        response.statusCode = 401;
      } else {
        final secret = 'secret-${++next}';
        known.add(secret);
        response
          ..statusCode = 201
          ..write(jsonEncode({'client': 'c$next', 'secret': secret}));
      }
    } else if (limited) {
      response
        ..statusCode = 429
        ..write(jsonEncode({'error': 'rate limited', 'scope': 'client'}));
    } else if (known.contains(bearer.replaceFirst('Bearer ', '')) ||
        (!registers && appKey)) {
      response.write(
        jsonEncode({'id': 'j1', 'status': 'done', 'progress': 100}),
      );
    } else {
      response
        ..statusCode = 401
        ..write(jsonEncode({'error': 'unauthorized'}));
    }
    await response.close();
  });
  return (server: server, log: log, known: known);
}

void main() {
  OmrConvertClient clientOf(HttpServer server, _MemorySecrets secrets) =>
      OmrConvertClient(
        config: OmrConvertConfig(
          baseUrl: 'http://127.0.0.1:${server.port}',
          token: 'app-key',
        ),
        secrets: secrets,
      );

  test('an install registers once and then asks with its own secret', () async {
    final registry = await _registry();
    addTearDown(registry.server.close);
    final secrets = _MemorySecrets();
    final client = clientOf(registry.server, secrets);

    expect((await client.jobStatus('j1')).isDone, isTrue);
    expect((await client.jobStatus('j1')).isDone, isTrue);

    expect(secrets.secret, 'secret-1');
    expect(registry.log, ['POST /clients', 'GET /jobs/j1', 'GET /jobs/j1']);
    // The next run of the app has the secret already.
    final again = clientOf(registry.server, secrets);
    expect((await again.jobStatus('j1')).isDone, isTrue);
    expect(registry.log.where((line) => line == 'POST /clients'), hasLength(1));
  });

  test('registers again when the server no longer knows the secret', () async {
    final registry = await _registry();
    addTearDown(registry.server.close);
    final secrets = _MemorySecrets('from-before');
    final client = clientOf(registry.server, secrets);

    expect((await client.jobStatus('j1')).isDone, isTrue);

    expect(secrets.secret, 'secret-1');
    expect(registry.log, ['GET /jobs/j1', 'POST /clients', 'GET /jobs/j1']);
  });

  test('a server without registration is asked with the app key', () async {
    final registry = await _registry(registers: false);
    addTearDown(registry.server.close);
    final secrets = _MemorySecrets();
    final client = clientOf(registry.server, secrets);

    expect((await client.jobStatus('j1')).isDone, isTrue);
    expect((await client.jobStatus('j1')).isDone, isTrue);

    expect(secrets.secret, isNull);
    // Asked about registration once, not before every request.
    expect(registry.log, ['POST /clients', 'GET /jobs/j1', 'GET /jobs/j1']);
  });

  test('says so when the uses of the day are spent', () async {
    final registry = await _registry(limited: true);
    addTearDown(registry.server.close);
    final client = clientOf(registry.server, _MemorySecrets());

    await expectLater(
      client.jobStatus('j1'),
      throwsA(
        isA<OmrRateLimitedException>().having(
          (error) => error.message,
          'message',
          contains('내일'),
        ),
      ),
    );
  });

  test('fetches the annotations the server separated, or nothing', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      if (request.uri.path == '/jobs/with/annotations') {
        request.response
          ..headers.contentType = ContentType.json
          ..add(
            utf8.encode(
              jsonEncode({
                'pages': [
                  {'page': 1, 'annotations': 1},
                ],
                'items': [
                  {'page': 1, 'type': 'ink', 'color': 'red', 'text': '도돌이 무시'},
                ],
              }),
            ),
          );
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    final client = OmrConvertClient(
      config: OmrConvertConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 'test-token',
      ),
    );

    final found = await client.jobAnnotations('with');
    expect(
      ((jsonDecode(found!) as Map)['items'] as List).single,
      containsPair('text', '도돌이 무시'),
    );
    expect(await client.jobAnnotations('without'), isNull);
  });

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
        );
      await request.response.close();
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
        );
      await request.response.close();
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
