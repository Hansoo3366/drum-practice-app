import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_config.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_reviewer.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_page_crop.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_patch.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';

import '../domain/omr_ai_patch_test.dart' show fixture, correction;

class _FailedManifestStorage extends SongFileStorage {
  _FailedManifestStorage(Directory root)
    : super(rootDirectoryProvider: () async => root);
  @override
  Future<void> saveScoreVersionManifest(String id, String json) async {
    throw StateError('simulated manifest failure');
  }
}

void main() {
  late Directory root;
  late SongFileStorage storage;
  late DigitalScoreEditorService service;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('omr_correction_');
    storage = SongFileStorage(rootDirectoryProvider: () async => root);
    service = DigitalScoreEditorService(storage: storage);
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'stores raw correction separately, can return to original without deletion',
    () async {
      await storage.replaceFile('scores/song.musicxml', utf8.encode(fixture));
      final xml = OmrAiPatch(fixture, 0, 0).apply(fixture, [correction()]);
      final next = await service.addXmlVersion(
        songId: 'song',
        musicXml: xml,
        catalog: ScoreVersionCatalog.empty,
        name: 'AI 검수',
      );
      expect(await service.loadVersionXml('song', next.activeId), xml);
      expect(
        await (await storage.resolve('scores/song.musicxml')).readAsString(),
        fixture,
      );
      final restored = next.copyWith(activeId: scoreVersionOriginalId);
      await service.saveVersionCatalog('song', restored);
      expect(
        (await service.loadVersionCatalog('song')).activeId,
        scoreVersionOriginalId,
      );
      expect(await service.loadVersionXml('song', next.activeId), xml);
      await expectLater(
        service.addXmlVersion(
          songId: 'song',
          musicXml: xml,
          catalog: ScoreVersionCatalog.empty,
          name: 'stale',
        ),
        throwsFormatException,
      );
      expect((await service.loadVersionCatalog('song')).versions, hasLength(1));
    },
  );

  test('malformed XML never creates a version', () async {
    await expectLater(
      service.addXmlVersion(
        songId: 'song',
        musicXml: '<broken',
        catalog: ScoreVersionCatalog.empty,
        name: 'invalid',
      ),
      throwsA(isA<Exception>()),
    );
    expect((await service.loadVersionCatalog('song')).versions, isEmpty);
  });

  test('failed manifest write cleans only its new version file', () async {
    await storage.replaceFile('scores/song.musicxml', utf8.encode(fixture));
    final failing = DigitalScoreEditorService(
      storage: _FailedManifestStorage(root),
    );
    await expectLater(
      failing.addXmlVersion(
        songId: 'song',
        musicXml: fixture,
        catalog: ScoreVersionCatalog.empty,
        name: 'failure',
      ),
      throwsStateError,
    );
    final directory = await storage.resolve(
      'score_versions/song/manifest.json',
    );
    expect(await directory.parent.list().toList(), isEmpty);
    expect(
      await (await storage.resolve('scores/song.musicxml')).readAsString(),
      fixture,
    );
  });

  test('region bounds reject zero, tiny, non-finite and outside values', () {
    OmrPageCrop.validateRegion(const Rect.fromLTWH(0, 0, 1, 1));
    for (final rect in [
      Rect.zero,
      const Rect.fromLTWH(-0.1, 0, 1, 1),
      const Rect.fromLTWH(0, 0, 2, 1),
      const Rect.fromLTWH(0, 0, 0.001, 1),
      const Rect.fromLTWH(double.nan, 0, 1, 1),
    ]) {
      expect(() => OmrPageCrop.validateRegion(rect), throwsFormatException);
    }
  });

  test(
    'explicit crop and stable measure IDs sent through existing AI client',
    () async {
      var calls = 0;
      final client = OmrAiClient(
        config: const OmrAiConfig(apiKey: 'test-only'),
        httpClient: MockClient((request) async {
          calls++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(jsonEncode(body), contains('p1_m0_n0'));
          expect(jsonEncode(body), contains('data:image/png;base64,AQID'));
          expect(jsonEncode(body), contains('Target part: P2'));
          return http.Response(
            jsonEncode({
              'output_text': jsonEncode({
                'hasError': true,
                'overallConfidence': 0.9,
                'corrections': [correction(id: 'p1_m0_n0').toJson()],
              }),
            }),
            200,
          );
        }),
      );
      final review = await OmrAiReviewer(storage: storage, client: client)
          .reviewRegion(
            pngBytes: Uint8List.fromList([1, 2, 3]),
            target: OmrAiPatch(fixture, 1, 0),
          );
      expect(calls, 1);
      expect(review.corrections.single.elementId, 'p1_m0_n0');
      expect((await service.loadVersionCatalog('song')).versions, isEmpty);
    },
  );
}
