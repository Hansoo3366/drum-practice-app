import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_layout.dart';
import 'package:page_a_diddle/core/audio/audio_engine_provider.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/tools/data/metronome_click_player.dart';
import 'package:page_a_diddle/features/tools/data/metronome_settings.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';
import 'package:page_a_diddle/features/tools/domain/tempo_trainer.dart';
import 'package:page_a_diddle/features/tools/presentation/metronome_settings_sheet.dart';

class TempoTrainerLaunch {
  const TempoTrainerLaunch({
    required this.songId,
    required this.startBpm,
    required this.targetBpm,
  });

  final String songId;
  final int startBpm;
  final int targetBpm;
}

class TempoTrainerScreen extends ConsumerStatefulWidget {
  const TempoTrainerScreen({this.launch, super.key});

  final TempoTrainerLaunch? launch;

  @override
  ConsumerState<TempoTrainerScreen> createState() => _TempoTrainerScreenState();
}

class _TempoTrainerScreenState extends ConsumerState<TempoTrainerScreen> {
  final _trainer = TempoTrainer();
  final _startController = TextEditingController(text: '80');
  final _targetController = TextEditingController(text: '140');
  final _incrementController = TextEditingController(text: '5');
  final _repetitionsController = TextEditingController(text: '4');
  final _sequence = MetronomeSequence();
  final _clicks = MetronomeClickPlayer();
  Timer? _timer;
  int _beat = 0;
  int _beatsPerBar = 4;
  int _previousBeatNumber = 0;
  bool _isCountIn = false;
  bool _wasCountIn = false;
  List<MetronomeAccentLevel> _accentPattern = const [
    MetronomeAccentLevel.strong,
    MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal,
  ];
  bool _haptics = true;
  bool _loading = false;
  String? _error;
  int? _flashBpm;

  int get _startBpm =>
      int.tryParse(_startController.text)?.clamp(40, 240) ?? _trainer.startBpm;
  int get _targetBpm =>
      int.tryParse(_targetController.text)?.clamp(40, 240) ??
      _trainer.targetBpm;
  int get _stepBpm =>
      int.tryParse(_incrementController.text)?.clamp(1, 40) ??
      _trainer.increment;
  int get _barsPerStep =>
      int.tryParse(_repetitionsController.text)?.clamp(1, 32) ??
      _trainer.repetitions;

  int? get _nextBpm {
    if (_trainer.currentBpm >= _trainer.targetBpm) {
      return null;
    }
    return (_trainer.currentBpm + _trainer.increment).clamp(
      _trainer.startBpm,
      _trainer.targetBpm,
    );
  }

  @override
  void initState() {
    super.initState();
    final launch = widget.launch;
    if (launch == null) {
      return;
    }
    _startController.text = '${launch.startBpm}';
    _targetController.text = '${launch.targetBpm}';
    _trainer.configure(
      startBpm: launch.startBpm,
      targetBpm: launch.targetBpm,
      increment: int.parse(_incrementController.text),
      repetitions: int.parse(_repetitionsController.text),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _startController.dispose();
    _targetController.dispose();
    _incrementController.dispose();
    _repetitionsController.dispose();
    if (SoLoud.instance.isInitialized) {
      unawaited(_clicks.dispose(SoLoud.instance));
    }
    super.dispose();
  }

  void _syncFromMetronomeSettings(MetronomeSettings settings) {
    _beatsPerBar = settings.meter.numerator;
    _accentPattern = List.of(settings.accents);
    _haptics = settings.haptics;
    _sequence.configure(
      beatsPerBar: _beatsPerBar,
      stepsPerBeat: settings.subdivision.stepsPerBeat,
      accentPattern: _accentPattern,
    );
  }

  Future<void> _start() async {
    if (_loading || _trainer.isRunning) {
      return;
    }
    try {
      _trainer.configure(
        startBpm: int.parse(_startController.text),
        targetBpm: int.parse(_targetController.text),
        increment: int.parse(_incrementController.text),
        repetitions: int.parse(_repetitionsController.text),
      );
    } on Object catch (_) {
      setState(() => _error = context.l10n.checkSettings);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final songId = widget.launch?.songId;
      if (songId != null) {
        await ref
            .read(songRepositoryProvider)
            .updateTargetBpm(id: songId, targetBpm: _trainer.targetBpm);
      }
      _syncFromMetronomeSettings(ref.read(metronomeSettingsProvider));
      final engine = await ref.read(audioEngineProvider.future);
      await _clicks.ensureLoaded(engine);
      if (!mounted) {
        _trainer.stop();
        return;
      }
      final settings = ref.read(metronomeSettingsProvider);
      _trainer.start();
      _sequence.start(countInBars: settings.countInBars);
      setState(() {
        _loading = false;
        _beat = 0;
        _previousBeatNumber = 0;
        _isCountIn = false;
        _wasCountIn = false;
        _flashBpm = null;
      });
      _tick(engine);
      _startTimer(engine);
    } on Object catch (_) {
      _trainer.stop();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.l10n.audioError;
        });
      }
    }
  }

  void _startTimer(SoLoud engine) {
    _timer?.cancel();
    final settings = ref.read(metronomeSettingsProvider);
    _timer = Timer.periodic(
      MetronomeSequence.intervalFor(
        _trainer.currentBpm,
        stepsPerBeat: settings.subdivision.stepsPerBeat,
      ),
      (_) => _tick(engine),
    );
  }

  void _tick(SoLoud engine) {
    if (!_trainer.isRunning) {
      return;
    }
    final wasCountIn = _wasCountIn;
    final previousBeat = _previousBeatNumber;
    final beat = _sequence.next();
    final barJustFinished =
        !wasCountIn &&
        !beat.isCountIn &&
        !beat.isSubdivision &&
        beat.number == 1 &&
        previousBeat == _beatsPerBar;

    if (mounted) {
      setState(() {
        _beat = beat.number;
        _isCountIn = beat.isCountIn;
        _wasCountIn = beat.isCountIn;
        if (!beat.isSubdivision) {
          _previousBeatNumber = beat.number;
        }
      });
    } else {
      _wasCountIn = beat.isCountIn;
      if (!beat.isSubdivision) {
        _previousBeatNumber = beat.number;
      }
    }

    unawaited(_clicks.play(engine, beat, haptics: _haptics));

    if (barJustFinished) {
      _onBarCompleted(engine);
    }
  }

  void _onBarCompleted(SoLoud engine) {
    if (!_trainer.isRunning) {
      return;
    }
    final before = _trainer.currentBpm;
    final finished = _trainer.completeRepetition();
    final stepped = !finished && _trainer.currentBpm != before;
    if (finished) {
      _stopAudio();
      if (mounted) {
        setState(() {
          _beat = 0;
          _previousBeatNumber = 0;
          _isCountIn = false;
          _wasCountIn = false;
          _flashBpm = _trainer.currentBpm;
        });
      }
      return;
    }
    if (stepped && engine.isInitialized) {
      _startTimer(engine);
    }
    if (mounted) {
      setState(() {
        if (stepped) {
          _flashBpm = _trainer.currentBpm;
        }
      });
    }
  }

  void _stop() {
    _trainer.stop();
    _stopAudio();
    setState(() {
      _beat = 0;
      _previousBeatNumber = 0;
      _isCountIn = false;
      _wasCountIn = false;
      _flashBpm = null;
      _error = null;
    });
  }

  void _stopAudio() {
    _timer?.cancel();
    _timer = null;
    if (SoLoud.instance.isInitialized) {
      unawaited(_clicks.stop(SoLoud.instance));
    }
  }

  Future<void> _openSettingsSheet() async {
    final l10n = context.l10n;
    final running = _trainer.isRunning;
    final metro = ref.read(metronomeSettingsProvider);
    await showMetronomeSettingsSheet(
      context: context,
      initial: metro,
      enabled: !running,
      subtitle: l10n.trainerHint,
      leading: [
        Row(
          children: [
            _SheetNumberField(
              label: l10n.start,
              controller: _startController,
              enabled: !running,
            ),
            const SizedBox(width: 12),
            _SheetNumberField(
              label: l10n.target,
              controller: _targetController,
              enabled: !running,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _SheetNumberField(
              label: l10n.increase,
              controller: _incrementController,
              enabled: !running,
            ),
            const SizedBox(width: 12),
            _SheetNumberField(
              label: l10n.repetitions,
              controller: _repetitionsController,
              enabled: !running,
            ),
          ],
        ),
      ],
      onChanged: (next) async {
        await ref.read(metronomeSettingsProvider.notifier).update(next);
        if (!running) {
          _syncFromMetronomeSettings(next);
        }
        if (mounted) {
          setState(() {});
        }
      },
    );
    if (mounted && !running) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioEngineProvider);
    final metro = ref.watch(metronomeSettingsProvider);
    final l10n = context.l10n;
    final running = _trainer.isRunning;
    final complete = _trainer.isComplete;
    final busy = audio.hasError || audio.isLoading || _loading;
    final startBpm = running ? _trainer.startBpm : _startBpm;
    final targetBpm = running ? _trainer.targetBpm : _targetBpm;
    final stepBpm = running ? _trainer.increment : _stepBpm;
    final barsPerStep = running ? _trainer.repetitions : _barsPerStep;
    final currentBpm = running || complete ? _trainer.currentBpm : startBpm;
    final climbProgress = targetBpm <= startBpm
        ? 1.0
        : ((currentBpm - startBpm) / (targetBpm - startBpm)).clamp(0.0, 1.0);
    final barsDone = running ? _trainer.completedRepetitions : 0;
    final beats = running ? _beatsPerBar : metro.meter.numerator;
    final accents = running ? _accentPattern : metro.accents;
    final nextBpm = running ? _nextBpm : (startBpm + stepBpm).clamp(40, 240);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Theme(
      data: AppTheme.stage,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.tempoTrainer)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ClimbHeader(
                  startBpm: startBpm,
                  currentBpm: currentBpm,
                  targetBpm: targetBpm,
                  progress: complete ? 1 : climbProgress,
                  running: running,
                  complete: complete,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 22,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var beat = 1; beat <= beats; beat++) ...[
                              _BeatDot(
                                active: running && _beat == beat,
                                strong:
                                    beat <= accents.length &&
                                    accents[beat - 1] ==
                                        MetronomeAccentLevel.strong,
                                muted:
                                    beat <= accents.length &&
                                    accents[beat - 1] ==
                                        MetronomeAccentLevel.mute,
                              ),
                              if (beat < beats) const SizedBox(width: 10),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        complete
                            ? l10n.targetReached
                            : running
                            ? (_isCountIn
                                  ? '${l10n.countIn} $_beat/$beats'
                                  : l10n.trainerStageBars(
                                      barsDone + 1,
                                      barsPerStep,
                                    ))
                            : l10n.trainerIdleTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.stageMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(flex: 2),
                      AnimatedScale(
                        scale: !reduceMotion && _flashBpm == currentBpm
                            ? 1.04
                            : 1,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: !reduceMotion && _flashBpm == currentBpm
                                ? AppColors.accent
                                : AppColors.canvas,
                            fontFamily: AppFonts.mono,
                            fontSize: 92,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -3.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          child: Text(
                            '$currentBpm',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BPM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.accent.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.4,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (running && !complete && nextBpm != null)
                        Text(
                          l10n.trainerNext(nextBpm),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.canvas,
                            fontFamily: AppFonts.mono,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (!running && !complete)
                        Text(
                          l10n.trainerHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.stageMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      const Spacer(),
                      _BarStageTrack(
                        total: barsPerStep,
                        filled: complete
                            ? barsPerStep
                            : running
                            ? barsDone
                            : 0,
                        activeIndex: running && !complete ? barsDone : null,
                      ),
                      if (_error case final error?) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFF8A80),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PlanCard(
                  plan:
                      '${l10n.trainerPlan(startBpm, stepBpm, barsPerStep, targetBpm)}\n${l10n.meterConfigured(metro.meter.label)}',
                  enabled: !running,
                  onTap: _openSettingsSheet,
                ),
                const SizedBox(height: 18),
                if (running)
                  AppPlayButton(
                    playing: true,
                    tooltip: l10n.stop,
                    onPressed: _stop,
                  )
                else
                  AppPlayButton(
                    playing: false,
                    tooltip: busy ? l10n.audioError : l10n.start,
                    onPressed: busy ? null : _start,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClimbHeader extends StatelessWidget {
  const _ClimbHeader({
    required this.startBpm,
    required this.currentBpm,
    required this.targetBpm,
    required this.progress,
    required this.running,
    required this.complete,
  });

  final int startBpm;
  final int currentBpm;
  final int targetBpm;
  final double progress;
  final bool running;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _EndpointLabel(value: '$startBpm', caption: context.l10n.start),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: AppColors.stagePanel,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      complete
                          ? '$targetBpm'
                          : running
                          ? '$currentBpm'
                          : '$startBpm → $targetBpm',
                      style: const TextStyle(
                        color: AppColors.canvas,
                        fontFamily: AppFonts.mono,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _EndpointLabel(
              value: '$targetBpm',
              caption: context.l10n.target,
              alignEnd: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _EndpointLabel extends StatelessWidget {
  const _EndpointLabel({
    required this.value,
    required this.caption,
    this.alignEnd = false,
  });

  final String value;
  final String caption;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: const TextStyle(
            color: AppColors.stageMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.canvas,
            fontFamily: AppFonts.mono,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _BarStageTrack extends StatelessWidget {
  const _BarStageTrack({
    required this.total,
    required this.filled,
    required this.activeIndex,
  });

  final int total;
  final int filled;
  final int? activeIndex;

  @override
  Widget build(BuildContext context) {
    final count = total.clamp(1, 16);
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 10,
              decoration: BoxDecoration(
                color: i < filled
                    ? AppColors.accent
                    : i == activeIndex
                    ? AppColors.accent.withValues(alpha: 0.35)
                    : AppColors.stagePanel,
                borderRadius: BorderRadius.circular(4),
                border: i == activeIndex
                    ? Border.all(color: AppColors.accent, width: 1.2)
                    : null,
              ),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.enabled,
    required this.onTap,
  });

  final String plan;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.stageElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  plan,
                  style: TextStyle(
                    color: enabled ? AppColors.canvas : AppColors.stageMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              if (enabled)
                const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.stageMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetNumberField extends StatelessWidget {
  const _SheetNumberField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        style: const TextStyle(
          color: AppColors.canvas,
          fontFamily: AppFonts.mono,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.stagePanel,
        ),
      ),
    );
  }
}

class _BeatDot extends StatelessWidget {
  const _BeatDot({
    required this.active,
    required this.strong,
    required this.muted,
  });

  final bool active;
  final bool strong;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final base = muted
        ? AppColors.stageOutline
        : strong
        ? AppColors.accent.withValues(alpha: 0.55)
        : AppColors.stageMuted;
    return SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: AnimatedScale(
          scale: active ? (strong ? 1.15 : 1.08) : 1,
          duration: const Duration(milliseconds: 80),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: strong ? 12 : 10,
            height: strong ? 12 : 10,
            decoration: BoxDecoration(
              color: active ? AppColors.accent : base,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
