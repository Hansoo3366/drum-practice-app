import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';

/// Shared surface fill for viewer chrome (no drop shadow).
const Color kViewerChromeFill = Color(0xF21A1C20);
const Color kViewerChromeBorder = Color(0x33FFFFFF);

/// Compact status pill for viewer chrome (auto-pause, follow, BPM).
class ViewerStatusChip extends StatelessWidget {
  const ViewerStatusChip({
    required this.label,
    this.tone = ViewerChipTone.accent,
    super.key,
  });

  final String label;
  final ViewerChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (tone) {
      ViewerChipTone.accent => (
        AppColors.accent,
        AppColors.accent.withValues(alpha: 0.18),
      ),
      ViewerChipTone.warning => (
        const Color(0xFFFF8A65),
        const Color(0x33FF8A65),
      ),
      ViewerChipTone.muted => (AppColors.stageMuted, AppColors.stagePanel),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

enum ViewerChipTone { accent, warning, muted }

/// Thin affordance when viewer chrome is hidden.
class ViewerChromePeekBar extends StatelessWidget {
  const ViewerChromePeekBar({this.hint, super.key});

  final String? hint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Top app bar for the PDF score viewer.
class ViewerTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ViewerTopBar({
    required this.title,
    required this.onBack,
    required this.onTitleTap,
    this.subtitle,
    this.bpm,
    this.autoPaused = false,
    this.followOff = false,
    this.followActive = false,
    this.showJamFollow = false,
    this.jamFollowing = true,
    this.onJamFollowToggle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final VoidCallback onTitleTap;
  final int? bpm;
  final bool autoPaused;
  final bool followOff;
  final bool followActive;
  final bool showJamFollow;
  final bool jamFollowing;
  final VoidCallback? onJamFollowToggle;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 52 : 64);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBar(
      primary: false,
      backgroundColor: AppColors.stage,
      foregroundColor: Colors.white,
      toolbarHeight: preferredSize.height,
      titleSpacing: 0,
      leading: IconButton(
        color: Colors.white,
        tooltip: l10n.back,
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: GestureDetector(
        onTap: onTitleTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (bpm case final tempo?) ...[
                  const SizedBox(width: 8),
                  ViewerStatusChip(label: '$tempo BPM'),
                ],
                if (autoPaused) ...[
                  const SizedBox(width: 6),
                  ViewerStatusChip(
                    label: l10n.autoPaused,
                    tone: ViewerChipTone.warning,
                  ),
                ],
                if (followOff) ...[
                  const SizedBox(width: 6),
                  ViewerStatusChip(
                    label: l10n.followOff,
                    tone: ViewerChipTone.warning,
                  ),
                ],
                if (followActive) ...[
                  const SizedBox(width: 6),
                  ViewerStatusChip(
                    label: l10n.progressFollow,
                    tone: ViewerChipTone.muted,
                  ),
                ],
              ],
            ),
            if (subtitle case final line?) ...[
              const SizedBox(height: 2),
              Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.accent.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (showJamFollow)
          IconButton(
            color: Colors.white,
            onPressed: onJamFollowToggle,
            tooltip: jamFollowing ? l10n.followConductor : l10n.returnToLive,
            icon: Icon(
              jamFollowing
                  ? Icons.sync_rounded
                  : Icons.play_circle_outline_rounded,
              color: jamFollowing ? AppColors.accent : Colors.white,
            ),
          ),
      ],
    );
  }
}

/// Bottom transport chrome for the PDF score viewer.
class ViewerBottomBar extends StatelessWidget {
  const ViewerBottomBar({
    required this.pageLabel,
    required this.pageNumber,
    required this.pageCount,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onPagePicker,
    required this.onPageScrub,
    required this.onMetronome,
    required this.onAnnotations,
    required this.onSettings,
    this.nextSongId,
    this.onNextSong,
    this.hasAudio = false,
    this.audioPlaying = false,
    this.audioLoading = false,
    this.onToggleAudio,
    this.metronomeRunning = false,
    this.metronomeLoading = false,
    this.showJamFollow = false,
    this.jamFollowing = true,
    this.onJamFollowToggle,
    this.annotationMode = false,
    this.showAnnotations = true,
    super.key,
  });

  final String pageLabel;
  final int pageNumber;
  final int pageCount;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onPagePicker;
  final ValueChanged<double> onPageScrub;
  final VoidCallback? onMetronome;
  final VoidCallback onAnnotations;
  final VoidCallback onSettings;
  final String? nextSongId;
  final VoidCallback? onNextSong;
  final bool hasAudio;
  final bool audioPlaying;
  final bool audioLoading;
  final VoidCallback? onToggleAudio;
  final bool metronomeRunning;
  final bool metronomeLoading;
  final bool showJamFollow;
  final bool jamFollowing;
  final VoidCallback? onJamFollowToggle;
  final bool annotationMode;
  final bool showAnnotations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxPage = pageCount < 1 ? 1 : pageCount;
    final value = pageNumber.clamp(1, maxPage).toDouble();

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kViewerChromeFill,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kViewerChromeBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CompactIconButton(
                    color: Colors.white,
                    tooltip: l10n.prevPage,
                    onPressed: onPrevPage,
                    icon: Icons.chevron_left_rounded,
                  ),
                  TextButton(
                    onPressed: onPagePicker,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(52, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      pageLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.2,
                        fontFamily: AppFonts.mono,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  CompactIconButton(
                    color: Colors.white,
                    tooltip: l10n.nextPage,
                    onPressed: onNextPage,
                    icon: Icons.chevron_right_rounded,
                  ),
                  const Spacer(),
                  if (nextSongId != null)
                    CompactIconButton(
                      color: Colors.white,
                      tooltip: l10n.nextSong,
                      onPressed: onNextSong,
                      icon: Icons.skip_next_rounded,
                    ),
                  if (hasAudio)
                    CompactIconButton(
                      color: Colors.white,
                      tooltip: audioPlaying ? l10n.pause : l10n.play,
                      selected: audioPlaying,
                      selectedColor: AppColors.accent,
                      onPressed: audioLoading ? null : onToggleAudio,
                      icon: audioPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  CompactIconButton(
                    color: Colors.white,
                    tooltip: metronomeRunning
                        ? l10n.metronomeStop
                        : l10n.metronome,
                    selected: metronomeRunning,
                    selectedColor: AppColors.accent,
                    onPressed: metronomeLoading ? null : onMetronome,
                    icon: Icons.speed_rounded,
                  ),
                  if (showJamFollow)
                    CompactIconButton(
                      color: Colors.white,
                      tooltip: jamFollowing
                          ? l10n.followConductor
                          : l10n.returnToLive,
                      onPressed: onJamFollowToggle,
                      icon: jamFollowing
                          ? Icons.sync_rounded
                          : Icons.play_circle_outline_rounded,
                    ),
                  if (showAnnotations)
                    CompactIconButton(
                      color: Colors.white,
                      tooltip: l10n.annotations,
                      selected: annotationMode,
                      selectedColor: AppColors.accent,
                      onPressed: onAnnotations,
                      icon: Icons.edit_note_rounded,
                    ),
                  CompactIconButton(
                    color: Colors.white,
                    tooltip: l10n.settings,
                    onPressed: onSettings,
                    icon: Icons.tune_rounded,
                  ),
                ],
              ),
              if (pageCount > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      min: 1,
                      max: maxPage.toDouble(),
                      divisions: maxPage - 1,
                      value: value,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.stageOutline,
                      onChanged: onPageScrub,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact page controls when full chrome is hidden.
class ViewerCollapsedPagePill extends StatelessWidget {
  const ViewerCollapsedPagePill({
    required this.pageLabel,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onPagePicker,
    super.key,
  });

  final String pageLabel;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;
  final VoidCallback onPagePicker;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 18),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kViewerChromeFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kViewerChromeBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CompactIconButton(
                  color: Colors.white,
                  tooltip: l10n.prevPage,
                  onPressed: onPrevPage,
                  icon: Icons.chevron_left_rounded,
                ),
                InkWell(
                  onTap: onPagePicker,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pageLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            fontFamily: AppFonts.mono,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CompactIconButton(
                  color: Colors.white,
                  tooltip: l10n.nextPage,
                  onPressed: onNextPage,
                  icon: Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live metronome readout while running.
class ViewerMetronomePill extends StatelessWidget {
  const ViewerMetronomePill({
    required this.bpm,
    required this.meterLabel,
    required this.beat,
    required this.isCountIn,
    required this.onTap,
    this.loading = false,
    super.key,
  });

  final int bpm;
  final String meterLabel;
  final int beat;
  final bool isCountIn;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.stageElevated.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: beat == 1
                      ? AppColors.accent
                      : AppColors.accent.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isCountIn
                    ? '$bpm · $meterLabel · C$beat'
                    : '$bpm · $meterLabel · $beat',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: AppFonts.mono,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toolbar while editing measure boxes.
class ViewerMeasureEditDock extends StatelessWidget {
  const ViewerMeasureEditDock({
    required this.hint,
    required this.onDone,
    this.hasSelection = false,
    this.onTempo,
    this.onTimeSignature,
    this.onSection,
    this.onDelete,
    super.key,
  });

  final String hint;
  final VoidCallback onDone;
  final bool hasSelection;
  final VoidCallback? onTempo;
  final VoidCallback? onTimeSignature;
  final VoidCallback? onSection;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kViewerChromeFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kViewerChromeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                CompactIconButton(
                  color: AppColors.accent,
                  tooltip: l10n.done,
                  onPressed: onDone,
                  icon: Icons.check_rounded,
                ),
              ],
            ),
            if (hasSelection) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  CompactIconButton(
                    color: Colors.white,
                    tooltip: l10n.tempo,
                    onPressed: onTempo,
                    icon: Icons.speed_rounded,
                  ),
                  CompactIconButton(
                    color: Colors.white,
                    tooltip: l10n.timeSignature,
                    onPressed: onTimeSignature,
                    icon: Icons.timelapse_rounded,
                  ),
                  CompactIconButton(
                    color: Colors.white,
                    tooltip: l10n.sectionLabel,
                    onPressed: onSection,
                    icon: Icons.label_outline_rounded,
                  ),
                  const Spacer(),
                  CompactIconButton(
                    color: Colors.white,
                    tooltip: l10n.deleteMeasure,
                    onPressed: onDelete,
                    icon: Icons.delete_outline_rounded,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
