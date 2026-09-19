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
  final repeats = {
    for (final item in current.items) item.section: item.repeats,
  };
  final sections = <String>[];
  for (final range in discoverScoreSections(score)) {
    if (!sections.contains(range.section)) {
      sections.add(range.section);
    }
  }
  return PlaybackSequence([
    for (final section in sections)
      PlaybackSequenceItem(section: section, repeats: repeats[section] ?? 1),
  ]);
}

class ScoreStructurePanel extends StatelessWidget {
  const ScoreStructurePanel({
    required this.score,
    required this.sequence,
    required this.measureIndex,
    required this.onSectionChanged,
    required this.onRepeatsChanged,
    required this.onInsertMeasure,
    super.key,
  });

  final MusicScore score;
  final PlaybackSequence sequence;
  final int measureIndex;
  final ValueChanged<String?> onSectionChanged;
  final void Function(String section, int repeats) onRepeatsChanged;
  final VoidCallback onInsertMeasure;

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
                Text(
                  l10n.playbackSequenceHelp,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
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
                    onPressed: onInsertMeasure,
                    icon: const Icon(Icons.add_box_outlined),
                    label: Text(l10n.insertMeasureAfter),
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
                  for (final value in marked)
                    _RepeatRow(
                      section: value,
                      repeats: _repeatsFor(sequence, value),
                      onRepeatsChanged: (repeats) {
                        onRepeatsChanged(value, repeats);
                      },
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _repeatsFor(PlaybackSequence sequence, String section) {
  for (final item in sequence.items) {
    if (item.section == section) return item.repeats;
  }
  return 1;
}

class _RepeatRow extends StatelessWidget {
  const _RepeatRow({
    required this.section,
    required this.repeats,
    required this.onRepeatsChanged,
  });

  final String section;
  final int repeats;
  final ValueChanged<int> onRepeatsChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
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
      ],
    );
  }
}
