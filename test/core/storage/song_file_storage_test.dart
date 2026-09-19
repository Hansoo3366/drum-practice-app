import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';

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

    expect(file.path, '${root.path}/scores/song.pdf');
  });

  test('합주 호스트 PDF를 임시 경로에 저장하고 PDF 헤더를 확인한다', () async {
    final relative = await storage.storeJamPdf(
      songId: 'jam-song',
      bytes: '%PDF-1.7\n'.codeUnits,
    );
    final file = await storage.resolve(relative);
    expect(relative, 'jam_host/jam-song.pdf');
    expect(await file.readAsString(), startsWith('%PDF-'));
    expect(
      storage.storeJamPdf(songId: 'bad', bytes: 'not pdf'.codeUnits),
      throwsFormatException,
    );
  });
}
