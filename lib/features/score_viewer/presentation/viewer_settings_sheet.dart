import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';

/// Snapshot of viewer settings sheet display state.
class ViewerSettingsSnapshot {
  const ViewerSettingsSnapshot({
    required this.hasAudio,
    required this.audioPlaying,
    required this.audioSpeedLabel,
    required this.metronomeRunning,
    required this.metronomeSubtitle,
    required this.canLoop,
    required this.loopLabel,
    required this.viewModeLabel,
    required this.hasMeasures,
    required this.autoPaused,
    required this.progressSubtitle,
    required this.showJamFollow,
    required this.jamFollowing,
    required this.jamFollowSubtitle,
    required this.currentMeasureLabel,
    required this.nextSongId,
    required this.canSyncAnchor,
    required this.anchorsLabel,
    required this.pedalLabel,
    required this.practiceLabel,
    required this.cuesLabel,
    required this.hardMeasuresLabel,
    required this.annotationsVisible,
    required this.hasAnnotationStrokes,
    required this.statusBarVisible,
    required this.annotationMode,
    this.canAnnotate = true,
  });

  final bool hasAudio;
  final bool audioPlaying;
  final String audioSpeedLabel;
  final bool metronomeRunning;
  final String metronomeSubtitle;
  final bool canLoop;
  final String loopLabel;
  final String viewModeLabel;
  final bool hasMeasures;
  final bool autoPaused;
  final String progressSubtitle;
  final bool showJamFollow;
  final bool jamFollowing;
  final String jamFollowSubtitle;
  final String currentMeasureLabel;
  final String? nextSongId;
  final bool canSyncAnchor;
  final String anchorsLabel;
  final String pedalLabel;
  final String practiceLabel;
  final String cuesLabel;
  final String hardMeasuresLabel;
  final bool annotationsVisible;
  final bool hasAnnotationStrokes;
  final bool statusBarVisible;
  final bool annotationMode;
  final bool canAnnotate;
}

/// Callbacks for [ViewerSettingsSheet] actions.
class ViewerSettingsActions {
  const ViewerSettingsActions({
    required this.onMusic,
    required this.onMetronome,
    required this.onViewMode,
    required this.onAnnotations,
    required this.onPlaybackSpeed,
    required this.onLoop,
    required this.onAutoAdvance,
    required this.onJamFollow,
    required this.onCurrentMeasure,
    required this.onNextSong,
    required this.onSyncAnchor,
    required this.onPedal,
    required this.onPracticeLog,
    required this.onCues,
    required this.onHardMeasures,
    required this.onAnnotationsVisible,
    required this.onClearAnnotations,
    required this.onStatusBar,
  });

  final VoidCallback onMusic;
  final VoidCallback onMetronome;
  final VoidCallback onViewMode;
  final VoidCallback onAnnotations;
  final VoidCallback onPlaybackSpeed;
  final VoidCallback onLoop;
  final VoidCallback onAutoAdvance;
  final VoidCallback onJamFollow;
  final VoidCallback onCurrentMeasure;
  final ValueChanged<String> onNextSong;
  final VoidCallback onSyncAnchor;
  final VoidCallback onPedal;
  final VoidCallback onPracticeLog;
  final VoidCallback onCues;
  final VoidCallback onHardMeasures;
  final ValueChanged<bool> onAnnotationsVisible;
  final VoidCallback onClearAnnotations;
  final VoidCallback onStatusBar;
}

/// Score viewer settings bottom sheet body.
class ViewerSettingsSheet extends StatelessWidget {
  const ViewerSettingsSheet({
    required this.snapshot,
    required this.actions,
    super.key,
  });

  final ViewerSettingsSnapshot snapshot;
  final ViewerSettingsActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = snapshot;
    final a = actions;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.scoreSettings,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 36,
                height: 3,
                child: ColoredBox(color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SettingsQuickAction(
                    icon: Icons.music_note_rounded,
                    label: l10n.music,
                    emphasized: s.hasAudio && s.audioPlaying,
                    onTap: a.onMusic,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SettingsQuickAction(
                    icon: Icons.speed_rounded,
                    label: l10n.metronome,
                    emphasized: s.metronomeRunning,
                    onTap: a.onMetronome,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SettingsQuickAction(
                    icon: Icons.view_quilt_rounded,
                    label: l10n.view,
                    onTap: a.onViewMode,
                  ),
                ),
                if (s.canAnnotate) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SettingsQuickAction(
                      icon: Icons.edit_note_rounded,
                      label: l10n.annotations,
                      emphasized: s.annotationMode,
                      onTap: a.onAnnotations,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (s.hasAudio || s.canLoop)
              SettingsExpansionGroup(
                title: l10n.playback,
                initiallyExpanded: true,
                foregroundColor: AppColors.canvas,
                mutedColor: AppColors.stageMuted,
                children: [
                  if (s.hasAudio)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.slow_motion_video_rounded,
                        color: Colors.white,
                      ),
                      title: Text(
                        l10n.playbackSpeed,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        s.audioSpeedLabel,
                        style: const TextStyle(color: AppColors.stageMuted),
                      ),
                      onTap: a.onPlaybackSpeed,
                    ),
                  if (s.canLoop)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.repeat_rounded,
                        color: Colors.white,
                      ),
                      title: Text(
                        l10n.loopSection,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        s.loopLabel,
                        style: const TextStyle(color: AppColors.stageMuted),
                      ),
                      onTap: a.onLoop,
                    ),
                ],
              ),
            SettingsExpansionGroup(
              title: l10n.progress,
              initiallyExpanded: true,
              foregroundColor: AppColors.canvas,
              mutedColor: AppColors.stageMuted,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.view_quilt_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    l10n.pageLayout,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    s.viewModeLabel,
                    style: const TextStyle(color: AppColors.stageMuted),
                  ),
                  onTap: a.onViewMode,
                ),
                if (s.hasMeasures)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      s.autoPaused
                          ? Icons.play_circle_outline_rounded
                          : Icons.track_changes_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      l10n.autoAdvance,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      s.progressSubtitle,
                      style: const TextStyle(color: AppColors.stageMuted),
                    ),
                    onTap: a.onAutoAdvance,
                  ),
                if (s.showJamFollow)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      s.jamFollowing
                          ? Icons.sync_rounded
                          : Icons.play_circle_outline_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      l10n.followConductor,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      s.jamFollowSubtitle,
                      style: const TextStyle(color: AppColors.stageMuted),
                    ),
                    onTap: a.onJamFollow,
                  ),
                if (s.hasMeasures)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.highlight_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      l10n.currentMeasure,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      s.currentMeasureLabel,
                      style: const TextStyle(color: AppColors.stageMuted),
                    ),
                    onTap: a.onCurrentMeasure,
                  ),
                if (s.nextSongId case final nextSongId?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.skip_next_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      l10n.nextSong,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => a.onNextSong(nextSongId),
                  ),
              ],
            ),
            SettingsExpansionGroup(
              title: l10n.practiceSync,
              foregroundColor: AppColors.canvas,
              mutedColor: AppColors.stageMuted,
              children: [
                if (s.canSyncAnchor)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.sync_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      l10n.syncAnchor,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      s.anchorsLabel,
                      style: const TextStyle(color: AppColors.stageMuted),
                    ),
                    onTap: a.onSyncAnchor,
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.keyboard_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    l10n.pedal,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    s.pedalLabel,
                    style: const TextStyle(color: AppColors.stageMuted),
                  ),
                  onTap: a.onPedal,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.history_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    l10n.practiceLog,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    s.practiceLabel,
                    style: const TextStyle(color: AppColors.stageMuted),
                  ),
                  onTap: a.onPracticeLog,
                ),
                if (s.hasMeasures)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.bookmark_outline_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      l10n.cue,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      s.cuesLabel,
                      style: const TextStyle(color: AppColors.stageMuted),
                    ),
                    onTap: a.onCues,
                  ),
                if (s.hasMeasures)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      l10n.hardMeasures,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      s.hardMeasuresLabel,
                      style: const TextStyle(color: AppColors.stageMuted),
                    ),
                    onTap: a.onHardMeasures,
                  ),
              ],
            ),
            SettingsExpansionGroup(
              title: l10n.display,
              foregroundColor: AppColors.canvas,
              mutedColor: AppColors.stageMuted,
              children: [
                if (s.canAnnotate) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.notes_rounded,
                      color: Colors.white,
                    ),
                    title: Text(
                      l10n.showAnnotations,
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: s.annotationsVisible,
                    onChanged: a.onAnnotationsVisible,
                  ),
                  if (s.hasAnnotationStrokes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.delete_sweep_outlined,
                        color: Colors.white,
                      ),
                      title: Text(
                        l10n.clearAnnotations,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: a.onClearAnnotations,
                    ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.stay_current_portrait_rounded,
                    color: Colors.white,
                  ),
                  title: Text(
                    l10n.statusBar,
                    style: const TextStyle(color: Colors.white),
                  ),
                  value: s.statusBarVisible,
                  onChanged: (_) => a.onStatusBar(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
