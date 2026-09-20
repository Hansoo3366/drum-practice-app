import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/bundled_score_seeder.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/score_type.dart';

void main() {
  test('bundled MXL scores decode as piano scores', () async {
    for (final definition in bundledScores) {
      final bytes = await File(definition.assetPath).readAsBytes();
      final score = const MusicXmlCodec().decode(
        bytes,
        fileName: definition.fileName,
      );

      expect(score.title, isNotEmpty);
      expect(score.parts, isNotEmpty);
      expect(score.measureCount, greaterThan(1));
    }
  });

  test(
    'seeds missing samples once without duplicating an existing title',
    () async {
      final root = await Directory.systemTemp.createTemp('bundled_scores_');
      final database = AppDatabase(NativeDatabase.memory());
      final storage = SongFileStorage(rootDirectoryProvider: () async => root);
      final repository = SongRepository(
        database,
        LabelRepository(database),
        storage,
      );
      final now = DateTime(2026, 9, 20, 12);
      await repository.saveSong(
        SongsCompanion.insert(
          id: 'user-clair',
          title: 'Claire de lune',
          artist: const Value('Claude Debussy'),
          scoreType: Value(ScoreType.musicXml.key),
          sourcePath: 'scores/user-clair.mxl',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final flags = <String>{};
      final seeder = BundledScoreSeeder(
        repository: repository,
        storage: storage,
        loadAsset: (path) => File(path).readAsBytes(),
        isSeeded: (key) async => flags.contains(key),
        markSeeded: (key) async {
          flags.add(key);
        },
      );

      try {
        await seeder.ensureSeeded();
        await seeder.ensureSeeded();

        final songs = await database.select(database.songs).get();
        expect(
          songs.where((song) => song.title == 'Claire de lune'),
          hasLength(1),
        );
        expect(
          songs.where(
            (song) => song.title == 'Fantaisie-Impromptu in C♯ Minor',
          ),
          hasLength(1),
        );
        expect(flags, hasLength(bundledScores.length));
        expect(
          File(
            '${root.path}/scores/bundled-fantaisie-impromptu.mxl',
          ).existsSync(),
          isTrue,
        );
      } finally {
        await database.close();
        await root.delete(recursive: true);
      }
    },
  );
}
