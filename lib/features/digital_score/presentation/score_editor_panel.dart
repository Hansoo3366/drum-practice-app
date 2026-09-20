import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/sheet_insets.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';
import 'package:page_a_diddle/features/digital_score/presentation/note_duration_icon.dart';

enum ScoreEditorMode { select, note, rest }

class ScoreEditorPanel extends StatelessWidget {
  const ScoreEditorPanel({
    required this.canUndo,
    required this.canRedo,
    required this.mode,
    required this.selectedEvent,
    required this.inputDurationType,
    required this.inputAlter,
    required this.onUndo,
    required this.onRedo,
    required this.onModeChanged,
    required this.onDurationTypeChanged,
    required this.onInputAlterChanged,
    required this.onEditSelected,
    required this.onAddChord,
    required this.onDeleteSelected,
    super.key,
  });

  final bool canUndo;
  final bool canRedo;
  final ScoreEditorMode mode;
  final MusicEvent? selectedEvent;
  final String inputDurationType;
  final int inputAlter;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final ValueChanged<ScoreEditorMode> onModeChanged;
  final ValueChanged<String> onDurationTypeChanged;
  final ValueChanged<int> onInputAlterChanged;
  final VoidCallback onEditSelected;
  final VoidCallback onAddChord;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasSelection = selectedEvent != null;
    return Material(
      color: AppColors.canvas,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Tooltip(
                        message: l10n.select,
                        child: ChoiceChip(
                          label: Icon(
                            Icons.touch_app_outlined,
                            size: 20,
                            color: mode == ScoreEditorMode.select
                                ? AppColors.accent
                                : AppColors.ink,
                          ),
                          selected: mode == ScoreEditorMode.select,
                          showCheckmark: false,
                          onSelected: (_) =>
                              onModeChanged(ScoreEditorMode.select),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l10n.addNote,
                        child: ChoiceChip(
                          label: NoteDurationIcon(
                            durationType: 'quarter',
                            color: mode == ScoreEditorMode.note
                                ? AppColors.accent
                                : AppColors.ink,
                          ),
                          selected: mode == ScoreEditorMode.note,
                          showCheckmark: false,
                          onSelected: (_) =>
                              onModeChanged(ScoreEditorMode.note),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l10n.addRest,
                        child: ChoiceChip(
                          label: NoteDurationIcon(
                            durationType: 'quarter',
                            rest: true,
                            color: mode == ScoreEditorMode.rest
                                ? AppColors.accent
                                : AppColors.ink,
                          ),
                          selected: mode == ScoreEditorMode.rest,
                          showCheckmark: false,
                          onSelected: (_) =>
                              onModeChanged(ScoreEditorMode.rest),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (mode == ScoreEditorMode.select)
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasSelection
                                ? _eventLabel(l10n, selectedEvent!)
                                : l10n.selectScoreEvent,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: hasSelection
                                      ? AppColors.ink
                                      : AppColors.mutedInk,
                                  fontWeight: hasSelection
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.editSelected,
                          onPressed: hasSelection ? onEditSelected : null,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: l10n.deleteSelectedEvent,
                          onPressed: hasSelection ? onDeleteSelected : null,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final type in staffDurationTypes)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Tooltip(
                              message: staffDurationLabels[type]!,
                              child: ChoiceChip(
                                label: NoteDurationIcon(
                                  durationType: type,
                                  rest: mode == ScoreEditorMode.rest,
                                  color: inputDurationType == type
                                      ? AppColors.accent
                                      : AppColors.ink,
                                ),
                                selected: inputDurationType == type,
                                showCheckmark: false,
                                onSelected: (_) => onDurationTypeChanged(type),
                              ),
                            ),
                          ),
                        if (mode == ScoreEditorMode.note)
                          for (final alter in const [-1, 0, 1])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(switch (alter) {
                                  -1 => '♭',
                                  1 => '♯',
                                  _ => '♮',
                                }),
                                selected: inputAlter == alter,
                                showCheckmark: false,
                                onSelected: (_) => onInputAlterChanged(alter),
                              ),
                            ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.undo,
                        onPressed: canUndo ? onUndo : null,
                        icon: const Icon(Icons.undo_rounded),
                      ),
                      IconButton(
                        tooltip: l10n.redo,
                        onPressed: canRedo ? onRedo : null,
                        icon: const Icon(Icons.redo_rounded),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onAddChord,
                        icon: const Icon(Icons.text_fields_rounded, size: 20),
                        label: Text(l10n.addChordSymbol),
                      ),
                    ],
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

String _eventLabel(AppLocalizations l10n, MusicEvent event) {
  return switch (event) {
    MusicNote(:final isRest, :final pitch, :final type) => [
      if (isRest) l10n.rest else if (pitch != null) _pitchLabel(pitch),
      if (type != null) staffDurationLabels[type] ?? type,
    ].join(' · '),
    MusicHarmony() => l10n.chordSymbol,
    _ => l10n.select,
  };
}

String _pitchLabel(MusicPitch pitch) {
  final accidental = switch (pitch.alter) {
    -2 => '♭♭',
    -1 => '♭',
    1 => '♯',
    2 => '♯♯',
    _ => '',
  };
  return '${pitch.step.name.toUpperCase()}$accidental${pitch.octave}';
}

Future<MusicNote?> showNoteEditorSheet(
  BuildContext context, {
  required MusicMeasure measure,
  MusicNote? existing,
  bool initialRest = false,
}) {
  return showModalBottomSheet<MusicNote>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _NoteEditorSheet(
      measure: measure,
      existing: existing,
      initialRest: initialRest,
    ),
  );
}

class _NoteEditorSheet extends StatefulWidget {
  const _NoteEditorSheet({
    required this.measure,
    required this.existing,
    required this.initialRest,
  });

  final MusicMeasure measure;
  final MusicNote? existing;
  final bool initialRest;

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late bool _isRest;
  late PitchStep _step;
  late int _alter;
  late int _octave;
  late int _duration;
  late int _onset;
  late int _staff;
  late String _voice;

  @override
  void initState() {
    super.initState();
    final note = widget.existing;
    _isRest = note?.isRest ?? widget.initialRest;
    _step = note?.pitch?.step ?? PitchStep.c;
    _alter = note?.pitch?.alter ?? 0;
    _octave = note?.pitch?.octave ?? 4;
    _duration = note?.duration ?? widget.measure.attributes.divisions;
    _onset = note?.onset ?? 0;
    _staff = note?.staff ?? 1;
    _voice = note?.voice ?? '1';
  }

  @override
  Widget build(BuildContext context) {
    final capacity = measureCapacity(widget.measure.attributes);
    final options = _durationOptions(
      widget.measure.attributes.divisions,
    ).where((option) => option.duration <= capacity).toList();
    if (!options.any((option) => option.duration == _duration)) {
      options.add(
        _DurationOption(label: '$_duration', duration: _duration, type: null),
      );
    }
    final maximumOnset = math.max(
      0,
      measureCapacity(widget.measure.attributes) - _duration,
    );
    final onsetOptions = _onsetOptions(
      widget.measure.attributes.divisions,
      maximumOnset,
      _onset,
    );
    final voices = {'1', '2', '3', '4', _voice}.toList()..sort();
    final selectedDuration = options.firstWhere(
      (option) => option.duration == _duration,
    );

    return _EditorSheetFrame(
      title: widget.existing == null
          ? (_isRest ? context.l10n.addRest : context.l10n.addNote)
          : context.l10n.editSelected,
      onSave: () {
        Navigator.of(context).pop(
          MusicNote(
            onset: _onset,
            duration: _duration,
            voice: _voice,
            staff: _staff,
            pitch: _isRest
                ? null
                : MusicPitch(step: _step, alter: _alter, octave: _octave),
            type:
                selectedDuration.type ??
                (_duration == widget.existing?.duration
                    ? widget.existing?.type
                    : null),
            dots: _duration == widget.existing?.duration
                ? (widget.existing?.dots ?? 0)
                : 0,
            isGrace: widget.existing?.isGrace ?? false,
            isChord:
                !_isRest &&
                (widget.existing?.isChord ?? false) &&
                _onset == widget.existing?.onset,
            tieStart: widget.existing?.tieStart ?? false,
            tieStop: widget.existing?.tieStop ?? false,
          ),
        );
      },
      child: Column(
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.music_note_rounded),
                label: Text(context.l10n.note),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.horizontal_rule_rounded),
                label: Text(context.l10n.rest),
              ),
            ],
            selected: {_isRest},
            onSelectionChanged: (value) {
              setState(() => _isRest = value.single);
            },
          ),
          const SizedBox(height: 16),
          if (!_isRest)
            Row(
              children: [
                Expanded(
                  child: _DropdownField<PitchStep>(
                    label: context.l10n.pitch,
                    value: _step,
                    values: PitchStep.values,
                    itemLabel: (step) => step.musicXmlName,
                    onChanged: (value) => setState(() => _step = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DropdownField<int>(
                    label: '♭ / ♯',
                    value: _alter,
                    values: const [-1, 0, 1],
                    itemLabel: (value) => switch (value) {
                      -1 => '♭',
                      1 => '♯',
                      _ => '♮',
                    },
                    onChanged: (value) => setState(() => _alter = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DropdownField<int>(
                    label: context.l10n.octave,
                    value: _octave,
                    values: List.generate(9, (index) => index),
                    itemLabel: (value) => '$value',
                    onChanged: (value) => setState(() => _octave = value),
                  ),
                ),
              ],
            ),
          if (!_isRest) const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DropdownField<int>(
                  label: context.l10n.noteValue,
                  value: _duration,
                  values: options.map((option) => option.duration).toList(),
                  itemLabel: (value) => options
                      .firstWhere((option) => option.duration == value)
                      .label,
                  onChanged: (value) {
                    setState(() {
                      _duration = value;
                      _onset = math.min(_onset, math.max(0, capacity - value));
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownField<int>(
                  key: ValueKey('onset-$_duration'),
                  label: context.l10n.position,
                  value: math.min(_onset, maximumOnset),
                  values: onsetOptions,
                  itemLabel: (value) => _positionLabel(
                    value,
                    widget.measure.attributes.divisions,
                  ),
                  onChanged: (value) => setState(() => _onset = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DropdownField<int>(
                  label: context.l10n.staff,
                  value: _staff,
                  values: List.generate(
                    widget.measure.attributes.staves,
                    (index) => index + 1,
                  ),
                  itemLabel: (value) => '$value',
                  onChanged: (value) => setState(() => _staff = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownField<String>(
                  label: context.l10n.voice,
                  value: _voice,
                  values: voices,
                  itemLabel: (value) => value,
                  onChanged: (value) => setState(() => _voice = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<MusicHarmony?> showHarmonyEditorSheet(
  BuildContext context, {
  required MusicMeasure measure,
  MusicHarmony? existing,
}) {
  return showModalBottomSheet<MusicHarmony>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _HarmonyEditorSheet(measure: measure, existing: existing),
  );
}

class _HarmonyEditorSheet extends StatefulWidget {
  const _HarmonyEditorSheet({required this.measure, required this.existing});

  final MusicMeasure measure;
  final MusicHarmony? existing;

  @override
  State<_HarmonyEditorSheet> createState() => _HarmonyEditorSheetState();
}

class _HarmonyEditorSheetState extends State<_HarmonyEditorSheet> {
  static const _kinds = {
    'major': 'Major',
    'minor': 'Minor',
    'dominant': '7',
    'major-seventh': 'Maj7',
    'minor-seventh': 'Min7',
    'diminished': 'Dim',
    'augmented': 'Aug',
    'suspended-fourth': 'Sus4',
  };

  late PitchStep _root;
  late int _alter;
  late String _kind;
  late int _onset;
  late int _staff;

  @override
  void initState() {
    super.initState();
    _root = widget.existing?.rootStep ?? PitchStep.c;
    _alter = widget.existing?.rootAlter ?? 0;
    _kind = widget.existing?.kind ?? 'major';
    if (!_kinds.containsKey(_kind)) _kind = 'major';
    _onset = widget.existing?.onset ?? 0;
    _staff = widget.existing?.staff ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final maximumOnset = measureCapacity(widget.measure.attributes) - 1;
    final onsetOptions = _onsetOptions(
      widget.measure.attributes.divisions,
      maximumOnset,
      _onset,
    );
    return _EditorSheetFrame(
      title: widget.existing == null
          ? context.l10n.addChordSymbol
          : context.l10n.editSelected,
      onSave: () {
        Navigator.of(context).pop(
          MusicHarmony(
            onset: _onset,
            staff: _staff,
            rootStep: _root,
            rootAlter: _alter,
            kind: _kind,
            kindText: null,
            bassStep: widget.existing?.bassStep,
            bassAlter: widget.existing?.bassAlter ?? 0,
          ),
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DropdownField<PitchStep>(
                  label: context.l10n.chordSymbol,
                  value: _root,
                  values: PitchStep.values,
                  itemLabel: (value) => value.musicXmlName,
                  onChanged: (value) => setState(() => _root = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownField<int>(
                  label: '♭ / ♯',
                  value: _alter,
                  values: const [-1, 0, 1],
                  itemLabel: (value) => switch (value) {
                    -1 => '♭',
                    1 => '♯',
                    _ => '♮',
                  },
                  onChanged: (value) => setState(() => _alter = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownField<String>(
                  label: context.l10n.chordSymbol,
                  value: _kind,
                  values: _kinds.keys.toList(),
                  itemLabel: (value) => _kinds[value]!,
                  onChanged: (value) => setState(() => _kind = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DropdownField<int>(
                  label: context.l10n.position,
                  value: _onset,
                  values: onsetOptions,
                  itemLabel: (value) => _positionLabel(
                    value,
                    widget.measure.attributes.divisions,
                  ),
                  onChanged: (value) => setState(() => _onset = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownField<int>(
                  label: context.l10n.staff,
                  value: _staff,
                  values: List.generate(
                    widget.measure.attributes.staves,
                    (index) => index + 1,
                  ),
                  itemLabel: (value) => '$value',
                  onChanged: (value) => setState(() => _staff = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MeasureSettingsResult {
  const MeasureSettingsResult({required this.keyFifths, required this.time});

  final int keyFifths;
  final MusicTimeSignature time;
}

Future<MeasureSettingsResult?> showMeasureSettingsSheet(
  BuildContext context, {
  required MusicMeasure measure,
}) {
  return showModalBottomSheet<MeasureSettingsResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _MeasureSettingsSheet(measure: measure),
  );
}

class _MeasureSettingsSheet extends StatefulWidget {
  const _MeasureSettingsSheet({required this.measure});

  final MusicMeasure measure;

  @override
  State<_MeasureSettingsSheet> createState() => _MeasureSettingsSheetState();
}

enum _TimeSignatureNotation { numbers, common, allaBreve }

class _MeasureSettingsSheetState extends State<_MeasureSettingsSheet> {
  late int _keyFifths;
  late int _beats;
  late int _beatType;
  late _TimeSignatureNotation _notation;

  @override
  void initState() {
    super.initState();
    _keyFifths = widget.measure.attributes.keyFifths;
    final time =
        widget.measure.attributes.time ??
        const MusicTimeSignature(beats: 4, beatType: 4);
    _beats = time.beats;
    _beatType = time.beatType;
    _notation = switch (time.symbol) {
      MusicTimeSymbol.common => _TimeSignatureNotation.common,
      MusicTimeSymbol.cut => _TimeSignatureNotation.allaBreve,
      null => _TimeSignatureNotation.numbers,
    };
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheetFrame(
      title: context.l10n.measureSettings,
      onSave: () {
        Navigator.of(context).pop(
          MeasureSettingsResult(
            keyFifths: _keyFifths,
            time: MusicTimeSignature(
              beats: _beats,
              beatType: _beatType,
              symbol: switch (_notation) {
                _TimeSignatureNotation.common => MusicTimeSymbol.common,
                _TimeSignatureNotation.allaBreve => MusicTimeSymbol.cut,
                _TimeSignatureNotation.numbers => null,
              },
            ),
          ),
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DropdownField<int>(
                  label: context.l10n.keySignature,
                  value: _keyFifths,
                  values: List.generate(15, (index) => index - 7),
                  itemLabel: _keyLabel,
                  onChanged: (value) => setState(() => _keyFifths = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DropdownField<_TimeSignatureNotation>(
                  label: context.l10n.timeSignatureNotation,
                  value: _notation,
                  values: _TimeSignatureNotation.values,
                  itemLabel: (value) => switch (value) {
                    _TimeSignatureNotation.numbers =>
                      context.l10n.timeSignatureNumbers,
                    _TimeSignatureNotation.common => context.l10n.commonTime,
                    _TimeSignatureNotation.allaBreve => context.l10n.allaBreve,
                  },
                  onChanged: (value) => setState(() {
                    _notation = value;
                    if (value == _TimeSignatureNotation.common) {
                      _beats = 4;
                      _beatType = 4;
                    } else if (value == _TimeSignatureNotation.allaBreve) {
                      _beats = 2;
                      _beatType = 2;
                    }
                  }),
                ),
              ),
            ],
          ),
          if (_notation == _TimeSignatureNotation.numbers) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DropdownField<int>(
                    label: context.l10n.timeSignature,
                    value: _beats,
                    values: List.generate(12, (index) => index + 1),
                    itemLabel: (value) => '$value',
                    onChanged: (value) => setState(() => _beats = value),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 24, 8, 0),
                  child: Text('/'),
                ),
                Expanded(
                  child: _DropdownField<int>(
                    label: ' ',
                    value: _beatType,
                    values: const [1, 2, 4, 8, 16],
                    itemLabel: (value) => '$value',
                    onChanged: (value) => setState(() => _beatType = value),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorSheetFrame extends StatelessWidget {
  const _EditorSheetFrame({
    required this.title,
    required this.onSave,
    required this.child,
  });

  final String title;
  final VoidCallback onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: sheetContentPadding(context),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
            const SizedBox(height: 24),
            FilledButton(onPressed: onSave, child: Text(context.l10n.save)),
          ],
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(itemLabel(item))),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _DurationOption {
  const _DurationOption({
    required this.label,
    required this.duration,
    required this.type,
  });

  final String label;
  final int duration;
  final String? type;
}

List<_DurationOption> _durationOptions(int divisions) {
  final options = [
    _DurationOption(label: '1', duration: divisions * 4, type: 'whole'),
    _DurationOption(label: '1/2', duration: divisions * 2, type: 'half'),
    _DurationOption(label: '1/4', duration: divisions, type: 'quarter'),
    _DurationOption(
      label: '1/8',
      duration: math.max(1, (divisions / 2).round()),
      type: 'eighth',
    ),
    _DurationOption(
      label: '1/16',
      duration: math.max(1, (divisions / 4).round()),
      type: '16th',
    ),
  ];
  final unique = <int, _DurationOption>{};
  for (final option in options) {
    unique.putIfAbsent(option.duration, () => option);
  }
  return unique.values.toList();
}

List<int> _onsetOptions(int divisions, int maximum, int current) {
  final step = math.max(1, (divisions / 4).round());
  final values = <int>{
    for (var value = 0; value <= maximum; value += step) value,
  };
  if (current >= 0 && current <= maximum) values.add(current);
  return values.toList()..sort();
}

String _positionLabel(int onset, int divisions) {
  final beat = onset / divisions + 1;
  return beat == beat.roundToDouble()
      ? '${beat.toInt()}'
      : beat.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

String _keyLabel(int fifths) {
  const labels = {
    -7: 'C♭ / A♭m',
    -6: 'G♭ / E♭m',
    -5: 'D♭ / B♭m',
    -4: 'A♭ / Fm',
    -3: 'E♭ / Cm',
    -2: 'B♭ / Gm',
    -1: 'F / Dm',
    0: 'C / Am',
    1: 'G / Em',
    2: 'D / Bm',
    3: 'A / F♯m',
    4: 'E / C♯m',
    5: 'B / G♯m',
    6: 'F♯ / D♯m',
    7: 'C♯ / A♯m',
  };
  return labels[fifths]!;
}
