import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

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
    const relativePath = 'scores/song.musicxml';
    final file = await storage.resolve(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsString('original');

    await service.save(
      songId: 'song',
      relativePath: relativePath,
      score: _score(),
      sequence: PlaybackSequence([
        PlaybackSequenceItem(section: 'INTRO', repeats: 4),
        PlaybackSequenceItem(section: 'VERSE', repeats: 2),
      ]),
    );

    final sequence = await service.loadSequence('song');
    expect(sequence.items.map((item) => item.section), ['INTRO', 'VERSE']);
    expect(sequence.items.map((item) => item.repeats), [4, 2]);
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
