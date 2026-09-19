enum ScoreFileFilter { pdf, musicXml }

bool matchesScoreFileName(String name, ScoreFileFilter filter) {
  final lower = name.toLowerCase();
  return switch (filter) {
    ScoreFileFilter.pdf => lower.endsWith('.pdf'),
    ScoreFileFilter.musicXml =>
      lower.endsWith('.musicxml') ||
      lower.endsWith('.mxl') ||
      lower.endsWith('.xml'),
  };
}
