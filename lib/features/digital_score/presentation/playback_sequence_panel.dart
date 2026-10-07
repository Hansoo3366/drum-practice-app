import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

String playbackSectionLabel(AppLocalizations l10n, String section) {
  return switch (section) {
    '' => l10n.sectionUnnamed,
    'INTRO' => l10n.sectionIntro,
    'VERSE' => l10n.sectionVerse,
    'PRE' => l10n.sectionPre,
    'CHORUS' => l10n.sectionChorus,
    'BRIDGE' => l10n.sectionBridge,
    'SOLO' => l10n.sectionSolo,
    'INTERLUDE' => l10n.sectionInterlude,
    'OUTRO' => l10n.sectionOutro,
    _ => section,
  };
}

/// "Verse 2" for the second section named Verse.
String scoreSectionLabel(AppLocalizations l10n, ScoreSection section) {
  final name = playbackSectionLabel(l10n, section.name);
  return section.number == null ? name : '$name ${section.number}';
}

/// "1:36" for a playback length in seconds.
String formatPlaybackLength(double seconds) {
  final total = seconds.round();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// The two steps of setting up a score's structure.
enum StructureTab { sections, order }

/// "Verse 2", or the bars ("8–10") of a section with no name.
String sectionDisplayName(
  AppLocalizations l10n,
  ScoreSection section, {
  int firstBarNumber = 1,
}) {
  return section.name.isEmpty
      ? l10n.barNumbers(_sectionBars(section, firstBarNumber))
      : scoreSectionLabel(l10n, section);
}

/// "5–10", or "0" for a section of one bar.
String _sectionBars(ScoreSection section, int firstBarNumber) => barRuns([
  for (
    var bar = section.startMeasureIndex;
    bar <= section.endMeasureIndex;
    bar++
  )
    bar,
], firstBarNumber: firstBarNumber);

/// Sections as the user named them: a piece split off where the written
/// order jumps (see [ScoreSection.continued]) joins the section before it.
List<List<ScoreSection>> namedSections(List<ScoreSection> sections) {
  final groups = <List<ScoreSection>>[];
  for (final section in sections) {
    if (section.continued && groups.isNotEmpty) {
      groups.last.add(section);
    } else {
      groups.add([section]);
    }
  }
  return groups;
}

/// The section a pick means, when it means one: the pick began on the bar
/// a named section starts at and was not drawn out to a later line. Naming
/// then renames that section; a pick elsewhere starts a new section.
ScoreSection? pickedSection(
  List<ScoreSection> sections,
  int? pickStart, {
  required bool extended,
}) {
  if (pickStart == null || extended) return null;
  for (final section in sections) {
    // A nameless stretch is not picked whole: tapping its first line picks
    // that line, to start dividing it.
    if (section.startMeasureIndex == pickStart && section.name.isNotEmpty) {
      return section;
    }
  }
  return null;
}

/// Divides the score into sections, then sets the playback order.
///
/// "Sections": tapping a staff line on the score picks it (a later line
/// extends the pick) and a name makes it a section. "Order": sections with
/// repeat counts, started from the written order, and a new score laid out
/// in that order. Every change is kept at once; undo steps back.
class ScoreStructurePanel extends StatelessWidget {
  const ScoreStructurePanel({
    required this.tab,
    required this.onTabChanged,
    required this.sequence,
    required this.sections,
    required this.selectedBar,
    this.selectedEnd,
    this.picking = false,
    required this.summary,
    required this.canUndo,
    required this.onUndo,
    required this.onClose,
    this.onCancelPick,
    required this.onSectionNamed,
    required this.onCustomSection,
    required this.onBoundaryRemoved,
    required this.onStepsChanged,
    this.onBuildFromScore,
    this.madeScoreExists = false,
    this.onMakeScore,
    this.firstBarNumber = 1,
    this.stepBars = const [],
    super.key,
  });

  /// The number of the score's first bar ([MusicScore.firstBarNumber]).
  final int firstBarNumber;

  /// The bars each step of [sequence] plays (see `playbackStepBars`).
  final List<List<int>> stepBars;

  /// The bars step [index] plays, as runs, when it is played once and its
  /// bars are known.
  String? _played(int index) {
    if (index >= stepBars.length || stepBars[index].isEmpty) return null;
    if (sequence.steps[index].repeats != 1) return null;
    return barRuns(stepBars[index], firstBarNumber: firstBarNumber);
  }

  final StructureTab tab;
  final ValueChanged<StructureTab> onTabChanged;
  final PlaybackSequence sequence;
  final List<ScoreSection> sections;
  final int? selectedBar;

  /// Last bar of a picked range (a later line), or null.
  final int? selectedEnd;

  /// True while bars are being picked, before a name is chosen.
  final bool picking;
  final ({int measures, int writtenMeasures, String time, int skipped}) summary;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onClose;

  /// Takes the pick back without changing anything.
  final VoidCallback? onCancelPick;

  /// A name for the picked bars; an empty name takes a section's name away
  /// (the selected chip tapped again).
  final ValueChanged<String> onSectionNamed;
  final VoidCallback onCustomSection;
  final VoidCallback onBoundaryRemoved;
  final ValueChanged<List<PlaybackStep>> onStepsChanged;

  /// Starts a custom order that plays what the written repeats and jumps
  /// play; without it the order lists each section once.
  final VoidCallback? onBuildFromScore;

  /// True when a score was already made from this version in this order.
  final bool madeScoreExists;

  /// Makes (or opens) the score laid out in this order.
  final VoidCallback? onMakeScore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return Material(
      color: AppColors.canvas,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            // Picking lines needs the score; the order needs the list.
            constraints: BoxConstraints(
              maxHeight: height * (tab == StructureTab.sections ? 0.3 : 0.45),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SegmentedButton<StructureTab>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                            ),
                            segments: [
                              ButtonSegment(
                                value: StructureTab.sections,
                                icon: const Icon(Icons.view_agenda_outlined),
                                label: Text(l10n.structureTabSections),
                              ),
                              ButtonSegment(
                                value: StructureTab.order,
                                icon: const Icon(Icons.format_list_numbered),
                                label: Text(l10n.structureTabOrder),
                              ),
                            ],
                            selected: {tab},
                            onSelectionChanged: (value) =>
                                onTabChanged(value.single),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.undo,
                        onPressed: canUndo ? onUndo : null,
                        icon: const Icon(Icons.undo_rounded),
                      ),
                      TextButton(onPressed: onClose, child: Text(l10n.close)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: tab == StructureTab.sections
                        ? _sectionsTab(context, l10n, theme)
                        : _orderTab(context, l10n, theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionsTab(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final bar = selectedBar;
    ScoreSection? current;
    for (final section in sections) {
      if (section.startMeasureIndex == bar) current = section;
    }
    final startsHere = selectedEnd == null && current != null;
    // A section starting here can still be renamed or merged.
    final named = startsHere && current.name.isNotEmpty ? current.name : null;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.mutedInk,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                bar == null
                    ? l10n.sectionStartHint
                    : selectedEnd != null
                    ? l10n.sectionRange(
                        bar + firstBarNumber,
                        selectedEnd! + firstBarNumber,
                      )
                    : picking || current == null
                    ? l10n.sectionBarPickEnd(bar + firstBarNumber)
                    : [
                        scoreSectionLabel(l10n, current),
                        l10n.barNumbers(_sectionBars(current, firstBarNumber)),
                      ].join(' · '),
                style: bar == null ? muted : theme.textTheme.titleSmall,
              ),
            ),
            if (bar != null && onCancelPick != null)
              TextButton(
                onPressed: onCancelPick,
                child: Text(l10n.sectionCancelPick),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in standardPlaybackSections)
              ChoiceChip(
                label: Text(playbackSectionLabel(l10n, value)),
                selected: named == value,
                // Tapped again, the name comes off: the bars stay a section.
                onSelected: bar == null
                    ? null
                    : (_) => onSectionNamed(named == value ? '' : value),
              ),
            ActionChip(
              avatar: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.sectionCustom),
              onPressed: bar == null ? null : onCustomSection,
            ),
            if (startsHere && current.startMeasureIndex > 0)
              ActionChip(
                avatar: const Icon(Icons.merge_rounded, size: 18),
                label: Text(l10n.sectionRemoveBoundary),
                onPressed: onBoundaryRemoved,
              ),
          ],
        ),
      ],
    );
  }

  Widget _orderTab(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.mutedInk,
    );
    final byId = {for (final section in sections) section.id: section};
    final steps = sequence.steps;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          [
            l10n.playbackSummary(summary.measures, summary.time),
            if (summary.skipped > 0) l10n.playbackSkipped(summary.skipped),
          ].join(' · '),
          style: muted,
        ),
        const SizedBox(height: 4),
        if (sections.isEmpty)
          Text(l10n.noSections, style: muted)
        else if (steps.isEmpty) ...[
          Text(l10n.playbackAsWritten, style: muted),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed:
                  onBuildFromScore ??
                  () => onStepsChanged([
                    for (final section in sections)
                      PlaybackStep(sectionId: section.id),
                  ]),
              icon: const Icon(Icons.playlist_add_rounded),
              label: Text(l10n.buildOrderFromSections),
            ),
          ),
        ] else
          for (var index = 0; index < steps.length; index++)
            if (byId[steps[index].sectionId] case final section?)
              _StepRow(
                // A split piece right after the piece before it reads as
                // that section going on.
                continues:
                    section.continued &&
                    index > 0 &&
                    byId[steps[index - 1].sectionId]?.endMeasureIndex ==
                        section.startMeasureIndex - 1,
                // The bars the step really plays, where they are known:
                // once through a first ending is "5–9", through the second
                // "5–7, 10". A step played several times says its section.
                label: section.name.isEmpty && _played(index) != null
                    ? l10n.barNumbers(_played(index)!)
                    : sectionDisplayName(
                        l10n,
                        section,
                        firstBarNumber: firstBarNumber,
                      ),
                bars: [
                  if (section.name.isNotEmpty || section.continued)
                    l10n.barNumbers(
                      _played(index) ?? _sectionBars(section, firstBarNumber),
                    ),
                  if (_played(index) == null)
                    if (steps[index] case PlaybackStep(
                      repeats: 1,
                      :final pass?,
                    ) when pass > 0)
                      l10n.endingPass(pass),
                ].join(' · '),
                repeats: steps[index].repeats,
                canMoveEarlier: index > 0,
                canMoveLater: index < steps.length - 1,
                onMoveEarlier: () => _moveStep(index, index - 1),
                onMoveLater: () => _moveStep(index, index + 1),
                onRemove: () => _changeStep(index, null),
                onRepeatsChanged: (repeats) =>
                    _changeStep(index, steps[index].copyWith(repeats: repeats)),
              ),
        if (sections.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.addToPlaybackSequence,
                style: theme.textTheme.bodyMedium,
              ),
              for (final group in namedSections(sections))
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    sectionDisplayName(
                      l10n,
                      group.first,
                      firstBarNumber: firstBarNumber,
                    ),
                  ),
                  onPressed: () => onStepsChanged([
                    ...steps,
                    for (final piece in group)
                      PlaybackStep(sectionId: piece.id),
                  ]),
                ),
            ],
          ),
        ],
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onMakeScore,
            icon: Icon(
              madeScoreExists
                  ? Icons.open_in_new_rounded
                  : Icons.library_add_outlined,
            ),
            label: Text(
              madeScoreExists
                  ? l10n.openScoreFromOrder
                  : l10n.makeScoreFromOrder,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.scoreFromOrderKeepsThis,
            style: muted,
            textAlign: TextAlign.center,
          ),
          Align(
            child: TextButton.icon(
              onPressed: () => onStepsChanged(const []),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(l10n.resetPlaybackOrder),
            ),
          ),
        ],
      ],
    );
  }

  void _changeStep(int index, PlaybackStep? step) {
    final steps = sequence.steps.toList();
    if (step == null) {
      steps.removeAt(index);
    } else {
      steps[index] = step;
    }
    onStepsChanged(steps);
  }

  void _moveStep(int from, int to) {
    final steps = sequence.steps.toList();
    steps.insert(to, steps.removeAt(from));
    onStepsChanged(steps);
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    this.continues = false,
    required this.label,
    required this.bars,
    required this.repeats,
    required this.canMoveEarlier,
    required this.canMoveLater,
    required this.onMoveEarlier,
    required this.onMoveLater,
    required this.onRemove,
    required this.onRepeatsChanged,
  });

  /// Shown as the section before it going on: indented, bars only.
  final bool continues;
  final String label;
  final String bars;
  final int repeats;
  final bool canMoveEarlier;
  final bool canMoveLater;
  final VoidCallback onMoveEarlier;
  final VoidCallback onMoveLater;
  final VoidCallback onRemove;
  final ValueChanged<int> onRepeatsChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: l10n.moveSectionEarlier,
          onPressed: canMoveEarlier ? onMoveEarlier : null,
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        IconButton(
          tooltip: l10n.moveSectionLater,
          onPressed: canMoveLater ? onMoveLater : null,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        Expanded(
          child: continues
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '↳ $bars',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedInk,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (bars.isNotEmpty)
                      Text(
                        bars,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                      ),
                  ],
                ),
        ),
        IconButton(
          tooltip: l10n.repeatDown,
          onPressed: repeats <= minPlaybackRepeats
              ? null
              : () => onRepeatsChanged(repeats - 1),
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 36,
          child: Text(
            l10n.repeatTimes(repeats),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.mono,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.repeatUp,
          onPressed: repeats >= maxPlaybackRepeats
              ? null
              : () => onRepeatsChanged(repeats + 1),
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: l10n.removeFromPlaybackSequence,
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}
