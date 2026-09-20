import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

String playbackSectionLabel(AppLocalizations l10n, String section) {
  return switch (section) {
    'INTRO' => l10n.sectionIntro,
    'VERSE' => l10n.sectionVerse,
    'PRE' => l10n.sectionPre,
    'CHORUS' => l10n.sectionChorus,
    'BRIDGE' => l10n.sectionBridge,
    'OUTRO' => l10n.sectionOutro,
    _ => section,
  };
}

PlaybackSequence sequenceForMarkedSections(
  MusicScore score,
  PlaybackSequence current,
) {
  final sections = <String>[];
  for (final range in discoverScoreSections(score)) {
    if (!sections.contains(range.section)) {
      sections.add(range.section);
    }
  }
  final marked = sections.toSet();
  final retained = <PlaybackSequenceItem>[
    for (final item in current.items)
      if (marked.contains(item.section)) item,
  ];
  final represented = retained.map((item) => item.section).toSet();
  return PlaybackSequence([
    ...retained,
    for (final section in sections)
      if (!represented.contains(section))
        PlaybackSequenceItem(section: section),
  ]);
}

class ScoreStructurePanel extends StatelessWidget {
  const ScoreStructurePanel({
    required this.score,
    required this.sequence,
    required this.measureIndex,
    required this.onSectionChanged,
    required this.onRepeatsChanged,
    required this.onSectionMoved,
    required this.onSectionAdded,
    required this.onSectionRemoved,
    required this.onDone,
    super.key,
  });

  final MusicScore score;
  final PlaybackSequence sequence;
  final int measureIndex;
  final ValueChanged<String?> onSectionChanged;
  final void Function(int index, int repeats) onRepeatsChanged;
  final void Function(int fromIndex, int toIndex) onSectionMoved;
  final ValueChanged<String> onSectionAdded;
  final ValueChanged<int> onSectionRemoved;
  final VoidCallback onDone;

  MusicMeasure get _measure {
    return score.parts.first.measures[measureIndex];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final section = measurePlaybackSection(_measure);
    final marked = <String>[];
    for (final range in discoverScoreSections(score)) {
      if (!marked.contains(range.section)) {
        marked.add(range.section);
      }
    }

    return Material(
      color: AppColors.canvas,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.playbackSequence,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(onPressed: onDone, child: Text(l10n.done)),
                  ],
                ),
                Text(
                  l10n.playbackSequenceHelp,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      l10n.scoreSection,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: section ?? '__none__',
                        isDense: true,
                        items: [
                          DropdownMenuItem(
                            value: '__none__',
                            child: Text(l10n.none),
                          ),
                          for (final value in standardPlaybackSections)
                            DropdownMenuItem(
                              value: value,
                              child: Text(playbackSectionLabel(l10n, value)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          onSectionChanged(value == '__none__' ? null : value);
                        },
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: section == null
                        ? null
                        : () => onSectionAdded(section),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.addToPlaybackSequence),
                  ),
                ),
                if (marked.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.noSections,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedInk,
                      ),
                    ),
                  )
                else
                  for (var index = 0; index < sequence.items.length; index++)
                    _RepeatRow(
                      section: sequence.items[index].section,
                      repeats: sequence.items[index].repeats,
                      canMoveEarlier: index > 0,
                      canMoveLater: index < sequence.items.length - 1,
                      onMoveEarlier: () => onSectionMoved(index, index - 1),
                      onMoveLater: () => onSectionMoved(index, index + 1),
                      onRemove: () => onSectionRemoved(index),
                      onRepeatsChanged: (repeats) =>
                          onRepeatsChanged(index, repeats),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepeatRow extends StatelessWidget {
  const _RepeatRow({
    required this.section,
    required this.repeats,
    required this.canMoveEarlier,
    required this.canMoveLater,
    required this.onMoveEarlier,
    required this.onMoveLater,
    required this.onRemove,
    required this.onRepeatsChanged,
  });

  final String section;
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
        Expanded(child: Text(playbackSectionLabel(l10n, section))),
        IconButton(
          tooltip: l10n.repeatDown,
          onPressed: repeats <= minPlaybackRepeats
              ? null
              : () => onRepeatsChanged(repeats - 1),
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$repeats',
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
