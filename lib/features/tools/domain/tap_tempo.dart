class TapTempo {
  static const _resetAfter = Duration(seconds: 2);
  static const _maxIntervals = 6;

  final List<Duration> _intervals = [];
  DateTime? _lastTap;

  int get tapCount => _lastTap == null ? 0 : _intervals.length + 1;

  int? get bpm {
    if (_intervals.isEmpty) {
      return null;
    }
    final averageMicroseconds =
        _intervals.fold<int>(0, (sum, value) => sum + value.inMicroseconds) /
        _intervals.length;
    return (Duration.microsecondsPerMinute / averageMicroseconds).round();
  }

  int? tap(DateTime time) {
    final lastTap = _lastTap;
    if (lastTap == null ||
        !time.isAfter(lastTap) ||
        time.difference(lastTap) > _resetAfter) {
      reset();
    } else {
      _intervals.add(time.difference(lastTap));
      if (_intervals.length > _maxIntervals) {
        _intervals.removeAt(0);
      }
    }
    _lastTap = time;
    return bpm;
  }

  void reset() {
    _intervals.clear();
    _lastTap = null;
  }
}
