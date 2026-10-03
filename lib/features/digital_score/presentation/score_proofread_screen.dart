import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/note_duration_icon.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_original_crop.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';

/// One-bar proofreading editor for converted scores.
///
/// Edits go straight into the raw MusicXML through [XmlMeasureEditor], so
/// everything the app does not model (dynamics, articulations, layout) stays
/// intact. Saving adds a named version; the source file is never changed.
/// Pops with `true` after a version was saved.
class ScoreProofreadScreen extends ConsumerStatefulWidget {
  const ScoreProofreadScreen({
    required this.songId,
    required this.musicXml,
    required this.catalog,
    this.partIndex = 0,
    this.measureIndex = 0,
    this.sequence,
    super.key,
  });

  final String songId;
  final String musicXml;
  final ScoreVersionCatalog catalog;
  final int partIndex;
  final int measureIndex;

  /// Sections and playback order of the version being edited. They are
  /// carried to the saved version, moved along when bars were added or
  /// removed. Read from storage (the catalog's active version) when null.
  final PlaybackSequence? sequence;

  @override
  ConsumerState<ScoreProofreadScreen> createState() =>
      _ScoreProofreadScreenState();
}

class _ScoreProofreadScreenState extends ConsumerState<ScoreProofreadScreen> {
  static const _historyLimit = 100;

  /// Characters of score kept for undo (about 16 MB of memory): 100 steps of
  /// a short song, some 15 of a 500 KB score.
  static const _historyCharacters = 8 * 1000 * 1000;

  /// A Verovio page narrower than A4 engraves the bar larger. Phones get the
  /// narrowest page so notes stay big enough to tap.
  static Size _pageSizeFor(double viewportWidth) =>
      Size((viewportWidth * 1.1).clamp(800, 1100).roundToDouble(), 1400);

  static const _editor = XmlMeasureEditor();
  static const _codec = MusicXmlCodec();

  final _playback = PianoScorePlaybackController();
  late final List<String> _history = [widget.musicXml];

  /// For each state after the first: the bar the edit was made in, the note
  /// picked before it and the note picked after it. Undo and redo go back to
  /// that bar and note instead of staying where the view happens to be.
  final List<({int measure, int before, int measureAfter, int after})> _edits =
      [];

  /// The bars of each state in [_history], as ids: the bars of the opened
  /// score are 0, 1, 2…, an added bar gets a new id. Sections follow their
  /// bars by these when a version is saved.
  late final List<int> _openedBars = [
    for (var i = 0; i < measureCountOf(widget.musicXml, widget.partIndex); i++)
      i,
  ];
  late final List<List<int>> _bars = [_openedBars];
  late var _nextBarId = _openedBars.length;
  var _cursor = 0;
  var _savedCursor = 0;
  late int _measureIndex = widget.measureIndex;
  int get _measureCount => _bars[_cursor].length;

  /// The number of the first bar, as printed scores count: a pickup is 0.
  int get _firstBarNumber => xmlFirstBarNumber(_xml);
  int? _noteIndex;
  late String _preview;
  late MusicScore _previewScore;
  XmlNoteSummary? _summary;
  late XmlBarInspection _bar;
  var _hasTexts = false;
  var _saving = false;

  String get _xml => _history[_cursor];
  bool get _dirty => _cursor != _savedCursor;
  MusicMeasure get _previewMeasure => _previewScore.parts.first.measures.first;
  XmlNoteRef? get _ref => _noteIndex == null
      ? null
      : XmlNoteRef(
          partIndex: widget.partIndex,
          measureIndex: _measureIndex,
          noteIndex: _noteIndex!,
        );

  /// Where the measures of the conversion are on the original page, when
  /// the song was converted and the server placed them.
  List<List<OmrBarPlace?>>? _places;

  /// For each bar of the opened score, its index in the conversion (-1 for
  /// a bar added since); null when the score still has the bars it had.
  late final List<int>? _openedOrigins = barOrigins(widget.musicXml);
  final _originals = <String, Future<Uint8List?>>{};
  var _showOriginal = true;

  /// The current bar on the original, or null: an added bar has none.
  OmrBarPlace? get _place {
    final places = _places;
    if (places == null || widget.partIndex >= places.length) return null;
    final id = _bars[_cursor][_measureIndex];
    if (id >= _openedBars.length) return null;
    final origins = _openedOrigins;
    final origin = origins == null ? id : origins[id];
    final part = places[widget.partIndex];
    return origin < 0 || origin >= part.length ? null : part[origin];
  }

  Future<Uint8List?> _original(String name) => _originals.putIfAbsent(
    name,
    () => ref.read(omrConvertServiceProvider).systemImage(widget.songId, name),
  );

  @override
  void initState() {
    super.initState();
    _measureIndex = _measureIndex.clamp(0, _measureCount - 1);
    _refresh(select: 0);
    unawaited(_loadPlaces());
  }

  Future<void> _loadPlaces() async {
    final places = await ref
        .read(omrConvertServiceProvider)
        .barPlaces(widget.songId);
    if (mounted && places != null) setState(() => _places = places);
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  /// Re-engraves the current bar and keeps [select] (or the current note)
  /// selected when it still exists.
  void _refresh({int? select}) => _show(_inspect(_xml), select: select);

  /// Reads the current bar of [xml]: one pass over the score. Throws a
  /// [FormatException] when the bar cannot be read.
  ({XmlBarInspection bar, MusicScore score}) _inspect(String xml) {
    final bar = _editor.inspect(xml, widget.partIndex, _measureIndex);
    return (bar: bar, score: _codec.decodeXml(bar.isolatedXml));
  }

  void _show(({XmlBarInspection bar, MusicScore score}) read, {int? select}) {
    _bar = read.bar;
    _previewScore = read.score;
    _preview = tagIsolatedNotes(read.bar.isolatedXml, _previewMeasure);
    final count = _previewMeasure.notes.length;
    final index = select ?? _noteIndex;
    _noteIndex = count == 0 || index == null ? null : index.clamp(0, count - 1);
    final note = _noteIndex;
    _summary = note == null || note >= read.bar.notes.length
        ? null
        : read.bar.notes[note];
    _hasTexts = read.bar.texts.isNotEmpty;
  }

  /// Applies [edit] at the selected note. An edit that adds or removes bars
  /// says with [bars] what the list of bar ids becomes.
  void _apply(
    XmlEditResult Function(String xml, XmlNoteRef ref) edit, {
    List<int> Function(List<int> bars, int at)? bars,
  }) {
    // A bar edit needs no note: a bar read without any can still be removed.
    final ref =
        _ref ??
        (bars == null
            ? null
            : XmlNoteRef(
                partIndex: widget.partIndex,
                measureIndex: _measureIndex,
                noteIndex: 0,
              ));
    if (ref == null) return;
    try {
      final result = edit(_xml, ref);
      final before = _measureIndex;
      _measureIndex = result.selection.measureIndex;
      final ({XmlBarInspection bar, MusicScore score}) read;
      try {
        // The edited bar must still read. A bar edit moves every bar after
        // it, so the whole score is read once more; saving reads it again.
        if (bars != null) _codec.decodeXml(result.xml);
        read = _inspect(result.xml);
      } on FormatException {
        _measureIndex = before;
        rethrow;
      }
      final current = _bars[_cursor];
      setState(() {
        _history
          ..removeRange(_cursor + 1, _history.length)
          ..add(result.xml);
        _bars
          ..removeRange(_cursor + 1, _bars.length)
          ..add(bars == null ? current : bars(current, ref.measureIndex));
        _edits
          ..removeRange(_cursor, _edits.length)
          ..add((
            measure: ref.measureIndex,
            before: ref.noteIndex,
            measureAfter: result.selection.measureIndex,
            after: result.selection.noteIndex,
          ));
        _cursor = _history.length - 1;
        // Every state is the whole score: a long score keeps fewer of them.
        var kept = _history.fold(0, (sum, state) => sum + state.length);
        while (_history.length > 2 &&
            (_history.length > _historyLimit + 1 ||
                kept > _historyCharacters)) {
          kept -= _history.first.length;
          _history.removeAt(0);
          _bars.removeAt(0);
          _edits.removeAt(0);
          _cursor--;
          _savedCursor--;
        }
        _show(read, select: result.selection.noteIndex);
      });
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  void _undo() {
    if (_cursor == 0) return;
    setState(() {
      final edit = _edits[_cursor - 1];
      _cursor--;
      _measureIndex = edit.measure;
      _refresh(select: edit.before);
    });
  }

  void _redo() {
    if (_cursor >= _history.length - 1) return;
    setState(() {
      final edit = _edits[_cursor];
      _cursor++;
      _measureIndex = edit.measureAfter;
      _refresh(select: edit.after);
    });
  }

  void _goToMeasure(int index) {
    if (index < 0 || index >= _measureCount || index == _measureIndex) return;
    setState(() {
      _measureIndex = index;
      _refresh(select: 0);
    });
  }

  void _selectNote(int index) {
    final count = _previewMeasure.notes.length;
    if (index < 0 || index >= count) return;
    // The bar is already read: picking another note needs no new pass.
    setState(() {
      _noteIndex = index;
      _summary = index < _bar.notes.length ? _bar.notes[index] : null;
    });
  }

  void _onEventTapped(ScoreEventAddress address) {
    final index = xmlNoteIndexForEvent(_previewMeasure, address.eventIndex);
    if (index != null) _selectNote(index);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _askBar() async {
    final number = await showDialog<int>(
      context: context,
      builder: (_) => _BarNumberDialog(
        current: _measureIndex + _firstBarNumber,
        first: _firstBarNumber,
        last: _measureCount - 1 + _firstBarNumber,
      ),
    );
    if (number != null && mounted) _goToMeasure(number - _firstBarNumber);
  }

  Future<void> _editChordSymbol() async {
    final ref = _ref;
    if (ref == null) return;
    final initial = _summary?.harmony ?? '';
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ChordSymbolDialog(initial: initial),
    );
    if (text == null || !mounted) return;
    if (text.isEmpty && initial.isEmpty) return;
    _apply((xml, ref) => _editor.setHarmony(xml, ref, text));
  }

  void _insertBar() => _apply(
    _editor.insertMeasureAfter,
    bars: (bars, at) => [...bars]..insert(at + 1, _nextBarId++),
  );

  void _duplicateBar() => _apply(
    _editor.duplicateMeasure,
    bars: (bars, at) => [...bars]..insert(at + 1, _nextBarId++),
  );

  void _deleteBar() => _apply(
    _editor.deleteMeasure,
    bars: (bars, at) => [...bars]..removeAt(at),
  );

  void _moveBar(int places) => _apply(
    (xml, ref) => _editor.moveMeasure(xml, ref, places),
    bars: (bars, at) {
      final moved = [...bars];
      final bar = moved.removeAt(at);
      return moved..insert(at + places, bar);
    },
  );

  Future<void> _editTexts() async {
    final texts = _bar.texts;
    if (texts.isEmpty) return;
    final change = await showDialog<({int index, String? text})>(
      context: context,
      builder: (_) => _BarTextsDialog(texts: texts),
    );
    if (change == null || !mounted) return;
    final text = change.text;
    _apply(
      (xml, ref) => text == null
          ? _editor.removeText(xml, ref, change.index)
          : _editor.setText(xml, ref, change.index, text),
    );
  }

  Future<bool> _save() async {
    if (_saving || !_dirty) return false;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _VersionNameDialog(
        initial: context.l10n.proofreadVersionName(
          widget.catalog.versions.length + 1,
        ),
      ),
    );
    if (name == null || name.isEmpty || !mounted) return false;
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      final service = ref.read(digitalScoreEditorServiceProvider);
      final sequence =
          widget.sequence ??
          await service.loadSequence(
            widget.songId,
            versionId: widget.catalog.activeId,
          );
      final bars = _bars[_cursor];
      final sameBars =
          bars.length == _openedBars.length &&
          [for (var i = 0; i < bars.length; i++) bars[i] == i].every((b) => b);
      await service.addXmlVersion(
        songId: widget.songId,
        // Generated parts follow the edited melody and chords.
        musicXml: regenerateAccompaniment(_xml),
        catalog: widget.catalog,
        name: name,
        // The new version keeps the sections and the playback order; where
        // bars were added, removed or moved, the sections go with their bars.
        sequence: sameBars
            ? sequence
            : remapSectionMarks(
                sequence,
                _openedBars,
                bars,
                writtenMarks: rehearsalSectionMarks(
                  _codec.decodeXml(widget.musicXml),
                ),
              ),
      );
      _savedCursor = _cursor;
      if (mounted) Navigator.of(context).pop(true);
      return true;
    } on FormatException catch (error) {
      _showMessage(error.message);
    } on Object {
      _showMessage(l10n.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    return false;
  }

  Future<void> _confirmLeave() async {
    final l10n = context.l10n;
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unsavedChangesTitle),
        content: Text(l10n.unsavedChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.discard),
            child: Text(l10n.discardChanges),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.save),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _LeaveChoice.discard:
        Navigator.of(context).pop(false);
      case _LeaveChoice.save:
        await _save();
    }
  }

  Widget _engraving(AppLocalizations l10n, int? selectedEvent) {
    return LayoutBuilder(
      builder: (context, constraints) => VerovioScoreView(
        score: _previewScore,
        engravingXml: _preview,
        engravingPageSize: _pageSizeFor(constraints.maxWidth),
        semanticsLabel: l10n.proofreadBar(
          _measureIndex + _firstBarNumber,
          _measureCount - 1 + _firstBarNumber,
        ),
        playback: _playback,
        inputMode: 'select',
        oneFingerPan: true,
        onEventTapped: _onEventTapped,
        selectedNoteAddress: selectedEvent == null
            ? null
            : ScoreEventAddress(
                partIndex: 0,
                measureIndex: 0,
                eventIndex: selectedEvent,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = _summary;
    final hasNote = summary != null && !summary.isRest && !summary.isGrace;
    final canRetime = summary != null && !summary.isGrace && !summary.inTuplet;
    final selectedEvent = _noteIndex == null
        ? null
        : eventIndexForXmlNote(_previewMeasure, _noteIndex!);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: Text(l10n.proofread),
          actions: [
            if (_places != null)
              IconButton(
                tooltip: l10n.showOriginal,
                isSelected: _showOriginal,
                onPressed: () => setState(() => _showOriginal = !_showOriginal),
                icon: const Icon(Icons.image_outlined),
                selectedIcon: const Icon(Icons.image_rounded),
              ),
            IconButton(
              tooltip: l10n.undo,
              onPressed: _cursor > 0 ? _undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: l10n.redo,
              onPressed: _cursor < _history.length - 1 ? _redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FilledButton(
                onPressed: _dirty && !_saving ? () => unawaited(_save()) : null,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, area) {
                    // Beside the engraving where there is width for both,
                    // above it on a phone held upright.
                    final beside = area.maxWidth >= 700;
                    return Flex(
                      direction: beside ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showOriginal && _places != null)
                          SizedBox(
                            width: beside ? area.maxWidth * 0.36 : null,
                            height: beside
                                ? null
                                : (area.maxHeight * 0.3).clamp(90.0, 190.0),
                            child: _OriginalStrip(
                              place: _place,
                              image: _place == null
                                  ? null
                                  : _original(_place!.image),
                              beside: beside,
                            ),
                          ),
                        // Keyed: showing or hiding the original must not
                        // make the engraving start over.
                        Expanded(
                          key: const ValueKey('engraving'),
                          child: _engraving(l10n, selectedEvent),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              _Toolbar(
                children: [
                  _ToolRow(
                    children: [
                      _ToolButton(
                        tooltip: l10n.previousBar,
                        onPressed: _measureIndex > 0
                            ? () => _goToMeasure(_measureIndex - 1)
                            : null,
                        child: const Icon(Icons.chevron_left_rounded),
                      ),
                      _ToolButton(
                        tooltip: l10n.goToBar,
                        wide: true,
                        onPressed: _measureCount > 1
                            ? () => unawaited(_askBar())
                            : null,
                        child: Text(
                          l10n.proofreadBar(
                            _measureIndex + _firstBarNumber,
                            _measureCount - 1 + _firstBarNumber,
                          ),
                        ),
                      ),
                      _ToolButton(
                        tooltip: l10n.nextBar,
                        onPressed: _measureIndex < _measureCount - 1
                            ? () => _goToMeasure(_measureIndex + 1)
                            : null,
                        child: const Icon(Icons.chevron_right_rounded),
                      ),
                      const _ToolGap(),
                      _ToolButton(
                        tooltip: l10n.insertMeasureAfter,
                        onPressed: _insertBar,
                        child: const Icon(Icons.add_box_outlined),
                      ),
                      _ToolButton(
                        tooltip: l10n.duplicateMeasure,
                        onPressed: _duplicateBar,
                        child: const Icon(Icons.copy_all_rounded),
                      ),
                      _ToolButton(
                        tooltip: l10n.deleteMeasure,
                        onPressed: _measureCount > 1 ? _deleteBar : null,
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                      _ToolButton(
                        tooltip: l10n.moveMeasureEarlier,
                        onPressed: _measureIndex > 0
                            ? () => _moveBar(-1)
                            : null,
                        child: const Icon(Icons.keyboard_double_arrow_left),
                      ),
                      _ToolButton(
                        tooltip: l10n.moveMeasureLater,
                        onPressed: _measureIndex < _measureCount - 1
                            ? () => _moveBar(1)
                            : null,
                        child: const Icon(Icons.keyboard_double_arrow_right),
                      ),
                      const _ToolGap(),
                      _ToolButton(
                        tooltip: l10n.previousNote,
                        onPressed: (_noteIndex ?? 0) > 0
                            ? () => _selectNote(_noteIndex! - 1)
                            : null,
                        child: const Icon(Icons.first_page_rounded),
                      ),
                      _ToolButton(
                        tooltip: l10n.nextNote,
                        onPressed:
                            _noteIndex != null &&
                                _noteIndex! < _previewMeasure.notes.length - 1
                            ? () => _selectNote(_noteIndex! + 1)
                            : null,
                        child: const Icon(Icons.last_page_rounded),
                      ),
                    ],
                  ),
                  _ToolRow(
                    children: [
                      for (final type in noteDurationTypes)
                        _ToolButton(
                          tooltip: '${l10n.noteValue} ${_fractionOf[type]}',
                          selected: summary?.type == type,
                          onPressed: canRetime
                              ? () => _apply(
                                  (xml, ref) =>
                                      _editor.setDuration(xml, ref, type, 0),
                                )
                              : null,
                          child: NoteDurationIcon(
                            durationType: type,
                            rest: summary?.isRest ?? false,
                            color: canRetime ? AppColors.ink : AppColors.border,
                          ),
                        ),
                      _ToolButton(
                        tooltip: l10n.dottedDuration,
                        selected: (summary?.dots ?? 0) > 0,
                        onPressed: canRetime && summary.type != null
                            ? () => _apply(
                                (xml, ref) => _editor.setDuration(
                                  xml,
                                  ref,
                                  summary.type!,
                                  summary.dots > 0 ? 0 : 1,
                                ),
                              )
                            : null,
                        child: const Icon(Icons.circle, size: 8),
                      ),
                    ],
                  ),
                  _ToolRow(
                    children: [
                      _ToolButton(
                        tooltip: l10n.noteStepUp,
                        onPressed: hasNote
                            ? () => _apply(
                                (xml, ref) => _editor.moveDiatonic(xml, ref, 1),
                              )
                            : null,
                        child: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      _ToolButton(
                        tooltip: l10n.noteStepDown,
                        onPressed: hasNote
                            ? () => _apply(
                                (xml, ref) =>
                                    _editor.moveDiatonic(xml, ref, -1),
                              )
                            : null,
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      _ToolButton(
                        tooltip: l10n.octaveUp,
                        onPressed: hasNote
                            ? () => _apply(
                                (xml, ref) => _editor.shiftOctave(xml, ref, 1),
                              )
                            : null,
                        child: const Icon(
                          Icons.keyboard_double_arrow_up_rounded,
                        ),
                      ),
                      _ToolButton(
                        tooltip: l10n.octaveDown,
                        onPressed: hasNote
                            ? () => _apply(
                                (xml, ref) => _editor.shiftOctave(xml, ref, -1),
                              )
                            : null,
                        child: const Icon(
                          Icons.keyboard_double_arrow_down_rounded,
                        ),
                      ),
                      const _ToolGap(),
                      for (final (alter, glyph, label) in [
                        (1, '♯', l10n.noteSharp),
                        (-1, '♭', l10n.noteFlat),
                        (0, '♮', l10n.noteNatural),
                      ])
                        _ToolButton(
                          tooltip: label,
                          selected: hasNote && summary.pitch?.alter == alter,
                          onPressed: hasNote
                              ? () => _apply(
                                  (xml, ref) =>
                                      _editor.setAlter(xml, ref, alter),
                                )
                              : null,
                          child: Text(
                            glyph,
                            style: const TextStyle(fontSize: 22, height: 1),
                          ),
                        ),
                    ],
                  ),
                  _ToolRow(
                    children: [
                      _ToolButton(
                        tooltip: l10n.addChordTone,
                        onPressed: hasNote
                            ? () => _apply(_editor.addChordNote)
                            : null,
                        child: const Icon(Icons.add_rounded),
                      ),
                      _ToolButton(
                        tooltip: l10n.deleteNote,
                        onPressed: hasNote
                            ? () => _apply(_editor.deleteNote)
                            : null,
                        child: const Icon(Icons.backspace_outlined),
                      ),
                      _ToolButton(
                        tooltip: l10n.restToNote,
                        onPressed: summary != null && summary.isRest
                            ? () => _apply(_editor.restToNote)
                            : null,
                        child: const Icon(Icons.music_note_rounded),
                      ),
                      const _ToolGap(),
                      _ToolButton(
                        tooltip: l10n.chordSymbol,
                        wide: true,
                        onPressed: summary != null && !summary.isGrace
                            ? () => unawaited(_editChordSymbol())
                            : null,
                        child: Text(
                          summary?.harmony?.isNotEmpty == true
                              ? summary!.harmony!
                              : l10n.chordSymbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _ToolButton(
                        tooltip: l10n.barTexts,
                        onPressed: summary != null && _hasTexts
                            ? () => unawaited(_editTexts())
                            : null,
                        child: const Icon(Icons.text_fields_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LeaveChoice { discard, save }

const _fractionOf = {
  'whole': '1',
  'half': '1/2',
  'quarter': '1/4',
  'eighth': '1/8',
  '16th': '1/16',
};

/// The bar being proofread as it is on the original page, above its
/// engraving: the staff line it is on, cut to the bar and a little of its
/// neighbours.
class _OriginalStrip extends StatelessWidget {
  const _OriginalStrip({
    required this.place,
    required this.image,
    required this.beside,
  });

  final OmrBarPlace? place;
  final Future<Uint8List?>? image;

  /// Whether it stands beside the engraving (else above it).
  final bool beside;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final none = Center(
      child: Text(
        l10n.noOriginalBar,
        style: const TextStyle(color: AppColors.mutedInk),
      ),
    );
    const line = BorderSide(color: AppColors.border);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: beside ? const Border(right: line) : const Border(bottom: line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: place == null || image == null
          ? none
          : FutureBuilder<Uint8List?>(
              // A new bar is a new picture, not a change to the last one.
              key: ValueKey('${place!.image}/${place!.focus}'),
              future: image,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                final bytes = snapshot.data;
                if (bytes == null) return none;
                return OmrOriginalCrop(
                  bytes: bytes,
                  focus: place!.focus,
                  around: 0.25,
                  semanticLabel: l10n.originalBar,
                  missing: none,
                );
              },
            ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final child in children)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: children,
    );
  }
}

class _ToolGap extends StatelessWidget {
  const _ToolGap();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 12);
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.selected = false,
    this.wide = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool selected;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.surfaceSoft : AppColors.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(4),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: wide ? 88 : 48,
                minHeight: 48,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  widthFactor: 1,
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: enabled ? AppColors.ink : AppColors.border,
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: enabled ? AppColors.ink : AppColors.border,
                        fontWeight: FontWeight.w600,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lists the texts of the bar. Pops with the index of a text and what it
/// should read, or null as the text to remove it.
class _BarTextsDialog extends StatefulWidget {
  const _BarTextsDialog({required this.texts});

  final List<String> texts;

  @override
  State<_BarTextsDialog> createState() => _BarTextsDialogState();
}

class _BarTextsDialogState extends State<_BarTextsDialog> {
  late final _controllers = [
    for (final text in widget.texts) TextEditingController(text: text),
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _rewrite(int index) {
    final text = _controllers[index].text.trim();
    if (text == widget.texts[index]) return;
    Navigator.of(context).pop((index: index, text: text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.barTexts),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              l10n.barTextsHint,
              style: const TextStyle(color: AppColors.mutedInk),
            ),
            for (final (index, controller) in _controllers.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _rewrite(index),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.save,
                      onPressed: () => _rewrite(index),
                      icon: const Icon(Icons.check_rounded),
                    ),
                    IconButton(
                      tooltip: l10n.remove,
                      onPressed: () =>
                          Navigator.of(context).pop((index: index, text: null)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _ChordSymbolDialog extends StatefulWidget {
  const _ChordSymbolDialog({required this.initial});

  final String initial;

  @override
  State<_ChordSymbolDialog> createState() => _ChordSymbolDialogState();
}

class _ChordSymbolDialogState extends State<_ChordSymbolDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      try {
        parseChordSymbol(text);
      } on FormatException catch (error) {
        setState(() => _error = error.message);
        return;
      }
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.chordSymbol),
      content: TextField(
        controller: _controller,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: l10n.chordSymbolHint,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        if (widget.initial.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(l10n.remove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

class _VersionNameDialog extends StatefulWidget {
  const _VersionNameDialog({required this.initial});

  final String initial;

  @override
  State<_VersionNameDialog> createState() => _VersionNameDialogState();
}

class _VersionNameDialogState extends State<_VersionNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.scoreVersionName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.scoreVersionName),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

class _BarNumberDialog extends StatefulWidget {
  const _BarNumberDialog({
    required this.current,
    required this.first,
    required this.last,
  });

  final int current;
  final int first;
  final int last;

  @override
  State<_BarNumberDialog> createState() => _BarNumberDialogState();
}

class _BarNumberDialogState extends State<_BarNumberDialog> {
  late final _controller = TextEditingController(text: '${widget.current}');
  var _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < widget.first || value > widget.last) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.goToBar),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: '${widget.first}–${widget.last}',
          errorText: _invalid ? '${widget.first}–${widget.last}' : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.move)),
      ],
    );
  }
}
