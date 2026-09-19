/// A4 at 96dpi. Engrave at this width, then scale the page to the phone.
const double scorePageWidthPx = 794;

class ScoreSystemSpan {
  const ScoreSystemSpan({
    required this.startMeasureIndex,
    required this.endMeasureIndex,
  });

  final int startMeasureIndex;
  final int endMeasureIndex;

  bool contains(int measureIndex) {
    return measureIndex >= startMeasureIndex &&
        measureIndex <= endMeasureIndex;
  }

  @override
  bool operator ==(Object other) {
    return other is ScoreSystemSpan &&
        other.startMeasureIndex == startMeasureIndex &&
        other.endMeasureIndex == endMeasureIndex;
  }

  @override
  int get hashCode => Object.hash(startMeasureIndex, endMeasureIndex);
}

ScoreSystemSpan scoreSystemFor(
  int measureIndex,
  List<ScoreSystemSpan> systems,
) {
  if (measureIndex < 0) {
    return const ScoreSystemSpan(startMeasureIndex: 0, endMeasureIndex: 0);
  }
  for (final system in systems) {
    if (system.contains(measureIndex)) return system;
  }
  return ScoreSystemSpan(
    startMeasureIndex: measureIndex,
    endMeasureIndex: measureIndex,
  );
}

int scoreSystemStart(int measureIndex, [List<ScoreSystemSpan> systems = const []]) {
  return scoreSystemFor(measureIndex, systems).startMeasureIndex;
}

int scoreSystemEnd(
  int measureIndex,
  int measureCount, [
  List<ScoreSystemSpan> systems = const [],
]) {
  final system = scoreSystemFor(measureIndex, systems);
  if (systems.isNotEmpty) return system.endMeasureIndex;
  if (measureCount <= 0) return 0;
  return measureIndex < measureCount ? measureIndex : measureCount - 1;
}
