import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:path/path.dart' as path;

class DigitalScoreEditorService {
  const DigitalScoreEditorService({
    required SongFileStorage storage,
    MusicXmlCodec codec = const MusicXmlCodec(),
  }) : _storage = storage,
       _codec = codec;

  final SongFileStorage _storage;
  final MusicXmlCodec _codec;

  Future<void> save({
    required String songId,
    required String relativePath,
    required MusicScore score,
    PlaybackSequence sequence = PlaybackSequence.empty,
    ArrangementProfile arrangement = ArrangementProfile.off,
  }) async {
    final format = path.extension(relativePath).toLowerCase() == '.mxl'
        ? MusicXmlFileFormat.mxl
        : MusicXmlFileFormat.musicXml;
    final bytes = _codec.encode(score, format);
    _codec.decode(bytes, fileName: relativePath);
    await _storage.replaceFile(relativePath, bytes);
    await _storage.savePlaybackSequence(songId, jsonEncode(sequence.toJson()));
    await _storage.saveArrangementProfile(
      songId,
      jsonEncode(arrangement.toJson()),
    );
  }

  Future<PlaybackSequence> loadSequence(String songId) async {
    final raw = await _storage.loadPlaybackSequence(songId);
    if (raw == null || raw.trim().isEmpty) return PlaybackSequence.empty;
    return PlaybackSequence.fromJson(jsonDecode(raw));
  }

  Future<ArrangementProfile> loadArrangement(String songId) async {
    final raw = await _storage.loadArrangementProfile(songId);
    if (raw == null || raw.trim().isEmpty) return ArrangementProfile.off;
    return ArrangementProfile.fromJson(jsonDecode(raw));
  }

  Future<int> loadOrCaptureOriginalFifths({
    required String songId,
    required MusicScore score,
  }) async {
    final stored = _originalFifthsFrom(await _storage.loadOriginalKey(songId));
    if (stored != null) return stored;
    final fifths = wrapKeyFifths(concertKeyFifths(score));
    await _storage.saveOriginalKey(songId, jsonEncode({'fifths': fifths}));
    return fifths;
  }
}

int? _originalFifthsFrom(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final fifths = decoded['fifths'];
    if (fifths is! int) return null;
    return wrapKeyFifths(fifths);
  } on Object {
    return null;
  }
}

final digitalScoreEditorServiceProvider = Provider<DigitalScoreEditorService>((
  ref,
) {
  return DigitalScoreEditorService(storage: ref.watch(songFileStorageProvider));
});
