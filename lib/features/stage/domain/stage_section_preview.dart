class StageSectionMarker {
  const StageSectionMarker({required this.number, required this.section});

  final int number;
  final String? section;
}

class StageSectionPreview {
  const StageSectionPreview({
    required this.currentMeasure,
    required this.currentSection,
    required this.nextSection,
    required this.measuresUntilNext,
  });

  final int currentMeasure;
  final String? currentSection;
  final String? nextSection;
  final int? measuresUntilNext;
}

StageSectionPreview? calculateStageSectionPreview(
  Iterable<StageSectionMarker> markers, {
  int? currentMeasure,
}) {
  final ordered = [...markers]..sort((a, b) => a.number.compareTo(b.number));
  if (ordered.isEmpty) return null;

  final current = currentMeasure ?? ordered.first.number;
  String? currentSection;
  for (final marker in ordered) {
    if (marker.number > current) break;
    final section = marker.section?.trim();
    if (section != null && section.isNotEmpty) currentSection = section;
  }

  StageSectionMarker? next;
  for (final marker in ordered) {
    final section = marker.section?.trim();
    if (marker.number > current &&
        section != null &&
        section.isNotEmpty &&
        section != currentSection) {
      next = marker;
      break;
    }
  }

  return StageSectionPreview(
    currentMeasure: current,
    currentSection: currentSection,
    nextSection: next?.section,
    measuresUntilNext: next == null ? null : next.number - current,
  );
}
