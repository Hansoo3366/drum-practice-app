import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:uuid/uuid.dart';

typedef IdGenerator = String Function();
typedef Clock = DateTime Function();

class PdfImportService {
  PdfImportService({
    required SongRepository repository,
    required SongFileStorage storage,
    IdGenerator? idGenerator,
    Clock? clock,
  }) : _repository = repository,
       _storage = storage,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _clock = clock ?? DateTime.now;

  final SongRepository _repository;
  final SongFileStorage _storage;
  final IdGenerator _idGenerator;
  final Clock _clock;

  Future<String> importPdf({
    required PickedLocalFile file,
    required String title,
    String? artist,
    int? defaultTempo,
    StorageProvider sourceProvider = StorageProvider.local,
    String? folderId,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('곡명 필요');
    }
    if (defaultTempo != null && (defaultTempo < 40 || defaultTempo > 240)) {
      throw const FormatException('BPM 40~240');
    }

    final id = _idGenerator();
    final relativePath = await _storage.storePdf(source: file, songId: id);
    final now = _clock();

    try {
      await _repository.saveSong(
        SongsCompanion.insert(
          id: id,
          title: normalizedTitle,
          artist: Value(_emptyToNull(artist)),
          defaultTempo: Value(defaultTempo),
          sourcePath: relativePath,
          sourceProvider: Value(sourceProvider.key),
          folderId: Value(folderId),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } on Object {
      await _storage.delete(relativePath);
      rethrow;
    }

    return id;
  }

  String? _emptyToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

final pdfImportServiceProvider = Provider<PdfImportService>((ref) {
  return PdfImportService(
    repository: ref.watch(songRepositoryProvider),
    storage: ref.watch(songFileStorageProvider),
  );
});
