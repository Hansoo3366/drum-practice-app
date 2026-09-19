import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:page_a_diddle/features/library/domain/score_type.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late MusicXmlImportService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('musicxml_import_');
    database = AppDatabase(NativeDatabase.memory());
    final storage = SongFileStorage(rootDirectoryProvider: () async => root);
    service = MusicXmlImportService(
      repository: SongRepository(database, LabelRepository(database), storage),
      storage: storage,
      idGenerator: () => 'score-1',
      clock: () => DateTime(2026, 9, 19, 10),
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('validates and stores MusicXML with score metadata', () async {
    final id = await service.importMusicXml(
      file: PickedLocalFile(
        name: 'piano.musicxml',
        bytes: Uint8List.fromList(_musicXml.codeUnits),
      ),
    );

    final song = await database.select(database.songs).getSingle();
    final stored = File('${root.path}/${song.sourcePath}');
    expect(id, 'score-1');
    expect(song.title, 'Local Piano');
    expect(song.artist, 'Composer');
    expect(song.defaultTempo, 88);
    expect(song.scoreType, ScoreType.musicXml.key);
    expect(song.sourcePath, endsWith('.musicxml'));
    expect(await stored.exists(), isTrue);
  });

  test('creates a blank piano MusicXML score', () async {
    final id = await service.createBlank(
      title: '새 곡',
      artist: '작성자',
      defaultTempo: 96,
    );

    final song = await database.select(database.songs).getSingle();
    final stored = File('${root.path}/${song.sourcePath}');
    expect(id, 'score-1');
    expect(song.title, '새 곡');
    expect(song.artist, '작성자');
    expect(song.defaultTempo, 96);
    expect(song.scoreType, ScoreType.musicXml.key);
    expect(await stored.exists(), isTrue);
    final score = await service.inspect(
      PickedLocalFile(
        name: 'score.musicxml',
        bytes: await stored.readAsBytes(),
      ),
    );
    expect(score.measureCount, 1);
    expect(score.parts.single.name, 'Piano');
    expect(score.parts.single.measures.single.attributes.staves, 2);
    expect(score.parts.single.measures.single.notes, hasLength(2));
    expect(
      score.parts.single.measures.single.notes.every((note) => note.isRest),
      isTrue,
    );
  });

  test('does not store an invalid MusicXML document', () async {
    expect(
      () => service.importMusicXml(
        file: PickedLocalFile(
          name: 'broken.musicxml',
          bytes: Uint8List.fromList('<not-a-score/>'.codeUnits),
        ),
      ),
      throwsFormatException,
    );

    expect(await database.select(database.songs).get(), isEmpty);
    expect(Directory('${root.path}/scores').existsSync(), isFalse);
  });
}

const _musicXml = '''
<score-partwise version="4.0">
  <movement-title>Local Piano</movement-title>
  <identification><creator type="composer">Composer</creator></identification>
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions></attributes>
    <direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>88</per-minute></metronome></direction-type></direction>
    <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice></note>
  </measure></part>
</score-partwise>
''';
