enum ScoreType {
  pdf('pdf'),
  musicXml('musicxml');

  const ScoreType(this.key);

  final String key;

  static ScoreType fromKey(String value) {
    return ScoreType.values.firstWhere(
      (type) => type.key == value,
      orElse: () => ScoreType.pdf,
    );
  }
}
