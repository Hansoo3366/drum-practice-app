import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_config.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late SongFileStorage storage;
  late HttpServer server;
  late List<String> requests;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('omr_suspect_');
    database = AppDatabase(NativeDatabase.memory());
    storage = SongFileStorage(rootDirectoryProvider: () async => root);
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri.path);
      if (request.uri.path == '/jobs/job-1/suspects/p1-s1-m4.png') {
        request.response.add([1, 2, 3]);
      } else if (request.uri.path == '/jobs/job-1/layout') {
        request.response.write(
          '{"parts":[[{"image":"p1-s1.jpg","focus":[0.1,0.5]},null]]}',
        );
      } else if (request.uri.path == '/jobs/job-1/systems/p1-s1.jpg') {
        request.response.add([7, 8]);
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
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

  test('fetches a crop once and keeps it with the song', () async {
    await storage.saveOmrJobId('song', 'job-1');

    expect(await service().suspectImage('song', 'p1-s1-m4.png'), [1, 2, 3]);
    expect(await service().suspectImage('song', 'p1-s1-m4.png'), [1, 2, 3]);

    expect(requests, ['/jobs/job-1/suspects/p1-s1-m4.png']);
    expect(await storage.loadOmrSuspectImage('song', 'p1-s1-m4.png'), [
      1,
      2,
      3,
    ]);
  });

  test('has no crop when the server has none, or the song no job', () async {
    expect(await service().suspectImage('song', 'p1-s1-m4.png'), isNull);
    expect(requests, isEmpty);

    await storage.saveOmrJobId('song', 'job-1');
    expect(await service().suspectImage('song', 'p9-s9-m9.png'), isNull);
  });

  test('a crop name cannot leave the song folder', () async {
    await storage.saveOmrSuspectImage('song', '../../escape.png', [9]);

    expect(File('${root.path}/escape.png').existsSync(), isFalse);
    expect(await storage.loadOmrSuspectImage('song', 'escape.png'), [9]);
    // A name that is no file name at all is refused, and has no crop.
    for (final name in ['..', '.', '', 'a.jpg', '.png']) {
      expect(
        () => storage.omrSuspectImagePathFor('song', name),
        throwsFormatException,
        reason: name,
      );
      expect(await service().suspectImage('song', name), isNull, reason: name);
    }
  });

  test('the originals of a song converted earlier are fetched once', () async {
    expect(await service().barPlaces('song'), isNull);

    await storage.saveOmrJobId('song', 'job-1');
    final places = await service().barPlaces('song');
    expect(places!.single, [(image: 'p1-s1.jpg', focus: (0.1, 0.5)), null]);
    expect(await service().systemImage('song', 'p1-s1.jpg'), [7, 8]);
    expect(await service().systemImage('song', 'p9-s9.jpg'), isNull);
    expect(await service().systemImage('song', '../x.png'), isNull);

    requests.clear();
    expect((await service().barPlaces('song'))!.single, hasLength(2));
    expect(await service().systemImage('song', 'p1-s1.jpg'), [7, 8]);
    expect(requests, isEmpty);

    await storage.deleteOmrReviewFiles('song');
    expect(await storage.loadOmrLayout('song'), isNull);
    expect(await storage.loadOmrSystemImage('song', 'p1-s1.jpg'), isNull);
  });

  test('what a conversion left with a song goes with the song', () async {
    await storage.saveOmrSuspectImage('song', 'p1-s1-m1.png', [1]);
    await storage.saveOmrSuspectImage('other', 'p1-s1-m1.png', [2]);
    await storage.saveOmrReviewState('song', '{"checked":["0:1"]}');
    await storage.saveOmrAnnotations('song', '{"items":[]}');
    await storage.saveOmrValidation('song', '{"issues":[]}');

    await storage.deleteOmrReviewFiles('song');
    await storage.deleteOmrReviewFiles('never-converted');

    expect(await storage.loadOmrSuspectImage('song', 'p1-s1-m1.png'), isNull);
    expect(await storage.loadOmrReviewState('song'), isNull);
    expect(await storage.loadOmrAnnotations('song'), isNull);
    expect(await storage.loadOmrValidation('song'), isNull);
    expect(await storage.loadOmrSuspectImage('other', 'p1-s1-m1.png'), [2]);
  });
}
