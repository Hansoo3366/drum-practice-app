import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/features/tools/domain/tap_tempo.dart';

/// Immersive tap pad — measure BPM, send to metronome.
class TapTempoScreen extends StatefulWidget {
  const TapTempoScreen({super.key});

  @override
  State<TapTempoScreen> createState() => _TapTempoScreenState();
}

class _TapTempoScreenState extends State<TapTempoScreen> {
  final _tempo = TapTempo();
  double _scale = 1;
  double _pulse = 1;

  int? get _displayBpm => switch (_tempo.bpm) {
    final bpm? => (bpm * _scale).round().clamp(40, 240),
    null => null,
  };

  void _tap() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tempo.tap(DateTime.now());
      _scale = 1;
      _pulse = 0.92;
    });
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _pulse = 1);
    });
  }

  void _changeScale(double factor) {
    setState(() => _scale *= factor);
  }

  void _reset() {
    setState(() {
      _tempo.reset();
      _scale = 1;
      _pulse = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bpm = _displayBpm;
    final hasTaps = _tempo.tapCount > 0;

    return Theme(
      data: AppTheme.stage,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tapTempo),
          actions: [
            CompactIconButton(
              icon: Icons.refresh_rounded,
              tooltip: l10n.reset,
              color: AppColors.stageMuted,
              onPressed: hasTaps ? _reset : null,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  bpm?.toString() ?? '···',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 88,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: bpm == null ? 8 : -3,
                    color: bpm == null
                        ? AppColors.stageMuted
                        : AppColors.canvas,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'BPM',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 20,
                  child: Text(
                    hasTaps
                        ? '${_tempo.tapCount} taps'
                              '${_scale != 1 ? ' · ×${_scale == _scale.roundToDouble() ? _scale.toInt() : _scale}' : ''}'
                        : l10n.tapInput,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.stageMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Semantics(
                  button: true,
                  label: l10n.tapInput,
                  child: GestureDetector(
                    onTapDown: (_) => _tap(),
                    child: AnimatedScale(
                      scale: _pulse,
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.easeOut,
                      child: Container(
                        width: 220,
                        height: 220,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                          border: Border.all(
                            color: AppColors.canvas.withValues(alpha: 0.18),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.35),
                              blurRadius: _pulse < 1 ? 8 : 28,
                              spreadRadius: _pulse < 1 ? 0 : 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          'TAP',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: AppColors.canvas,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: bpm == null ? null : () => _changeScale(.5),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.canvas,
                          disabledForegroundColor: AppColors.stageOutline,
                          side: const BorderSide(color: AppColors.stageOutline),
                          minimumSize: const Size(0, 48),
                        ),
                        child: Semantics(
                          label: l10n.halve,
                          excludeSemantics: true,
                          child: const Text(
                            '½',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: bpm == null ? null : () => _changeScale(2),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.canvas,
                          disabledForegroundColor: AppColors.stageOutline,
                          side: const BorderSide(color: AppColors.stageOutline),
                          minimumSize: const Size(0, 48),
                        ),
                        child: Semantics(
                          label: l10n.double,
                          excludeSemantics: true,
                          child: const Text(
                            '2×',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: bpm == null
                      ? null
                      : () => context.push('/tools/metronome?bpm=$bpm'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.canvas,
                    disabledBackgroundColor: AppColors.stageElevated,
                    disabledForegroundColor: AppColors.stageOutline,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    l10n.openInMetronome,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
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
