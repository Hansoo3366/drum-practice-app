import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';

MusicScore blankPianoScore({
  String? title,
  String? composer,
  double? tempoBpm,
}) {
  final attributes = MusicAttributes(
    divisions: 4,
    keyFifths: 0,
    keyMode: 'major',
    time: const MusicTimeSignature(beats: 4, beatType: 4),
    staves: 2,
    clefs: const {
      1: MusicClef(sign: 'G', line: 2),
      2: MusicClef(sign: 'F', line: 4),
    },
  );
  return MusicScore(
    title: title,
    composer: composer,
    tempoBpm: tempoBpm,
    parts: [
      MusicPart(
        id: 'P1',
        name: 'Piano',
        measures: [
          MusicMeasure(
            number: '1',
            attributes: attributes,
            events: [
              MusicNote(
                onset: 0,
                duration: 16,
                voice: '1',
                staff: 1,
                type: 'whole',
              ),
              MusicNote(
                onset: 0,
                duration: 16,
                voice: '2',
                staff: 2,
                type: 'whole',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
