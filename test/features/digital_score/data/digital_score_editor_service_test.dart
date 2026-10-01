import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';

void main() {
  late Directory root;
  late SongFileStorage storage;
  late DigitalScoreEditorService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('score_editor_save_');
    storage = SongFileStorage(rootDirectoryProvider: () async => root);
    service = DigitalScoreEditorService(storage: storage);
  });

  tearDown(() => root.delete(recursive: true));

  for (final extension in ['musicxml', 'mxl']) {
    test('saves and validates edited .$extension scores in place', () async {
      final relativePath = 'scores/song.$extension';
      final file = await storage.resolve(relativePath);
      await file.parent.create(recursive: true);
      await file.writeAsString('original');

      await service.save(
        songId: 'song',
        relativePath: relativePath,
        score: _score(),
      );

      final bytes = await file.readAsBytes();
      final decoded = const MusicXmlCodec().decode(
        bytes,
        fileName: relativePath,
      );
      expect(decoded.title, 'Saved edit');
      expect(decoded.noteCount, 1);
      final sequence = await service.loadSequence('song');
      expect(sequence, PlaybackSequence.empty);
      expect(await service.loadArrangement('song'), ArrangementProfile.off);
      expect(
        file.parent.listSync().where((entry) => entry.path.endsWith('.bak')),
        isEmpty,
      );
    });
  }

  test(
    'rejects empty replacement bytes without touching the original',
    () async {
      const relativePath = 'scores/song.musicxml';
      final file = await storage.resolve(relativePath);
      await file.parent.create(recursive: true);
      await file.writeAsString('original');

      await expectLater(
        storage.replaceFile(relativePath, const []),
        throwsFormatException,
      );

      expect(await file.readAsString(), 'original');
    },
  );

  test('stores Playback Sequence beside the MusicXML file', () async {
    final saved = PlaybackSequence(
      marks: [
        SectionMark(startMeasureIndex: 0, name: 'INTRO'),
        SectionMark(startMeasureIndex: 1, name: 'VERSE'),
      ],
      steps: [
        PlaybackStep(sectionId: sectionIdAt(0), repeats: 4),
        PlaybackStep(sectionId: sectionIdAt(1), repeats: 2),
      ],
    );
    const relativePath = 'scores/song.musicxml';
    final file = await storage.resolve(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsString('original');

    await service.save(
      songId: 'song',
      relativePath: relativePath,
      score: _score(),
      sequence: saved,
    );

    expect(await service.loadSequence('song'), saved);
  });

  test('keeps a playback order per version, inheriting the original', () async {
    final original = PlaybackSequence(
      marks: [SectionMark(startMeasureIndex: 0, name: 'VERSE')],
      steps: [PlaybackStep(sectionId: sectionIdAt(0), repeats: 2)],
    );
    await service.saveSequence(songId: 'song', sequence: original);

    // A version without its own order starts from the original's.
    expect(await service.loadSequence('song', versionId: 'v1'), original);

    await service.saveSequence(
      songId: 'song',
      versionId: 'v1',
      sequence: PlaybackSequence.empty,
    );
    expect(
      await service.loadSequence('song', versionId: 'v1'),
      PlaybackSequence.empty,
    );
    expect(await service.loadSequence('song'), original);
  });

  test('stores an arrangement profile beside the MusicXML file', () async {
    const relativePath = 'scores/song.musicxml';
    final file = await storage.resolve(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsString('original');

    await service.save(
      songId: 'song',
      relativePath: relativePath,
      score: _score(),
      arrangement: const ArrangementProfile(style: ArrangementStyle.broken),
    );

    expect(
      await service.loadArrangement('song'),
      const ArrangementProfile(style: ArrangementStyle.broken),
    );
    final decoded = const MusicXmlCodec().decode(
      await file.readAsBytes(),
      fileName: relativePath,
    );
    expect(decoded.noteCount, 1);
  });

  test(
    'captures the original key once and keeps it after later scores',
    () async {
      final first = await service.loadOrCaptureOriginalFifths(
        songId: 'song',
        score: _score(),
      );
      final later = await service.loadOrCaptureOriginalFifths(
        songId: 'song',
        score: _score(fifths: 2),
      );

      expect(first, 0);
      expect(later, 0);
    },
  );

  test(
    'adds and deletes score versions without a default performance copy',
    () async {
      const relativePath = 'scores/song.musicxml';
      final file = await storage.resolve(relativePath);
      await file.parent.create(recursive: true);
      await file.writeAsString('original');
      await service.save(
        songId: 'song',
        relativePath: relativePath,
        score: _score(),
      );
      await storage.savePerformanceScore(
        'song',
        const MusicXmlCodec().encode(
          _score(fifths: 1),
          MusicXmlFileFormat.musicXml,
        ),
      );

      final catalog = await service.loadVersionCatalog('song');
      expect(catalog.versions, isEmpty);

      final added = await service.addVersion(
        songId: 'song',
        source: _score(fifths: 3),
        catalog: catalog,
        name: '연습용',
      );
      expect(added.versions.single.name, '연습용');

      await service.save(
        songId: 'song',
        relativePath: relativePath,
        score: _score(fifths: 4),
        versionId: added.activeId,
      );
      final loaded = await service.loadVersionScore(
        songId: 'song',
        versionId: added.activeId,
      );
      expect(loaded?.parts.first.measures.first.attributes.keyFifths, 4);

      final deleted = await service.deleteVersion(
        songId: 'song',
        versionId: added.activeId,
        catalog: added,
      );
      expect(deleted.versions, isEmpty);
      expect(deleted.activeId, scoreVersionOriginalId);
      final original = const MusicXmlCodec().decode(
        await file.readAsBytes(),
        fileName: relativePath,
      );
      expect(original.parts.first.measures.first.attributes.keyFifths, 0);
    },
  );

  test(
    'falls back to the original score when a version manifest is malformed',
    () async {
      final manifest = await storage.resolve(
        storage.scoreVersionManifestPathFor('song'),
      );
      await manifest.parent.create(recursive: true);
      await manifest.writeAsString('{not valid json');

      final catalog = await service.loadVersionCatalog('song');

      expect(catalog, ScoreVersionCatalog.empty);
    },
  );
}

MusicScore _score({int fifths = 0}) {
  return MusicScore(
    title: 'Saved edit',
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          MusicMeasure(
            number: '1',
            attributes: MusicAttributes(
              divisions: 4,
              keyFifths: fifths,
              time: const MusicTimeSignature(beats: 4, beatType: 4),
            ),
            events: [
              MusicNote(
                onset: 0,
                duration: 4,
                voice: '1',
                staff: 1,
                pitch: const MusicPitch(step: PitchStep.c, octave: 4),
                type: 'quarter',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
