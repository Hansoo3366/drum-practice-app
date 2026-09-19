import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/library/domain/score_file_filter.dart';

void main() {
  test('matches PDF and MusicXML file names', () {
    expect(matchesScoreFileName('chart.pdf', ScoreFileFilter.pdf), isTrue);
    expect(matchesScoreFileName('chart.PDF', ScoreFileFilter.pdf), isTrue);
    expect(matchesScoreFileName('chart.mxl', ScoreFileFilter.pdf), isFalse);

    expect(matchesScoreFileName('song.mxl', ScoreFileFilter.musicXml), isTrue);
    expect(
      matchesScoreFileName('song.musicxml', ScoreFileFilter.musicXml),
      isTrue,
    );
    expect(matchesScoreFileName('song.xml', ScoreFileFilter.musicXml), isTrue);
    expect(matchesScoreFileName('song.pdf', ScoreFileFilter.musicXml), isFalse);
  });
}
