import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/blank_piano_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_editor_panel.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';

/// Blank piano score used by the Edit tab.
///
/// Note entry follows the same replace-mode contract as an opened score:
/// duration first, tap or letter for pitch, and the bar stays filled.
class PianoDraftEditorScreen extends ConsumerStatefulWidget {
  const PianoDraftEditorScreen({super.key});

  @override
  ConsumerState<PianoDraftEditorScreen> createState() =>
      _PianoDraftEditorScreenState();
}

class _PianoDraftEditorScreenState
    extends ConsumerState<PianoDraftEditorScreen> {
  static const _codec = MusicXmlCodec();

  final _playback = PianoScorePlaybackController();
  late final MusicScoreEditor _editor = MusicScoreEditor(
    blankPianoScore(title: 'New piano score'),
  );

  ScoreEditorMode _mode = ScoreEditorMode.note;
  String _durationType = 'quarter';
  int _alter = 0;
  int _dots = 0;
  bool _chord = false;
  bool _saving = false;
  NoteCaret _caret = const NoteCaret(
    partIndex: 0,
    measureIndex: 0,
    staff: 1,
    onset: 0,
  );
  ScoreEventAddress? _selected;

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  MusicEvent? get _selectedEvent {
    final address = _selected;
    if (address == null) return null;
    final measures = _editor.score.parts[address.partIndex].measures;
    if (address.measureIndex >= measures.length) return null;
    final events = measures[address.measureIndex].events;
    if (address.eventIndex < 0 || address.eventIndex >= events.length) {
      return null;
    }
    return events[address.eventIndex];
  }

  void _commit(NoteWriteResult result, ScoreEditCommand? command) {
    if (result.changed && command != null) {
      _editor.apply(command);
    }
    setState(() {
      _caret = result.caret;
      _selected = result.address;
    });
  }

  void _place(AlphaTabStaffTappedEvent hit) {
    if (_mode == ScoreEditorMode.select) {
      final measure =
          _editor.score.parts[hit.partIndex].measures[hit.measureIndex];
      final onset = onsetFromTicks(
        hit.onsetTicks,
        measure.attributes.divisions,
      );
      setState(() {
        _caret = NoteCaret(
          partIndex: hit.partIndex,
          measureIndex: hit.measureIndex,
          staff: hit.staff,
          onset: onset,
        );
        _selected = findNoteAt(
          score: _editor.score,
          partIndex: hit.partIndex,
          measureIndex: hit.measureIndex,
          staff: hit.staff,
          onset: onset,
          midi: hit.midi,
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
      durationType: _durationType,
      dots: _dots,
      alter: _alter,
      rest: _mode == ScoreEditorMode.rest,
      chord: _chord && _mode == ScoreEditorMode.note,
    );
    final result = writeNoteInput(_editor.score, request);
    _commit(result, result.changed ? WriteNoteInputCommand(request) : null);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = await _askTitle();
    if (title == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final score = _editor.score.copyWith(title: title);
      final id = await ref
          .read(musicXmlImportServiceProvider)
          .importMusicXml(
            file: PickedLocalFile(
              name: 'score.musicxml',
              bytes: _codec.encode(score, MusicXmlFileFormat.musicXml),
            ),
            title: title,
          );
      _editor.markSaved();
      if (!mounted) return;
      context.go('/score/$id');
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askTitle() {
    final controller = TextEditingController(text: context.l10n.newPianoScore);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.createScore),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.scoreVersionName),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final pitched =
        _selectedEvent is MusicNote && !(_selectedEvent! as MusicNote).isRest;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.newPianoScore),
        actions: [
          IconButton(
            tooltip: context.l10n.undo,
            onPressed: _editor.canUndo ? () => setState(_editor.undo) : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: context.l10n.redo,
            onPressed: _editor.canRedo ? () => setState(_editor.redo) : null,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: context.l10n.addMeasure,
            onPressed: () => setState(() {
              final after = math.min(
                _caret.measureIndex,
                math.max(0, _editor.score.measureCount - 1),
              );
              _editor.apply(InsertMeasureCommand(afterMeasureIndex: after));
            }),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: context.l10n.save,
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: VerovioScoreView(
              score: _editor.score,
              playbackSequence: PlaybackSequence.empty,
              playbackArrangement: ArrangementProfile.off,
              semanticsLabel: context.l10n.newPianoScore,
              playback: _playback,
              oneFingerPan: false,
              inputMode: switch (_mode) {
                ScoreEditorMode.note => 'note',
                ScoreEditorMode.rest => 'rest',
                ScoreEditorMode.select => 'select',
              },
              inputDurationType: _durationType,
              inputRest: _mode == ScoreEditorMode.rest,
              inputAlter: _alter,
              inputDots: _dots,
              inputCaret: _caret,
              selectedNoteAddress: _selected,
              onStaffTapped: _place,
              onNoteTapped: (hit) {
                final address = findRenderedNoteAddress(
                  score: _editor.score,
                  partIndex: hit.partIndex,
                  measureIndex: hit.measureIndex,
                  staff: hit.staff,
                  onsetTicks: hit.onsetTicks,
                  midi: hit.midi,
                );
                if (address == null) return;
                setState(() {
                  _selected = address;
                  _mode = ScoreEditorMode.select;
                });
              },
            ),
          ),
          ScoreEditorPanel(
            canUndo: _editor.canUndo,
            canRedo: _editor.canRedo,
            mode: _mode,
            selectedEvent: _selectedEvent,
            inputDurationType: _durationType,
            inputAlter: _alter,
            inputDots: _dots,
            inputChord: _chord,
            editSelectionDuration:
                _mode == ScoreEditorMode.select && _selectedEvent is MusicNote,
            onToggleDot: () => setState(() => _dots = _dots == 0 ? 1 : 0),
            onToggleChord: () => setState(() => _chord = !_chord),
            onPitchDown: pitched
                ? () => _retune(RepitchNoteCommand(_selected!, -1))
                : null,
            onPitchUp: pitched
                ? () => _retune(RepitchNoteCommand(_selected!, 1))
                : null,
            onOctaveDown: pitched
                ? () => _retune(ShiftNoteOctaveCommand(_selected!, -1))
                : null,
            onOctaveUp: pitched
                ? () => _retune(ShiftNoteOctaveCommand(_selected!, 1))
                : null,
            onUndo: () => setState(_editor.undo),
            onRedo: () => setState(_editor.redo),
            onModeChanged: (mode) => setState(() => _mode = mode),
            onDurationTypeChanged: (type) =>
                setState(() => _durationType = type),
            onInputAlterChanged: (alter) => setState(() => _alter = alter),
            onEditSelected: () {},
            onAddChord: () {},
            onDeleteSelected: () {
              final address = _selected;
              if (address == null) return;
              final result = deleteNoteRestoringRest(_editor.score, address);
              _commit(
                result,
                result.changed ? DeleteNoteRestoringRestCommand(address) : null,
              );
            },
          ),
        ],
      ),
    );
  }

  void _retune(ScoreEditCommand command) {
    final address = _selected;
    if (address == null) return;
    final before = _editor.score;
    _editor.apply(command);
    if (identical(before, _editor.score)) return;
    setState(() {});
  }
}
