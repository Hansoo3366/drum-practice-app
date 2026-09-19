import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';

class ScorePlaybackBar extends StatefulWidget {
  const ScorePlaybackBar({
    required this.state,
    required this.onPlayPause,
    required this.onStop,
    required this.onSeek,
    this.onEditSequence,
    this.onTranspose,
    this.onEditArrangement,
    this.sequenceSelected = false,
    this.arrangementSelected = false,
    this.padBottomSafeArea = true,
    super.key,
  });

  final ScorePlaybackState state;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<double> onSeek;
  final VoidCallback? onEditSequence;
  final VoidCallback? onTranspose;
  final VoidCallback? onEditArrangement;
  final bool sequenceSelected;
  final bool arrangementSelected;
  final bool padBottomSafeArea;

  @override
  State<ScorePlaybackBar> createState() => _ScorePlaybackBarState();
}

class _ScorePlaybackBarState extends State<ScorePlaybackBar> {
  double? _dragPositionMs;

  @override
  void didUpdateWidget(covariant ScorePlaybackBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.state.ready) _dragPositionMs = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final duration = state.durationMs.isFinite && state.durationMs > 0
        ? state.durationMs
        : 1.0;
    final position = (_dragPositionMs ?? state.currentTimeMs).clamp(
      0,
      duration,
    );
    final canControl = state.canControl;

    return Material(
      color: AppColors.canvas,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          bottom: widget.padBottomSafeArea,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                CompactIconButton(
                  tooltip: l10n.stop,
                  onPressed: canControl ? widget.onStop : null,
                  icon: Icons.stop_rounded,
                ),
                CompactIconButton(
                  tooltip: state.playing ? l10n.pause : l10n.play,
                  selected: state.playing,
                  selectedColor: AppColors.accent,
                  onPressed: canControl ? widget.onPlayPause : null,
                  icon: state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                if (widget.onEditSequence != null)
                  CompactIconButton(
                    tooltip: l10n.playbackSequence,
                    selected: widget.sequenceSelected,
                    selectedColor: AppColors.accent,
                    onPressed: widget.onEditSequence,
                    icon: Icons.playlist_play_rounded,
                  ),
                if (widget.onTranspose != null)
                  CompactIconButton(
                    tooltip: l10n.scoreTranspose,
                    onPressed: widget.onTranspose,
                    icon: Icons.swap_vert_rounded,
                  ),
                if (widget.onEditArrangement != null)
                  CompactIconButton(
                    tooltip: l10n.scoreArrangement,
                    selected: widget.arrangementSelected,
                    selectedColor: AppColors.accent,
                    onPressed: widget.onEditArrangement,
                    icon: Icons.piano_rounded,
                  ),
                const SizedBox(width: 8),
                _ClockLabel(value: formatPlaybackClock(position.toDouble())),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.accent,
                      overlayColor: AppColors.accent.withValues(alpha: 0.16),
                    ),
                    child: Slider(
                      value: position.toDouble(),
                      max: duration,
                      onChanged: canControl
                          ? (value) => setState(() => _dragPositionMs = value)
                          : null,
                      onChangeEnd: canControl
                          ? (value) {
                              setState(() => _dragPositionMs = null);
                              widget.onSeek(value);
                            }
                          : null,
                    ),
                  ),
                ),
                _ClockLabel(value: formatPlaybackClock(state.durationMs)),
                const SizedBox(width: 8),
                Semantics(
                  label: l10n.measureBeat(
                    state.measureNumber,
                    state.displayBeat,
                  ),
                  child: _ClockLabel(
                    value: '${state.measureNumber} · ${state.displayBeat}',
                    width: 52,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockLabel extends StatelessWidget {
  const _ClockLabel({required this.value, this.width = 36});

  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedInk,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
