import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/features/tools/data/metronome_settings.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';
import 'package:page_a_diddle/features/tools/presentation/metronome_subdivision_icon.dart';

List<MetronomeAccentLevel> accentsForMeter(
  MetronomeMeter meter,
  List<MetronomeAccentLevel> current,
) {
  return List.generate(
    meter.numerator,
    (index) => index < current.length
        ? current[index]
        : index == 0
        ? MetronomeAccentLevel.strong
        : MetronomeAccentLevel.normal,
  );
}

/// Shared metronome options used by the metronome and tempo trainer.
Future<void> showMetronomeSettingsSheet({
  required BuildContext context,
  required MetronomeSettings initial,
  required ValueChanged<MetronomeSettings> onChanged,
  bool enabled = true,
  List<Widget>? leading,
  String? title,
  String? subtitle,
}) {
  final bpmController = TextEditingController(text: '${initial.bpm}');
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.stageElevated,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      var settings = initial;
      return Theme(
        data: AppTheme.stage,
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              void apply(MetronomeSettings next) {
                settings = next;
                bpmController.value = TextEditingValue(
                  text: '${next.bpm}',
                  selection: TextSelection.collapsed(
                    offset: '${next.bpm}'.length,
                  ),
                );
                onChanged(next);
                setSheetState(() {});
              }

              void commitBpm(String raw) {
                final value = int.tryParse(raw);
                if (value == null) {
                  bpmController.text = '${settings.bpm}';
                  return;
                }
                apply(settings.copyWith(bpm: value.clamp(40, 240).toInt()));
              }

              final l10n = context.l10n;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title ?? l10n.settings,
                        style: const TextStyle(
                          color: AppColors.canvas,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle case final subtitleText?) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitleText,
                          style: const TextStyle(
                            color: AppColors.stageMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (leading case final leadingWidgets?) ...[
                        const SizedBox(height: 16),
                        ...leadingWidgets,
                        const SizedBox(height: 8),
                      ] else
                        const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: l10n.bpmDown,
                            color: AppColors.canvas,
                            onPressed: enabled
                                ? () => apply(
                                    settings.copyWith(
                                      bpm: (settings.bpm - 1)
                                          .clamp(40, 240)
                                          .toInt(),
                                    ),
                                  )
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          SizedBox(
                            width: 132,
                            height: 48,
                            child: TextField(
                              controller: bpmController,
                              enabled: enabled,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.canvas,
                                fontFamily: AppFonts.mono,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                suffixText: 'BPM',
                                suffixStyle: TextStyle(
                                  color: AppColors.stageMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              onSubmitted: commitBpm,
                              onEditingComplete: () =>
                                  commitBpm(bpmController.text),
                              onTapOutside: (_) =>
                                  commitBpm(bpmController.text),
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.bpmUp,
                            color: AppColors.canvas,
                            onPressed: enabled
                                ? () => apply(
                                    settings.copyWith(
                                      bpm: (settings.bpm + 1)
                                          .clamp(40, 240)
                                          .toInt(),
                                    ),
                                  )
                                : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CompactOptionTile(
                        label: l10n.meter,
                        value: settings.meter.label,
                        enabled: enabled,
                        foregroundColor: AppColors.canvas,
                        mutedColor: AppColors.stageMuted,
                        onTap: () async {
                          final selected =
                              await showOptionPickerSheet<MetronomeMeter>(
                                context: context,
                                title: l10n.meter,
                                options: metronomeMeters,
                                labelOf: (meter) => meter.label,
                                selected: settings.meter,
                                backgroundColor: AppColors.stageElevated,
                                foregroundColor: AppColors.canvas,
                                mutedColor: AppColors.stageMuted,
                              );
                          if (selected == null) {
                            return;
                          }
                          apply(
                            settings.copyWith(
                              meter: selected,
                              accents: accentsForMeter(
                                selected,
                                settings.accents,
                              ),
                            ),
                          );
                        },
                      ),
                      CompactOptionTile(
                        label: l10n.countIn,
                        value: metronomeCountInLabel(
                          settings.countInBars,
                          l10n,
                        ),
                        enabled: enabled,
                        foregroundColor: AppColors.canvas,
                        mutedColor: AppColors.stageMuted,
                        onTap: () async {
                          final selected = await showOptionPickerSheet<int>(
                            context: context,
                            title: l10n.countIn,
                            options: metronomeCountInBarOptions,
                            labelOf: (bars) =>
                                metronomeCountInLabel(bars, l10n),
                            selected: settings.countInBars,
                            backgroundColor: AppColors.stageElevated,
                            foregroundColor: AppColors.canvas,
                            mutedColor: AppColors.stageMuted,
                          );
                          if (selected == null) {
                            return;
                          }
                          apply(settings.copyWith(countInBars: selected));
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.haptics,
                          style: const TextStyle(
                            color: AppColors.canvas,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        value: settings.haptics,
                        activeThumbColor: AppColors.accent,
                        onChanged: enabled
                            ? (value) =>
                                  apply(settings.copyWith(haptics: value))
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.beatUnit,
                        style: const TextStyle(
                          color: AppColors.stageMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final subdivision in MetronomeSubdivision.values)
                            IconButton(
                              onPressed: enabled
                                  ? () => apply(
                                      settings.copyWith(
                                        subdivision: subdivision,
                                      ),
                                    )
                                  : null,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    settings.subdivision == subdivision
                                    ? AppColors.accent.withValues(alpha: 0.22)
                                    : AppColors.stagePanel,
                                foregroundColor:
                                    settings.subdivision == subdivision
                                    ? AppColors.accent
                                    : AppColors.stageMuted,
                              ),
                              icon: MetronomeSubdivisionIcon(
                                subdivision: subdivision,
                                color: settings.subdivision == subdivision
                                    ? AppColors.accent
                                    : AppColors.stageMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.accent,
                        style: const TextStyle(
                          color: AppColors.stageMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (
                            var beat = 1;
                            beat <= settings.meter.numerator;
                            beat++
                          )
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: enabled
                                  ? () {
                                      final pattern = List.of(settings.accents);
                                      pattern[beat - 1] =
                                          pattern[beat - 1].next;
                                      apply(
                                        settings.copyWith(accents: pattern),
                                      );
                                    }
                                  : null,
                              child: Container(
                                width: 44,
                                height: 56,
                                alignment: Alignment.bottomCenter,
                                decoration: BoxDecoration(
                                  color: AppColors.stagePanel,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.stageOutline,
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (settings.accents[beat - 1] !=
                                        MetronomeAccentLevel.mute)
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: FractionallySizedBox(
                                          heightFactor:
                                              settings.accents[beat - 1] ==
                                                  MetronomeAccentLevel.strong
                                              ? 1
                                              : 0.5,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: AppColors.accent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text(
                                          '$beat',
                                          style: const TextStyle(
                                            color: AppColors.canvas,
                                            fontFamily: AppFonts.mono,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  ).whenComplete(bpmController.dispose);
}
