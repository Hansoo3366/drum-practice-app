import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_config.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';

const _aiXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>
<part id="P1"><measure number="1"><attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
<note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note></measure></part></score-partwise>''';

void main() {
  late Directory root;
  late AppDatabase database;
  late SongFileStorage storage;
  late HttpServer server;

  /// The server's job, as the fake answers it.
  late String ai;
  late List<String> requests;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('omr_ai_fetch_');
    database = AppDatabase(NativeDatabase.memory());
    storage = SongFileStorage(rootDirectoryProvider: () async => root);
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final path = request.uri.path;
      requests.add('${request.method} $path');
      final response = request.response;
      void json(Object body, [int status = 200]) => response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      final job = {'id': 'job-1', 'status': 'done', 'progress': 100};
      switch ('${request.method} $path') {
        case 'GET /jobs/job-1':
          json({...job, 'ai': ai});
          // The review finishes between two polls.
          if (ai == 'running') ai = 'done';
        case 'POST /jobs/job-1/ai-review':
          ai = 'running';
          json({...job, 'ai': ai}, 202);
        case 'GET /jobs/job-1/ai':
          // The server sends ai.mxl, a compressed MusicXML file.
          const codec = MusicXmlCodec();
          response.add(
            codec.encode(codec.decodeXml(_aiXml), MusicXmlFileFormat.mxl),
          );
        case 'GET /jobs/job-1/ai-review':
          json({'measures': 1});
        default:
          json({'error': 'not found'}, 404);
      }
      await response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await database.close();
    await root.delete(recursive: true);
  });

  OmrConvertService service() => OmrConvertService(
    client: OmrConvertClient(
      config: OmrConvertConfig(
        baseUrl: 'http://127.0.0.1:${server.port}',
        token: 't',
      ),
    ),
    importer: MusicXmlImportService(
      repository: SongRepository(database, LabelRepository(database), storage),
      storage: storage,
    ),
    storage: storage,
  );

  Future<OmrAiFetch> fetch() =>
      service().fetchAiVersion('song', pollInterval: Duration.zero);

  test('runs a failed AI review again and adds the AI version', () async {
    await storage.saveOmrJobId('song', 'job-1');
    ai = 'error';

    expect(await fetch(), OmrAiFetch.added);

    expect(requests, contains('POST /jobs/job-1/ai-review'));
    final catalog = await DigitalScoreEditorService(
      storage: storage,
    ).loadVersionCatalog('song');
    final added = catalog.versions.single;
    expect(
      (added.name, added.origin),
      (aiCorrectedVersionName, aiVersionOrigin),
    );
    expect(catalog.activeId, added.id);
    expect(await storage.loadOmrAiReview('song'), isNotNull);
  });

  test('a finished review is fetched without running it again', () async {
    await storage.saveOmrJobId('song', 'job-1');
    ai = 'done';

    expect(await fetch(), OmrAiFetch.added);
    expect(requests, isNot(contains('POST /jobs/job-1/ai-review')));
  });

  test('tells why nothing was added', () async {
    expect(await fetch(), OmrAiFetch.expired); // no job id kept

    await storage.saveOmrJobId('song', 'gone');
    expect(await fetch(), OmrAiFetch.expired); // the server dropped the job

    await storage.saveOmrJobId('song', 'job-1');
    ai = 'unchanged';
    expect(await fetch(), OmrAiFetch.unchanged);
  });
}
