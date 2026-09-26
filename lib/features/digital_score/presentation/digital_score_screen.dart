import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_empty_state.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_data.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_reviewer.dart';
import 'package:page_a_diddle/features/digital_score/data/score_export_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input_feature.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';
import 'package:page_a_diddle/features/digital_score/presentation/arrangement_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_correction_screen.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/playback_sequence_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_editor_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_playback_bar.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_transpose_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';

class DigitalScoreScreen extends ConsumerStatefulWidget {
  const DigitalScoreScreen({required this.songId, super.key});

  final String songId;

  @override
  ConsumerState<DigitalScoreScreen> createState() => _DigitalScoreScreenState();
}

class _DigitalScoreScreenState extends ConsumerState<DigitalScoreScreen> {
  final _playback = PianoScorePlaybackController();
  final _scoreViewKey = GlobalKey<VerovioScoreViewState>();
  final Map<String, MusicScoreEditor> _versionEditors = {};
  final Map<String, String> _versionXml = {};
  MusicScoreEditor? _originalEditor;
  String? _loadedSongId;
  ScoreVersionCatalog _versionCatalog = ScoreVersionCatalog.empty;
  String _activeVersionId = scoreVersionOriginalId;
  ArrangementProfile _arrangement = ArrangementProfile.off;
  ArrangementProfile _savedArrangement = ArrangementProfile.off;
  PlaybackSequence _sequence = PlaybackSequence.empty;
  PlaybackSequence _savedSequence = PlaybackSequence.empty;
  List<ScoreSystemSpan> _systems = const [];
  bool _editing = false;
  bool _playbackEnabled = false;
  bool _saving = false;
  String? _pendingVersionName;
  bool _exporting = false;
  bool _confirmingLeave = false;
  bool _showMeasureTools = false;
  bool _showSequencePanel = false;
  int _partIndex = 0;
  int _measureIndex = 0;
  int? _reviewMeasureIndex;
  ScoreEventAddress? _selectedAddress;
  ScoreEditorMode _editorMode = ScoreEditorMode.select;
  String _inputDurationType = 'quarter';
  int _inputAlter = 0;
  int _inputDots = 0;
  bool _inputChord = false;
  NoteCaret? _caret;

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
    return originalDirty ||
        versionDirty ||
        _arrangement != _savedArrangement ||
        _sequence != _savedSequence;
  }

  MusicScoreEditor _editorFor(DigitalScoreData data) {
    if (_loadedSongId != data.song.id) {
      _originalEditor = MusicScoreEditor(data.score);
      _versionEditors.clear();
      _versionXml.clear();
      _versionCatalog = data.versionCatalog;
      _activeVersionId = data.versionCatalog.activeId;
      if (_activeVersionId != scoreVersionOriginalId &&
          data.activeVersionScore != null) {
        _versionEditors[_activeVersionId] = MusicScoreEditor(
          data.activeVersionScore!,
        );
        if (data.activeVersionXml != null) {
          _versionXml[_activeVersionId] = data.activeVersionXml!;
        }
      } else {
        _activeVersionId = scoreVersionOriginalId;
      }
      _loadedSongId = data.song.id;
      _arrangement = data.arrangement;
      _savedArrangement = data.arrangement;
      _sequence = data.sequence;
      _savedSequence = data.sequence;
      _partIndex = 0;
      _measureIndex = 0;
      _selectedAddress = null;
      _showMeasureTools = false;
      _showSequencePanel = false;
      _systems = const [];
      _pendingVersionName = null;
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

  MusicScore _performanceScore(MusicScore written) {
    return displayedDigitalScore(
      written: written,
      editing: _editing || _showSequencePanel,
      playbackEnabled: _playbackEnabled,
      sequence: _sequence,
      arrangement: _arrangement,
    );
  }

  Future<bool> _save(DigitalScoreData data, MusicScoreEditor editor) async {
    if (_saving) return false;
    if (_pendingVersionName != null) return _saveNewVersion(data, editor);
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
            versionId: _activeVersionId,
          );
      editor.markSaved();
      _versionXml.remove(_activeVersionId);
      _savedArrangement = _arrangement;
      _savedSequence = _sequence;
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

  Future<bool> _saveNewVersion(
    DigitalScoreData data,
    MusicScoreEditor editor,
  ) async {
    final name = _pendingVersionName?.trim();
    if (name == null || name.isEmpty) return false;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(digitalScoreEditorServiceProvider);
      final previousSavedScore = _activeVersionId == scoreVersionOriginalId
          ? data.score
          : await service.loadVersionScore(
              songId: data.song.id,
              versionId: _activeVersionId,
            );
      if (!mounted) return false;
      if (previousSavedScore == null) {
        throw StateError('The active score version could not be reloaded.');
      }
      final source = editor.score;
      final next = await service.addVersion(
        songId: data.song.id,
        source: source,
        catalog: _versionCatalog,
        name: name,
      );
      if (!mounted) return true;
      final created = next.versions.last;
      editor.resetTo(previousSavedScore);
      _versionEditors[created.id] = MusicScoreEditor(source);
      setState(() {
        _versionCatalog = next;
        _activeVersionId = created.id;
        _pendingVersionName = null;
        _editing = false;
        _savedArrangement = _arrangement;
        _savedSequence = _sequence;
        _selectedAddress = null;
        _showMeasureTools = false;
        _partIndex = 0;
        _measureIndex = 0;
        _clampNavigation(_editor!.score);
      });
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

  void _apply(
    ScoreEditCommand command, {
    ScoreEventAddress? selectedAddress,
    NoteCaret? caret,
  }) {
    final editor = _editor;
    if (editor == null) return;
    try {
      editor.apply(command);
      setState(() {
        _selectedAddress = selectedAddress;
        if (caret != null) {
          _caret = caret;
          _partIndex = caret.partIndex
              .clamp(0, editor.score.parts.length - 1)
              .toInt();
          _measureIndex = caret.measureIndex
              .clamp(0, editor.score.parts[_partIndex].measures.length - 1)
              .toInt();
        }
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

  NoteCaret get _inputCaret {
    final editor = _editor;
    final caret = _caret;
    if (caret != null) return caret;
    final measureIndex = editor == null
        ? _measureIndex
        : _measureIndex
              .clamp(0, math.max(0, editor.score.measureCount - 1))
              .toInt();
    return NoteCaret(
      partIndex: _partIndex,
      measureIndex: measureIndex,
      staff: 1,
      onset: 0,
    );
  }

  void _rememberCaret(NoteCaret caret, {ScoreEventAddress? address}) {
    final editor = _editor;
    setState(() {
      _caret = caret;
      _selectedAddress = address;
      if (editor == null || editor.score.parts.isEmpty) return;
      _partIndex = caret.partIndex
          .clamp(0, editor.score.parts.length - 1)
          .toInt();
      final measures = editor.score.parts[_partIndex].measures;
      if (measures.isEmpty) return;
      _measureIndex = math.min(caret.measureIndex, measures.length - 1).toInt();
    });
  }

  void _commitNoteInput(NoteWriteResult result, NoteInputRequest? request) {
    if (!result.changed || request == null) {
      _rememberCaret(result.caret, address: result.address);
      return;
    }
    _apply(
      WriteNoteInputCommand(request),
      selectedAddress: result.address,
      caret: result.caret,
    );
  }

  void _placeStaffNote(AlphaTabStaffTappedEvent hit) {
    final editor = _editor;
    if (editor == null || !_editing) return;
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
        _caret = NoteCaret(
          partIndex: hit.partIndex,
          measureIndex: hit.measureIndex,
          staff: hit.staff,
          onset: onset,
          voice: voiceOnStaff(measure, staff: hit.staff, onset: onset),
        );
      });
      return;
    }
    final request = NoteInputRequest(
      partIndex: hit.partIndex,
      measureIndex: hit.measureIndex,
      staff: hit.staff,
      onsetTicks: hit.onsetTicks,
      midi: hit.midi,
      durationType: _inputDurationType,
      dots: _inputDots,
      alter: _inputAlter,
      rest: _editorMode == ScoreEditorMode.rest,
      chord: _inputChord && _editorMode == ScoreEditorMode.note,
    );
    _commitNoteInput(writeNoteInput(editor.score, request), request);
  }

  void _changeSelectedDuration(String type, {int? dots}) {
    final editor = _editor;
    final address = _selectedAddress;
    if (editor == null || address == null) return;
    if (_selectedEvent is! MusicNote) return;
    final result = changeNoteDuration(
      editor.score,
      address,
      durationType: type,
      dots: dots ?? _inputDots,
    );
    if (!result.changed) {
      _rememberCaret(result.caret, address: result.address);
      return;
    }
    _apply(
      ChangeNoteDurationCommand(
        address: address,
        durationType: type,
        dots: dots ?? _inputDots,
      ),
      selectedAddress: result.address,
      caret: result.caret,
    );
  }

  void _nudgeSelected({int semitones = 0, int octaves = 0}) {
    final editor = _editor;
    final address = _selectedAddress;
    if (editor == null || address == null) return;
    final result = octaves != 0
        ? shiftNoteOctave(editor.score, address, octaves: octaves)
        : repitchNote(editor.score, address, semitones: semitones);
    if (!result.changed) return;
    _apply(
      octaves != 0
          ? ShiftNoteOctaveCommand(address, octaves)
          : RepitchNoteCommand(address, semitones),
      selectedAddress: address,
      caret: result.caret,
    );
  }

  KeyEventResult _onNoteKey(KeyEvent event) {
    if (event is! KeyDownEvent || !_editing) return KeyEventResult.ignored;
    final editor = _editor;
    if (editor == null) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final control =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final durations = {
      LogicalKeyboardKey.digit3: '16th',
      LogicalKeyboardKey.digit4: 'eighth',
      LogicalKeyboardKey.digit5: 'quarter',
      LogicalKeyboardKey.digit6: 'half',
      LogicalKeyboardKey.digit7: 'whole',
    };
    final duration = durations[key];
    if (duration != null) {
      setState(() => _inputDurationType = duration);
      if (_editorMode == ScoreEditorMode.select) {
        _changeSelectedDuration(duration);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.period) {
      final dots = _inputDots == 0 ? 1 : 0;
      setState(() => _inputDots = dots);
      if (_editorMode == ScoreEditorMode.select) {
        _changeSelectedDuration(_inputDurationType, dots: dots);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final delta = key == LogicalKeyboardKey.arrowUp ? 1 : -1;
      _nudgeSelected(
        semitones: control ? 0 : delta,
        octaves: control ? delta : 0,
      );
      return KeyEventResult.handled;
    }
    final letter = switch (key) {
      LogicalKeyboardKey.keyA => 'a',
      LogicalKeyboardKey.keyB => 'b',
      LogicalKeyboardKey.keyC => 'c',
      LogicalKeyboardKey.keyD => 'd',
      LogicalKeyboardKey.keyE => 'e',
      LogicalKeyboardKey.keyF => 'f',
      LogicalKeyboardKey.keyG => 'g',
      _ => null,
    };
    final restKey =
        key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0;
    if (letter == null && !restKey) return KeyEventResult.ignored;
    if (_editorMode == ScoreEditorMode.select) {
      setState(() => _editorMode = ScoreEditorMode.note);
    }
    final caret = _inputCaret;
    if (caret.partIndex < 0 || caret.partIndex >= editor.score.parts.length) {
      return KeyEventResult.handled;
    }
    final measures = editor.score.parts[caret.partIndex].measures;
    if (caret.measureIndex < 0 || caret.measureIndex >= measures.length) {
      return KeyEventResult.handled;
    }
    final measure = measures[caret.measureIndex];
    final midi = letter == null
        ? 60
        : midiForLetter(
            letter,
            previousMidi: previousMidiOnStaff(editor.score, caret),
            staff: caret.staff,
          );
    final request = NoteInputRequest(
      partIndex: caret.partIndex,
      measureIndex: caret.measureIndex,
      staff: caret.staff,
      onsetTicks: onsetToTicks(caret.onset, measure.attributes.divisions),
      midi: midi,
      durationType: _inputDurationType,
      dots: _inputDots,
      alter: _inputAlter,
      rest: restKey || _editorMode == ScoreEditorMode.rest,
      chord: !restKey && (shift || _inputChord),
    );
    _commitNoteInput(writeNoteInput(editor.score, request), request);
    return KeyEventResult.handled;
  }

  void _moveStaffNote(AlphaTabNoteDraggedEvent hit) {
    final editor = _editor;
    if (!_editing || _editorMode != ScoreEditorMode.select || editor == null) {
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
    try {
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
          final xml = await service.loadVersionXml(data.song.id, versionId);
          if (!mounted) return;
          if (xml != null) _versionXml[versionId] = xml;
        }
      }
      setState(() {
        _activeVersionId = versionId;
        _versionCatalog = _versionCatalog.copyWith(activeId: versionId);
        _pendingVersionName = null;
        _editing = false;
        _selectedAddress = null;
        _showMeasureTools = false;
        _partIndex = 0;
        _measureIndex = 0;
        _clampNavigation(_editor!.score);
      });
      await _persistVersionCatalog(data.song.id);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
    }
  }

  Future<void> _beginEditing() async {
    if (!noteInputEnabled || _saving || _editing) return;
    final number = ScoreVersionCatalog.nextVersionNumber(
      _versionCatalog.versions,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _ScoreVersionDialog(initialName: context.l10n.scoreVersionN(number)),
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    setState(() {
      _pendingVersionName = name.trim();
      _editing = true;
      _showSequencePanel = false;
      _selectedAddress = null;
      _showMeasureTools = false;
      _editorMode = ScoreEditorMode.select;
    });
  }

  void _endEditing() {
    if (!_editing) return;
    final hasPendingChanges =
        _editor?.isDirty == true ||
        _arrangement != _savedArrangement ||
        _sequence != _savedSequence;
    setState(() {
      _editing = false;
      if (!hasPendingChanges) _pendingVersionName = null;
      _selectedAddress = null;
      _showMeasureTools = false;
      final view = _scoreViewKey.currentState;
      if (view != null) unawaited(view.cancelMeasureDrag());
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
    late final ScoreVersionCatalog next;
    try {
      next = await ref
          .read(digitalScoreEditorServiceProvider)
          .deleteVersion(
            songId: data.song.id,
            versionId: deletedId,
            catalog: _versionCatalog,
          );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      return;
    }
    if (!mounted) return;
    _versionEditors.remove(deletedId);
    setState(() {
      _versionCatalog = next;
      _activeVersionId = scoreVersionOriginalId;
      _pendingVersionName = null;
      _editing = false;
      _selectedAddress = null;
      _showMeasureTools = false;
      _partIndex = 0;
      _measureIndex = 0;
      _clampNavigation(_editor!.score);
    });
  }

  Future<void> _persistVersionCatalog(String songId) async {
    await ref
        .read(digitalScoreEditorServiceProvider)
        .saveVersionCatalog(songId, _versionCatalog);
  }

  void _togglePlayback() {
    setState(() => _playbackEnabled = !_playbackEnabled);
    if (!_playbackEnabled) _playback.stop();
  }

  void _toggleSequencePanel() {
    setState(() {
      _showSequencePanel = !_showSequencePanel;
      if (_showSequencePanel) _editing = false;
      _selectedAddress = null;
      _showMeasureTools = false;
    });
  }

  void _updateSequence(PlaybackSequence next) {
    if (_sequence == next) return;
    setState(() => _sequence = next);
  }

  void _changeSequenceRepeats(int index, int repeats) {
    if (index < 0 || index >= _sequence.items.length) return;
    final items = _sequence.items.toList();
    items[index] = items[index].copyWith(repeats: repeats);
    _updateSequence(PlaybackSequence(items));
  }

  void _moveSequenceItem(int fromIndex, int toIndex) {
    if (fromIndex < 0 ||
        fromIndex >= _sequence.items.length ||
        toIndex < 0 ||
        toIndex >= _sequence.items.length) {
      return;
    }
    final items = _sequence.items.toList();
    final item = items.removeAt(fromIndex);
    items.insert(toIndex, item);
    _updateSequence(PlaybackSequence(items));
  }

  void _addSequenceSection(String section) {
    if (_sequence.items.any((item) => item.section == section)) return;
    _updateSequence(
      PlaybackSequence([
        ..._sequence.items,
        PlaybackSequenceItem(section: section),
      ]),
    );
  }

  void _removeSequenceItem(int index) {
    if (index < 0 || index >= _sequence.items.length) return;
    final items = _sequence.items.toList()..removeAt(index);
    _updateSequence(PlaybackSequence(items));
  }

  Future<void> _editArrangement(MusicScore score) async {
    final next = await showArrangementSheet(
      context,
      profile: _arrangement,
      score: score,
    );
    if (!mounted || next == null) return;
    setState(() => _arrangement = next);
  }

  void _onMenuSelected(
    _ScoreMenuAction action,
    DigitalScoreData data,
    MusicScore score,
  ) {
    switch (action) {
      case _ScoreMenuAction.transpose:
        _transpose(score, originalFifths: data.originalFifths);
      case _ScoreMenuAction.arrangement:
        _editArrangement(score);
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
    if ((!_editing && !_showSequencePanel) || editor == null) return;
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
    final event = editor
        .score
        .parts[address.partIndex]
        .measures[address.measureIndex]
        .events[address.eventIndex];
    setState(() {
      _partIndex = address.partIndex;
      _measureIndex = address.measureIndex;
      _selectedAddress = address;
      _showMeasureTools = true;
      _editorMode = ScoreEditorMode.select;
      if (event is MusicNote) {
        _caret = NoteCaret(
          partIndex: address.partIndex,
          measureIndex: address.measureIndex,
          staff: event.staff,
          onset: event.onset,
          voice: event.voice,
        );
      }
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

  Future<void> _showQualitySheet(DigitalScoreData data) async {
    final report = data.quality;
    if (report == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _OmrQualitySheet(
          data: data,
          report: report,
          onCorrect: () {
            Navigator.of(context).pop();
            unawaited(_showOmrCorrection(data));
          },
          onJump: (index) {
            setState(() {
              _measureIndex = index;
              _reviewMeasureIndex = index;
            });
          },
          onReviewed: (updated) async {
            await ref
                .read(songFileStorageProvider)
                .saveOmrQuality(widget.songId, jsonEncode(updated.toJson()));
            ref.invalidate(digitalScoreDataProvider(widget.songId));
          },
        );
      },
    );
  }

  Future<void> _showOmrCorrection(DigitalScoreData data) async {
    if (_isDirty || _editing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('편집을 저장하거나 취소한 뒤 원본을 대조하세요.')),
      );
      return;
    }
    final service = ref.read(digitalScoreEditorServiceProvider);
    try {
      final xml = _activeVersionId == scoreVersionOriginalId
          ? data.sourceXml
          : await service.loadVersionXml(data.song.id, _activeVersionId);
      if (!mounted || xml == null) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => OmrCorrectionScreen(
            songId: data.song.id,
            musicXml: xml,
            catalog: _versionCatalog,
          ),
        ),
      );
      if (!mounted) return;
      final catalog = await service.loadVersionCatalog(data.song.id);
      if (!mounted) return;
      setState(() => _versionCatalog = catalog);
      await _switchVersion(versionId: catalog.activeId, data: data);
      ref.invalidate(digitalScoreDataProvider(widget.songId));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  int? _measureIndexFor(MusicScore score, String number) {
    for (final part in score.parts) {
      final index = part.measures.indexWhere(
        (measure) => measure.number == number,
      );
      if (index >= 0) return index;
    }
    return int.tryParse(number);
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
        return Focus(
          autofocus: _editing,
          onKeyEvent: (node, event) => _onNoteKey(event),
          child: PopScope(
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
                    tooltip: context.l10n.playbackSequence,
                    isSelected: _showSequencePanel,
                    onPressed: _toggleSequencePanel,
                    icon: const Icon(Icons.playlist_play_rounded),
                  ),
                  if (value.quality != null)
                    IconButton(
                      tooltip: context.l10n.omrReview,
                      onPressed: () => unawaited(_showQualitySheet(value)),
                      icon: Badge(
                        isLabelVisible: value.quality!.issues.isNotEmpty,
                        label: Text('${value.quality!.issues.length}'),
                        child: const Icon(Icons.fact_check_outlined),
                      ),
                    ),
                  if (_activeVersionId != scoreVersionOriginalId)
                    IconButton(
                      tooltip: context.l10n.deleteScoreVersion,
                      onPressed: () => unawaited(_deleteActiveVersion(value)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  if (noteInputEnabled)
                    IconButton(
                      tooltip: context.l10n.scoreEdit,
                      isSelected: _editing,
                      onPressed: _editing
                          ? _endEditing
                          : () => unawaited(_beginEditing()),
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
                        PopupMenuItem(
                          value: _ScoreMenuAction.arrangement,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.piano_rounded),
                            title: Text(context.l10n.scoreArrangement),
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
                    child: VerovioScoreView(
                      key: _scoreViewKey,
                      score: score,
                      engravingXml:
                          (_editing || _isDirty || _arrangement.isNotOff)
                          ? null
                          : _activeVersionId == scoreVersionOriginalId
                          ? value.sourceXml
                          : _versionXml[_activeVersionId],
                      playbackScore: _playbackEnabled
                          ? _performanceScore(score)
                          : null,
                      playbackSequence: _playbackEnabled
                          ? _sequence
                          : PlaybackSequence.empty,
                      playbackArrangement: _playbackEnabled
                          ? _arrangement
                          : ArrangementProfile.off,
                      semanticsLabel: value.song.title,
                      playback: _playback,
                      playbackVisible: _playbackEnabled,
                      highlightedMeasureIndex: (_editing || _showSequencePanel)
                          ? _measureIndex
                          : _reviewMeasureIndex,
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
                      inputAlter: _inputAlter,
                      inputDots: _inputDots,
                      inputCaret: _editing ? _caret : null,
                      onNoteTapped: _onNoteTapped,
                      onStaffTapped: _placeStaffNote,
                      onMeasureTapped: _selectMeasure,
                      onSystemsChanged: (systems) {
                        if (listEquals(_systems, systems)) return;
                        setState(() => _systems = systems);
                      },
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
                          onEditSequence: _toggleSequencePanel,
                          onEditArrangement: () =>
                              unawaited(_editArrangement(score)),
                          sequenceSelected: _showSequencePanel,
                          arrangementSelected: _arrangement.isNotOff,
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
                  if (_showSequencePanel)
                    ScoreStructurePanel(
                      score: score,
                      sequence: _sequence,
                      measureIndex: _measureIndex.clamp(
                        0,
                        math.max(0, score.measureCount - 1),
                      ),
                      onSectionChanged: (section) => _apply(
                        UpdateSystemSectionCommand(
                          measureIndex: _measureIndex,
                          section: section,
                          systems: _systems,
                        ),
                      ),
                      onRepeatsChanged: _changeSequenceRepeats,
                      onSectionMoved: _moveSequenceItem,
                      onSectionAdded: _addSequenceSection,
                      onSectionRemoved: _removeSequenceItem,
                      onDone: _toggleSequencePanel,
                    ),
                  if (_editing)
                    ScoreEditorPanel(
                      canUndo: editor.canUndo,
                      canRedo: editor.canRedo,
                      mode: _editorMode,
                      selectedEvent: _selectedEvent,
                      inputDurationType: _inputDurationType,
                      inputAlter: _inputAlter,
                      inputDots: _inputDots,
                      inputChord: _inputChord,
                      editSelectionDuration:
                          _editorMode == ScoreEditorMode.select &&
                          _selectedEvent is MusicNote,
                      onToggleDot: () {
                        final dots = _inputDots == 0 ? 1 : 0;
                        setState(() => _inputDots = dots);
                        if (_editorMode == ScoreEditorMode.select) {
                          _changeSelectedDuration(
                            _inputDurationType,
                            dots: dots,
                          );
                        }
                      },
                      onToggleChord: () =>
                          setState(() => _inputChord = !_inputChord),
                      onPitchDown:
                          _selectedEvent is MusicNote &&
                              !(_selectedEvent! as MusicNote).isRest
                          ? () => _nudgeSelected(semitones: -1)
                          : null,
                      onPitchUp:
                          _selectedEvent is MusicNote &&
                              !(_selectedEvent! as MusicNote).isRest
                          ? () => _nudgeSelected(semitones: 1)
                          : null,
                      onOctaveDown:
                          _selectedEvent is MusicNote &&
                              !(_selectedEvent! as MusicNote).isRest
                          ? () => _nudgeSelected(octaves: -1)
                          : null,
                      onOctaveUp:
                          _selectedEvent is MusicNote &&
                              !(_selectedEvent! as MusicNote).isRest
                          ? () => _nudgeSelected(octaves: 1)
                          : null,
                      onUndo: _undo,
                      onRedo: _redo,
                      onModeChanged: (mode) => setState(() {
                        _editorMode = mode;
                        _caret ??= _inputCaret;
                        if (mode != ScoreEditorMode.select) {
                          _showMeasureTools = false;
                        }
                      }),
                      onDurationTypeChanged: (type) {
                        setState(() => _inputDurationType = type);
                        if (_editorMode == ScoreEditorMode.select) {
                          _changeSelectedDuration(type);
                        }
                      },
                      onInputAlterChanged: (alter) =>
                          setState(() => _inputAlter = alter),
                      onEditSelected: _editSelected,
                      onAddChord: _addChord,
                      onDeleteSelected: () {
                        final editor = _editor;
                        final address = _selectedAddress;
                        if (editor == null || address == null) return;
                        final result = deleteNoteRestoringRest(
                          editor.score,
                          address,
                        );
                        if (!result.changed) return;
                        _apply(
                          DeleteNoteRestoringRestCommand(address),
                          caret: result.caret,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScoreVersionDialog extends StatefulWidget {
  const _ScoreVersionDialog({required this.initialName});

  final String initialName;

  @override
  State<_ScoreVersionDialog> createState() => _ScoreVersionDialogState();
}

class _ScoreVersionDialogState extends State<_ScoreVersionDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.scoreVersionName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.scoreVersionName),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(context.l10n.save)),
      ],
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

class _OmrQualitySheet extends ConsumerStatefulWidget {
  const _OmrQualitySheet({
    required this.data,
    required this.report,
    required this.onJump,
    required this.onReviewed,
    required this.onCorrect,
  });

  final DigitalScoreData data;
  final OmrQualityReport report;
  final void Function(int index) onJump;
  final Future<void> Function(OmrQualityReport updated) onReviewed;
  final VoidCallback onCorrect;

  @override
  ConsumerState<_OmrQualitySheet> createState() => _OmrQualitySheetState();
}

class _OmrQualitySheetState extends ConsumerState<_OmrQualitySheet> {
  late OmrQualityReport _report = widget.report;
  final _keyController = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _runAi() async {
    final xml = widget.data.sourceXml;
    if (xml == null) {
      setState(() => _error = '원본 MusicXML이 없습니다.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(omrAiReviewerProvider)
          .review(
            songId: widget.data.song.id,
            score: widget.data.score,
            musicXml: xml,
            report: _report,
          );
      await widget.onReviewed(updated);
      if (mounted) setState(() => _report = updated);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final match = _report.sourceMatch;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            l10n.omrHealthScore(_report.score),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (match != null) ...[
            const SizedBox(height: 8),
            Text(
              match.hasReference
                  ? [
                      if (match.chordRecall != null)
                        '코드 ${match.chordHitCount}/${match.chordRefCount} (${match.chordRecall}%)',
                      if (match.lyricRecall != null)
                        '가사 ${match.lyricHitCount}/${match.lyricRefCount} (${match.lyricRecall}%)',
                      if (match.combined != null) '원본 대조 ${match.combined}%',
                    ].join(' · ')
                  : '원본 PDF에 대조할 텍스트가 없습니다.',
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : widget.onCorrect,
            icon: const Icon(Icons.compare_outlined),
            label: const Text('원본 마디 대조·수정'),
          ),
          TextField(
            controller: _keyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'XAI_API_KEY',
              hintText: l10n.omrAiNeedKey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        await ref
                            .read(omrAiReviewerProvider)
                            .saveKey(_keyController.text);
                      },
                child: Text(l10n.omrAiSaveKey),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _runAi,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.omrAiRun),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          if (_report.issues.isEmpty)
            Text(l10n.omrReviewEmpty)
          else
            for (final entry in _report.groupedByRule.entries)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                leading: Icon(switch (entry.value.first.severity) {
                  OmrIssueSeverity.high => Icons.error_outline,
                  OmrIssueSeverity.medium => Icons.warning_amber_outlined,
                  OmrIssueSeverity.low => Icons.info_outline,
                }),
                title: Text(omrRuleHeadline(entry.key)),
                subtitle: Text('${entry.key} · ${entry.value.length}곳'),
                children: [
                  for (final issue in entry.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(issue.message),
                      subtitle: Text(
                        [
                          if (issue.measureNumber != null)
                            '마디 ${issue.measureNumber}',
                          if (issue.ai != null)
                            issue.ai!.corrections.isEmpty
                                ? 'AI: 수정 없음 (${issue.ai!.overallConfidence.toStringAsFixed(2)})'
                                : 'AI: ${issue.ai!.corrections.map((c) => '${c.property} ${c.currentValue}→${c.suggestedValue}').join(', ')}',
                        ].join(' · '),
                      ),
                      onTap: issue.measureNumber == null
                          ? null
                          : () {
                              final index = widget
                                  .data
                                  .score
                                  .parts
                                  .first
                                  .measures
                                  .indexWhere(
                                    (measure) =>
                                        measure.number == issue.measureNumber,
                                  );
                              if (index >= 0) widget.onJump(index);
                              Navigator.pop(context);
                            },
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

enum _LeaveAction { discard, save }

enum _ScoreMenuAction {
  transpose,
  arrangement,
  exportMusicXml,
  exportMidi,
  exportPdf,
  exportProject,
}
