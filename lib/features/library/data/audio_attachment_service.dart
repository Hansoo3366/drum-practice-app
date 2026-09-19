import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

class AudioAttachmentService {
  const AudioAttachmentService({
    required SongRepository repository,
    required SongFileStorage storage,
  }) : _repository = repository,
       _storage = storage;

  final SongRepository _repository;
  final SongFileStorage _storage;

  Future<String> attach({
    required String songId,
    required PickedLocalFile file,
  }) async {
    final song = await _repository.getSong(songId);
    if (song == null) {
      throw StateError('곡 없음');
    }

    final relativePath = await _storage.storeAudio(
      source: file,
      songId: songId,
    );
    try {
      await _repository.attachAudio(
        id: songId,
        path: relativePath,
        name: file.name,
      );
    } on Object {
      await _storage.delete(relativePath);
      rethrow;
    }

    final previousPath = song.audioPath;
    if (previousPath != null && previousPath != relativePath) {
      await _storage.delete(previousPath);
    }
    return file.name;
  }
}

final audioAttachmentServiceProvider = Provider<AudioAttachmentService>((ref) {
  return AudioAttachmentService(
    repository: ref.watch(songRepositoryProvider),
    storage: ref.watch(songFileStorageProvider),
  );
});
