import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;
  late SongFileStorage storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('page_a_diddle_storage_');
    storage = SongFileStorage(rootDirectoryProvider: () async => root);
  });

  tearDown(() => root.delete(recursive: true));

  test('앱 저장소 밖으로 나가는 경로를 거부한다', () async {
    expect(storage.resolve('../outside.pdf'), throwsFormatException);
    expect(storage.resolve('/tmp/outside.pdf'), throwsFormatException);
  });

  test('정상적인 상대 경로는 앱 저장소 안에서 해석한다', () async {
    final file = await storage.resolve('scores/song.pdf');

    expect(file.path, path.join(root.path, 'scores', 'song.pdf'));
  });

  test('합주 호스트 PDF를 임시 경로에 저장하고 PDF 헤더를 확인한다', () async {
    final relative = await storage.storeJamPdf(
      songId: 'jam-song',
      bytes: '%PDF-1.7\n'.codeUnits,
    );
    final file = await storage.resolve(relative);
    expect(relative, path.join('jam_host', 'jam-song.pdf'));
    expect(await file.readAsString(), startsWith('%PDF-'));
    expect(
      storage.storeJamPdf(songId: 'bad', bytes: 'not pdf'.codeUnits),
      throwsFormatException,
    );
  });

  test('MusicXML과 MXL을 전자 악보 확장자로 저장한다', () async {
    final xmlPath = await storage.storeMusicXml(
      source: PickedLocalFile(
        name: 'score.musicxml',
        bytes: Uint8List.fromList('<score-partwise/>'.codeUnits),
      ),
      songId: 'xml-song',
    );
    final mxlPath = await storage.storeMusicXml(
      source: PickedLocalFile(
        name: 'score.mxl',
        bytes: Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]),
      ),
      songId: 'mxl-song',
    );

    expect(xmlPath, path.join('scores', 'xml-song.musicxml'));
    expect(mxlPath, path.join('scores', 'mxl-song.mxl'));
    expect(await (await storage.resolve(xmlPath)).exists(), isTrue);
    expect(await (await storage.resolve(mxlPath)).exists(), isTrue);
  });

  test('stores the original concert key beside other score sidecars', () async {
    expect(
      storage.originalKeyPathFor('song'),
      path.join('original_keys', 'song.json'),
    );
    await storage.saveOriginalKey('song', '{"fifths":-2}');
    expect(await storage.loadOriginalKey('song'), '{"fifths":-2}');
  });
}
