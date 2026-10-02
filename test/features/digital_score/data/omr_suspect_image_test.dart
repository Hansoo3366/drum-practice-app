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
  });
}
