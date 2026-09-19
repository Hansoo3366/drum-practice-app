import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/stage/domain/stage_setlist_progress.dart';

void main() {
  const songs = [
    StageSetlistItem(
      songId: 'a',
      title: '첫째',
      offlineAvailable: false,
      bpm: 100,
    ),
    StageSetlistItem(
      songId: 'b',
      title: '둘째',
      offlineAvailable: true,
      bpm: 120,
    ),
    StageSetlistItem(
      songId: 'c',
      title: '셋째',
      offlineAvailable: true,
      bpm: 140,
    ),
  ];

  test('다운로드된 첫 곡부터 Stage를 시작한다', () {
    expect(firstStageSongId(songs), 'b');
    expect(firstStageSongId(songs, fromSongId: 'c'), 'c');
    expect(firstStageSongId(songs, fromSongId: 'a'), 'b');
    expect(firstStageSongId(const []), isNull);
  });

  test('오프라인 곡만 세고 이전·다음 곡을 고른다', () {
    final progress = calculateStageSetlistProgress(songs, currentSongId: 'b');

    expect(progress?.position, 1);
    expect(progress?.total, 2);
    expect(progress?.title, '둘째');
    expect(progress?.bpm, 120);
    expect(progress?.previousSongId, isNull);
    expect(progress?.nextSongId, 'c');
    expect(progress?.nextTitle, '셋째');
  });

  test('마지막 곡에는 다음이 없다', () {
    final progress = calculateStageSetlistProgress(songs, currentSongId: 'c');

    expect(progress?.position, 2);
    expect(progress?.previousSongId, 'b');
    expect(progress?.nextSongId, isNull);
  });

  test('현재 곡이 세트리스트에 없으면 진행 정보를 만들지 않는다', () {
    expect(calculateStageSetlistProgress(songs, currentSongId: 'a'), isNull);
  });
}
