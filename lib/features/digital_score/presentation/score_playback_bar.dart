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
    this.tempoPercent = 100,
    this.onTempo,
    this.sequenceSelected = false,
    this.padBottomSafeArea = true,
    this.firstBarNumber = 1,
    super.key,
  });

  /// The number of the score's first bar ([MusicScore.firstBarNumber]).
  final int firstBarNumber;

  final ScorePlaybackState state;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final ValueChanged<double> onSeek;
  final VoidCallback? onEditSequence;
  final VoidCallback? onTranspose;

  /// How fast the score plays, in percent of its written tempo, and what
  /// takes a new one. Without [onTempo] the bar has no tempo control.
  final int tempoPercent;
  final ValueChanged<int>? onTempo;
  final bool sequenceSelected;
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
    final barNumber = state.measureNumber - 1 + widget.firstBarNumber;
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controls = <Widget>[
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
                  if (widget.onTempo != null)
                    _TempoButton(
                      percent: widget.tempoPercent,
                      onChanged: widget.onTempo!,
                    ),
                ];
                final timeline = <Widget>[
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
                ];
                final beat = Semantics(
                  label: l10n.measureBeat(barNumber, state.displayBeat),
                  child: _ClockLabel(
                    value: '$barNumber · ${state.displayBeat}',
                    width: 52,
                  ),
                );
                if (constraints.maxWidth < 480 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [...controls, beat],
                      ),
                      const SizedBox(height: 8),
                      Row(children: timeline),
                    ],
                  );
                }
                return Row(
                  children: [
                    ...controls,
                    const SizedBox(width: 8),
                    ...timeline,
                    const SizedBox(width: 8),
                    beat,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The slowest and the fastest practice tempo, in percent.
const playbackTempoMin = 40;
const playbackTempoMax = 150;

/// The practice tempo, as a number to press: slowing a passage down is the
/// first thing a player does with a score that plays.
class _TempoButton extends StatelessWidget {
  const _TempoButton({required this.percent, required this.onChanged});

  final int percent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Tooltip(
      message: l10n.playbackTempo,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) =>
              _TempoSheet(percent: percent, onChanged: onChanged),
        ),
        child: Semantics(
          button: true,
          label: '${l10n.playbackTempo} $percent%',
          excludeSemantics: true,
          child: SizedBox(
            width: 44 * MediaQuery.textScalerOf(context).scale(1),
            height: 40,
            child: Center(
              child: Text(
                '$percent%',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TempoSheet extends StatefulWidget {
  const _TempoSheet({required this.percent, required this.onChanged});

  final int percent;
  final ValueChanged<int> onChanged;

  @override
  State<_TempoSheet> createState() => _TempoSheetState();
}

class _TempoSheetState extends State<_TempoSheet> {
  late int _percent = widget.percent;

  void _set(int value) {
    final next = value.clamp(playbackTempoMin, playbackTempoMax);
    if (next == _percent) return;
    setState(() => _percent = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.playbackTempo,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text('$_percent%', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: '-5%',
                  onPressed: _percent > playbackTempoMin
                      ? () => _set(_percent - 5)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Slider(
                    value: _percent.toDouble(),
                    min: playbackTempoMin.toDouble(),
                    max: playbackTempoMax.toDouble(),
                    divisions: (playbackTempoMax - playbackTempoMin) ~/ 5,
                    label: '$_percent%',
                    // The music is made again at the new tempo: once the
                    // finger lets go, not at every step on the way.
                    onChanged: (value) =>
                        setState(() => _percent = value.round()),
                    onChangeEnd: (value) => widget.onChanged(value.round()),
                  ),
                ),
                IconButton(
                  tooltip: '+5%',
                  onPressed: _percent < playbackTempoMax
                      ? () => _set(_percent + 5)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _percent == 100 ? null : () => _set(100),
                child: const Text('100%'),
              ),
            ),
          ],
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
      width: width * MediaQuery.textScalerOf(context).scale(1),
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
