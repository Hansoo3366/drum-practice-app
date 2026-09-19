import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_layout.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/core/audio/audio_engine_provider.dart';
import 'package:page_a_diddle/features/tools/data/metronome_click_player.dart';
import 'package:page_a_diddle/features/tools/data/metronome_settings.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';
import 'package:page_a_diddle/features/tools/presentation/metronome_settings_sheet.dart';

class MetronomeScreen extends ConsumerStatefulWidget {
  const MetronomeScreen({this.initialBpm, super.key});

  final int? initialBpm;

  @override
  ConsumerState<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends ConsumerState<MetronomeScreen> {
  final _sequence = MetronomeSequence();
  final _clicks = MetronomeClickPlayer();
  final _bpmController = TextEditingController(text: '120');
  Timer? _timer;
  Timer? _persistTimer;
  int _bpm = 120;
  MetronomeMeter _meter = const MetronomeMeter(4, 4);
  int _beat = 0;
  MetronomeSubdivision _subdivision = MetronomeSubdivision.quarter;
  List<MetronomeAccentLevel> _accentPattern = const [
    MetronomeAccentLevel.strong,
    MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal,
  ];
  int _countInBars = 1;
  bool _isCountIn = false;
  bool _isRunning = false;
  bool _isLoading = false;
  bool _haptics = true;
  var _hydrated = false;

  int get _beatsPerBar => _meter.numerator;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialBpm;
    if (seed != null) {
      _bpm = seed.clamp(40, 240);
      _bpmController.text = '$_bpm';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _persistTimer?.cancel();
    _bpmController.dispose();
    if (SoLoud.instance.isInitialized) {
      unawaited(_clicks.dispose(SoLoud.instance));
    }
    super.dispose();
  }

  void _hydrateFromSettings(MetronomeSettings settings) {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    final bpm = widget.initialBpm?.clamp(40, 240) ?? settings.bpm;
    setState(() {
      _bpm = bpm;
      _bpmController.text = '$bpm';
      _meter = settings.meter;
      _subdivision = settings.subdivision;
      _accentPattern = List.of(settings.accents);
      _countInBars = settings.countInBars;
      _haptics = settings.haptics;
    });
    _sequence.configure(
      beatsPerBar: settings.meter.numerator,
      stepsPerBeat: settings.subdivision.stepsPerBeat,
      accentPattern: settings.accents,
    );
    if (widget.initialBpm != null) {
      _schedulePersist();
    }
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 280), () {
      unawaited(
        ref
            .read(metronomeSettingsProvider.notifier)
            .update(
              MetronomeSettings(
                bpm: _bpm,
                meter: _meter,
                subdivision: _subdivision,
                accents: _accentPattern,
                countInBars: _countInBars,
                haptics: _haptics,
              ),
            ),
      );
    });
  }

  Future<void> _toggle() async {
    if (_isLoading) {
      return;
    }
    if (_isRunning) {
      _stop();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final engine = await ref.read(audioEngineProvider.future);
      await _clicks.ensureLoaded(engine);
      if (!mounted) {
        return;
      }
      _sequence.configure(
        beatsPerBar: _beatsPerBar,
        stepsPerBeat: _subdivision.stepsPerBeat,
        accentPattern: _accentPattern,
      );
      _sequence.start(countInBars: _countInBars);
      setState(() => _isRunning = true);
      _tick(engine);
      _startTimer(engine);
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.audioError)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startTimer(SoLoud engine) {
    _timer?.cancel();
    _timer = Timer.periodic(
      MetronomeSequence.intervalFor(
        _bpm,
        stepsPerBeat: _subdivision.stepsPerBeat,
      ),
      (_) => _tick(engine),
    );
  }

  void _tick(SoLoud engine) {
    final beat = _sequence.next();
    if (mounted) {
      setState(() {
        _beat = beat.number;
        _isCountIn = beat.isCountIn;
      });
    }
    unawaited(_clicks.play(engine, beat, haptics: _haptics));
  }

  void _stop() {
    _timer?.cancel();
    if (SoLoud.instance.isInitialized) {
      unawaited(_clicks.stop(SoLoud.instance));
    }
    setState(() {
      _isRunning = false;
      _isCountIn = false;
      _beat = 0;
    });
  }

  void _setBpm(int value) {
    final bpm = value.clamp(40, 240).toInt();
    setState(() {
      _bpm = bpm;
      _bpmController.value = TextEditingValue(
        text: '$bpm',
        selection: TextSelection.collapsed(offset: '$bpm'.length),
      );
    });
    _schedulePersist();
    if (_isRunning && SoLoud.instance.isInitialized) {
      _startTimer(SoLoud.instance);
    }
  }

  void _commitBpm(String value) {
    _setBpm(int.tryParse(value) ?? _bpm);
  }

  void _setMeter(MetronomeMeter meter) {
    final pattern = accentsForMeter(meter, _accentPattern);
    setState(() {
      _meter = meter;
      _accentPattern = pattern;
      _sequence.configure(beatsPerBar: meter.numerator, accentPattern: pattern);
      if (_isRunning) {
        _sequence.start(countIn: false);
      }
    });
    _schedulePersist();
  }

  MetronomeSettings get _currentSettings => MetronomeSettings(
    bpm: _bpm,
    meter: _meter,
    subdivision: _subdivision,
    accents: _accentPattern,
    countInBars: _countInBars,
    haptics: _haptics,
  );

  void _applySettings(MetronomeSettings next) {
    setState(() {
      _meter = next.meter;
      _subdivision = next.subdivision;
      _accentPattern = List.of(next.accents);
      _countInBars = next.countInBars;
      _haptics = next.haptics;
      _sequence.configure(
        beatsPerBar: next.meter.numerator,
        stepsPerBeat: next.subdivision.stepsPerBeat,
        accentPattern: next.accents,
      );
      if (_isRunning) {
        _sequence.start(countIn: false);
      }
    });
    _schedulePersist();
  }

  Future<void> _openDetailSheet() async {
    await showMetronomeSettingsSheet(
      context: context,
      initial: _currentSettings,
      enabled: !_isRunning,
      onChanged: _applySettings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(metronomeSettingsProvider);
    if (!_hydrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hydrateFromSettings(settings);
        }
      });
    }
    final audio = ref.watch(audioEngineProvider);
    final l10n = context.l10n;
    final busy = _isLoading || audio.hasError || audio.isLoading;
    final status = _isCountIn
        ? '${l10n.countIn} $_beat/$_beatsPerBar'
        : _isRunning
        ? '$_beat/$_beatsPerBar'
        : audio.isLoading
        ? l10n.preparing
        : audio.hasError
        ? l10n.audioError
        : ' ';

    return Theme(
      data: AppTheme.stage,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.metronome),
          actions: [
            IconButton(
              tooltip: l10n.settings,
              onPressed: _openDetailSheet,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              children: [
                SizedBox(
                  height: 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var beat = 1; beat <= _beatsPerBar; beat++) ...[
                        _BeatDot(
                          active: _isRunning && _beat == beat,
                          strong:
                              _accentPattern[beat - 1] ==
                              MetronomeAccentLevel.strong,
                          muted:
                              _accentPattern[beat - 1] ==
                              MetronomeAccentLevel.mute,
                        ),
                        if (beat < _beatsPerBar) const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 18,
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.stageMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CompactIconButton(
                      icon: Icons.remove_rounded,
                      tooltip: l10n.bpmDown,
                      onPressed: () => _setBpm(_bpm - 1),
                    ),
                    SizedBox(
                      width: 196,
                      height: 78,
                      child: TextField(
                        controller: _bpmController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.canvas,
                          fontFamily: AppFonts.mono,
                          fontSize: 72,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -2.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        decoration: const InputDecoration(
                          suffixText: 'BPM',
                          filled: false,
                          fillColor: Colors.transparent,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          suffixStyle: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.stageMuted,
                          ),
                        ),
                        onSubmitted: _commitBpm,
                        onEditingComplete: () =>
                            _commitBpm(_bpmController.text),
                        onTapOutside: (_) => _commitBpm(_bpmController.text),
                      ),
                    ),
                    CompactIconButton(
                      icon: Icons.add_rounded,
                      tooltip: l10n.bpmUp,
                      onPressed: () => _setBpm(_bpm + 1),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: _bpm.toDouble(),
                    min: 40,
                    max: 240,
                    divisions: 200,
                    onChanged: (value) => _setBpm(value.round()),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _MetaChip(
                        label: l10n.meter,
                        value: _meter.label,
                        onTap: () async {
                          final selected =
                              await showOptionPickerSheet<MetronomeMeter>(
                                context: context,
                                title: l10n.meter,
                                options: metronomeMeters,
                                labelOf: (meter) => meter.label,
                                selected: _meter,
                                backgroundColor: AppColors.stageElevated,
                                foregroundColor: AppColors.canvas,
                                mutedColor: AppColors.stageMuted,
                              );
                          if (selected != null) {
                            _setMeter(selected);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetaChip(
                        label: l10n.beatUnit,
                        value: _subdivision.label,
                        onTap: _openDetailSheet,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                AppPlayButton(
                  playing: _isRunning,
                  tooltip: _isRunning
                      ? l10n.stop
                      : busy
                      ? l10n.audioError
                      : l10n.start,
                  onPressed: busy ? null : _toggle,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed slot — pulse with scale so layout never jumps.
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.stageElevated,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.stageMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.canvas,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
