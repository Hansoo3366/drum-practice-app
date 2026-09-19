import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/pdf_import_service.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late PdfImportService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('page_a_diddle_test_');
    database = AppDatabase(NativeDatabase.memory());
    service = PdfImportService(
      repository: SongRepository(
        database,
        LabelRepository(database),
        SongFileStorage(rootDirectoryProvider: () async => root),
      ),
      storage: SongFileStorage(rootDirectoryProvider: () async => root),
      idGenerator: () => 'song-1',
      clock: () => DateTime(2026, 8, 19, 10),
    );
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('PDF를 앱 저장소로 복사하고 곡 정보를 저장한다', () async {
    final id = await service.importPdf(
      file: PickedLocalFile(
        name: 'practice.pdf',
        bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
      ),
      title: 'Practice Song',
      artist: 'Band',
      defaultTempo: 128,
    );

    final song = await database.select(database.songs).getSingle();
    final savedFile = File('${root.path}/${song.sourcePath}');

    expect(id, 'song-1');
    expect(song.title, 'Practice Song');
    expect(song.artist, 'Band');
    expect(song.defaultTempo, 128);
    expect(song.offlineAvailable, isTrue);
    expect(await savedFile.readAsString(), '%PDF-1.7');
  });

  test('40~240 범위를 벗어난 BPM은 파일을 저장하지 않는다', () async {
    for (final tempo in [39, 241]) {
      expect(
        () => service.importPdf(
          file: PickedLocalFile(
            name: 'practice.pdf',
            bytes: Uint8List.fromList('%PDF'.codeUnits),
          ),
          title: 'Practice Song',
          defaultTempo: tempo,
        ),
        throwsFormatException,
      );
    }

    expect(Directory('${root.path}/scores').existsSync(), isFalse);
  });

  test('OS 파일 선택기로 가져온 곡은 확인 가능한 원본 경로를 기록한다', () async {
    await service.importPdf(
      file: PickedLocalFile(
        name: 'provider.pdf',
        bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
      ),
      title: 'Provider Song',
      sourceProvider: StorageProvider.osFileProvider,
    );

    final song = await database.select(database.songs).getSingle();

    expect(song.sourceProvider, StorageProvider.osFileProvider.key);
    expect(song.offlineAvailable, isTrue);
  });

  test('빈 파일은 PDF로 저장하지 않는다', () async {
    expect(
      () => service.importPdf(
        file: PickedLocalFile(name: 'empty.pdf', bytes: Uint8List(0)),
        title: 'Empty Score',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'PDF를 다시 선택하세요.',
        ),
      ),
    );

    expect(await database.select(database.songs).get(), isEmpty);
    expect(File('${root.path}/scores/song-1.pdf').existsSync(), isFalse);
  });
}
