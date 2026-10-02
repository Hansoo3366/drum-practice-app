import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
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
import 'package:page_a_diddle/features/digital_score/data/engraved_pdf_exporter.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_reviewer.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/digital_score/data/score_export_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_advice.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input_feature.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_transpose.dart';
import 'package:page_a_diddle/features/digital_score/presentation/arrangement_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_correction_screen.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_review_screen.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_part_sheet.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/playback_sequence_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_editor_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_playback_bar.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_proofread_screen.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_structure_controller.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_transpose_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';

part 'digital_score_screen_widgets.dart';

/// The scores of [plans] (a name and what to write) over the melody of
/// [source], with [corrections] made to its chords first. A top-level
/// function, so the isolate is sent these values and nothing of the screen.
Future<List<({String name, String xml})>> _instrumentScoresInBackground(
  String source,
  List<ChordCorrection> corrections,
  Map<AccompanimentInstrument, String> names,
  List<({String name, AccompanimentSetup setup})> plans,
) => Isolate.run(() {
  final corrected = applyChordCorrections(source, corrections);
  return [
    for (final plan in plans)
      (
        name: plan.name,
        xml: accompanimentMusicXml(corrected, setup: plan.setup, names: names),
      ),
  ];
});

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
  List<ScoreSystemSpan> _systems = const [];
  bool _editing = false;
  bool _playbackEnabled = false;
  bool _saving = false;
  String? _pendingVersionName;
  bool _exporting = false;
  bool _fetchingAi = false;
  bool _confirmingLeave = false;
  bool _showMeasureTools = false;
  bool _showSequencePanel = false;
  StructureTab _structureTab = StructureTab.sections;

  /// Sections, playback order and the panel's line pick.
  late final ScoreStructureController _structure = ScoreStructureController(
    versionId: () => _activeVersionId,
    save: (versionId, sequence) => ref
        .read(digitalScoreEditorServiceProvider)
        .saveSequence(
          songId: widget.songId,
          versionId: versionId,
          sequence: sequence,
        ),
    onSaveFailed: () {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
    },
  )..addListener(_onStructureChanged);

  PlaybackSequence get _sequence => _structure.sequence;

  void _onStructureChanged() {
    if (mounted) setState(() {});
  }

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
    _structure.dispose();
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
        // The order panel saves as it goes; bar edits move sections and
        // are saved with the edited score.
        (_editing && !_structure.isSaved);
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
      _structure.load(
        materializePlaybackSequence(
          data.activeVersionScore ?? data.score,
          data.sequence,
        ),
      );
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

  ({int measures, int writtenMeasures, String time, int skipped})
  _sequenceSummary(MusicScore score) {
    try {
      final summary = performanceSummary(score, _sequence);
      final bpm = score.tempoBpm ?? 120;
      return (
        measures: summary.measures,
        writtenMeasures: score.measureCount,
        time: formatPlaybackLength(summary.quarters * 60 / bpm),
        skipped: summary.skipped,
      );
    } on FormatException {
      return (
        measures: 0,
        writtenMeasures: score.measureCount,
        time: '-',
        skipped: 0,
      );
    }
  }

  /// The score as it plays. Built again only when what it is made from
  /// changes: the score view takes a new object for a new performance and
  /// stops playing, so an unrelated rebuild must hand it the same one.
  MusicScore _performanceScore(MusicScore written) {
    final editing = _editing || _showSequencePanel;
    final made = _performance;
    if (made != null &&
        identical(made.written, written) &&
        made.editing == editing &&
        made.playbackEnabled == _playbackEnabled &&
        made.sequence == _sequence &&
        made.arrangement == _arrangement) {
      return made.score;
    }
    final score = displayedDigitalScore(
      written: written,
      editing: editing,
      playbackEnabled: _playbackEnabled,
      sequence: _sequence,
      arrangement: _arrangement,
    );
    _performance = (
      written: written,
      editing: editing,
      playbackEnabled: _playbackEnabled,
      sequence: _sequence,
      arrangement: _arrangement,
      score: score,
    );
    return score;
  }

  ({
    MusicScore written,
    bool editing,
    bool playbackEnabled,
    PlaybackSequence sequence,
    ArrangementProfile arrangement,
    MusicScore score,
  })?
  _performance;

  Future<bool> _save(DigitalScoreData data, MusicScoreEditor editor) async {
    if (_saving) return false;
    if (_pendingVersionName == null &&
        editor.isDirty &&
        _activeVersionId == scoreVersionOriginalId) {
      // The original is never written: its edits become a version.
      final number = ScoreVersionCatalog.nextVersionNumber(
        _versionCatalog.versions,
      );
      final name = await showDialog<String>(
        context: context,
        builder: (context) => _ScoreVersionDialog(
          initialName: context.l10n.scoreVersionN(number),
        ),
      );
      if (!mounted || name == null || name.trim().isEmpty) return false;
      _pendingVersionName = name.trim();
    }
    if (_pendingVersionName != null) return _saveNewVersion(data, editor);
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(digitalScoreEditorServiceProvider);
      if (editor.isDirty) {
        await service.save(
          songId: data.song.id,
          relativePath: data.song.sourcePath,
          score: editor.score,
          sequence: _sequence,
          arrangement: _arrangement,
          versionId: _activeVersionId,
        );
      } else {
        await service.saveSidecars(
          songId: data.song.id,
          versionId: _activeVersionId,
          sequence: _sequence,
          arrangement: _arrangement,
        );
      }
      editor.markSaved();
      _versionXml.remove(_activeVersionId);
      _savedArrangement = _arrangement;
      _structure.markSaved();
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
      // Section boundaries followed the edited bars; they belong to the copy.
      await service.saveSequence(
        songId: data.song.id,
        versionId: created.id,
        sequence: _sequence,
      );
      if (!mounted) return true;
      editor.resetTo(previousSavedScore);
      _versionEditors[created.id] = MusicScoreEditor(source);
      setState(() {
        _versionCatalog = next;
        _activeVersionId = created.id;
        _pendingVersionName = null;
        _editing = false;
        _savedArrangement = _arrangement;
        _structure.markSaved();
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
      final exported =
          await _exportFromFile(data, written, kind) ??
          await const ScoreExportService().encode(
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

  /// The export made from the version's own file, so nothing the editing
  /// model does not hold is lost (tuplets, dynamics, generated instrument
  /// parts and their sounds): MusicXML as written with the user's sections,
  /// in playing order when an order is set; MIDI as it plays; PDF as the
  /// viewer engraves it, every part and staff.
  ///
  /// Null when there is no file to export from (unsaved edits, playback
  /// accompaniment on, a project export): the model is exported then.
  Future<ScoreExport?> _exportFromFile(
    DigitalScoreData data,
    MusicScore written,
    ScoreExportKind kind,
  ) async {
    final editor = _editor;
    if (editor == null ||
        kind == ScoreExportKind.project ||
        _editing ||
        editor.isDirty ||
        _arrangement.isNotOff) {
      return null;
    }
    final l10n = context.l10n;
    final view = _scoreViewKey.currentState;
    final String source;
    try {
      source = await _activeSourceXml(data, editor);
    } on Object {
      return null;
    }
    final title = safeExportFileName(data.song.title);
    if (kind == ScoreExportKind.midi) {
      final midi = await buildPlaybackMidiInBackground(
        engravingXml: source,
        score: written,
        sequence: _sequence,
        arrangement: ArrangementProfile.off,
        bpm: (written.tempoBpm ?? 120).round(),
      );
      return ScoreExport(
        bytes: playbackMidiFile(midi),
        fileName: '$title.mid',
        extension: 'mid',
      );
    }
    // The score in playing order when the user set one, with the sections
    // at the bars where each step starts.
    var xml = source;
    var score = written;
    var sequence = _sequence;
    if (_sequence.steps.isNotEmpty) {
      xml = expandMusicXml(source, performanceMeasureMap(written, _sequence));
      score = const MusicXmlCodec().decodeXml(xml);
      sequence = PlaybackSequence(
        marks: performanceSectionMarks(written, _sequence),
      );
    }
    if (sequence.marks.isNotEmpty) {
      xml = withSectionRehearsals(xml, [
        for (final section in scoreSections(score, sequence))
          if (section.name.isNotEmpty && !section.continued)
            (
              measureIndex: section.startMeasureIndex,
              label: scoreSectionLabel(l10n, section),
            ),
      ]);
    }
    if (kind == ScoreExportKind.musicXml) {
      return ScoreExport(
        bytes: Uint8List.fromList(utf8.encode(xml)),
        fileName: '$title.musicxml',
        extension: 'musicxml',
      );
    }
    if (view == null) return null;
    final pages = await view.engravePages(xml);
    if (pages.isEmpty) return null;
    return ScoreExport(
      bytes: await const EngravedPdfExporter().export(
        pages,
        title: data.song.title,
        text: await rootBundle.load('assets/fonts/SUIT-Regular.ttf'),
        fallbacks: [
          await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'),
        ],
      ),
      fileName: '$title.pdf',
      extension: 'pdf',
    );
  }

  void _apply(
    ScoreEditCommand command, {
    ScoreEventAddress? selectedAddress,
    NoteCaret? caret,
  }) {
    final editor = _editor;
    if (editor == null) return;
    try {
      final before = editor.measureIds;
      final written = rehearsalSectionMarks(editor.score);
      editor.apply(command);
      _structure.followMeasureEdits(
        before,
        editor.measureIds,
        writtenMarks: written,
      );
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
    final before = editor.measureIds;
    final written = rehearsalSectionMarks(editor.score);
    setState(() {
      editor.undo();
      _structure.followMeasureEdits(
        before,
        editor.measureIds,
        writtenMarks: written,
      );
      _selectedAddress = null;
      _clampNavigation(editor.score);
    });
  }

  void _redo() {
    final editor = _editor;
    if (editor == null || !editor.canRedo) return;
    final before = editor.measureIds;
    final written = rehearsalSectionMarks(editor.score);
    setState(() {
      editor.redo();
      _structure.followMeasureEdits(
        before,
        editor.measureIds,
        writtenMarks: written,
      );
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
    await _structure.saving;
    if (!mounted) return;
    if (!_structure.isSaved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saveSequenceFirst)));
      return;
    }
    try {
      if (versionId != scoreVersionOriginalId) {
        final existing = _versionEditors[versionId];
        if (existing == null) {
          final service = ref.read(digitalScoreEditorServiceProvider);
          final version = await service.loadVersion(
            songId: data.song.id,
            versionId: versionId,
          );
          if (!mounted) return;
          if (version == null) return;
          _versionEditors[versionId] = MusicScoreEditor(version.score);
          if (version.xml case final xml?) _versionXml[versionId] = xml;
        }
      }
      final target = versionId == scoreVersionOriginalId
          ? _originalEditor!.score
          : _versionEditors[versionId]!.score;
      final sequence = materializePlaybackSequence(
        target,
        await ref
            .read(digitalScoreEditorServiceProvider)
            .loadSequence(data.song.id, versionId: versionId),
      );
      if (!mounted) return;
      setState(() {
        _activeVersionId = versionId;
        _structure.load(sequence);
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
        !_structure.isSaved;
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
      _structure.clearPick();
      // Without sections there is no order to set yet.
      final score = _editor?.score;
      _structureTab = score == null || scoreSections(score, _sequence).isEmpty
          ? StructureTab.sections
          : StructureTab.order;
      if (_showSequencePanel) _editing = false;
      _selectedAddress = null;
      _showMeasureTools = false;
    });
  }

  void _nameSection(MusicScore score, String name) {
    final bar = _structure.pickStart;
    if (bar == null) return;
    final end = _structure.pickEnd;
    try {
      _structure.update(
        end == null
            ? setSectionBoundary(
                score,
                _sequence,
                measureIndex: bar,
                name: name,
              )
            : setSectionRange(
                score,
                _sequence,
                start: bar,
                end: end,
                name: name,
              ),
      );
      // The range is now a section starting at the first bar; show it as one.
      // The next tap starts a new pick.
      _structure.endPick();
    } on Object {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.changeFailed)));
    }
  }

  Future<void> _nameSectionCustom(MusicScore score) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _SectionNameDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    _nameSection(score, name);
  }

  void _removeSectionBoundary(MusicScore score) {
    final bar = _structure.pickStart;
    if (bar == null) return;
    _structure.update(
      removeSectionBoundary(score, _sequence, measureIndex: bar),
    );
  }

  /// Raw MusicXML of the active version as saved, so an expanded copy keeps
  /// markings the codec does not model. Unsaved note edits use the codec.
  Future<String> _activeSourceXml(
    DigitalScoreData data,
    MusicScoreEditor editor,
  ) async {
    if (editor.isDirty) {
      return utf8.decode(const MusicXmlCodec().encodeMusicXml(editor.score));
    }
    if (_activeVersionId == scoreVersionOriginalId) {
      if (data.sourceXml case final xml?) return xml;
    } else {
      final cached = _versionXml[_activeVersionId];
      if (cached != null) return cached;
      final loaded = await ref
          .read(digitalScoreEditorServiceProvider)
          .loadVersionXml(data.song.id, _activeVersionId);
      if (loaded != null) return loaded;
    }
    return utf8.decode(const MusicXmlCodec().encodeMusicXml(editor.score));
  }

  /// The score version laid out in the current order, made earlier from
  /// this version and order, or null.
  ScoreVersionRef? get _scoreFromOrder {
    if (_sequence.steps.isEmpty) return null;
    final origin = performanceOrigin(_activeVersionId, _sequence);
    return _versionCatalog.versions
        .where((version) => version.origin == origin)
        .firstOrNull;
  }

  /// Opens the score laid out in the current order, making it first when
  /// there is none yet. The current version stays as it is.
  Future<void> _openScoreFromOrder(
    DigitalScoreData data,
    MusicScoreEditor editor,
  ) async {
    if (_sequence.steps.isEmpty) return;
    await _structure.saving;
    if (!mounted) return;
    final made = _scoreFromOrder;
    if (made == null) {
      await _makePerformanceVersion(
        data,
        editor,
        origin: performanceOrigin(_activeVersionId, _sequence),
      );
      return;
    }
    _toggleSequencePanel();
    await _switchVersion(versionId: made.id, data: data);
  }

  /// Closes the panel once the last change is saved.
  Future<void> _closeStructurePanel() async {
    await _structure.saving;
    if (mounted && _showSequencePanel) _toggleSequencePanel();
  }

  Future<void> _makePerformanceVersion(
    DigitalScoreData data,
    MusicScoreEditor editor, {
    required String origin,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (editor.isDirty || _arrangement != _savedArrangement) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveBeforeProofread)));
      return;
    }
    final number = ScoreVersionCatalog.nextVersionNumber(
      _versionCatalog.versions,
    );
    // The written score keeps its version; the playing order becomes a new
    // score the user opens like any other version.
    final name = l10n.performanceVersionName(number);
    setState(() => _saving = true);
    try {
      final service = ref.read(digitalScoreEditorServiceProvider);
      final source = await _activeSourceXml(data, editor);
      final expanded = expandMusicXml(
        source,
        performanceMeasureMap(editor.score, _sequence),
      );
      final catalog = await service.addXmlVersion(
        songId: data.song.id,
        musicXml: expanded,
        catalog: _versionCatalog,
        name: name.trim(),
        origin: origin,
      );
      // The copy is already in playing order, so it gets no order of its own,
      // only the sections at the bars where each step now starts.
      await service.saveSequence(
        songId: data.song.id,
        versionId: catalog.activeId,
        sequence: PlaybackSequence(
          marks: performanceSectionMarks(editor.score, _sequence),
        ),
      );
      if (!mounted) return;
      setState(() {
        _versionCatalog = catalog.copyWith(activeId: _activeVersionId);
        _showSequencePanel = false;
      });
      await _switchVersion(versionId: catalog.activeId, data: data);
      messenger.showSnackBar(SnackBar(content: Text(l10n.scoreSaved)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Gets the server's AI version of a converted score, running the AI
  /// review again when it failed at import, and opens it.
  Future<void> _fetchAiVersion(DigitalScoreData data) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_isDirty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveBeforeProofread)));
      return;
    }
    setState(() => _fetchingAi = true);
    messenger.showSnackBar(SnackBar(content: Text(l10n.aiFetching)));
    try {
      final result = await ref
          .read(omrConvertServiceProvider)
          .fetchAiVersion(data.song.id);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (result != OmrAiFetch.added) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (result) {
              OmrAiFetch.unchanged => l10n.aiFetchUnchanged,
              OmrAiFetch.expired => l10n.aiFetchExpired,
              OmrAiFetch.unavailable => l10n.aiFetchUnavailable,
              _ => l10n.aiFetchFailed,
            }),
          ),
        );
        return;
      }
      final catalog = await ref
          .read(digitalScoreEditorServiceProvider)
          .loadVersionCatalog(data.song.id);
      if (!mounted) return;
      setState(
        () => _versionCatalog = catalog.copyWith(activeId: _activeVersionId),
      );
      await _switchVersion(versionId: catalog.activeId, data: data);
    } on Object {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.aiFetchFailed)));
      }
    } finally {
      if (mounted) setState(() => _fetchingAi = false);
    }
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
      case _ScoreMenuAction.playbackOrder:
        _toggleSequencePanel();
      case _ScoreMenuAction.review:
        unawaited(_showQualitySheet(data));
      case _ScoreMenuAction.fetchAi:
        unawaited(_fetchAiVersion(data));
      case _ScoreMenuAction.deleteVersion:
        unawaited(_deleteActiveVersion(data));
      case _ScoreMenuAction.transpose:
        unawaited(_transpose(data, score));
      case _ScoreMenuAction.threeStaff:
        unawaited(_makeThreeStaff(data, score));
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

  /// Transposes the version on screen into a new version, written from its
  /// file so lyrics, tuplets, line breaks and every other marking stay. The
  /// version itself, and the original, are never changed.
  Future<void> _transpose(DigitalScoreData data, MusicScore score) async {
    final editor = _editor;
    if (editor == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_isDirty || _editing) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveBeforeProofread)));
      return;
    }
    final request = await showScoreTransposeSheet(
      context,
      currentFifths: concertKeyFifths(score),
      originalFifths: data.originalFifths,
      score: score,
    );
    if (!mounted || request == null) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(digitalScoreEditorServiceProvider);
      final transposed = transposeMusicXml(
        await _activeSourceXml(data, editor),
        semitones: request.semitones,
        fifthsDelta: request.fifthsDelta,
      );
      final key = keyTonicLabel(
        wrapKeyFifths(concertKeyFifths(score) + request.fifthsDelta),
      );
      final catalog = await service.addXmlVersion(
        songId: data.song.id,
        musicXml: transposed,
        catalog: _versionCatalog,
        name: _uniqueVersionName(l10n.transposedVersionName(key)),
      );
      // Same bars: the sections and order carry over.
      await service.saveSequence(
        songId: data.song.id,
        versionId: catalog.activeId,
        sequence: _sequence,
      );
      if (!mounted) return;
      setState(() {
        _versionCatalog = catalog.copyWith(activeId: _activeVersionId);
      });
      await _switchVersion(versionId: catalog.activeId, data: data);
      messenger.showSnackBar(SnackBar(content: Text(l10n.scoreSaved)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Makes a version with a piano part under the melody: the chords of the
  /// chord symbols for the right hand, their bass for the left. The version
  /// on screen, and the original, are never changed.
  Future<void> _makeThreeStaff(DigitalScoreData data, MusicScore score) async {
    final editor = _editor;
    if (editor == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_isDirty || _editing) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveBeforeProofread)));
      return;
    }
    setState(() => _saving = true);
    try {
      final shown = await _activeSourceXml(data, editor);
      // A score that already has a generated piano part gets a new one, in
      // the style chosen now, from its melody.
      final earlier = generatedAccompaniment(shown);
      final source = withoutGeneratedAccompaniment(shown);
      final obstacle = analyzeLeadSheet(source).obstacle;
      if (obstacle != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              obstacle == ThreeStaffObstacle.noChords
                  ? l10n.threeStaffNeedsChords
                  : l10n.threeStaffNeedsMelody,
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _saving = false);
      final request = await showPianoPartSheet(
        context,
        advise: () => _arrangementAdvice(source, score),
        initial: earlier?.setup ?? const AccompanimentSetup(),
        roles: {
          for (final section in scoreSections(score, _sequence))
            if (!section.continued)
              section.startMeasureIndex: SectionRole.fromSectionName(
                section.name,
              ),
        },
      );
      if (!mounted || request == null) return;
      setState(() => _saving = true);
      final service = ref.read(digitalScoreEditorServiceProvider);
      final names = {
        for (final instrument in request.instruments)
          instrument: accompanimentInstrumentLabel(l10n, instrument),
      };
      // One score per instrument, named after it, or one for them all.
      // Written in the background: each score reads the melody again.
      final scores = await _instrumentScoresInBackground(
        source,
        request.corrections,
        names,
        request.separate
            ? [
                for (final instrument in request.instruments)
                  (
                    name: names[instrument]!,
                    setup: request.setupFor(instrument),
                  ),
              ]
            : [(name: l10n.threeStaffVersionName, setup: request.setup)],
      );
      if (!mounted) return;
      var catalog = _versionCatalog;
      for (final made in scores) {
        catalog = await service.addXmlVersion(
          songId: data.song.id,
          musicXml: made.xml,
          catalog: catalog,
          name: _uniqueVersionName(made.name, catalog: catalog),
        );
        // Same bars: the sections and order carry over.
        await service.saveSequence(
          songId: data.song.id,
          versionId: catalog.activeId,
          sequence: _sequence,
        );
      }
      if (!mounted) return;
      final opened = catalog.activeId;
      setState(() {
        _versionCatalog = catalog.copyWith(activeId: _activeVersionId);
      });
      await _switchVersion(versionId: opened, data: data);
      messenger.showSnackBar(SnackBar(content: Text(l10n.scoreSaved)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Asks the server what style suits the lead sheet [source], section by
  /// section, and which chord symbols look misread.
  Future<ArrangementAdvice> _arrangementAdvice(
    String source,
    MusicScore score,
  ) async {
    final brief = arrangementBrief(
      source,
      tempoBpm: score.tempoBpm,
      sections: [
        for (final section in scoreSections(score, _sequence))
          if (section.name.isNotEmpty && !section.continued)
            (
              name: '${section.name.toLowerCase()}${section.number ?? ''}',
              start: section.startMeasureIndex + 1,
              end: section.endMeasureIndex + 1,
            ),
      ],
    );
    final answer = await ref
        .read(omrConvertClientProvider)
        .arrangementAdvice(brief: brief, bars: score.measureCount);
    return ArrangementAdvice.fromJson(answer, source);
  }

  /// [name], or "[name] 2", "[name] 3" when a version has that name.
  String _uniqueVersionName(String name, {ScoreVersionCatalog? catalog}) {
    final used = {
      for (final version in (catalog ?? _versionCatalog).versions) version.name,
    };
    if (!used.contains(name)) return name;
    var number = 2;
    while (used.contains('$name $number')) {
      number++;
    }
    return '$name $number';
  }

  void _selectMeasure(int measureIndex) {
    if (_showSequencePanel) {
      // Sections are picked by staff line: a tap takes the whole line, a tap
      // on a later line extends the pick to that line's end.
      ScoreSystemSpan? line;
      for (final system in _systems) {
        if (system.contains(measureIndex)) line = system;
      }
      final lineStart = line?.startMeasureIndex ?? measureIndex;
      final lineEnd = line?.endMeasureIndex ?? measureIndex;
      setState(() => _structureTab = StructureTab.sections);
      _structure.pickLine(lineStart, lineEnd);
      return;
    }
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
        content: Text(
          editor.isDirty || _arrangement != _savedArrangement
              ? context.l10n.unsavedChangesBody
              : context.l10n.sequenceUnsavedBody,
        ),
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
          onReview: () {
            Navigator.of(context).pop();
            unawaited(_showOmrReview(data));
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

  Future<void> _showProofread(DigitalScoreData data) async {
    if (_isDirty || _editing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saveBeforeProofread)));
      return;
    }
    final service = ref.read(digitalScoreEditorServiceProvider);
    try {
      final xml = _activeVersionId == scoreVersionOriginalId
          ? data.sourceXml
          : await service.loadVersionXml(data.song.id, _activeVersionId);
      if (!mounted || xml == null) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ScoreProofreadScreen(
            songId: data.song.id,
            musicXml: xml,
            catalog: _versionCatalog,
            measureIndex: _reviewMeasureIndex ?? 0,
            sequence: _sequence,
          ),
        ),
      );
      if (saved != true || !mounted) return;
      await _openProofreadVersion(data);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  /// Opens the version the proofreading editor just saved.
  Future<void> _openProofreadVersion(DigitalScoreData data) async {
    final service = ref.read(digitalScoreEditorServiceProvider);
    // The editor saved the sections and order with the version, moved along
    // where bars were added or removed.
    final catalog = await service.loadVersionCatalog(data.song.id);
    if (!mounted) return;
    setState(() => _versionCatalog = catalog);
    await _switchVersion(versionId: catalog.activeId, data: data);
    ref.invalidate(digitalScoreDataProvider(widget.songId));
  }

  /// The measures the conversion server doubts, with the original beside
  /// what was recognised.
  Future<void> _showOmrReview(DigitalScoreData data) async {
    if (_isDirty || _editing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.saveBeforeProofread)));
      return;
    }
    final service = ref.read(digitalScoreEditorServiceProvider);
    final storage = ref.read(songFileStorageProvider);
    try {
      final songId = data.song.id;
      final bars = omrReviewBars(
        validationJson: await storage.loadOmrValidation(songId),
        aiReviewJson: await storage.loadOmrAiReview(songId),
      );
      if (!mounted) return;
      if (bars.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('검토할 의심 마디가 없습니다.')));
        return;
      }
      final checked = omrReviewChecked(
        await storage.loadOmrReviewState(songId),
      );
      final annotations = omrAnnotations(
        await storage.loadOmrAnnotations(songId),
      );
      final xml = _activeVersionId == scoreVersionOriginalId
          ? data.sourceXml
          : await service.loadVersionXml(songId, _activeVersionId);
      if (!mounted || xml == null) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OmrReviewScreen(
            songId: songId,
            musicXml: xml,
            catalog: _versionCatalog,
            bars: bars,
            checked: checked,
            annotations: annotations,
          ),
        ),
      );
      if (saved != true || !mounted) return;
      await _openProofreadVersion(data);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
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
        // Folded phones cannot fit every score action in the app bar.
        final compact = MediaQuery.sizeOf(context).width < 600;
        final sections = scoreSections(score, _sequence);
        ScoreSection? selectedSection;
        if (_showSequencePanel && _structure.pickStart != null) {
          for (final section in sections) {
            // Only a section that starts here is "selected"; a bar in the
            // middle of one is a new start, not the whole section.
            if (section.startMeasureIndex == _structure.pickStart) {
              selectedSection = section;
            }
          }
        }
        final pickedRange = _showSequencePanel
            ? (_structure.pickEnd != null
                  ? (start: _structure.pickStart!, end: _structure.pickEnd!)
                  : _structure.pickingEnd || selectedSection == null
                  ? null
                  : (
                      start: selectedSection.startMeasureIndex,
                      end: selectedSection.endMeasureIndex,
                    ))
            : null;
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
                      selectedItemBuilder: (context) => [
                        for (final version in _versionCatalog.selectable)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: compact ? 96 : 200,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _versionLabel(version),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
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
                  if (!compact)
                    IconButton(
                      tooltip: context.l10n.playbackSequence,
                      isSelected: _showSequencePanel,
                      onPressed: _toggleSequencePanel,
                      icon: const Icon(Icons.playlist_play_rounded),
                    ),
                  if (!compact && value.quality != null)
                    IconButton(
                      tooltip: context.l10n.omrReview,
                      onPressed: () => unawaited(_showQualitySheet(value)),
                      icon: Badge(
                        isLabelVisible: value.quality!.issues.isNotEmpty,
                        label: Text('${value.quality!.issues.length}'),
                        child: const Icon(Icons.fact_check_outlined),
                      ),
                    ),
                  if (!compact && _activeVersionId != scoreVersionOriginalId)
                    IconButton(
                      tooltip: context.l10n.deleteScoreVersion,
                      onPressed: () => unawaited(_deleteActiveVersion(value)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  if (!_editing && value.sourceXml != null)
                    IconButton(
                      tooltip: context.l10n.proofread,
                      onPressed: () => unawaited(_showProofread(value)),
                      icon: const Icon(Icons.edit_outlined),
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
                        if (compact) ...[
                          PopupMenuItem(
                            value: _ScoreMenuAction.playbackOrder,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.playlist_play_rounded),
                              title: Text(context.l10n.playbackSequence),
                            ),
                          ),
                          if (value.quality != null)
                            PopupMenuItem(
                              value: _ScoreMenuAction.review,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Badge(
                                  isLabelVisible:
                                      value.quality!.issues.isNotEmpty,
                                  label: Text(
                                    '${value.quality!.issues.length}',
                                  ),
                                  child: const Icon(Icons.fact_check_outlined),
                                ),
                                title: Text(context.l10n.omrReview),
                              ),
                            ),
                          if (value.omrJobId != null &&
                              !_versionCatalog.versions.any(
                                (version) =>
                                    version.origin == aiVersionOrigin ||
                                    version.name == aiCorrectedVersionName,
                              ))
                            PopupMenuItem(
                              value: _ScoreMenuAction.fetchAi,
                              enabled: !_fetchingAi,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.auto_fix_high_outlined,
                                ),
                                title: Text(context.l10n.fetchAiVersion),
                              ),
                            ),
                          if (_activeVersionId != scoreVersionOriginalId)
                            PopupMenuItem(
                              value: _ScoreMenuAction.deleteVersion,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.delete_outline_rounded,
                                ),
                                title: Text(context.l10n.deleteScoreVersion),
                              ),
                            ),
                          const PopupMenuDivider(),
                        ],
                        PopupMenuItem(
                          value: _ScoreMenuAction.transpose,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.swap_vert_rounded),
                            title: Text(context.l10n.scoreTranspose),
                          ),
                        ),
                        PopupMenuItem(
                          value: _ScoreMenuAction.threeStaff,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.queue_music_rounded),
                            title: Text(context.l10n.makeThreeStaff),
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
                      // Playback order does not change the notation, so an
                      // unsaved order keeps the source engraving.
                      engravingXml:
                          (_editing || editor.isDirty || _arrangement.isNotOff)
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
                      highlightedMeasureIndex: _showSequencePanel
                          ? _structure.pickStart
                          : _editing
                          ? _measureIndex
                          : _reviewMeasureIndex,
                      highlightedMeasureRange: pickedRange,
                      // Sections the user set replace the printed rehearsal
                      // boxes on screen; the file itself is not touched.
                      rehearsalMarks: _sequence.marks.isEmpty
                          ? null
                          : [
                              for (final section in sections)
                                // A piece continuing the same section (split
                                // at a jump) gets no box of its own.
                                if (section.name.isNotEmpty &&
                                    !section.continued)
                                  (
                                    measureIndex: section.startMeasureIndex,
                                    label: scoreSectionLabel(
                                      context.l10n,
                                      section,
                                    ),
                                  ),
                            ],
                      oneFingerPan: !_editing,
                      inputMode: _showSequencePanel
                          ? 'select'
                          : !_editing
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
                      onNoteTapped: _editing ? _onNoteTapped : null,
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
                      tab: _structureTab,
                      onTabChanged: (tab) =>
                          setState(() => _structureTab = tab),
                      sequence: _sequence,
                      sections: sections,
                      selectedBar: _structure.pickStart,
                      selectedEnd: _structure.pickEnd,
                      picking: _structure.pickingEnd,
                      summary: _sequenceSummary(score),
                      canUndo: _structure.canUndo,
                      onUndo: _structure.undo,
                      onClose: () => unawaited(_closeStructurePanel()),
                      onSectionNamed: (name) => _nameSection(score, name),
                      onCustomSection: () =>
                          unawaited(_nameSectionCustom(score)),
                      onBoundaryRemoved: () => _removeSectionBoundary(score),
                      onStepsChanged: (steps) =>
                          _structure.update(_sequence.copyWith(steps: steps)),
                      onBuildFromScore: () => _structure.update(
                        writtenOrderSequence(score, _sequence),
                      ),
                      madeScoreExists: _scoreFromOrder != null,
                      onMakeScore: _saving
                          ? null
                          : () => unawaited(_openScoreFromOrder(value, editor)),
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
