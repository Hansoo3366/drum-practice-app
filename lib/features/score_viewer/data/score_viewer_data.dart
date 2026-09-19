import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';

class ScoreViewerData {
  const ScoreViewerData({
    required this.song,
    required this.file,
    this.audioFile,
  });

  final Song song;
  final File file;
  final File? audioFile;
}

final scoreViewerDataProvider = FutureProvider.autoDispose
    .family<ScoreViewerData, String>((ref, id) async {
      final repository = ref.watch(songRepositoryProvider);
      final song = await repository.getSong(id);
      if (song == null) {
        throw StateError('악보 없음');
      }

      final file = await ref
          .watch(songFileStorageProvider)
          .resolve(song.sourcePath);
      if (!await file.exists()) {
        throw StateError('PDF 없음');
      }
      if (await file.length() == 0) {
        throw StateError('빈 PDF입니다. 다시 가져오세요.');
      }

      File? audioFile;
      if (song.audioPath case final audioPath?) {
        final candidate = await ref
            .watch(songFileStorageProvider)
            .resolve(audioPath);
        if (await candidate.exists() && await candidate.length() > 0) {
          audioFile = candidate;
        }
      }

      await repository.markOpened(id);
      return ScoreViewerData(song: song, file: file, audioFile: audioFile);
    });
