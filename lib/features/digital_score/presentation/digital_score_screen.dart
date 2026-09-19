import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/widgets/app_empty_state.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_data.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/score_export_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/playback_sequence_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_editor_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_playback_bar.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_transpose_panel.dart';

class DigitalScoreScreen extends ConsumerStatefulWidget {
  const DigitalScoreScreen({required this.songId, super.key});

  final String songId;

  @override
  ConsumerState<DigitalScoreScreen> createState() => _DigitalScoreScreenState();
}

class _DigitalScoreScreenState extends ConsumerState<DigitalScoreScreen> {
  final _playback = PianoScorePlaybackController();
  MusicScoreEditor? _editor;
  String? _editorSourcePath;
  PlaybackSequence _sequence = PlaybackSequence.empty;
  PlaybackSequence _savedSequence = PlaybackSequence.empty;
  ArrangementProfile _arrangement = ArrangementProfile.off;
  ArrangementProfile _savedArrangement = ArrangementProfile.off;
  bool _editing = false;
  bool _structuring = false;
  bool _playbackEnabled = false;
  bool _saving = false;
  bool _exporting = false;
  bool _confirmingLeave = false;
  int _partIndex = 0;
  int _measureIndex = 0;
  List<ScoreSystemSpan> _systems = const [];
  ScoreEventAddress? _selectedAddress;
  String _inputDurationType = 'quarter';
  bool _inputRest = false;
  int _inputAlter = 0;

  @override
  void dispose() {
    _playback.stop();
    _playback.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final editor = _editor;
    return editor != null &&
        (editor.isDirty ||
            _sequence != _savedSequence ||
            _arrangement != _savedArrangement);
  }

  MusicScoreEditor _editorFor(DigitalScoreData data) {
    if (_editor == null || _editorSourcePath != data.song.sourcePath) {
      _editor = MusicScoreEditor(data.score);
      _editorSourcePath = data.song.sourcePath;
      _sequence = sequenceForMarkedSections(data.score, data.sequence);
      _savedSequence = _sequence;
      _arrangement = data.arrangement;
      _savedArrangement = data.arrangement;
      _partIndex = 0;
      _measureIndex = 0;
      _systems = const [];
      _selectedAddress = null;
    }
    return _editor!;
  }

  MusicScore _viewScore(MusicScore written) {
    return displayedDigitalScore(
      written: written,
      editing: _editing || _structuring,
      playbackEnabled: _playbackEnabled,
      sequence: _sequence,
      arrangement: _arrangement,
    );
  }

  Future<bool> _save(DigitalScoreData data, MusicScoreEditor editor) async {
    if (_saving) return false;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(digitalScoreEditorServiceProvider)
          .save(
            songId: data.song.id,
            relativePath: data.song.sourcePath,
            score: editor.score,
            sequence: _sequence,
            arrangement: _arrangement,
          );
      editor.markSaved();
      _savedSequence = _sequence;
      _savedArrangement = _arrangement;
      if (!mounted) return true;
      setState(() {});
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.scoreSaved)));
      return true;
    } on Object {
      if (!mounted) return false;
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export(
    DigitalScoreData data,
    MusicScore written,
    ScoreExportKind kind,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final exported = await const ScoreExportService().encode(
        written: written,
        title: data.song.title,
        sequence: _sequence,
        arrangement: _arrangement,
        kind: kind,
      );
      final savedPath = await FilePicker.saveFile(
        dialogTitle: exported.fileName,
        fileName: exported.fileName,
        type: FileType.custom,
        allowedExtensions: [exported.extension],
        bytes: exported.bytes,
      );
      if (!mounted || savedPath == null) return;
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.done)));
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _apply(ScoreEditCommand command, {ScoreEventAddress? selectedAddress}) {
    final editor = _editor;
    if (editor == null) return;
    try {
      editor.apply(command);
      setState(() {
        _selectedAddress = selectedAddress;
        _clampNavigation(editor.score);
      });
    } on Object {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.changeFailed)));
    }
  }

  void _undo() {
    final editor = _editor;
    if (editor == null || !editor.canUndo) return;
    setState(() {
      editor.undo();
      _selectedAddress = null;
      _clampNavigation(editor.score);
    });
  }

  void _redo() {
    final editor = _editor;
    if (editor == null || !editor.canRedo) return;
    setState(() {
      editor.redo();
      _selectedAddress = null;
      _clampNavigation(editor.score);
    });
  }

  void _clampNavigation(MusicScore score) {
    _partIndex = math.min(_partIndex, score.parts.length - 1);
    _measureIndex = math.min(
      _measureIndex,
      score.parts[_partIndex].measures.length - 1,
    );
  }

  MusicMeasure get _currentMeasure {
    final score = _editor!.score;
    return score.parts[_partIndex].measures[_measureIndex];
  }

  MusicEvent? get _selectedEvent {
    final address = _selectedAddress;
    final editor = _editor;
    if (address == null || editor == null) return null;
    if (address.partIndex < 0 ||
        address.partIndex >= editor.score.parts.length) {
      return null;
    }
    final measures = editor.score.parts[address.partIndex].measures;
    if (address.measureIndex < 0 || address.measureIndex >= measures.length) {
      return null;
    }
    final events = measures[address.measureIndex].events;
    if (address.eventIndex < 0 || address.eventIndex >= events.length) {
      return null;
    }
    return events[address.eventIndex];
  }

  void _placeStaffNote(AlphaTabStaffTappedEvent hit) {
    final editor = _editor;
    if (editor == null) return;
    if (_structuring) {
      if (hit.partIndex < 0 || hit.partIndex >= editor.score.parts.length) {
        return;
      }
      final measures = editor.score.parts[hit.partIndex].measures;
      if (hit.measureIndex < 0 || hit.measureIndex >= measures.length) return;
      setState(() {
        _partIndex = hit.partIndex;
        _measureIndex = scoreSystemStart(hit.measureIndex, _systems);
      });
      return;
    }
    if (!_editing) return;
    if (hit.partIndex < 0 || hit.partIndex >= editor.score.parts.length) {
      return;
    }
    final measures = editor.score.parts[hit.partIndex].measures;
    if (hit.measureIndex < 0 || hit.measureIndex >= measures.length) return;
    final measure = measures[hit.measureIndex];
    final onset = onsetFromTicks(hit.onsetTicks, measure.attributes.divisions);
    final existingNote = findNoteAt(
      score: editor.score,
      partIndex: hit.partIndex,
      measureIndex: hit.measureIndex,
      staff: hit.staff,
      onset: onset,
      midi: _inputRest
          ? null
          : pitchFromMidi(hit.midi, alter: _inputAlter).midi,
      rest: _inputRest,
    );
    if (existingNote != null) {
      setState(() {
        _partIndex = existingNote.partIndex;
        _measureIndex = existingNote.measureIndex;
        _selectedAddress = existingNote;
      });
      return;
    }
    if (_inputRest) {
      final pitched = findNoteAt(
        score: editor.score,
        partIndex: hit.partIndex,
        measureIndex: hit.measureIndex,
        staff: hit.staff,
        onset: onset,
      );
      if (pitched != null) {
        setState(() {
          _partIndex = pitched.partIndex;
          _measureIndex = pitched.measureIndex;
          _selectedAddress = pitched;
        });
        return;
      }
    }
    final restAt = findNoteAt(
      score: editor.score,
      partIndex: hit.partIndex,
      measureIndex: hit.measureIndex,
      staff: hit.staff,
      onset: onset,
      rest: true,
    );
    final note = noteFromStaffTap(
      measure: measure,
      staff: hit.staff,
      onsetTicks: hit.onsetTicks,
      midi: hit.midi,
      durationType: _inputDurationType,
      rest: _inputRest,
      alter: _inputAlter,
    );
    if (restAt != null && !_inputRest) {
      _apply(
        ReplaceScoreEventCommand(address: restAt, event: note),
        selectedAddress: restAt,
      );
      setState(() {
        _partIndex = hit.partIndex;
        _measureIndex = hit.measureIndex;
      });
      return;
    }
    _apply(
      InsertScoreEventCommand(
        partIndex: hit.partIndex,
        measureIndex: hit.measureIndex,
        event: note,
      ),
    );
    final placed = findNoteAt(
      score: _editor!.score,
      partIndex: hit.partIndex,
      measureIndex: hit.measureIndex,
      staff: note.staff,
      onset: note.onset,
      midi: note.pitch?.midi,
      rest: note.isRest,
    );
    setState(() {
      _partIndex = hit.partIndex;
      _measureIndex = hit.measureIndex;
      _selectedAddress = placed;
    });
  }

  void _moveStaffNote(AlphaTabNoteDraggedEvent hit) {
    final editor = _editor;
    if (_structuring || !_editing || editor == null) return;
    final address = findRenderedNoteAddress(
      score: editor.score,
      partIndex: hit.partIndex,
      measureIndex: hit.measureIndex,
      staff: hit.staff,
      onsetTicks: hit.onsetTicks,
      midi: hit.originalMidi,
    );
    if (address == null) return;
    final existing = editor
        .score
        .parts[address.partIndex]
        .measures[address.measureIndex]
        .events[address.eventIndex];
    if (existing is! MusicNote || existing.isRest) return;
    _apply(
      ReplaceScoreEventCommand(
        address: address,
        event: existing.copyWith(
          pitch: pitchFromMidi(hit.midi, alter: _inputAlter),
        ),
      ),
      selectedAddress: address,
    );
    setState(() {
      _partIndex = address.partIndex;
      _measureIndex = address.measureIndex;
    });
  }

  void _insertMeasureAfter() {
    final editor = _editor;
    if (editor == null) return;
    final before = editor.score.measureCount;
    _apply(InsertMeasureCommand(afterMeasureIndex: _measureIndex));
    final next = _editor;
    if (next == null || next.score.measureCount == before) return;
    setState(() {
      _measureIndex = math.min(
        _measureIndex + 1,
        next.score.measureCount - 1,
      );
      _sequence = sequenceForMarkedSections(next.score, _sequence);
    });
  }

  void _setMeasureSection(String? section) {
    _apply(
      UpdateSystemSectionCommand(
        measureIndex: _measureIndex,
        section: section,
        systems: _systems,
      ),
    );
    final editor = _editor;
    if (editor == null) return;
    setState(() {
      _sequence = sequenceForMarkedSections(editor.score, _sequence);
    });
  }

  void _setSectionRepeats(String section, int repeats) {
    setState(() {
      _sequence = sequenceForMarkedSections(
        _editor!.score,
        PlaybackSequence([
          for (final item in _sequence.items)
            if (item.section == section)
              item.copyWith(repeats: repeats)
            else
              item,
          if (_sequence.items.every((item) => item.section != section))
            PlaybackSequenceItem(section: section, repeats: repeats),
        ]),
      );
    });
  }

  void _togglePlayback() {
    setState(() => _playbackEnabled = !_playbackEnabled);
    if (!_playbackEnabled) _playback.stop();
  }

  void _onToolSelected(_ScoreTool tool) {
    switch (tool) {
      case _ScoreTool.chord:
        _addChord();
      case _ScoreTool.editSelected:
        _editSelected();
    }
  }

  Future<void> _addChord() async {
    final event = await showHarmonyEditorSheet(
      context,
      measure: _currentMeasure,
    );
    if (!mounted || event == null) return;
    final address = ScoreEventAddress(
      partIndex: _partIndex,
      measureIndex: _measureIndex,
      eventIndex: _currentMeasure.events.length,
    );
    _apply(
      InsertScoreEventCommand(
        partIndex: _partIndex,
        measureIndex: _measureIndex,
        event: event,
      ),
      selectedAddress: address,
    );
  }

  Future<void> _editSelected() async {
    final address = _selectedAddress;
    final existing = _selectedEvent;
    if (address == null || existing == null) return;
    MusicEvent? replacement;
    if (existing is MusicNote) {
      replacement = await showNoteEditorSheet(
        context,
        measure: _editor!
            .score
            .parts[address.partIndex]
            .measures[address.measureIndex],
        existing: existing,
      );
    } else if (existing is MusicHarmony) {
      replacement = await showHarmonyEditorSheet(
        context,
        measure: _editor!
            .score
            .parts[address.partIndex]
            .measures[address.measureIndex],
        existing: existing,
      );
    }
    if (!mounted || replacement == null) return;
    _apply(
      ReplaceScoreEventCommand(address: address, event: replacement),
      selectedAddress: address,
    );
  }

  Future<void> _transpose(
    MusicScore score, {
    required int originalFifths,
  }) async {
    final request = await showScoreTransposeSheet(
      context,
      currentFifths: concertKeyFifths(score),
      originalFifths: originalFifths,
    );
    if (!mounted || request == null) return;
    _apply(
      TransposeScoreCommand(
        semitones: request.semitones,
        fifthsDelta: request.fifthsDelta,
      ),
    );
  }

  void _toggleStructuring() {
    setState(() {
      _structuring = !_structuring;
      if (_structuring) {
        _editing = false;
        _selectedAddress = null;
        _measureIndex = scoreSystemStart(_measureIndex, _systems);
        final editor = _editor;
        if (editor != null) {
          _sequence = sequenceForMarkedSections(editor.score, _sequence);
        }
      }
    });
  }

  void _selectMeasure(int measureIndex) {
    final editor = _editor;
    if ((!_structuring && !_editing) || editor == null) return;
    final measures = editor.score.parts.first.measures;
    if (measureIndex < 0 || measureIndex >= measures.length) return;
    setState(() => _measureIndex = scoreSystemStart(measureIndex, _systems));
  }

  void _onNoteTapped(AlphaTabNoteTappedEvent hit) {
    final editor = _editor;
    if (_structuring) {
      setState(() {
        _partIndex = hit.partIndex;
        _measureIndex = scoreSystemStart(hit.measureIndex, _systems);
      });
      return;
    }
    if (!_editing || editor == null) return;
    final address = findRenderedNoteAddress(
      score: editor.score,
      partIndex: hit.partIndex,
      measureIndex: hit.measureIndex,
      staff: hit.staff,
      onsetTicks: hit.onsetTicks,
      midi: hit.midi,
    );
    if (address == null) return;
    setState(() {
      _partIndex = address.partIndex;
      _measureIndex = address.measureIndex;
      _selectedAddress = address;
    });
  }

  Future<void> _confirmLeave(
    DigitalScoreData data,
    MusicScoreEditor editor,
  ) async {
    if (_confirmingLeave) return;
    _confirmingLeave = true;
    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unsavedChangesTitle),
        content: Text(context.l10n.unsavedChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _LeaveAction.discard),
            child: Text(context.l10n.discardChanges),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _LeaveAction.save),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    _confirmingLeave = false;
    if (!mounted || action == null) return;
    if (action == _LeaveAction.save && !await _save(data, editor)) return;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(digitalScoreDataProvider(widget.songId));
    return data.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: context.l10n.loadFailed,
          body: context.l10n.retryAction,
          actionLabel: context.l10n.retryAction,
          onAction: () =>
              ref.invalidate(digitalScoreDataProvider(widget.songId)),
        ),
      ),
      data: (value) {
        final editor = _editorFor(value);
        final score = editor.score;
        return PopScope(
          canPop: !_isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave(value, editor);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(value.song.title),
              actions: [
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_isDirty)
                  IconButton(
                    tooltip: context.l10n.save,
                    onPressed: () => _save(value, editor),
                    icon: const Icon(Icons.save_rounded),
                  ),
                IconButton(
                  tooltip: context.l10n.scoreEdit,
                  isSelected: _editing,
                  onPressed: () => setState(() {
                    _editing = !_editing;
                    if (_editing) _structuring = false;
                    if (!_editing) _selectedAddress = null;
                  }),
                  icon: const Icon(Icons.edit_note_rounded),
                  selectedIcon: const Icon(Icons.check_rounded),
                ),
                IconButton(
                  tooltip: context.l10n.play,
                  isSelected: _playbackEnabled,
                  onPressed: _togglePlayback,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  selectedIcon: const Icon(Icons.play_circle_rounded),
                ),
                IconButton(
                  tooltip: context.l10n.playbackSequence,
                  isSelected: _structuring,
                  onPressed: _toggleStructuring,
                  icon: const Icon(Icons.playlist_play_rounded),
                ),
                IconButton(
                  tooltip: context.l10n.scoreTranspose,
                  onPressed: () =>
                      _transpose(score, originalFifths: value.originalFifths),
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
                if (_editing)
                  PopupMenuButton<_ScoreTool>(
                    tooltip: context.l10n.scoreTools,
                    icon: const Icon(Icons.tune_rounded),
                    onSelected: _onToolSelected,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _ScoreTool.chord,
                        child: Text(context.l10n.addChordSymbol),
                      ),
                      if (_selectedAddress != null)
                        PopupMenuItem(
                          value: _ScoreTool.editSelected,
                          child: Text(context.l10n.editSelected),
                        ),
                    ],
                  ),
                if (_exporting)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  PopupMenuButton<ScoreExportKind>(
                    tooltip: context.l10n.save,
                    icon: const Icon(Icons.download_rounded),
                    onSelected: (kind) => _export(value, score, kind),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: ScoreExportKind.musicXml,
                        child: Text('.musicxml'),
                      ),
                      const PopupMenuItem(
                        value: ScoreExportKind.xml,
                        child: Text('.xml'),
                      ),
                      const PopupMenuItem(
                        value: ScoreExportKind.mxl,
                        child: Text('.mxl'),
                      ),
                      const PopupMenuItem(
                        value: ScoreExportKind.midi,
                        child: Text('.mid'),
                      ),
                      const PopupMenuItem(
                        value: ScoreExportKind.pdf,
                        child: Text('.pdf'),
                      ),
                      PopupMenuItem(
                        value: ScoreExportKind.project,
                        child: Text(context.l10n.scoreProject),
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: PianoScoreView(
                    score: _viewScore(score),
                    semanticsLabel: value.song.title,
                    playback: _playback,
                    playbackVisible: _playbackEnabled,
                    highlightedMeasureIndex: (_editing || _structuring)
                        ? scoreSystemStart(_measureIndex, _systems)
                        : null,
                    absorbMeasureTaps: _structuring,
                    oneFingerPan: !_editing,
                    onNoteTapped: _onNoteTapped,
                    onStaffTapped: _placeStaffNote,
                    onMeasureTapped: _selectMeasure,
                    onSystemsChanged: (systems) {
                      if (!mounted) return;
                      setState(() {
                        _systems = systems;
                        if (_structuring) {
                          _measureIndex = scoreSystemStart(
                            _measureIndex,
                            _systems,
                          );
                        }
                      });
                    },
                    onNoteDragged: _moveStaffNote,
                    onPlayerIssue: () {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.playFailed)),
                      );
                    },
                  ),
                ),
                if (_playbackEnabled)
                  ListenableBuilder(
                    listenable: _playback,
                    builder: (context, _) {
                      return ScorePlaybackBar(
                        state: _playback.state,
                        padBottomSafeArea: !_editing && !_structuring,
                        onPlayPause: () => _playback.playPause(),
                        onStop: () => _playback.stop(),
                        onSeek: (positionMs) => _playback.seek(positionMs),
                      );
                    },
                  ),
                if (_structuring)
                  ScoreStructurePanel(
                    score: score,
                    sequence: _sequence,
                    measureIndex: _measureIndex,
                    onSectionChanged: _setMeasureSection,
                    onRepeatsChanged: _setSectionRepeats,
                    onInsertMeasure: _insertMeasureAfter,
                  ),
                if (_editing)
                  ScoreEditorPanel(
                    canUndo: editor.canUndo,
                    canRedo: editor.canRedo,
                    hasSelection: _selectedAddress != null,
                    inputDurationType: _inputDurationType,
                    inputRest: _inputRest,
                    inputAlter: _inputAlter,
                    onUndo: _undo,
                    onRedo: _redo,
                    onDurationTypeChanged: (type) =>
                        setState(() => _inputDurationType = type),
                    onInputRestChanged: (value) =>
                        setState(() => _inputRest = value),
                    onInputAlterChanged: (alter) =>
                        setState(() => _inputAlter = alter),
                    onDeleteSelected: () {
                      final address = _selectedAddress;
                      if (address != null) {
                        _apply(DeleteScoreEventCommand(address));
                      }
                    },
                    onInsertMeasure: _insertMeasureAfter,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _LeaveAction { discard, save }

enum _ScoreTool { chord, editSelected }
