import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/sheet_insets.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';

String arrangementStyleLabel(AppLocalizations l10n, ArrangementStyle style) {
  return switch (style) {
    ArrangementStyle.off => l10n.arrangementOff,
    ArrangementStyle.block => l10n.arrangementBlock,
    ArrangementStyle.pulse => l10n.arrangementPulse,
    ArrangementStyle.broken => l10n.arrangementBroken,
  };
}

Future<ArrangementProfile?> showArrangementSheet(
  BuildContext context, {
  required ArrangementProfile profile,
  MusicScore? score,
}) {
  return showModalBottomSheet<ArrangementProfile>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ArrangementSheet(initial: profile, score: score),
  );
}

class _ArrangementSheet extends StatefulWidget {
  const _ArrangementSheet({required this.initial, this.score});

  final ArrangementProfile initial;
  final MusicScore? score;

  @override
  State<_ArrangementSheet> createState() => _ArrangementSheetState();
}

class _ArrangementSheetState extends State<_ArrangementSheet> {
  late ArrangementStyle _style;

  @override
  void initState() {
    super.initState();
    _style = widget.initial.style;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasHarmony = widget.score == null || scoreHasHarmony(widget.score!);
    return Padding(
      padding: sheetContentPadding(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.scoreArrangement,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: l10n.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.arrangementHint,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
            ),
          ),
          const SizedBox(height: 8),
          if (!hasHarmony)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.noHarmony,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedInk),
              ),
            )
          else
            for (final style in ArrangementStyle.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(arrangementStyleLabel(l10n, style)),
                selected: _style == style,
                selectedColor: AppColors.accent,
                onTap: () => setState(() => _style = style),
              ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () =>
                  Navigator.pop(context, ArrangementProfile(style: _style)),
              child: Text(l10n.done),
            ),
          ),
        ],
      ),
    );
  }
}
