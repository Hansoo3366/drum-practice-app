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
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';

/// A one-bar score whose only note is [step]: C as the rules left it, D as the
/// AI review corrected it.
String _xml(String step) => '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>V</part-name></score-part></part-list>
<part id="P1"><measure number="1"><attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
<note><pitch><step>$step</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note></measure></part></score-partwise>''';

void main() {
  late Directory root;
  late AppDatabase database;
  late SongFileStorage storage;
  late HttpServer server;

  /// Whether the fake server's job finished its AI review.
  late bool reviewed;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('omr_import_');
    database = AppDatabase(NativeDatabase.memory());
    storage = SongFileStorage(rootDirectoryProvider: () async => root);
    reviewed = true;
    const codec = MusicXmlCodec();
    List<int> mxl(String step) =>
        codec.encode(codec.decodeXml(_xml(step)), MusicXmlFileFormat.mxl);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;
      void json(Object body, [int status = 200]) => response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      switch ('${request.method} ${request.uri.path}') {
        case 'GET /jobs/job-1':
          json({
            'id': 'job-1',
            'status': 'done',
            'progress': 100,
            'ai': reviewed ? 'done' : 'error',
          });
        case 'GET /jobs/job-1/result':
          response.add(mxl('C'));
        case 'GET /jobs/job-1/corrections':
          json({'items': <Object>[]});
        case 'GET /jobs/job-1/ai' when reviewed:
          response.add(mxl('D'));
        case 'GET /jobs/job-1/ai-review' when reviewed:
          json({'measures': 1});
        case 'POST /jobs/job-1/ai-review':
          reviewed = true;
          json({'id': 'job-1', 'status': 'done', 'ai': 'done'}, 202);
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

  /// The first note of the song's original, as stored.
  Future<PitchStep?> original(String songId) async {
    final song = await (database.select(
      database.songs,
    )..where((s) => s.id.equals(songId))).getSingle();
    final bytes = await File('${root.path}/${song.sourcePath}').readAsBytes();
    final score = const MusicXmlCodec().decode(
      bytes,
      fileName: song.sourcePath,
    );
    return score.parts.first.measures.first.events
        .whereType<MusicNote>()
        .first
        .pitch
        ?.step;
  }

  test(
    'the original of a conversion is the score the AI review finished',
    () async {
      final id = await service().importResult(jobId: 'job-1', title: '곡');

      expect(await original(id), PitchStep.d);
      // Nothing to choose between: the stages before it are not versions.
      final catalog = await DigitalScoreEditorService(
        storage: storage,
      ).loadVersionCatalog(id);
      expect(catalog.versions, isEmpty);
      expect(await storage.loadOmrOriginalHasAi(id), isTrue);
      expect(await storage.loadOmrAiReview(id), isNotNull);
      expect(await storage.loadOmrCorrections(id), isNotNull);
      expect(await storage.loadOmrJobId(id), 'job-1');
    },
  );

  test('without a finished review the rule-corrected score is the original, '
      'and the review can still be fetched', () async {
    reviewed = false;
    final id = await service().importResult(jobId: 'job-1', title: '곡');

    expect(await original(id), PitchStep.c);
    expect(await storage.loadOmrOriginalHasAi(id), isFalse);
    expect(await storage.loadOmrAiReview(id), isNull);

    // "AI 보정 받기": the original stays; the review arrives as a version.
    expect(
      await service().fetchAiVersion(id, pollInterval: Duration.zero),
      OmrAiFetch.added,
    );
    expect(await original(id), PitchStep.c);
    final catalog = await DigitalScoreEditorService(
      storage: storage,
    ).loadVersionCatalog(id);
    expect(catalog.versions.single.name, aiCorrectedVersionName);
    expect(catalog.activeId, catalog.versions.single.id);
  });

  test('removing a song forgets that its original had the review', () async {
    final id = await service().importResult(jobId: 'job-1', title: '곡');
    await storage.deleteOmrReviewFiles(id);

    expect(await storage.loadOmrOriginalHasAi(id), isFalse);
  });
}
