import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';

class OmrQualityAnalyzer {
  const OmrQualityAnalyzer();

  OmrQualityReport analyze(
    MusicScore score, {
    String? sourceXml,
    DateTime? now,
  }) {
    final issues = <OmrQualityIssue>[];
    for (final part in score.parts) {
      issues.addAll(_partIssues(part));
    }
    issues.addAll(_documentIssues(score, sourceXml));
    final penalty = issues.fold<int>(0, (sum, issue) {
      return sum +
          switch (issue.severity) {
            OmrIssueSeverity.high => 8,
            OmrIssueSeverity.medium => 3,
            OmrIssueSeverity.low => 1,
          };
    });
    return OmrQualityReport(
      issues: List.unmodifiable(issues),
      score: (100 - penalty).clamp(0, 100),
      analyzedAt: now ?? DateTime.now(),
    );
  }

  List<OmrQualityIssue> _documentIssues(MusicScore score, String? sourceXml) {
    final issues = <OmrQualityIssue>[];
    final xml = sourceXml ?? '';
    final hasHarmony =
        score.parts.any(
          (part) => part.measures.any(
            (measure) => measure.events.any((event) => event is MusicHarmony),
          ),
        ) ||
        xml.contains('<harmony');
    if (!hasHarmony) {
      issues.add(
        const OmrQualityIssue(
          rule: 'V009',
          severity: OmrIssueSeverity.medium,
          message: '코드 심벌(F, Dm7 등)이 없습니다.',
        ),
      );
    }
    if (!xml.contains('<lyric')) {
      issues.add(
        const OmrQualityIssue(
          rule: 'V010',
          severity: OmrIssueSeverity.medium,
          message: '가사가 없습니다.',
        ),
      );
    }
    final hasTime = score.parts.any(
      (part) => part.measures.any((measure) => measure.attributes.time != null),
    );
    if (!hasTime) {
      issues.add(
        const OmrQualityIssue(
          rule: 'V011',
          severity: OmrIssueSeverity.high,
          message: '박자표가 없습니다.',
        ),
      );
    }
    if (!xml.contains('<fifths') && !xml.contains('<key')) {
      issues.add(
        const OmrQualityIssue(
          rule: 'V008',
          severity: OmrIssueSeverity.medium,
          message: '조표가 없습니다.',
        ),
      );
    }
    return issues;
  }

  List<OmrQualityIssue> _partIssues(MusicPart part) {
    final issues = <OmrQualityIssue>[];
    var time = part.measures.first.attributes.time;
    var divisions = part.measures.first.attributes.divisions;
    final openTies = <String, int>{};

    for (final measure in part.measures) {
      if (measure.attributes.time != null) time = measure.attributes.time;
      divisions = measure.attributes.divisions;
      final expected = _expectedTicks(time, divisions);
      final filled = _voiceFill(measure);
      if (expected > 0) {
        if (measure.implicit && filled > 0 && filled != expected) {
          issues.add(
            OmrQualityIssue(
              rule: 'V001',
              severity: OmrIssueSeverity.medium,
              measureNumber: measure.number,
              message: '못갖춘마디 길이가 $filled tick, 온마디는 $expected tick입니다.',
            ),
          );
        } else if (!measure.implicit && filled != expected && filled > 0) {
          issues.add(
            OmrQualityIssue(
              rule: 'V001',
              severity: OmrIssueSeverity.high,
              measureNumber: measure.number,
              message: '마디 길이가 $filled tick, $expected tick이어야 합니다.',
            ),
          );
        }
      }

      if (measure.notes.isEmpty && !measure.implicit) {
        issues.add(
          OmrQualityIssue(
            rule: 'V007',
            severity: OmrIssueSeverity.medium,
            measureNumber: measure.number,
            message: '음표가 없는 마디입니다.',
          ),
        );
      }

      issues.addAll(_pitchOutliers(measure));
      issues.addAll(_beamIssues(measure));
      _collectTies(measure, openTies);
    }

    for (final entry in openTies.entries) {
      if (entry.value > 0) {
        issues.add(
          OmrQualityIssue(
            rule: 'V003',
            severity: OmrIssueSeverity.high,
            message: '붙임줄 시작이 ${entry.value}개 닫히지 않았습니다.',
          ),
        );
      }
    }
    return issues;
  }

  int _expectedTicks(MusicTimeSignature? time, int divisions) {
    if (time == null || time.beatType <= 0) return 0;
    return time.beats * divisions * 4 ~/ time.beatType;
  }

  int _voiceFill(MusicMeasure measure) {
    final byVoice = <String, int>{};
    for (final note in measure.notes) {
      if (note.isGrace || note.isChord) continue;
      byVoice[note.voice] = (byVoice[note.voice] ?? 0) + note.duration;
    }
    if (byVoice.isEmpty) return 0;
    return byVoice.values.reduce((a, b) => a > b ? a : b);
  }

  List<OmrQualityIssue> _pitchOutliers(MusicMeasure measure) {
    final issues = <OmrQualityIssue>[];
    final lastMidi = <String, int>{};
    for (final note in measure.notes) {
      if (note.isRest || note.pitch == null) continue;
      final key = '${note.voice}/${note.staff}';
      final midi = note.pitch!.midi;
      final previous = lastMidi[key];
      if (previous != null) {
        final jump = (midi - previous).abs();
        if (jump >= 16 && jump % 12 != 0) {
          issues.add(
            OmrQualityIssue(
              rule: 'V006',
              severity: OmrIssueSeverity.low,
              measureNumber: measure.number,
              message: '음높이가 갑자기 $previous에서 $midi로 뜁니다.',
            ),
          );
        }
      }
      lastMidi[key] = midi;
    }
    return issues;
  }

  List<OmrQualityIssue> _beamIssues(MusicMeasure measure) {
    final open = <int, int>{};
    for (final note in measure.notes) {
      for (final beam in note.beams) {
        switch (beam.value) {
          case 'begin':
            open[beam.number] = (open[beam.number] ?? 0) + 1;
          case 'end':
            open[beam.number] = (open[beam.number] ?? 0) - 1;
        }
      }
    }
    if (open.values.any((count) => count != 0)) {
      return [
        OmrQualityIssue(
          rule: 'V005',
          severity: OmrIssueSeverity.low,
          measureNumber: measure.number,
          message: '8분음표 빔이 닫히지 않았습니다.',
        ),
      ];
    }
    return const [];
  }

  void _collectTies(MusicMeasure measure, Map<String, int> openTies) {
    for (final note in measure.notes) {
      if (note.pitch == null) continue;
      final key = '${note.voice}/${note.pitch!.midi}';
      if (note.tieStop) {
        openTies[key] = (openTies[key] ?? 0) - 1;
      }
      if (note.tieStart) {
        openTies[key] = (openTies[key] ?? 0) + 1;
      }
    }
  }
}
