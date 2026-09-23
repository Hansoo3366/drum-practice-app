import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';

class DigitalScoreData {
  const DigitalScoreData({
    required this.song,
    required this.score,
    this.versionCatalog = ScoreVersionCatalog.empty,
    this.activeVersionScore,
    this.sequence = PlaybackSequence.empty,
    this.arrangement = ArrangementProfile.off,
    this.originalFifths = 0,
  });

  final Song song;

  /// The immutable source score. Version editors are layered on top of it.
  final MusicScore score;
  final ScoreVersionCatalog versionCatalog;

  /// The persisted active version, when the catalog points at a version.
  /// `null` means the active score is the original source score.
  final MusicScore? activeVersionScore;
  final PlaybackSequence sequence;
  final ArrangementProfile arrangement;
  final int originalFifths;
}

final digitalScoreDataProvider = FutureProvider.autoDispose
    .family<DigitalScoreData, String>((ref, songId) async {
      final repository = ref.watch(songRepositoryProvider);
      final song = await repository.getSong(songId);
      if (song == null) {
        throw StateError('악보를 찾을 수 없습니다.');
      }
      final file = await ref
          .watch(songFileStorageProvider)
          .resolve(song.sourcePath);
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('MusicXML 파일을 찾을 수 없습니다.');
      }
      final score = const MusicXmlCodec().decode(
        await file.readAsBytes(),
        fileName: file.path,
      );
      final editor = ref.watch(digitalScoreEditorServiceProvider);
      final sequence = await editor.loadSequence(songId);
      final arrangement = await editor.loadArrangement(songId);
      final originalFifths = await editor.loadOrCaptureOriginalFifths(
        songId: songId,
        score: score,
      );
      var versionCatalog = await editor.loadVersionCatalog(songId);
      MusicScore? activeVersionScore;
      if (versionCatalog.activeId != scoreVersionOriginalId) {
        try {
          activeVersionScore = await editor.loadVersionScore(
            songId: songId,
            versionId: versionCatalog.activeId,
          );
        } on Object {
          activeVersionScore = null;
        }
        if (activeVersionScore == null) {
          // A stale catalog must not prevent the original score from opening.
          versionCatalog = versionCatalog.copyWith(
            activeId: scoreVersionOriginalId,
          );
          await editor.saveVersionCatalog(songId, versionCatalog);
        }
      }
      await repository.markOpened(songId);
      return DigitalScoreData(
        song: song,
        score: score,
        versionCatalog: versionCatalog,
        activeVersionScore: activeVersionScore,
        sequence: sequence,
        arrangement: arrangement,
        originalFifths: originalFifths,
      );
    });
