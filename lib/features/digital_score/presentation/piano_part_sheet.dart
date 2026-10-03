import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/sheet_insets.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_advice.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';

/// How the piano part is to be made: its style, and the chord symbols the
/// user agreed to change first.
class PianoPartRequest {
  const PianoPartRequest({
    required this.plan,
    this.instruments = const [AccompanimentInstrument.piano],
    this.roles = const {},
    this.density = AccompanimentDensity.normal,
    this.splitPoint,
    this.separate = true,
    this.corrections = const [],
  });

  /// The parts to make, in score order.
  final List<AccompanimentInstrument> instruments;

  /// How the piano plays, when it is among them.
  final AccompanimentPlan plan;

  /// What each stretch of the song is, by first bar.
  final Map<int, SectionRole> roles;
  final AccompanimentDensity density;

  /// Lowest note of the piano's right hand, or null for the register's own.
  final int? splitPoint;

  /// One score per instrument (the melody with that part under it), or all
  /// the parts under the melody in one score.
  final bool separate;
  final List<ChordCorrection> corrections;

  AccompanimentSetup get setup => _setup(instruments);

  /// The setup of the score for [instrument] alone.
  AccompanimentSetup setupFor(AccompanimentInstrument instrument) =>
      _setup([instrument]);

  AccompanimentSetup _setup(List<AccompanimentInstrument> parts) =>
      AccompanimentSetup(
        instruments: parts,
        piano: plan,
        roles: roles,
        density: density,
        splitPoint: splitPoint,
      );
}

/// Asks for the style of the piano part. [advise] fetches a recommendation
/// (a style per section, chord symbols to look at again); it throws when no
/// recommendation can be had.
///
/// [initial] is the style the sheet opens with: that of the piano part the
/// score already has, when it is made again. [roles] are the sections of
/// the score as the structure panel names them; a recommendation may read
/// them differently.
Future<PianoPartRequest?> showPianoPartSheet(
  BuildContext context, {
  required Future<ArrangementAdvice> Function() advise,
  AccompanimentSetup initial = const AccompanimentSetup(),
  Map<int, SectionRole> roles = const {},
  int firstBarNumber = 1,
}) {
  return showModalBottomSheet<PianoPartRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _PianoPartSheet(
      advise: advise,
      initial: initial,
      roles: roles,
      firstBarNumber: firstBarNumber,
    ),
  );
}

String accompanimentInstrumentLabel(
  AppLocalizations l10n,
  AccompanimentInstrument instrument,
) => switch (instrument) {
  AccompanimentInstrument.piano => l10n.pianoPartName,
  AccompanimentInstrument.organ => l10n.organPartName,
  AccompanimentInstrument.strings => l10n.stringsPartName,
  AccompanimentInstrument.pad => l10n.padPartName,
  AccompanimentInstrument.brass => l10n.brassPartName,
};

String accompanimentPatternLabel(
  AppLocalizations l10n,
  AccompanimentPattern pattern,
) => switch (pattern) {
  AccompanimentPattern.auto => l10n.pianoPatternAuto,
  AccompanimentPattern.held => l10n.pianoPatternHeld,
  AccompanimentPattern.beats => l10n.pianoPatternBeats,
  AccompanimentPattern.broken => l10n.pianoPatternBroken,
};

String accompanimentRegisterLabel(
  AppLocalizations l10n,
  AccompanimentRegister register,
) => switch (register) {
  AccompanimentRegister.middle => l10n.pianoRegisterMiddle,
  AccompanimentRegister.low => l10n.pianoRegisterLow,
};

class _PianoPartSheet extends StatefulWidget {
  const _PianoPartSheet({
    required this.advise,
    required this.initial,
    required this.roles,
    required this.firstBarNumber,
  });

  final Future<ArrangementAdvice> Function() advise;
  final AccompanimentSetup initial;
  final Map<int, SectionRole> roles;

  /// The number of the score's first bar ([MusicScore.firstBarNumber]).
  final int firstBarNumber;

  @override
  State<_PianoPartSheet> createState() => _PianoPartSheetState();
}

class _PianoPartSheetState extends State<_PianoPartSheet> {
  late final _instruments = widget.initial.instruments.toSet();
  late var _roles = widget.initial.roles.isNotEmpty
      ? Map.of(widget.initial.roles)
      : Map.of(widget.roles);
  var _separate = true;
  late var _density = widget.initial.density;
  late var _split = widget.initial.splitPoint;
  late var _base = widget.initial.piano.base;
  late var _sections = Map.of(widget.initial.piano.sections);
  var _corrections = <ChordCorrection>[];
  final _accepted = <ChordCorrection>{};
  var _note = '';
  var _asking = false;
  var _failed = false;
  var _advised = false;

  Future<void> _ask() async {
    setState(() {
      _asking = true;
      _failed = false;
    });
    try {
      final advice = await widget.advise();
      if (!mounted) return;
      setState(() {
        _base = advice.plan.base;
        _sections = Map.of(advice.plan.sections);
        // The recommendation reads the song's sections for itself.
        _roles = {..._roles, ...advice.roles};
        _corrections = advice.corrections;
        _accepted.clear();
        _note = advice.note;
        _advised = true;
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.mutedInk,
    );
    final starts = _sections.keys.toList()..sort();
    return Padding(
      padding: sheetContentPadding(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.makeThreeStaff,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.accompanimentInstruments,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final instrument in AccompanimentInstrument.values)
                  FilterChip(
                    label: Text(accompanimentInstrumentLabel(l10n, instrument)),
                    selected: _instruments.contains(instrument),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _instruments.add(instrument);
                      } else {
                        _instruments.remove(instrument);
                      }
                    }),
                  ),
              ],
            ),
            if (_instruments.length > 1) ...[
              const SizedBox(height: 16),
              Text(l10n.accompanimentOutput, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.accompanimentSeparateScores),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.accompanimentOneScore),
                  ),
                ],
                selected: {_separate},
                onSelectionChanged: (value) =>
                    setState(() => _separate = value.single),
              ),
            ],
            const SizedBox(height: 16),
            Text(l10n.accompanimentDensity, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<AccompanimentDensity>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: AccompanimentDensity.light,
                  label: Text(l10n.accompanimentDensityLight),
                ),
                ButtonSegment(
                  value: AccompanimentDensity.normal,
                  label: Text(l10n.accompanimentDensityNormal),
                ),
                ButtonSegment(
                  value: AccompanimentDensity.full,
                  label: Text(l10n.accompanimentDensityFull),
                ),
              ],
              selected: {_density},
              onSelectionChanged: (value) =>
                  setState(() => _density = value.single),
            ),
            // Pattern, register and split point are the piano's.
            if (_instruments.contains(AccompanimentInstrument.piano)) ...[
              const SizedBox(height: 16),
              Text(l10n.pianoSplitPoint, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  // 0 stands for "by the register".
                  ButtonSegment(value: 0, label: Text(l10n.pianoSplitAuto)),
                  const ButtonSegment(value: 55, label: Text('G3')),
                  const ButtonSegment(value: 60, label: Text('C4')),
                ],
                selected: {
                  const {55, 60}.contains(_split) ? _split! : 0,
                },
                onSelectionChanged: (value) => setState(
                  () => _split = value.single == 0 ? null : value.single,
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.pianoPattern, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<AccompanimentPattern>(
                showSelectedIcon: false,
                segments: [
                  for (final pattern in AccompanimentPattern.values)
                    ButtonSegment(
                      value: pattern,
                      label: Text(accompanimentPatternLabel(l10n, pattern)),
                    ),
                ],
                selected: {_base.pattern},
                onSelectionChanged: (value) => setState(
                  () => _base = _base.copyWith(pattern: value.single),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.pianoRegister, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<AccompanimentRegister>(
                showSelectedIcon: false,
                segments: [
                  for (final register in AccompanimentRegister.values)
                    ButtonSegment(
                      value: register,
                      label: Text(accompanimentRegisterLabel(l10n, register)),
                    ),
                ],
                selected: {_base.register},
                onSelectionChanged: (value) => setState(
                  () => _base = _base.copyWith(register: value.single),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _asking ? null : _ask,
                  icon: _asking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(l10n.pianoAskAdvice),
                ),
                const SizedBox(width: 12),
                if (_failed)
                  Expanded(child: Text(l10n.pianoAdviceFailed, style: muted)),
              ],
            ),
            if (_note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_note, style: theme.textTheme.bodyMedium),
            ],
            if (starts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.pianoSectionStyles,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(_sections.clear),
                    child: Text(l10n.pianoOneStyle),
                  ),
                ],
              ),
              for (final start in starts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    l10n.pianoSectionStyle(
                      start + widget.firstBarNumber,
                      accompanimentPatternLabel(
                        l10n,
                        _sections[start]!.pattern,
                      ),
                      accompanimentRegisterLabel(
                        l10n,
                        _sections[start]!.register,
                      ),
                    ),
                  ),
                ),
            ],
            if (_advised) ...[
              const SizedBox(height: 12),
              Text(l10n.pianoChordFixes, style: theme.textTheme.titleSmall),
              if (_corrections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l10n.pianoNoChordFixes, style: muted),
                ),
              for (final correction in _corrections)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _accepted.contains(correction),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _accepted.add(correction);
                    } else {
                      _accepted.remove(correction);
                    }
                  }),
                  title: Text(
                    l10n.pianoChordFix(
                      correction.measureIndex + widget.firstBarNumber,
                      correction.current,
                      correction.suggested,
                    ),
                  ),
                  subtitle: correction.reason.isEmpty
                      ? null
                      : Text(correction.reason),
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _asking || _instruments.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        PianoPartRequest(
                          instruments: [
                            for (final instrument
                                in AccompanimentInstrument.values)
                              if (_instruments.contains(instrument)) instrument,
                          ],
                          roles: _roles,
                          density: _density,
                          splitPoint: _split,
                          separate: _separate,
                          plan: AccompanimentPlan(
                            base: _base,
                            sections: _sections,
                          ),
                          corrections: [
                            for (final correction in _corrections)
                              if (_accepted.contains(correction)) correction,
                          ],
                        ),
                      ),
                child: Text(l10n.pianoMake),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
