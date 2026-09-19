import 'package:page_a_diddle/l10n/app_localizations.dart';

enum MetronomeSubdivision {
  quarter(1, '♩'),
  eighth(2, '♪'),
  sixteenth(4, '♬'),
  triplet(3, '♪♪♪'),
  sextuplet(6, '♪♪♪♪♪♪');

  const MetronomeSubdivision(this.stepsPerBeat, this.label);

  final int stepsPerBeat;
  final String label;
}

class MetronomeMeter {
  const MetronomeMeter(this.numerator, this.denominator);

  final int numerator;
  final int denominator;

  String get label => '$numerator/$denominator';

  @override
  bool operator ==(Object other) =>
      other is MetronomeMeter &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);
}

enum MetronomeAccentLevel {
  mute(0, 0),
  normal(600, .4),
  strong(900, 1.0);

  const MetronomeAccentLevel(this.frequency, this.volume);

  final int frequency;
  final double volume;

  String label(AppLocalizations l10n) => switch (this) {
    MetronomeAccentLevel.mute => l10n.accentMute,
    MetronomeAccentLevel.normal => l10n.accentNormal,
    MetronomeAccentLevel.strong => l10n.accentStrong,
  };
}

extension MetronomeAccentLevelCycle on MetronomeAccentLevel {
  MetronomeAccentLevel get next => switch (this) {
    MetronomeAccentLevel.strong => MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal => MetronomeAccentLevel.mute,
    MetronomeAccentLevel.mute => MetronomeAccentLevel.strong,
  };
}

const metronomeMeters = <MetronomeMeter>[
  MetronomeMeter(1, 4),
  MetronomeMeter(2, 4),
  MetronomeMeter(3, 4),
  MetronomeMeter(4, 4),
  MetronomeMeter(5, 4),
  MetronomeMeter(6, 4),
  MetronomeMeter(3, 8),
  MetronomeMeter(5, 8),
  MetronomeMeter(6, 8),
  MetronomeMeter(7, 8),
  MetronomeMeter(9, 8),
  MetronomeMeter(12, 8),
];

/// Count-In 마디 수. 기획: 없음 / 1 / 2 / 4
const metronomeCountInBarOptions = <int>[0, 1, 2, 4];

int normalizeMetronomeCountInBars(int? bars) {
  if (bars == null || bars <= 0) {
    return 0;
  }
  if (bars >= 4) {
    return 4;
  }
  if (bars >= 2) {
    return 2;
  }
  return 1;
}

String metronomeCountInLabel(int bars, AppLocalizations l10n) {
  final normalized = normalizeMetronomeCountInBars(bars);
  if (normalized == 0) {
    return l10n.none;
  }
  return l10n.barsLabel(normalized);
}

class MetronomeBeat {
  const MetronomeBeat({
    required this.number,
    required this.isCountIn,
    required this.isAccent,
    this.accentLevel = MetronomeAccentLevel.normal,
    this.isSubdivision = false,
  });

  final int number;
  final bool isCountIn;
  final bool isAccent;
  final MetronomeAccentLevel accentLevel;
  final bool isSubdivision;
}

class MetronomeSequence {
  MetronomeSequence({int beatsPerBar = 4, int stepsPerBeat = 1})
    : beatsPerBar = beatsPerBar.clamp(1, 12).toInt(),
      _stepsPerBeat = stepsPerBeat.clamp(1, 6).toInt() {
    _accentPattern = List.generate(
      this.beatsPerBar,
      (index) => index == 0
          ? MetronomeAccentLevel.strong
          : MetronomeAccentLevel.normal,
    );
  }

  int beatsPerBar;
  int _stepsPerBeat;
  List<MetronomeAccentLevel> _accentPattern = [
    MetronomeAccentLevel.strong,
    MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal,
  ];
  int _step = -1;
  int _countInRemaining = 0;

  int get stepsPerBeat => _stepsPerBeat;

  static Duration intervalFor(int bpm, {int stepsPerBeat = 1}) {
    final safeBpm = bpm.clamp(40, 240).toInt();
    return Duration(
      microseconds:
          Duration.microsecondsPerMinute ~/ safeBpm ~/ stepsPerBeat.clamp(1, 6),
    );
  }

  void configure({
    int? beatsPerBar,
    int? stepsPerBeat,
    List<MetronomeAccentLevel>? accentPattern,
  }) {
    if (beatsPerBar != null) {
      this.beatsPerBar = beatsPerBar.clamp(1, 12).toInt();
    }
    if (stepsPerBeat != null) {
      _stepsPerBeat = stepsPerBeat.clamp(1, 6).toInt();
    }
    final pattern = accentPattern ?? _accentPattern;
    _accentPattern = List.generate(
      this.beatsPerBar,
      (index) =>
          index < pattern.length ? pattern[index] : MetronomeAccentLevel.normal,
    );
  }

  void start({bool countIn = false, int? countInBars}) {
    _step = -1;
    final bars = normalizeMetronomeCountInBars(
      countInBars ?? (countIn ? 1 : 0),
    );
    _countInRemaining = bars * beatsPerBar * _stepsPerBeat;
  }

  /// startAt 타임라인의 절대 step(0부터)에 해당하는 박.
  MetronomeBeat beatAt(int absoluteStep, {required int countInBars}) {
    final stepsPerBar = beatsPerBar * _stepsPerBeat;
    final countInSteps =
        normalizeMetronomeCountInBars(countInBars) * stepsPerBar;
    final step = absoluteStep < 0 ? 0 : absoluteStep;
    final isCountIn = step < countInSteps;
    final phaseStep = isCountIn
        ? step % stepsPerBar
        : (step - countInSteps) % stepsPerBar;
    final beat = phaseStep ~/ _stepsPerBeat + 1;
    final isSubdivision = phaseStep % _stepsPerBeat != 0;
    final accentLevel = isSubdivision
        ? MetronomeAccentLevel.normal
        : _accentPattern[beat - 1];
    return MetronomeBeat(
      number: beat,
      isCountIn: isCountIn,
      isAccent: accentLevel == MetronomeAccentLevel.strong,
      accentLevel: accentLevel,
      isSubdivision: isSubdivision,
    );
  }

  MetronomeBeat next() {
    final isCountIn = _countInRemaining > 0;
    if (isCountIn) {
      _countInRemaining -= 1;
    }
    _step = (_step + 1) % (beatsPerBar * _stepsPerBeat);
    final beat = _step ~/ _stepsPerBeat + 1;
    final isSubdivision = _step % _stepsPerBeat != 0;
    final accentLevel = isSubdivision
        ? MetronomeAccentLevel.normal
        : _accentPattern[beat - 1];
    return MetronomeBeat(
      number: beat,
      isCountIn: isCountIn,
      isAccent: accentLevel == MetronomeAccentLevel.strong,
      accentLevel: accentLevel,
      isSubdivision: isSubdivision,
    );
  }
}
