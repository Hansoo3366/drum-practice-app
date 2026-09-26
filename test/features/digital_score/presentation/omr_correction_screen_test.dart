import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_config.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_reviewer.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_page_crop.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_correction_screen.dart';

import '../domain/omr_ai_patch_test.dart' show fixture, correction;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=',
);

class _FakeCrop extends OmrPageCrop {
  @override
  Future<({Uint8List png, double aspect, int pageCount})> loadPage(
    Uint8List bytes,
    int index,
  ) async => (png: _png, aspect: 1.0, pageCount: 2);

  @override
  Future<Uint8List> renderRegion({
    required Uint8List pdfBytes,
    required int pageIndex,
    required Rect region,
  }) async {
    OmrPageCrop.validateRegion(region);
    return _png;
  }
}

class _MemoryStorage extends SongFileStorage {
  String? manifest;
  final versions = <String, List<int>>{};
  @override
  Future<({String fileName, List<int> bytes})?> loadOmrSource(
    String id,
  ) async => (fileName: 'source.pdf', bytes: [1, 2, 3]);
  @override
  Future<String?> loadScoreVersionManifest(String id) async => manifest;
  @override
  Future<void> saveScoreVersionManifest(String id, String json) async {
    manifest = json;
  }

  @override
  Future<void> saveScoreVersionBytes(
    String id,
    String versionId,
    List<int> bytes,
  ) async {
    versions[versionId] = bytes;
  }

  @override
  Future<List<int>?> loadScoreVersionBytes(String id, String versionId) async =>
      versions[versionId];
  @override
  Future<void> deleteScoreVersion(String id, String versionId) async {
    versions.remove(versionId);
  }

  @override
  Future<void> replaceFile(String relativePath, List<int> bytes) async {
    throw StateError('Original must not be overwritten');
  }
}

void main() {
  testWidgets('manual crop, approval only, separate save and undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _MemoryStorage();
    final service = DigitalScoreEditorService(storage: storage);
    var calls = 0;
    final reviewer = OmrAiReviewer(
      storage: storage,
      client: OmrAiClient(
        config: const OmrAiConfig(apiKey: 'mock-only'),
        httpClient: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({
              'output_text': jsonEncode({
                'hasError': true,
                'overallConfidence': 0.9,
                'corrections': [
                  correction().toJson(),
                  correction(id: 'foreign').toJson(),
                ],
              }),
            }),
            200,
          );
        }),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          songFileStorageProvider.overrideWithValue(storage),
          omrPageCropProvider.overrideWithValue(_FakeCrop()),
          omrAiReviewerProvider.overrideWithValue(reviewer),
        ],
        child: const MaterialApp(
          home: OmrCorrectionScreen(
            songId: 'song',
            musicXml: fixture,
            catalog: ScoreVersionCatalog.empty,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    final image = find.byWidgetPredicate(
      (w) => w is Image && w.semanticLabel == null,
    );
    await tester.ensureVisible(image);
    await tester.dragFrom(
      tester.getTopLeft(image) + const Offset(32, 32),
      const Offset(160, 100),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('선택 영역 확인'));
    await tester.tap(find.text('선택 영역 확인'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.ensureVisible(find.text('확인하고 AI 비교'));
    await tester.tap(find.text('확인하고 AI 비교'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    final tiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(tiles.first.value, false);
    expect(tiles.last.onChanged, isNull);
    expect((await service.loadVersionCatalog('song')).versions, isEmpty);
    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '검수 1');
    await tester.ensureVisible(find.text('선택한 수정 저장'));
    await tester.tap(find.text('선택한 수정 저장'));
    await tester.pumpAndSettle();
    final saved = await service.loadVersionCatalog('song');
    expect(saved.versions, hasLength(1));
    expect(saved.activeId, isNot(scoreVersionOriginalId));
    expect(storage.versions, hasLength(1));
    await tester.tap(find.byTooltip('이전 버전으로 복귀'));
    await tester.pumpAndSettle();
    final reverted = await service.loadVersionCatalog('song');
    expect(reverted.activeId, scoreVersionOriginalId);
    expect(reverted.versions, hasLength(1));
    expect(
      await service.loadVersionXml('song', saved.activeId),
      contains('<step>D</step>'),
    );
    expect(tester.takeException(), isNull);
  });
}
