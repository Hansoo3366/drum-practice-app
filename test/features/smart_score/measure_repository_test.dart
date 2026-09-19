import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/smart_score/data/audio_anchor_repository.dart';
import 'package:page_a_diddle/features/smart_score/data/cue_repository.dart';
import 'package:page_a_diddle/features/smart_score/data/measure_repository.dart';
import 'package:page_a_diddle/features/smart_score/data/tempo_map_repository.dart';
import 'package:page_a_diddle/features/smart_score/data/time_signature_map_repository.dart';

void main() {
  test('마디 영역을 만들고 수정하고 삭제한다', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = MeasureRepository(database);
    final anchors = AudioAnchorRepository(database);
    final cues = CueRepository(database);
    final tempoMaps = TempoMapRepository(database);
    final timeSignatures = TimeSignatureMapRepository(database);
    final now = DateTime(2026, 8, 19);
    await database
        .into(database.songs)
        .insert(
          SongsCompanion.insert(
            id: 'song-1',
            title: 'Smart Score',
            sourcePath: 'scores/smart.pdf',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await repository.add(
      songId: 'song-1',
      page: 1,
      x: 0.1,
      y: 0.2,
      width: 0.3,
      height: 0.1,
    );
    var measures = await repository.watchMeasures('song-1').first;
    expect(measures.single.number, 1);
    expect(
      (await database.select(database.songs).getSingle()).scoreType,
      'pdf',
    );

    await repository.updateSection(id: measures.single.id, section: 'chorus');
    measures = await repository.watchMeasures('song-1').first;
    expect(measures.single.section, 'CHORUS');
    await repository.updateDifficult(
      measure: measures.single,
      isDifficult: true,
    );
    measures = await repository.watchMeasures('song-1').first;
    expect(measures.single.isDifficult, isTrue);

    await anchors.save(songId: 'song-1', measureNumber: 1, audioTime: 3.42);
    expect((await anchors.watch('song-1').first).single.audioTime, 3.42);
    await anchors.save(songId: 'song-1', measureNumber: 1, audioTime: 4.1);
    final savedAnchor = (await anchors.watch('song-1').first).single;
    expect(savedAnchor.audioTime, 4.1);
    await anchors.delete(savedAnchor);
    expect(await anchors.watch('song-1').first, isEmpty);

    await cues.save(songId: 'song-1', measureNumber: 1, label: 'Crash');
    expect((await cues.watch('song-1').first).single.label, 'Crash');
    await cues.save(songId: 'song-1', measureNumber: 1, label: 'STOP');
    final savedCue = (await cues.watch('song-1').first).single;
    expect(savedCue.label, 'STOP');
    await cues.delete(savedCue);
    expect(await cues.watch('song-1').first, isEmpty);

    await tempoMaps.save(
      songId: 'song-1',
      startMeasure: 1,
      endMeasure: 16,
      mode: 'step',
      startBpm: 120,
    );
    await tempoMaps.save(
      songId: 'song-1',
      startMeasure: 17,
      endMeasure: 32,
      mode: 'gradual',
      startBpm: 128,
      endBpm: 110,
    );
    final maps = await tempoMaps.watch('song-1').first;
    expect(maps, hasLength(2));
    expect(maps.last.endBpm, 110);
    await tempoMaps.delete(maps.first);
    expect(await tempoMaps.watch('song-1').first, hasLength(1));

    await timeSignatures.save(
      songId: 'song-1',
      startMeasure: 1,
      endMeasure: 32,
      numerator: 4,
      denominator: 4,
    );
    await timeSignatures.save(
      songId: 'song-1',
      startMeasure: 33,
      endMeasure: 36,
      numerator: 3,
      denominator: 4,
    );
    final signatures = await timeSignatures.watch('song-1').first;
    expect(signatures, hasLength(2));
    expect(signatures.last.numerator, 3);
    await timeSignatures.delete(signatures.first);
    expect(await timeSignatures.watch('song-1').first, hasLength(1));

    await repository.updateRect(
      id: measures.single.id,
      x: 0.2,
      y: 0.3,
      width: 0.4,
      height: 0.2,
    );
    measures = await repository.watchMeasures('song-1').first;
    expect(measures.single.x, 0.2);
    expect(measures.single.width, 0.4);

    await repository.delete(measures.single);
    expect(await repository.watchMeasures('song-1').first, isEmpty);
    expect(
      (await database.select(database.songs).getSingle()).scoreType,
      'pdf',
    );
  });
}
