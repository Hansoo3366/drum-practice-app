import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality_analyzer.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

class OmrConvertService {
  OmrConvertService({
    required OmrConvertClient client,
    required MusicXmlImportService importer,
    required SongFileStorage storage,
    this.codec = const MusicXmlCodec(),
    this.analyzer = const OmrQualityAnalyzer(),
  }) : _client = client,
       _importer = importer,
       _storage = storage;

  final OmrConvertClient _client;
  final MusicXmlImportService _importer;
  final SongFileStorage _storage;
  final MusicXmlCodec codec;
  final OmrQualityAnalyzer analyzer;

  Future<OmrRemoteJob> start({
    required PickedLocalFile source,
    OmrRecognitionProfile profile = OmrRecognitionProfile.standard,
  }) async {
    final bytes = await _read(source);
    return _client.startConvert(
      fileName: source.name,
      bytes: bytes,
      profile: profile,
    );
  }

  Future<OmrRemoteJob> status(String jobId) => _client.jobStatus(jobId);

  Future<String> importResult({
    required String jobId,
    required String title,
    String? folderId,
    PickedLocalFile? original,
  }) async {
    final mxl = await _client.jobResult(jobId);
    final songId = await _importer.importMusicXml(
      file: PickedLocalFile(name: '$title.mxl', bytes: mxl),
      title: title,
      folderId: folderId,
    );
    if (original?.bytes != null) {
      await _storage.saveOmrSource(
        songId: songId,
        fileName: original!.name,
        bytes: original.bytes!,
      );
    }
    final xml = codec.xmlString(mxl, fileName: '$title.mxl');
    final report = analyzer.analyze(codec.decodeXml(xml), sourceXml: xml);
    await _storage.saveOmrQuality(songId, jsonEncode(report.toJson()));
    return songId;
  }

  Future<Uint8List> _read(PickedLocalFile file) async {
    if (file.bytes case final bytes?) return bytes;
    final filePath = file.path;
    if (filePath == null) {
      throw const FormatException('변환할 파일을 읽을 수 없습니다.');
    }
    return File(filePath).readAsBytes();
  }
}

final omrConvertClientProvider = Provider<OmrConvertClient>((ref) {
  return OmrConvertClient();
});

final omrConvertServiceProvider = Provider<OmrConvertService>((ref) {
  return OmrConvertService(
    client: ref.watch(omrConvertClientProvider),
    importer: ref.watch(musicXmlImportServiceProvider),
    storage: ref.watch(songFileStorageProvider),
  );
});
