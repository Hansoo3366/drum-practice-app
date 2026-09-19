class TempoTrainer {
  TempoTrainer({
    int startBpm = 80,
    int targetBpm = 140,
    int increment = 5,
    int repetitions = 4,
  }) {
    configure(
      startBpm: startBpm,
      targetBpm: targetBpm,
      increment: increment,
      repetitions: repetitions,
    );
  }

  int startBpm = 80;
  int targetBpm = 140;
  int increment = 5;
  int repetitions = 4;
  int currentBpm = 80;
  int completedRepetitions = 0;
  bool isRunning = false;
  bool _finished = false;

  bool get isComplete => _finished;

  void configure({
    required int startBpm,
    required int targetBpm,
    required int increment,
    required int repetitions,
  }) {
    if (isRunning) {
      throw StateError('Tempo Trainer is running.');
    }
    _validateBpm(startBpm, 'startBpm');
    _validateBpm(targetBpm, 'targetBpm');
    if (targetBpm < startBpm) {
      throw ArgumentError('targetBpm must not be lower than startBpm.');
    }
    if (increment < 1 || increment > 40) {
      throw ArgumentError.value(increment, 'increment');
    }
    if (repetitions < 1 || repetitions > 32) {
      throw ArgumentError.value(repetitions, 'repetitions');
    }
    this.startBpm = startBpm;
    this.targetBpm = targetBpm;
    this.increment = increment;
    this.repetitions = repetitions;
    currentBpm = startBpm;
    completedRepetitions = 0;
    _finished = false;
  }

  void start() {
    currentBpm = startBpm;
    completedRepetitions = 0;
    _finished = false;
    isRunning = true;
  }

  void stop() {
    isRunning = false;
  }

  bool completeRepetition() {
    if (!isRunning) {
      throw StateError('Tempo Trainer is not running.');
    }
    completedRepetitions += 1;
    if (completedRepetitions < repetitions) {
      return false;
    }
    completedRepetitions = 0;
    if (currentBpm >= targetBpm) {
      isRunning = false;
      _finished = true;
      return true;
    }
    currentBpm = (currentBpm + increment).clamp(startBpm, targetBpm);
    return false;
  }

  void _validateBpm(int value, String name) {
    if (value < 40 || value > 240) {
      throw ArgumentError.value(value, name, 'BPM은 40~240이어야 합니다.');
    }
  }
}
