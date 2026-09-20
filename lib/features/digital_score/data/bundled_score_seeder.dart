import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef BundledScoreAssetLoader = Future<Uint8List> Function(String path);
typedef BundledScoreFlagReader = Future<bool> Function(String key);
typedef BundledScoreFlagWriter = Future<void> Function(String key);

class BundledScoreDefinition {
  const BundledScoreDefinition({
    required this.id,
    required this.assetPath,
    required this.fileName,
    required this.title,
    required this.artist,
  });

  final String id;
  final String assetPath;
  final String fileName;
  final String title;
  final String artist;

  String get seedKey => 'bundled_score_seeded_v1_$id';
}

const bundledScores = <BundledScoreDefinition>[
  BundledScoreDefinition(
    id: 'bundled-clair-de-lune',
    assetPath: 'assets/scores/clair-de-lune-claude-debussy.mxl',
    fileName: 'clair-de-lune-claude-debussy.mxl',
    title: 'Claire de lune',
    artist: 'Claude Debussy',
  ),
  BundledScoreDefinition(
    id: 'bundled-fantaisie-impromptu',
    assetPath: 'assets/scores/fantaisie-impromptu-in-c-minor-chopin.mxl',
    fileName: 'fantaisie-impromptu-in-c-minor-chopin.mxl',
    title: 'Fantaisie-Impromptu in C♯ Minor',
    artist: 'Frédéric Chopin',
  ),
];

class BundledScoreSeeder {
  BundledScoreSeeder({
    required SongRepository repository,
    required SongFileStorage storage,
    required BundledScoreAssetLoader loadAsset,
    required BundledScoreFlagReader isSeeded,
    required BundledScoreFlagWriter markSeeded,
  }) : _repository = repository,
       _storage = storage,
       _loadAsset = loadAsset,
       _isSeeded = isSeeded,
       _markSeeded = markSeeded;

  final SongRepository _repository;
  final SongFileStorage _storage;
  final BundledScoreAssetLoader _loadAsset;
  final BundledScoreFlagReader _isSeeded;
  final BundledScoreFlagWriter _markSeeded;

  Future<void>? _pending;

  Future<void> ensureSeeded() => _pending ??= _seed();

  Future<void> _seed() async {
    final existing = (await _repository.watchSongs().first).toList();
    for (final definition in bundledScores) {
      if (await _isSeeded(definition.seedKey)) continue;

      final sameTitle = existing.any(
        (song) =>
            song.title.trim().toLowerCase() ==
            definition.title.trim().toLowerCase(),
      );
      final fixedRecord = await _repository.getSong(definition.id);
      if (!sameTitle && fixedRecord == null) {
        final bytes = await _loadAsset(definition.assetPath);
        final importer = MusicXmlImportService(
          repository: _repository,
          storage: _storage,
          idGenerator: () => definition.id,
        );
        await importer.importMusicXml(
          file: PickedLocalFile(name: definition.fileName, bytes: bytes),
          title: definition.title,
          artist: definition.artist,
          sourceProvider: StorageProvider.local,
        );
        final added = await _repository.getSong(definition.id);
        if (added != null) existing.add(added);
      }
      await _markSeeded(definition.seedKey);
    }
  }
}

final bundledScoreSeederProvider = Provider<BundledScoreSeeder>((ref) {
  Future<SharedPreferences> preferences() => SharedPreferences.getInstance();

  return BundledScoreSeeder(
    repository: ref.watch(songRepositoryProvider),
    storage: ref.watch(songFileStorageProvider),
    loadAsset: (path) async {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    },
    isSeeded: (key) async => (await preferences()).getBool(key) ?? false,
    markSeeded: (key) async {
      await (await preferences()).setBool(key, true);
    },
  );
});
