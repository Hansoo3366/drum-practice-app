import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_data.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/data/score_export_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/blank_piano_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/staff_note_input.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';
import 'package:page_a_diddle/features/library/domain/picked_local_file.dart';
import 'package:page_a_diddle/features/piano/data/lomse_ffi_editor_session.dart';
import 'package:page_a_diddle/features/piano/domain/app_score_element_registry.dart';
import 'package:page_a_diddle/features/piano/domain/lomse_editor_contract.dart';

/// Piano-only custom editor backed by a single Lomse native session.
///
/// Verovio remains the Flutter viewer. Lomse owns the editable MusicXML
/// snapshot and undo/redo history. App-owned target mapping is rebuilt from
/// every MusicXML snapshot before the next command crosses the FFI boundary.
class LomsePianoEditorScreen extends ConsumerStatefulWidget {
  const LomsePianoEditorScreen({this.songId, this.initialData, super.key});

  final String? songId;
  final DigitalScoreData? initialData;

  @override
  ConsumerState<LomsePianoEditorScreen> createState() =>
      _LomsePianoEditorScreenState();
}

enum _LomseInsertMode { select, note, rest, erase }

enum _LomseExportKind { musicXml, pdf }

class _LomsePianoEditorScreenState
    extends ConsumerState<LomsePianoEditorScreen> {
  static const _codec = MusicXmlCodec();

  final _playback = PianoScorePlaybackController();

  LomseEditorSession? _session;
  MusicScore? _score;
  AppScoreElementRegistry? _registry;
  String _title = 'Piano editor';
  String? _musicXml;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  int _undoDepth = 0;
  int _redoDepth = 0;
  ResolvedAppScoreTarget? _selectedTarget;
  _LomseInsertMode _insertMode = _LomseInsertMode.note;
  String _durationType = 'quarter';

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _playback.stop();
    _playback.dispose();
    final session = _session;
    if (session != null) unawaited(session.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    LomseEditorSession? session;
    try {
      final data =
          widget.initialData ??
          (widget.songId == null
              ? null
              : await ref.read(
                  digitalScoreDataProvider(widget.songId!).future,
                ));
      final sourceScore = data == null
          ? blankPianoScore(title: 'New piano score')
          : data.activeVersionScore ?? data.score;
      final sourceXml = utf8.decode(
        _codec.encode(sourceScore, MusicXmlFileFormat.musicXml),
      );
      final nativeSession = FfiLomseEditorSession.tryCreate();
      if (nativeSession == null) {
        throw StateError(
          'Lomse native bridge is unavailable in this piano build.',
        );
      }
      session = nativeSession;
      await session.loadMusicXml(sourceXml);
      final exported = await session.exportMusicXml();
      final parsed = _codec.decodeXml(exported);

      if (!mounted) {
        await session.dispose();
        return;
      }
      _session = session;
      session = null;
      setState(() {
        _title = data?.song.title ?? 'Piano editor';
        _musicXml = exported;
        _score = parsed;
        _registry = AppScoreElementRegistry(parsed);
        _loading = false;
        _error = null;
      });
    } on Object catch (error) {
      await session?.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refreshFromNative({bool dirty = true}) async {
    final session = _session;
    if (session == null) throw StateError('Lomse session is not ready.');
    final exported = await session.exportMusicXml();
    final parsed = _codec.decodeXml(exported);
    if (!mounted) return;
    setState(() {
      _musicXml = exported;
      _score = parsed;
      _registry = AppScoreElementRegistry(parsed);
      if (dirty) _dirty = true;
    });
  }

  Future<void> _insertFromStaff(AlphaTabStaffTappedEvent event) async {
    final target = _registry?.resolveStaffPosition(
      partIndex: event.partIndex,
      measureIndex: event.measureIndex,
      staff: event.staff,
      onsetTicks: event.onsetTicks,
      midi: event.midi,
    );
    if (_insertMode == _LomseInsertMode.select) {
      if (!mounted) return;
      setState(() {
        _selectedTarget = target?.eventIndex == null ? null : target;
      });
      return;
    }
    if (_insertMode == _LomseInsertMode.erase) {
      if (target?.eventIndex != null) await _deleteTarget(target!);
      return;
    }
    await _executeInsert(
      _ldpSource(midi: event.midi, staff: event.staff),
      target: target,
    );
  }

  void _selectNote(AlphaTabNoteTappedEvent event) {
    final target = _registry?.resolveStaffPosition(
      partIndex: event.partIndex,
      measureIndex: event.measureIndex,
      staff: event.staff,
      onsetTicks: event.onsetTicks,
      midi: event.midi,
    );
    if (target?.eventIndex == null) return;
    if (_insertMode == _LomseInsertMode.erase) {
      unawaited(_deleteTarget(target!));
      return;
    }
    if (!mounted) return;
    setState(() {
      _selectedTarget = target;
    });
  }

  Future<void> _insertAtCursor() async {
    await _executeInsert(_ldpSource(midi: 60, staff: 1));
  }

  Future<void> _executeInsert(
    String source, {
    ResolvedAppScoreTarget? target,
  }) async {
    final session = _session;
    if (session == null || _busy) return;
    setState(() => _busy = true);
    try {
      await session.execute(
        LomseEditRequest(
          action: 'insert_ldp',
          target: target?.key,
          values: {
            'source': source,
            if (target != null) 'cursor': target.nativeCursor,
          },
        ),
      );
      await _refreshFromNative();
      if (!mounted) return;
      setState(() {
        _undoDepth++;
        _redoDepth = 0;
        if (target?.eventIndex == null) {
          _selectedTarget = null;
        }
      });
    } on Object catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTarget(ResolvedAppScoreTarget target) async {
    final session = _session;
    if (session == null || _busy) return;
    setState(() => _busy = true);
    try {
      await session.execute(
        LomseEditRequest(
          action: 'delete_staff_obj',
          target: target.key,
          values: {'cursor': target.nativeCursor},
        ),
      );
      await _refreshFromNative();
      if (!mounted) return;
      setState(() {
        _selectedTarget = null;
        _undoDepth++;
        _redoDepth = 0;
      });
    } on Object catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nudgeSelected(int semitones) async {
    final target = _selectedTarget;
    final note = _selectedNote;
    if (target == null || note == null || note.isRest || note.pitch == null) {
      return;
    }
    final measure =
        _score!.parts[target.partIndex].measures[target.measureIndex];
    await _executeInsert(
      _ldpSource(
        midi: note.pitch!.midi + semitones,
        staff: note.staff,
        voice: note.voice,
        durationType: _durationTypeForNote(note, measure),
      ),
      target: target,
    );
  }

  ScoreEventAddress? get _selectedAddress {
    final target = _selectedTarget;
    final eventIndex = target?.eventIndex;
    if (target == null || eventIndex == null) return null;
    return ScoreEventAddress(
      partIndex: target.partIndex,
      measureIndex: target.measureIndex,
      eventIndex: eventIndex,
    );
  }

  MusicNote? get _selectedNote {
    final address = _selectedAddress;
    final score = _score;
    if (address == null || score == null) return null;
    if (address.partIndex < 0 || address.partIndex >= score.parts.length) {
      return null;
    }
    final part = score.parts[address.partIndex];
    if (address.measureIndex < 0 ||
        address.measureIndex >= part.measures.length) {
      return null;
    }
    final events = part.measures[address.measureIndex].events;
    if (address.eventIndex < 0 || address.eventIndex >= events.length) {
      return null;
    }
    final event = events[address.eventIndex];
    return event is MusicNote ? event : null;
  }

  Future<void> _undo() async {
    final session = _session;
    if (session == null || _busy || _undoDepth == 0) return;
    setState(() => _busy = true);
    try {
      await session.undo();
      await _refreshFromNative();
      if (!mounted) return;
      setState(() {
        _undoDepth--;
        _redoDepth++;
      });
    } on Object catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redo() async {
    final session = _session;
    if (session == null || _busy || _redoDepth == 0) return;
    setState(() => _busy = true);
    try {
      await session.redo();
      await _refreshFromNative();
      if (!mounted) return;
      setState(() {
        _redoDepth--;
        _undoDepth++;
      });
    } on Object catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final score = _score;
    final xml = _musicXml;
    if (score == null || xml == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (widget.songId == null) {
        final title = await _askNewScoreTitle();
        if (title == null || !mounted) return;
        final createdId = await ref
            .read(musicXmlImportServiceProvider)
            .importMusicXml(
              file: PickedLocalFile(
                name: 'score.musicxml',
                bytes: Uint8List.fromList(utf8.encode(xml)),
              ),
              title: title,
            );
        if (!mounted) return;
        setState(() => _dirty = false);
        context.go('/score/$createdId');
        return;
      }

      final data = await ref.read(
        digitalScoreDataProvider(widget.songId!).future,
      );
      await ref
          .read(digitalScoreEditorServiceProvider)
          .save(
            songId: data.song.id,
            relativePath: data.song.sourcePath,
            score: score,
            sequence: data.sequence,
            arrangement: data.arrangement,
            versionId: data.versionCatalog.activeId,
          );
      ref.invalidate(digitalScoreDataProvider(widget.songId!));
      if (!mounted) return;
      setState(() => _dirty = false);
      _showMessage('Score saved');
    } on Object catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(_LomseExportKind kind) async {
    final score = _score;
    if (score == null || _busy) return;
    setState(() => _busy = true);
    try {
      final exported = await const ScoreExportService().encode(
        written: score,
        title: score.title ?? _title,
        sequence: PlaybackSequence.empty,
        arrangement: ArrangementProfile.off,
        kind: switch (kind) {
          _LomseExportKind.musicXml => ScoreExportKind.musicXml,
          _LomseExportKind.pdf => ScoreExportKind.pdf,
        },
      );
      final extension = '.${exported.extension}';
      final fileName = exported.fileName.endsWith(extension)
          ? exported.fileName.substring(
              0,
              exported.fileName.length - extension.length,
            )
          : exported.fileName;
      await FilePicker.saveFile(
        dialogTitle: exported.fileName,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [exported.extension],
        bytes: exported.bytes,
      );
    } on Object catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askNewScoreTitle() async {
    final controller = TextEditingController(text: 'New piano score');
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create score'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (_) => Navigator.pop(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final normalized = title?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Discard the current piano edit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }

  String _ldpSource({
    required int midi,
    required int staff,
    String? voice,
    String? durationType,
  }) {
    final pitch = _ldpPitch(midi);
    final duration = _ldpDuration(durationType ?? _durationType);
    final resolvedVoice = voice ?? '1';
    return _insertMode == _LomseInsertMode.rest
        ? '(r $duration v$resolvedVoice p$staff)'
        : '(n $pitch $duration v$resolvedVoice p$staff)';
  }

  String _ldpDuration(String durationType) => switch (durationType) {
    'whole' => 'w',
    'half' => 'h',
    'quarter' => 'q',
    'eighth' => 'e',
    _ => 'q',
  };

  String _ldpPitch(int midi) {
    final pitch = pitchFromMidi(midi.clamp(21, 108).toInt());
    final accidental = switch (pitch.alter) {
      -2 => '--',
      -1 => '-',
      1 => '#',
      2 => '##',
      _ => '',
    };
    return '$accidental${pitch.step.name}${pitch.octave}';
  }

  String _durationTypeForNote(MusicNote note, MusicMeasure measure) {
    if (note.type != null && staffDurationTypes.contains(note.type)) {
      return note.type!;
    }
    final quarter = measure.attributes.divisions;
    if (note.duration >= quarter * 4) return 'whole';
    if (note.duration >= quarter * 2) return 'half';
    if (note.duration <= math.max(1, (quarter / 2).round())) {
      return 'eighth';
    }
    return 'quarter';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: _LomseEditorAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _score == null || _session == null) {
      return Scaffold(
        appBar: const _LomseEditorAppBar(),
        body: _LomseErrorState(
          message: _error ?? 'Lomse editor could not be loaded.',
          onRetry: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            unawaited(_initialize());
          },
        ),
      );
    }

    final score = _score!;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dirty) unawaited(_confirmLeave());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            IconButton(
              tooltip: 'Undo',
              onPressed: _busy || _undoDepth == 0 ? null : _undo,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: _busy || _redoDepth == 0 ? null : _redo,
              icon: const Icon(Icons.redo_rounded),
            ),
            IconButton(
              tooltip: 'Save',
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
            PopupMenuButton<_LomseExportKind>(
              enabled: !_busy,
              tooltip: 'Export score',
              onSelected: _export,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _LomseExportKind.musicXml,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.music_note_outlined),
                    title: Text('MusicXML'),
                  ),
                ),
                PopupMenuItem(
                  value: _LomseExportKind.pdf,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('PDF'),
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
                score: score,
                playbackSequence: PlaybackSequence.empty,
                playbackArrangement: ArrangementProfile.off,
                semanticsLabel: _title,
                playback: _playback,
                inputMode: _insertMode == _LomseInsertMode.note
                    ? 'note'
                    : _insertMode == _LomseInsertMode.rest
                    ? 'rest'
                    : 'select',
                inputDurationType: _durationType,
                inputRest: _insertMode == _LomseInsertMode.rest,
                oneFingerPan: false,
                selectedNoteAddress: _selectedAddress,
                onNoteTapped: _selectNote,
                onStaffTapped: _insertFromStaff,
              ),
            ),
            _LomseEditorToolbar(
              mode: _insertMode,
              durationType: _durationType,
              revision: _session!.revision,
              busy: _busy,
              hasSelection: _selectedAddress != null,
              onModeChanged: (mode) => setState(() => _insertMode = mode),
              onDurationChanged: (value) =>
                  setState(() => _durationType = value),
              onInsert: _insertAtCursor,
              onDelete: _selectedTarget == null
                  ? null
                  : () => unawaited(_deleteTarget(_selectedTarget!)),
              onPitchDown: _selectedNote?.isRest == true
                  ? null
                  : () => unawaited(_nudgeSelected(-1)),
              onPitchUp: _selectedNote?.isRest == true
                  ? null
                  : () => unawaited(_nudgeSelected(1)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LomseEditorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _LomseEditorAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Piano editor'));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _LomseErrorState extends StatelessWidget {
  const _LomseErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 16),
            Text(
              'Lomse editor unavailable',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LomseEditorToolbar extends StatelessWidget {
  const _LomseEditorToolbar({
    required this.mode,
    required this.durationType,
    required this.revision,
    required this.busy,
    required this.hasSelection,
    required this.onModeChanged,
    required this.onDurationChanged,
    required this.onInsert,
    required this.onDelete,
    required this.onPitchDown,
    required this.onPitchUp,
  });

  final _LomseInsertMode mode;
  final String durationType;
  final int revision;
  final bool busy;
  final bool hasSelection;
  final ValueChanged<_LomseInsertMode> onModeChanged;
  final ValueChanged<String> onDurationChanged;
  final VoidCallback onInsert;
  final VoidCallback? onDelete;
  final VoidCallback? onPitchDown;
  final VoidCallback? onPitchUp;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                _modeChip(
                  context,
                  mode: _LomseInsertMode.select,
                  label: 'Select',
                  icon: Icons.near_me_outlined,
                ),
                const SizedBox(width: 6),
                _modeChip(
                  context,
                  mode: _LomseInsertMode.note,
                  label: 'Note',
                  icon: Icons.music_note_outlined,
                ),
                const SizedBox(width: 6),
                _modeChip(
                  context,
                  mode: _LomseInsertMode.rest,
                  label: 'Rest',
                  icon: Icons.horizontal_rule_rounded,
                ),
                const SizedBox(width: 6),
                _modeChip(
                  context,
                  mode: _LomseInsertMode.erase,
                  label: 'Erase',
                  icon: Icons.auto_fix_off_outlined,
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: durationType,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'whole', child: Text('Whole')),
                    DropdownMenuItem(value: 'half', child: Text('Half')),
                    DropdownMenuItem(value: 'quarter', child: Text('Quarter')),
                    DropdownMenuItem(value: 'eighth', child: Text('Eighth')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) onDurationChanged(value);
                        },
                ),
                if (hasSelection) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Lower pitch',
                    onPressed: busy ? null : onPitchDown,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  IconButton(
                    tooltip: 'Raise pitch',
                    onPressed: busy ? null : onPitchUp,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  IconButton(
                    tooltip: 'Delete selected note',
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  'Lomse r$revision',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.mutedInk),
                ),
                IconButton(
                  tooltip: 'Insert at cursor',
                  onPressed: busy ? null : onInsert,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip(
    BuildContext context, {
    required _LomseInsertMode mode,
    required String label,
    required IconData icon,
  }) {
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 17),
      selected: this.mode == mode,
      showCheckmark: false,
      onSelected: busy ? null : (_) => onModeChanged(mode),
    );
  }
}
