import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/library/data/audio_attachment_service.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

void main() {
  test('오디오를 앱 저장소에 복사하고 곡에 연결한다', () async {
    final root = await Directory.systemTemp.createTemp('page_a_diddle_audio_');
    final database = AppDatabase(NativeDatabase.memory());
    final repository = SongRepository(
      database,
      LabelRepository(database),
      SongFileStorage(rootDirectoryProvider: () async => root),
    );
    final service = AudioAttachmentService(
      repository: repository,
      storage: SongFileStorage(rootDirectoryProvider: () async => root),
    );
    addTearDown(() async {
      await database.close();
      await root.delete(recursive: true);
    });

    final now = DateTime(2026, 8, 19);
    await repository.saveSong(
      SongsCompanion.insert(
        id: 'song-1',
        title: 'Practice',
        sourcePath: 'scores/song-1.pdf',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await service.attach(
      songId: 'song-1',
      file: PickedLocalFile(
        name: 'track.mp3',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    final song = await repository.getSong('song-1');
    final audioFile = File('${root.path}/${song!.audioPath}');
    expect(song.audioName, 'track.mp3');
    expect(await audioFile.readAsBytes(), [1, 2, 3]);
  });
}
