import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
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
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
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
  final _scoreViewKey = GlobalKey<PianoScoreViewState>();
  final Map<String, MusicScoreEditor> _versionEditors = {};
  MusicScoreEditor? _originalEditor;
  String? _loadedSongId;
  ScoreVersionCatalog _versionCatalog = ScoreVersionCatalog.empty;
  String _activeVersionId = scoreVersionOriginalId;
  ArrangementProfile _arrangement = ArrangementProfile.off;
  ArrangementProfile _savedArrangement = ArrangementProfile.off;
  bool _editing = false;
  bool _playbackEnabled = false;
  bool _saving = false;
  bool _exporting = false;
  bool _confirmingLeave = false;
  bool _showMeasureTools = false;
  int _partIndex = 0;
  int _measureIndex = 0;
  ScoreEventAddress? _selectedAddress;
  ScoreEditorMode _editorMode = ScoreEditorMode.select;
  String _inputDurationType = 'quarter';
  int _inputAlter = 0;

  @override
  void dispose() {
    _playback.stop();
    _playback.dispose();
    super.dispose();
  }

  MusicScoreEditor? get _editor => _activeVersionId == scoreVersionOriginalId
      ? _originalEditor
      : _versionEditors[_activeVersionId];

  bool get _isDirty {
    final originalDirty = _originalEditor?.isDirty ?? false;
    final versionDirty = _versionEditors.values.any((editor) => editor.isDirty);
    return originalDirty || versionDirty || _arrangement != _savedArrangement;
  }

  MusicScoreEditor _editorFor(DigitalScoreData data) {
    if (_loadedSongId != data.song.id) {
      _originalEditor = MusicScoreEditor(data.score);
      _versionEditors.clear();
      _versionCatalog = data.versionCatalog;
      _activeVersionId = scoreVersionOriginalId;
      _loadedSongId = data.song.id;
      _arrangement = data.arrangement;
      _savedArrangement = data.arrangement;
      _partIndex = 0;
      _measureIndex = 0;
      _selectedAddress = null;
      _showMeasureTools = false;
    }
    return _editor!;
  }

  String _versionLabel(ScoreVersionRef version) {
    final l10n = context.l10n;
    if (version.isOriginal) return l10n.scoreOriginal;
    if (version.id == scoreVersionLegacyPerformanceId) {
      return l10n.scorePerformance;
    }
    return version.name;
  }

  MusicScore _viewScore(MusicScore written) {
    return displayedDigitalScore(
      written: written,
      editing: _editing,
      playbackEnabled: _playbackEnabled,
      sequence: PlaybackSequence.empty,
      arrangement: ArrangementProfile.off,
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
            arrangement: _arrangement,
            versionId: _activeVersionId,
          );
      editor.markSaved();
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
        sequence: PlaybackSequence.empty,
        arrangement: ArrangementProfile.off,
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
    if (!_editing) return;
    if (hit.partIndex < 0 || hit.partIndex >= editor.score.parts.length) {
      return;
    }
    final measures = editor.score.parts[hit.partIndex].measures;
    if (hit.measureIndex < 0 || hit.measureIndex >= measures.length) return;
    final measure = measures[hit.measureIndex];
    if (_editorMode == ScoreEditorMode.select) {
      final onset = onsetFromTicks(
        hit.onsetTicks,
        measure.attributes.divisions,
      );
      final selected =
          findNoteAt(
            score: editor.score,
            partIndex: hit.partIndex,
            measureIndex: hit.measureIndex,
            staff: hit.staff,
            onset: onset,
            midi: hit.midi,
          ) ??
          findNoteAt(
            score: editor.score,
            partIndex: hit.partIndex,
            measureIndex: hit.measureIndex,
            staff: hit.staff,
            onset: onset,
          ) ??
          findNoteAt(
            score: editor.score,
            partIndex: hit.partIndex,
            measureIndex: hit.measureIndex,
            staff: hit.staff,
            onset: onset,
            rest: true,
          );
      setState(() {
        _partIndex = hit.partIndex;
        _measureIndex = hit.measureIndex;
        _selectedAddress = selected;
        _showMeasureTools = true;
      });
      return;
    }
    final addingRest = _editorMode == ScoreEditorMode.rest;
    final onset = onsetFromTicks(hit.onsetTicks, measure.attributes.divisions);
    final existingNote = findNoteAt(
      score: editor.score,
      partIndex: hit.partIndex,
      measureIndex: hit.measureIndex,
      staff: hit.staff,
      onset: onset,
      midi: addingRest
          ? null
          : pitchFromMidi(hit.midi, alter: _inputAlter).midi,
      rest: addingRest,
    );
    if (existingNote != null) {
      setState(() {
        _partIndex = existingNote.partIndex;
        _measureIndex = existingNote.measureIndex;
        _selectedAddress = existingNote;
        _editorMode = ScoreEditorMode.select;
      });
      return;
    }
    if (addingRest) {
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
          _editorMode = ScoreEditorMode.select;
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
      rest: addingRest,
      alter: _inputAlter,
    );
    if (!addingRest) {
      final overlappingRestIndexes = <int>[];
      for (var index = 0; index < measure.events.length; index++) {
        final event = measure.events[index];
        if (event is! MusicNote || !event.isRest) continue;
        if (event.staff != note.staff || event.voice != note.voice) continue;
        if (event.onset < note.end && event.end > note.onset) {
          overlappingRestIndexes.add(index);
        }
      }
      for (final index in overlappingRestIndexes.reversed) {
        _apply(
          DeleteScoreEventCommand(
            ScoreEventAddress(
              partIndex: hit.partIndex,
              measureIndex: hit.measureIndex,
              eventIndex: index,
            ),
          ),
        );
      }
    } else if (restAt != null) {
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
    if (!_editing ||
        _editorMode != ScoreEditorMode.select ||
        editor == null) {
      return;
    }
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
      _measureIndex = math.min(_measureIndex + 1, next.score.measureCount - 1);
      _showMeasureTools = true;
    });
  }

  void _duplicateMeasure() {
    _apply(DuplicateMeasureCommand(measureIndex: _measureIndex));
    final editor = _editor;
    if (editor == null) return;
    setState(() {
      _measureIndex = math.min(
        _measureIndex + 1,
        editor.score.measureCount - 1,
      );
      _showMeasureTools = true;
    });
  }

  void _deleteMeasure() {
    _apply(DeleteMeasureCommand(measureIndex: _measureIndex));
    final editor = _editor;
    if (editor == null) return;
    setState(() {
      _measureIndex = math.min(_measureIndex, editor.score.measureCount - 1);
      _showMeasureTools = editor.score.measureCount > 0;
    });
  }

  void _moveMeasure(int fromIndex, int toIndex) {
    _apply(MoveMeasureCommand(fromIndex: fromIndex, toIndex: toIndex));
    setState(() {
      _measureIndex = toIndex;
      _showMeasureTools = true;
    });
  }

  void _startMeasureDrag() {
    final state = _scoreViewKey.currentState;
    if (state == null) return;
    unawaited(state.startMeasureDrag(_measureIndex));
  }

  Future<void> _switchVersion({
    required String versionId,
    required DigitalScoreData data,
  }) async {
    if (versionId == _activeVersionId) return;
    if (versionId != scoreVersionOriginalId) {
      final existing = _versionEditors[versionId];
      if (existing == null) {
        final service = ref.read(digitalScoreEditorServiceProvider);
        final score = await service.loadVersionScore(
          songId: data.song.id,
          versionId: versionId,
        );
        if (!mounted) return;
        if (score == null) return;
        _versionEditors[versionId] = MusicScoreEditor(score);
      }
    }
    setState(() {
      _activeVersionId = versionId;
      _versionCatalog = _versionCatalog.copyWith(activeId: versionId);
      _selectedAddress = null;
      _showMeasureTools = false;
      _partIndex = 0;
      _measureIndex = 0;
      _clampNavigation(_editor!.score);
    });
    unawaited(
      ref
          .read(digitalScoreEditorServiceProvider)
          .saveVersionCatalog(data.song.id, _versionCatalog),
    );
  }

  Future<void> _addVersion(DigitalScoreData data) async {
    final number = ScoreVersionCatalog.nextVersionNumber(
      _versionCatalog.versions,
    );
    final controller = TextEditingController(
      text: context.l10n.scoreVersionN(number),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.addScoreVersion),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: context.l10n.scoreVersionName),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (!mounted || name == null || name.isEmpty) return;
    final source = _editor?.score ?? data.score;
    final service = ref.read(digitalScoreEditorServiceProvider);
    final next = await service.addVersion(
      songId: data.song.id,
      source: source,
      catalog: _versionCatalog,
      name: name,
    );
    if (!mounted) return;
    final created = next.versions.last;
    _versionEditors[created.id] = MusicScoreEditor(source);
    setState(() {
      _versionCatalog = next;
      _activeVersionId = created.id;
      _selectedAddress = null;
      _showMeasureTools = false;
      _partIndex = 0;
      _measureIndex = 0;
      _clampNavigation(_editor!.score);
    });
  }

  Future<void> _deleteActiveVersion(DigitalScoreData data) async {
    if (_activeVersionId == scoreVersionOriginalId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.deleteScoreVersion),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.delete),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    final deletedId = _activeVersionId;
    final next = await ref
        .read(digitalScoreEditorServiceProvider)
        .deleteVersion(
          songId: data.song.id,
          versionId: deletedId,
          catalog: _versionCatalog,
        );
    if (!mounted) return;
    _versionEditors.remove(deletedId);
    setState(() {
      _versionCatalog = next;
      _activeVersionId = scoreVersionOriginalId;
      _selectedAddress = null;
      _showMeasureTools = false;
      _partIndex = 0;
      _measureIndex = 0;
      _clampNavigation(_editor!.score);
    });
  }

  void _togglePlayback() {
    setState(() => _playbackEnabled = !_playbackEnabled);
    if (!_playbackEnabled) _playback.stop();
  }

  void _onMenuSelected(
    _ScoreMenuAction action,
    DigitalScoreData data,
    MusicScore score,
  ) {
    switch (action) {
      case _ScoreMenuAction.transpose:
        _transpose(score, originalFifths: data.originalFifths);
      case _ScoreMenuAction.exportMusicXml:
        _export(data, score, ScoreExportKind.musicXml);
      case _ScoreMenuAction.exportMidi:
        _export(data, score, ScoreExportKind.midi);
      case _ScoreMenuAction.exportPdf:
        _export(data, score, ScoreExportKind.pdf);
      case _ScoreMenuAction.exportProject:
        _export(data, score, ScoreExportKind.project);
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
      score: score,
    );
    if (!mounted || request == null) return;
    _apply(
      TransposeScoreCommand(
        semitones: request.semitones,
        fifthsDelta: request.fifthsDelta,
      ),
    );
  }

  void _selectMeasure(int measureIndex) {
    final editor = _editor;
    if (!_editing || editor == null) return;
    final measures = editor.score.parts.first.measures;
    if (measureIndex < 0 || measureIndex >= measures.length) return;
    setState(() {
      _measureIndex = measureIndex;
      _showMeasureTools = true;
      _selectedAddress = null;
    });
  }

  void _onNoteTapped(AlphaTabNoteTappedEvent hit) {
    final editor = _editor;
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
      _showMeasureTools = true;
      _editorMode = ScoreEditorMode.select;
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
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _activeVersionId,
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      for (final version in _versionCatalog.selectable)
                        DropdownMenuItem(
                          value: version.id,
                          child: Text(_versionLabel(version)),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      unawaited(_switchVersion(versionId: id, data: value));
                    },
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.addScoreVersion,
                  onPressed: () => unawaited(_addVersion(value)),
                  icon: const Icon(Icons.playlist_add_rounded),
                ),
                if (_activeVersionId != scoreVersionOriginalId)
                  IconButton(
                    tooltip: context.l10n.deleteScoreVersion,
                    onPressed: () => unawaited(_deleteActiveVersion(value)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                IconButton(
                  tooltip: context.l10n.scoreEdit,
                  isSelected: _editing,
                  onPressed: () => setState(() {
                    _editing = !_editing;
                    if (!_editing) {
                      _selectedAddress = null;
                      _showMeasureTools = false;
                      final view = _scoreViewKey.currentState;
                      if (view != null) unawaited(view.cancelMeasureDrag());
                    } else {
                      _editorMode = ScoreEditorMode.select;
                    }
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
                if (_exporting)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  PopupMenuButton<_ScoreMenuAction>(
                    tooltip: context.l10n.scoreTools,
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) =>
                        _onMenuSelected(action, value, score),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _ScoreMenuAction.transpose,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.swap_vert_rounded),
                          title: Text(context.l10n.scoreTranspose),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _ScoreMenuAction.exportPdf,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.picture_as_pdf_outlined),
                          title: Text('PDF'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _ScoreMenuAction.exportMusicXml,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.music_note_rounded),
                          title: Text('MusicXML'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _ScoreMenuAction.exportProject,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.folder_zip_outlined),
                          title: Text(context.l10n.scoreProject),
                        ),
                      ),
                      const PopupMenuItem(
                        value: _ScoreMenuAction.exportMidi,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.graphic_eq_rounded),
                          title: Text('MIDI'),
                        ),
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
                    key: _scoreViewKey,
                    score: _viewScore(score),
                    semanticsLabel: value.song.title,
                    playback: _playback,
                    playbackVisible: _playbackEnabled,
                    highlightedMeasureIndex: _editing ? _measureIndex : null,
                    oneFingerPan: !_editing,
                    inputMode: !_editing
                        ? 'off'
                        : switch (_editorMode) {
                            ScoreEditorMode.note => 'note',
                            ScoreEditorMode.rest => 'rest',
                            ScoreEditorMode.select => 'select',
                          },
                    inputDurationType: _inputDurationType,
                    inputRest: _editorMode == ScoreEditorMode.rest,
                    onNoteTapped: _onNoteTapped,
                    onStaffTapped: _placeStaffNote,
                    onMeasureTapped: _selectMeasure,
                    onMeasureMoved: _moveMeasure,
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
                        padBottomSafeArea: !_editing,
                        onPlayPause: () => _playback.playPause(),
                        onStop: () => _playback.stop(),
                        onSeek: (positionMs) => _playback.seek(positionMs),
                      );
                    },
                  ),
                if (_editing && _showMeasureTools)
                  _MeasureToolsBar(
                    canDelete: score.measureCount > 1,
                    onAdd: _insertMeasureAfter,
                    onRemove: _deleteMeasure,
                    onDuplicate: _duplicateMeasure,
                    onDrag: _startMeasureDrag,
                  ),
                if (_editing)
                  ScoreEditorPanel(
                    canUndo: editor.canUndo,
                    canRedo: editor.canRedo,
                    mode: _editorMode,
                    selectedEvent: _selectedEvent,
                    inputDurationType: _inputDurationType,
                    inputAlter: _inputAlter,
                    onUndo: _undo,
                    onRedo: _redo,
                    onModeChanged: (mode) => setState(() {
                      _editorMode = mode;
                      if (mode != ScoreEditorMode.select) {
                        _selectedAddress = null;
                        _showMeasureTools = false;
                      }
                    }),
                    onDurationTypeChanged: (type) =>
                        setState(() => _inputDurationType = type),
                    onInputAlterChanged: (alter) =>
                        setState(() => _inputAlter = alter),
                    onEditSelected: _editSelected,
                    onAddChord: _addChord,
                    onDeleteSelected: () {
                      final address = _selectedAddress;
                      if (address != null) {
                        _apply(DeleteScoreEventCommand(address));
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MeasureToolsBar extends StatelessWidget {
  const _MeasureToolsBar({
    required this.canDelete,
    required this.onAdd,
    required this.onRemove,
    required this.onDuplicate,
    required this.onDrag,
  });

  final bool canDelete;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onDrag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: AppColors.canvas,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.insertMeasureAfter,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                ),
                IconButton(
                  tooltip: l10n.deleteMeasure,
                  onPressed: canDelete ? onRemove : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                IconButton(
                  tooltip: l10n.duplicateMeasure,
                  onPressed: onDuplicate,
                  icon: const Icon(Icons.copy_all_rounded),
                ),
                IconButton(
                  tooltip: l10n.dragMeasure,
                  onPressed: onDrag,
                  icon: const Icon(Icons.drag_indicator_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _LeaveAction { discard, save }

enum _ScoreMenuAction {
  transpose,
  exportMusicXml,
  exportMidi,
  exportPdf,
  exportProject,
}
