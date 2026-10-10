import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/native_score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_original_crop.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_editor_chrome.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_editor_panel.dart';
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
    this.lineStarts,
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

  /// The bars that begin a line where the score was being read, for a
  /// score that writes no line breaks of its own: the editor then shows the
  /// same lines, and not a layout of its own.
  final List<int>? lineStarts;

  @override
  ConsumerState<ScoreProofreadScreen> createState() =>
      _ScoreProofreadScreenState();
}

class _ScoreProofreadScreenState extends ConsumerState<ScoreProofreadScreen> {
  static const _historyLimit = 100;

  /// Characters of score kept for undo (about 16 MB of memory): 100 steps of
  /// a short song, some 15 of a 500 KB score.
  static const _historyCharacters = 8 * 1000 * 1000;

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

  /// The part as it is engraved: line by line, and the bars of all lines as
  /// the score view counts them.
  late List<String> _chunks;
  late MusicScore _previewScore;

  /// The bar being worked on, read on its own.
  late MusicScore _barScore;
  XmlNoteSummary? _summary;
  late XmlBarInspection _bar;
  late XmlBarSigns _signs;
  var _hasTexts = false;

  /// The palette of tools open under the bar: one at a time, like the entry
  /// palette of a notation program, so the score keeps the screen.
  var _palette = _Palette.note;

  /// A line (slur, hairpin, pedal…) whose first note is picked and whose
  /// last note is still to be picked.
  ({SpanKind kind, int measure, int note})? _spanFrom;

  /// The verse whose words the lyric tool shows and writes.
  var _verse = 1;

  /// The octave the keyboard begins at.
  var _keyboardOctave = 4;

  /// Whether the keys build a chord on the picked note instead of going on
  /// to the next: the first key is the note, the ones after it join it.
  var _chordKeys = false;

  /// The keys pressed for the chord being built, and the chord built
  /// before it, which one button writes again.
  var _chordNow = <int>[];
  var _chordBefore = <int>[];

  /// The width of the white keys: three sizes, for a thumb or for reach.
  var _keyWidth = 1;
  static const _keyWidths = [34.0, 44.0, 58.0];

  /// A run of notes copied with the note tools, to be written elsewhere.
  NoteClip? _noteClip;

  /// What a tap on the score does: pick a note, rub one out, or write a
  /// note or rest of the value in hand.
  var _tool = _Tool.select;

  /// The value the note and rest tools write.
  var _entryType = 'quarter';
  var _entryDots = 0;

  /// What stands under the score: nothing, the keyboard, or a palette.
  var _panel = _Panel.none;

  /// The score view, asked to bring a bar into view.
  final _scoreKey = GlobalKey<VerovioScoreViewState>();

  /// The bars that begin the lines of the engraving for [xml]: the lines
  /// the score writes, so the editor shows the page as the score does. A
  /// score that writes none has the lines the viewer set for it; once bars
  /// were added or removed, as many bars to a line as it had there.
  List<int> _lineStartsFor(String xml) {
    final written = writtenLineStarts(xml, widget.partIndex);
    if (written.isNotEmpty) return written;
    final count = measureCountOf(xml, widget.partIndex);
    final shown = widget.lineStarts ?? const <int>[];
    final usable =
        shown.isNotEmpty && shown.first == 0 && shown.every((s) => s < count);
    if (usable && count == _openedBars.length) return shown;
    final perLine = usable && shown.length > 1
        ? (shown.last / (shown.length - 1)).round().clamp(1, 8)
        : 4;
    return [for (var start = 0; start < count; start += perLine) start];
  }

  /// The lines of the part as they were last read: the text each was made
  /// from, what is engraved for it, and its bars.
  List<({String text, String shown, List<MusicMeasure> bars})> _lines =
      const [];

  /// The score the lines of [_lines] were last put together into, and for
  /// which state.
  ({String xml, List<String> chunks, MusicScore score})? _shown;

  bool get _writing => _tool == _Tool.note || _tool == _Tool.rest;

  /// Bars copied with the bar range tool, to be pasted after another bar.
  MeasureClip? _clip;

  /// Whether a tap picks the other end of a run of notes (the range tool).
  var _ranging = false;

  /// The other end of a run of notes, in whatever bar: the tools for pitch,
  /// length and marks then work on every note from the picked one to it.
  /// Picked with the range tool, or by a finger held down and moved.
  ({int bar, int note})? _rangeEnd;

  /// Whole bars picked (a bar tapped twice, and bars added with the
  /// handles): what is cut, copied, repeated or transposed as bars.
  ({int from, int to})? _barSel;

  /// The notes of bar [index], counted as the editor counts them.
  List<MusicNote> _notesOf(int index) => index == _measureIndex
      ? _previewMeasure.notes.toList()
      : _shownMeasure(index).notes.toList();

  /// The notes the tools work on, in the order of the score: the picked
  /// one, or with a run picked every note from one end to the other. A run
  /// of notes keeps to the staff it began on; whole bars are all of them.
  List<XmlNoteRef> get _pickedRefs {
    final from = _noteIndex;
    if (from == null) return const [];
    XmlNoteRef at(int bar, int note) => XmlNoteRef(
      partIndex: widget.partIndex,
      measureIndex: bar,
      noteIndex: note,
    );
    final end = _rangeEnd;
    if (end == null || end.bar < 0 || end.bar >= _measureCount) {
      return [at(_measureIndex, from)];
    }
    final here = _notesOf(_measureIndex);
    if (from >= here.length) return [at(_measureIndex, from)];
    final staff = _barSel == null ? here[from].staff : null;
    final forward =
        end.bar > _measureIndex ||
        (end.bar == _measureIndex && end.note >= from);
    final first = forward ? (bar: _measureIndex, note: from) : end;
    final last = forward ? end : (bar: _measureIndex, note: from);
    final refs = <XmlNoteRef>[];
    for (var bar = first.bar; bar <= last.bar; bar++) {
      final notes = _notesOf(bar);
      for (final (index, note) in notes.indexed) {
        if ((bar < first.bar || index < first.note) && bar == first.bar) {
          continue;
        }
        if (bar == last.bar && index > last.note) continue;
        if (staff != null && note.staff != staff) continue;
        if (_only != _Only.all && !_isOuterNote(notes, index)) continue;
        refs.add(at(bar, index));
      }
    }
    return refs;
  }

  /// Whether note [index] of [notes] is the highest (or lowest, as [_only]
  /// says) of its chord. A note on its own is; a rest is not.
  bool _isOuterNote(List<MusicNote> notes, int index) {
    final pitch = notes[index].pitch;
    if (pitch == null) return false;
    var start = index;
    while (start > 0 && notes[start].isChord) {
      start--;
    }
    var best = pitch.midi;
    var bestAt = index;
    for (var i = start; i < notes.length; i++) {
      if (i > start && !notes[i].isChord) break;
      final midi = notes[i].pitch?.midi;
      if (midi == null) continue;
      final better = _only == _Only.top ? midi > best : midi < best;
      if (better) {
        best = midi;
        bestAt = i;
      }
    }
    return bestAt == index;
  }

  /// What the editor says of each picked note.
  List<XmlNoteSummary> get _pickedSummaries {
    final bars = <int, List<XmlNoteSummary>>{};
    return [
      for (final ref in _pickedRefs)
        if ((bars[ref.measureIndex] ??= _summariesOf(_xml, ref.measureIndex))
            case final notes when ref.noteIndex < notes.length)
          notes[ref.noteIndex],
    ];
  }

  List<XmlNoteSummary> _summariesOf(String xml, int bar) =>
      bar == _measureIndex && identical(xml, _xml)
      ? _bar.notes
      : _editor.inspect(xml, widget.partIndex, bar).notes;

  void _dropRange() {
    _rangeEnd = null;
    _barSel = null;
    _only = _Only.all;
  }

  /// Of the chords in a run of notes, which note the tools work on: all
  /// of them, or the highest or lowest of each (a melody, a bass line).
  var _only = _Only.all;

  /// How the editor is laid out, for the hand and the light it is used in.
  /// Kept while the app runs: the same next time the editor is opened.
  static var _railRight = false;
  static var _smallTools = false;
  static var _darkScore = false;

  /// How large the notes are engraved, next to the page they are engraved
  /// on: the lines keep their bars, the notes grow or shrink in them.
  static var _noteSize = 1.0;
  static const _noteSizes = [0.85, 1.0, 1.2, 1.45];

  /// The bar after which the player stops, when only picked bars play.
  int? _playUntil;

  /// The chord the keys were building is done: it is the chord before now.
  void _endChord() {
    if (_chordNow.isEmpty) return;
    _chordBefore = _chordNow;
    _chordNow = <int>[];
  }

  /// Whether the next key of the keyboard writes a new note after the
  /// picked one, instead of giving the picked one its pitch: the keys have
  /// come to the end of a bar that is shorter than its time, and go on into
  /// what is missing.
  var _keysAppend = false;

  var _saving = false;

  String get _xml => _history[_cursor];
  bool get _dirty => _cursor != _savedCursor;

  /// The bar being worked on, as decoded.
  MusicMeasure get _previewMeasure => _barScore.parts.first.measures.first;

  /// Bar [index] as the score view counts its notes: an address on screen
  /// is an event of this bar.
  MusicMeasure _shownMeasure(int index) {
    final bars = _previewScore.parts.first.measures;
    return bars[index.clamp(0, bars.length - 1)];
  }

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
    _playback.addListener(_onPlayback);
    _measureIndex = _measureIndex.clamp(0, _measureCount - 1);
    _refresh(select: 0);
    unawaited(_loadPlaces());
    unawaited(_offerDraft());
  }

  /// Whether a note is sounded when it is written, moved or stepped to.
  var _sounds = true;

  /// Lets the picked note (its whole chord) be heard.
  void _soundPicked() {
    if (!_sounds) return;
    final index = _noteIndex;
    if (index == null || index >= _bar.notes.length) return;
    final notes = _bar.notes;
    // The notes of the chord stand one after the other, the first leading.
    var first = index;
    while (first > 0 && !notes[first].leadsChord) {
      first--;
    }
    final midis = <int>[];
    for (var i = first; i < notes.length; i++) {
      if (i > first && notes[i].leadsChord) break;
      if (notes[i].pitch case final pitch?) midis.add(pitch.midi);
    }
    if (midis.isEmpty) return;
    unawaited(_scoreKey.currentState?.sound(midis));
  }

  Timer? _draftTimer;

  /// Read once: the draft is also written when the screen is left, when
  /// nothing may be looked up any more.
  late final DigitalScoreEditorService _drafts = ref.read(
    digitalScoreEditorServiceProvider,
  );

  /// Keeps what was edited, a moment after the last edit: a call, a dead
  /// battery or a closed app does not take the corrections with it.
  void _keepDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 2), _writeDraft);
  }

  void _writeDraft() {
    _draftTimer = null;
    final service = _drafts;
    if (!_dirty) {
      unawaited(service.discardDraft(widget.songId));
      return;
    }
    unawaited(
      service
          .saveDraft(
            songId: widget.songId,
            base: widget.musicXml,
            xml: _xml,
            bars: _bars[_cursor],
          )
          .then((_) {}, onError: (Object _) {}),
    );
  }

  /// Offers the corrections that were being made when the editor was last
  /// left without saving.
  Future<void> _offerDraft() async {
    final service = _drafts;
    final draft = await service.loadDraft(
      songId: widget.songId,
      base: widget.musicXml,
    );
    if (draft == null || !mounted || _cursor != 0) return;
    final l10n = context.l10n;
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.draftTitle),
        content: Text(l10n.draftBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.discardChanges),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.draftResume),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume != true) {
      if (resume == false) unawaited(service.discardDraft(widget.songId));
      return;
    }
    if (_cursor != 0) return;
    try {
      final before = _measureIndex;
      _measureIndex = _measureIndex.clamp(0, draft.bars.length - 1);
      final _Read read;
      try {
        read = _inspect(draft.xml);
      } on FormatException {
        _measureIndex = before;
        rethrow;
      }
      setState(() {
        // One step of undo back to the score as it was opened.
        _history.add(draft.xml);
        _bars.add(draft.bars);
        _edits.add((
          measure: before,
          before: _noteIndex ?? 0,
          measureAfter: _measureIndex,
          after: 0,
        ));
        _cursor = 1;
        for (final bar in draft.bars) {
          if (bar >= _nextBarId) _nextBarId = bar + 1;
        }
        _show(read, select: 0);
      });
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _loadPlaces() async {
    final places = await ref
        .read(omrConvertServiceProvider)
        .barPlaces(widget.songId);
    if (mounted && places != null) setState(() => _places = places);
  }

  @override
  void dispose() {
    _toolHintTimer?.cancel();
    // What was waiting to be kept is kept now.
    if (_draftTimer != null) {
      _draftTimer!.cancel();
      _writeDraft();
    }
    _playback.removeListener(_onPlayback);
    _playback.dispose();
    super.dispose();
  }

  /// Re-engraves the current bar and keeps [select] (or the current note)
  /// selected when it still exists.
  void _refresh({int? select}) => _show(_inspect(_xml), select: select);

  /// Reads [xml] for the screen: the whole part to show, and the current
  /// bar to work on. Throws a [FormatException] when it cannot be read.
  _Read _inspect(String xml) {
    final bar = _editor.inspect(xml, widget.partIndex, _measureIndex);
    var shown = _shown;
    if (shown == null || !identical(shown.xml, xml)) {
      // Line by line: a line whose text is as it was keeps what was read
      // of it, so an edit reads one line and not the score.
      final starts = _lineStartsFor(xml);
      final texts = partChunks(xml, widget.partIndex, starts);
      final lines = <({String text, String shown, List<MusicMeasure> bars})>[];
      MusicScore? first;
      for (var i = 0; i < texts.length; i++) {
        if (i < _lines.length && _lines[i].text == texts[i]) {
          lines.add(_lines[i]);
          continue;
        }
        final decoded = _codec.decodeXml(texts[i]);
        if (i == 0) first = decoded;
        final bars = decoded.parts.first.measures;
        lines.add((
          text: texts[i],
          shown: chunkForDisplay(texts[i], bars, starts[i]),
          bars: bars,
        ));
      }
      _lines = lines;
      final base = first ?? shown?.score ?? _codec.decodeXml(texts.first);
      shown = (
        xml: xml,
        chunks: [for (final line in lines) line.shown],
        score: base.copyWith(
          parts: [
            base.parts.first.copyWith(
              measures: [for (final line in lines) ...line.bars],
            ),
          ],
        ),
      );
      _shown = shown;
    }
    return (
      bar: bar,
      barScore: _codec.decodeXml(bar.isolatedXml),
      score: shown.score,
      chunks: shown.chunks,
      signs: _editor.barSigns(xml, widget.partIndex, _measureIndex),
    );
  }

  void _show(_Read read, {int? select}) {
    _bar = read.bar;
    _signs = read.signs;
    _previewScore = read.score;
    _chunks = read.chunks;
    _barScore = read.barScore;
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
    bool keepRange = false,
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
    // Any edit ends a line that was being drawn.
    if (_spanFrom != null) setState(() => _spanFrom = null);
    try {
      final result = edit(_xml, ref);
      final before = _measureIndex;
      _measureIndex = result.selection.measureIndex;
      final _Read read;
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
        _keepDraft();
        // A run of notes stays picked only for edits that leave every note
        // where it is.
        final end = _rangeEnd;
        if (keepRange &&
            end != null &&
            end.bar < _measureCount &&
            end.note < _notesOf(end.bar).length) {
          _rangeEnd = end;
        } else {
          _dropRange();
        }
      });
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  void _undo() {
    if (_cursor == 0) return;
    setState(() {
      _spanFrom = null;
      _keysAppend = false;
      _dropRange();
      final edit = _edits[_cursor - 1];
      _cursor--;
      _measureIndex = edit.measure;
      _refresh(select: edit.before);
    });
    _keepDraft();
    _reveal();
  }

  void _redo() {
    if (_cursor >= _history.length - 1) return;
    setState(() {
      _spanFrom = null;
      _keysAppend = false;
      _dropRange();
      final edit = _edits[_cursor];
      _cursor++;
      _measureIndex = edit.measureAfter;
      _refresh(select: edit.after);
    });
    _keepDraft();
    _reveal();
  }

  void _goToMeasure(int index, {int select = 0}) {
    if (index < 0 || index >= _measureCount || index == _measureIndex) return;
    setState(() {
      _measureIndex = index;
      _keysAppend = false;
      _endChord();
      _dropRange();
      _refresh(select: select);
    });
    _reveal();
  }

  /// Brings the current bar into view once the frame is drawn.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scoreKey.currentState?.showMeasure(_measureIndex);
    });
  }

  /// Works on the bar a tap fell in, without moving the page: the bar is
  /// under the finger.
  bool _enterBar(int index) {
    if (index == _measureIndex) return true;
    if (index < 0 || index >= _measureCount) return false;
    try {
      setState(() {
        _measureIndex = index;
        _keysAppend = false;
        _endChord();
        _dropRange();
        _refresh(select: 0);
      });
      return true;
    } on FormatException catch (error) {
      _showMessage(error.message);
      return false;
    }
  }

  /// The note before (-1) or after (+1) the picked one, into the next bar
  /// where the bar ends.
  void _stepNote(int by) {
    // Building chords, the arrow goes on to the next note or rest: the
    // tones of the chord just built are not stops on the way.
    if (_chordKeys && by > 0) {
      _stepEvent();
      return;
    }
    final index = _noteIndex;
    final count = _previewMeasure.notes.length;
    if (index != null && index + by >= 0 && index + by < count) {
      _selectNote(index + by);
      _soundPicked();
    } else if (by < 0 && _measureIndex > 0) {
      _goToMeasure(_measureIndex - 1, select: 1 << 20);
    } else if (by > 0 && _measureIndex < _measureCount - 1) {
      _goToMeasure(_measureIndex + 1);
    }
  }

  void _selectNote(int index) {
    final count = _previewMeasure.notes.length;
    if (index < 0 || index >= count) return;
    // The bar is already read: picking another note needs no new pass.
    setState(() {
      _keysAppend = false;
      _endChord();
      _noteIndex = index;
      _summary = index < _bar.notes.length ? _bar.notes[index] : null;
    });
  }

  void _onEventTapped(ScoreEventAddress address) {
    // With the range tool a tap is the other end of the run, in whatever
    // bar: the bar being worked on stays the one the run began in.
    if (_ranging &&
        _noteIndex != null &&
        _spanFrom == null &&
        _tool == _Tool.select) {
      final end = xmlNoteIndexForEvent(
        _shownMeasure(address.measureIndex),
        address.eventIndex,
      );
      if (end == null) return;
      setState(() {
        _barSel = null;
        _rangeEnd = (bar: address.measureIndex, note: end);
      });
      return;
    }
    if (!_enterBar(address.measureIndex)) return;
    final index = xmlNoteIndexForEvent(
      _shownMeasure(address.measureIndex),
      address.eventIndex,
    );
    if (index == null) return;
    if (_spanFrom != null) {
      _finishSpan(index);
      return;
    }
    if (_tool == _Tool.eraser) {
      _selectNote(index);
      _erase();
      return;
    }
    // A tap on one note lets a run of notes go.
    if (_rangeEnd != null || _barSel != null) setState(_dropRange);
    _selectNote(index);
    // The keyboard shows the octave of the note that was picked.
    if (index < _bar.notes.length) {
      if (_bar.notes[index].pitch case final pitch?) {
        _keyboardOctave = pitch.octave.clamp(1, 7);
      }
    }
  }

  /// The eraser: a note becomes a rest, an ornament note goes. A rest
  /// stays: taking it out would move every note after it.
  void _erase() {
    final summary = _summary;
    if (summary == null || summary.isRest) return;
    _apply(summary.isGrace ? _editor.removeNote : _editor.deleteNote);
  }

  /// Whether the word on what a tap does with the tool in hand is shown:
  /// for a moment after the tool is taken up, then the score is clear
  /// again.
  var _toolHint = false;
  Timer? _toolHintTimer;

  void _setTool(_Tool tool) => setState(() {
    _tool = tool;
    _toolHint = true;
    _toolHintTimer?.cancel();
    _toolHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toolHint = false);
    });
    _keysAppend = false;
    if (tool != _Tool.select) {
      _ranging = false;
      _dropRange();
    }
  });

  /// Gives the picked note the value in hand before it is written, where
  /// it can take it: a note of a tuplet keeps its own, and a value that does
  /// not fit the bar leaves the note as long as it is.
  XmlEditResult _withEntryValue(String xml, XmlNoteRef ref) {
    final target = _editor.describe(xml, ref);
    if (target.isGrace ||
        target.inTuplet ||
        (target.type == _entryType && target.dots == _entryDots)) {
      return XmlEditResult(xml, ref);
    }
    try {
      return _editor.setDuration(xml, ref, _entryType, _entryDots);
    } on FormatException {
      return XmlEditResult(xml, ref);
    }
  }

  /// The dot: the picked note gets one, then two, then none; the value in
  /// hand follows it.
  void _dot() {
    final summary = _summary;
    if (summary == null || summary.isGrace || summary.inTuplet) {
      setState(() => _entryDots = (_entryDots + 1) % 3);
      return;
    }
    final type = summary.type;
    if (type == null) return;
    final dots = (summary.dots + 1) % 3;
    setState(() => _entryDots = dots);
    _setLength(type, dots);
  }

  /// Opens the note values beside the note tool; the one picked is the
  /// value the note and rest tools write.
  Future<void> _pickEntryValue(BuildContext anchor) async {
    final l10n = context.l10n;
    final type = await showToolFlyout<String>(
      anchor,
      choices: [
        for (final type in noteDurationTypes)
          (
            value: type,
            tooltip: '${l10n.noteValue} ${_fractionOf[type]}',
            selected: _entryType == type,
            child: MusicGlyph(MusicGlyphs.duration(type)),
          ),
      ],
    );
    if (type == null || !mounted) return;
    setState(() {
      _entryType = type;
      _entryDots = 0;
      if (!_writing) _tool = _Tool.note;
    });
  }

  /// Opens the accidentals beside their tool; the one picked goes on the
  /// picked notes.
  Future<void> _pickAccidental(BuildContext anchor) async {
    final l10n = context.l10n;
    final picked = _summary?.pitch?.alter;
    final alter = await showToolFlyout<int>(
      anchor,
      choices: [
        for (final (alter, label) in [
          (1, l10n.noteSharp),
          (-1, l10n.noteFlat),
          (0, l10n.noteNatural),
          (2, l10n.doubleSharp),
          (-2, l10n.doubleFlat),
        ])
          (
            value: alter,
            tooltip: label,
            selected: picked == alter,
            child: MusicGlyph(MusicGlyphs.accidental(alter)),
          ),
      ],
    );
    if (alter == null || !mounted) return;
    _applyEach(
      (xml, ref) => _editor.setAlter(xml, ref, alter),
      where: (note) => !note.isRest && !note.isGrace,
    );
  }

  /// Opens the list of palettes; the one picked shows its tools under the
  /// score.
  Future<void> _choosePalette() async {
    final l10n = context.l10n;
    final palette = await showModalBottomSheet<_Palette>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final palette in _Palette.values)
                _PaletteTile(
                  label: _paletteLabel(l10n, palette),
                  selected: _panel == _Panel.palette && _palette == palette,
                  onTap: () => Navigator.of(context).pop(palette),
                  child: switch (palette) {
                    _Palette.note => const Icon(Icons.edit_note_rounded),
                    _Palette.length => const MusicGlyph(MusicGlyphs.note8thUp),
                    _Palette.pitch => const MusicGlyph(
                      MusicGlyphs.accidentalSharp,
                    ),
                    _Palette.marks => const MusicGlyph(
                      MusicGlyphs.fermataAbove,
                    ),
                    _Palette.looks => const Icon(Icons.auto_fix_high_rounded),
                    _Palette.words => const Text(
                      'C7',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _Palette.bar => const MusicGlyph(MusicGlyphs.repeatRight),
                    _Palette.score => const MusicGlyph(MusicGlyphs.gClef),
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (palette == null || !mounted) return;
    _openPalette(palette);
  }

  void _openPalette(_Palette palette) {
    setState(() {
      _palette = palette;
      _panel = _Panel.palette;
    });
    // The panel takes room from the score: the bar worked on stays in view.
    _reveal();
  }

  /// Begins drawing [kind] at the picked note, or takes away the one that
  /// begins or ends there.
  void _startSpan(SpanKind kind) {
    final index = _noteIndex;
    final summary = _summary;
    if (index == null || summary == null) return;
    if (summary.spans.contains(kind)) {
      _apply((xml, ref) => _editor.removeSpan(xml, ref, kind));
      return;
    }
    // With a run of notes picked the line is drawn over the run at once,
    // as when a selection is made first and the tool tapped then.
    final picked = _pickedRefs;
    if (_rangeEnd != null && picked.length > 1) {
      _apply(
        (xml, ref) => _editor.addSpan(xml, picked.first, picked.last, kind),
        keepRange: true,
      );
      return;
    }
    setState(
      () => _spanFrom = (kind: kind, measure: _measureIndex, note: index),
    );
  }

  /// Draws the line being drawn as far as the note [index] of this bar.
  void _finishSpan(int index) {
    final span = _spanFrom;
    if (span == null) return;
    final start = XmlNoteRef(
      partIndex: widget.partIndex,
      measureIndex: span.measure,
      noteIndex: span.note,
    );
    _selectNote(index);
    _apply((xml, ref) => _editor.addSpan(xml, start, ref, span.kind));
  }

  /// Applies [edit] to every picked note that [where] takes, as one step
  /// that undo takes back as one. With [backwards] the last note first, for
  /// edits after which the notes behind are counted anew.
  void _applyEach(
    XmlEditResult Function(String xml, XmlNoteRef ref) edit, {
    bool Function(XmlNoteSummary note)? where,
    bool backwards = false,
  }) {
    final picked = _pickedRefs;
    if (picked.length <= 1) {
      _apply(edit);
      return;
    }
    final bars = _barSel;
    _apply((xml, ref) {
      var current = xml;
      var done = 0;
      final read = <int, List<XmlNoteSummary>>{};
      for (final at in backwards ? picked.reversed : picked) {
        final notes = read[at.measureIndex] ??= _summariesOf(
          xml,
          at.measureIndex,
        );
        if (at.noteIndex >= notes.length) continue;
        if (where != null && !where(notes[at.noteIndex])) continue;
        try {
          current = edit(current, at).xml;
          done++;
        } on FormatException {
          // A note the edit does not fit is passed over.
        }
      }
      if (done == 0) {
        throw const FormatException('고른 음에는 할 수 없는 편집입니다.');
      }
      return XmlEditResult(current, ref);
    }, keepRange: !backwards);
    // Whole bars stay picked whatever was done to their notes: the bars
    // are the same bars, with other notes in them.
    if (bars != null && _barSel == null && bars.to < _measureCount) {
      _pickBars(bars.from, bars.to);
    }
  }

  /// Puts an articulation on every picked note, or takes it off them all
  /// when every one of them has it.
  void _toggleMark(String name, {required bool restsToo}) {
    bool has(XmlNoteSummary note) =>
        name == 'fermata' ? note.fermata : note.articulations.contains(name);
    bool takes(XmlNoteSummary note) =>
        note.leadsChord && !note.isGrace && (restsToo || !note.isRest);
    final all = [
      for (final note in _pickedSummaries)
        if (takes(note)) note,
    ];
    final allHave = all.isNotEmpty && all.every(has);
    _applyEach(
      (xml, ref) => _editor.toggleArticulation(xml, ref, name),
      where: (note) => takes(note) && has(note) == allHave,
    );
  }

  Future<void> _askBarRange({int? from, int? to}) async {
    final first = _firstBarNumber;
    final choice = await showDialog<_BarRangeChoice>(
      context: context,
      builder: (_) => _BarRangeDialog(
        current: (from ?? _measureIndex) + first,
        currentTo: (to ?? from ?? _measureIndex) + first,
        first: first,
        last: _measureCount - 1 + first,
      ),
    );
    if (choice == null || !mounted) return;
    _actOnBars(
      choice.action,
      choice.from - first,
      choice.to - first,
      semitones: choice.semitones,
    );
  }

  /// Copies, cuts, removes or transposes the bars [from]..[to].
  void _actOnBars(
    _BarRangeAction action,
    int from,
    int to, {
    int semitones = 0,
  }) {
    final l10n = context.l10n;
    if (action == _BarRangeAction.copy || action == _BarRangeAction.cut) {
      try {
        final clip = _editor.copyMeasures(_xml, from, to);
        setState(() => _clip = clip);
        if (action == _BarRangeAction.copy) {
          _showMessage(l10n.barsCopied(clip.length));
          return;
        }
      } on FormatException catch (error) {
        _showMessage(error.message);
        return;
      }
    }
    switch (action) {
      case _BarRangeAction.copy:
        break;
      case _BarRangeAction.cut || _BarRangeAction.delete:
        _apply(
          (xml, ref) => _editor.clearMeasures(xml, widget.partIndex, from, to),
          bars: (bars, _) => bars,
          keepRange: true,
        );
        if (_barSel == null) _pickBars(from, to);
      case _BarRangeAction.remove:
        _apply(
          (xml, ref) => _editor.deleteMeasures(xml, widget.partIndex, from, to),
          bars: (bars, _) => [...bars]..removeRange(from, to + 1),
        );
      case _BarRangeAction.transpose:
        _apply(
          (xml, ref) => _editor.transposeMeasures(
            xml,
            widget.partIndex,
            from,
            to,
            semitones,
          ),
          bars: (bars, _) => bars,
          keepRange: true,
        );
    }
  }

  /// Puts the copied bars after bar [after], or after the bar being worked
  /// on.
  void _pasteBars({int? after, MeasureClip? clip}) {
    final pasted = clip ?? _clip;
    if (pasted == null) return;
    final at = after ?? _measureIndex;
    _apply(
      (xml, ref) => _editor.pasteMeasures(
        xml,
        XmlNoteRef(partIndex: widget.partIndex, measureIndex: at, noteIndex: 0),
        pasted,
      ),
      bars: (bars, _) => [...bars]
        ..insertAll(at + 1, [
          for (var i = 0; i < pasted.length; i++) _nextBarId++,
        ]),
    );
  }

  /// Writes the copied bars over the bars from [at] on: as many bars give
  /// way as were copied, and the score grows where they do not fit.
  void _overwriteBars(int at) {
    final clip = _clip;
    if (clip == null) return;
    _apply(
      (xml, ref) => _editor.overwriteMeasures(xml, ref.inBar(at, 0), clip),
      bars: (bars, _) => [
        ...bars,
        for (var i = bars.length; i < at + clip.length; i++) _nextBarId++,
      ],
    );
    if (at + clip.length <= _measureCount) {
      _pickBars(at, at + clip.length - 1);
    }
  }

  /// The picked bars once more, right after themselves.
  void _duplicateBars(int from, int to) {
    try {
      _pasteBars(after: to, clip: _editor.copyMeasures(_xml, from, to));
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  /// A finger carried the picked notes: up or down the staff, or to the
  /// side for an accidental.
  void _onSelectionDragged(int steps, int alter) {
    if (steps != 0) {
      _applyEach(
        (xml, ref) => _editor.moveDiatonic(xml, ref, steps),
        where: (note) => !note.isRest,
      );
    }
    if (alter != 0) {
      _applyEach((xml, ref) {
        final now = _editor.describe(xml, ref).pitch?.alter ?? 0;
        return _editor.setAlter(xml, ref, (now + alter).clamp(-2, 2));
      }, where: (note) => !note.isRest);
    }
    _soundPicked();
  }

  /// Words of the score were tapped: the chord symbol or the syllable of
  /// the note they stand at is what is to be corrected.
  void _onTextTapped(ScoreEventAddress address, bool above) {
    if (!_enterBar(address.measureIndex)) return;
    final index = xmlNoteIndexForEvent(
      _shownMeasure(address.measureIndex),
      address.eventIndex,
    );
    if (index == null) return;
    if (_rangeEnd != null || _barSel != null) setState(_dropRange);
    _selectNote(index);
    final summary = _summary;
    if (summary == null) return;
    if (above) {
      unawaited(_editChordSymbol());
    } else if (!summary.isRest && !summary.isGrace) {
      unawaited(_editLyric());
    }
  }

  /// A finger held down and moved, or a handle of the run, goes over the
  /// score: the notes from where it began to where it is are picked.
  void _onRangeDragged(ScoreEventAddress from, ScoreEventAddress to) {
    final bars = _barSel;
    if (from.measureIndex != _measureIndex && !_enterBar(from.measureIndex)) {
      return;
    }
    final start = xmlNoteIndexForEvent(
      _shownMeasure(from.measureIndex),
      from.eventIndex,
    );
    final end = xmlNoteIndexForEvent(
      _shownMeasure(to.measureIndex),
      to.eventIndex,
    );
    if (start == null || end == null) return;
    setState(() {
      _ranging = false;
      if (bars != null) {
        // Whole bars stay whole bars.
        final forward = to.measureIndex >= from.measureIndex;
        final count = _notesOf(from.measureIndex).length;
        final last = _notesOf(to.measureIndex).length - 1;
        _noteIndex = count == 0 ? null : (forward ? 0 : count - 1);
        _rangeEnd = (
          bar: to.measureIndex,
          note: forward ? math.max(0, last) : 0,
        );
        _barSel = (
          from: math.min(from.measureIndex, to.measureIndex),
          to: math.max(from.measureIndex, to.measureIndex),
        );
      } else {
        _noteIndex = start;
        _rangeEnd = (bar: to.measureIndex, note: end);
        _barSel = null;
      }
      final index = _noteIndex;
      _summary = index != null && index < _bar.notes.length
          ? _bar.notes[index]
          : null;
    });
  }

  /// A bar tapped twice: the whole bar is picked, and what is done to bars
  /// stands ready under the score.
  void _onBarDoubleTapped(int index) => _pickBars(index, index);

  /// Picks the bars [from]..[to] whole.
  void _pickBars(int from, int to) {
    if (!_enterBar(from)) return;
    final count = _previewMeasure.notes.length;
    final last = _notesOf(to).length;
    setState(() {
      _tool = _Tool.select;
      _ranging = false;
      _only = _Only.all;
      _barSel = (from: from, to: to);
      _noteIndex = count == 0 ? null : 0;
      _summary = _bar.notes.isEmpty ? null : _bar.notes.first;
      _rangeEnd = count == 0 ? null : (bar: to, note: math.max(0, last - 1));
    });
  }

  /// Gives every picked note the same value. A run of notes closes up, the
  /// notes following one another as before; a single note keeps the notes
  /// after it where they are.
  void _setLength(String type, int dots) {
    final picked = _pickedRefs;
    if (picked.length <= 1) {
      _apply((xml, ref) => _editor.setDuration(xml, ref, type, dots));
      return;
    }
    final bars = <int, List<int>>{};
    for (final ref in picked) {
      final notes = _summariesOf(_xml, ref.measureIndex);
      if (ref.noteIndex >= notes.length) continue;
      final note = notes[ref.noteIndex];
      if (!note.leadsChord || note.isGrace || note.inTuplet) continue;
      bars.putIfAbsent(ref.measureIndex, () => []).add(ref.noteIndex);
    }
    _apply((xml, ref) {
      var current = xml;
      var done = 0;
      for (final MapEntry(key: bar, value: notes) in bars.entries) {
        try {
          current = _editor.setNoteLengths(current, widget.partIndex, bar, {
            for (final note in notes) note: (type: type, dots: dots),
          }).xml;
          done += notes.length;
        } on FormatException {
          // A bar that cannot close up (voices, tuplets): note by note,
          // the last first, so the ones before keep their numbers.
          for (final note in notes.reversed) {
            try {
              current = _editor
                  .setDuration(current, ref.inBar(bar, note), type, dots)
                  .xml;
              done++;
            } on FormatException {
              // A note that cannot take the value is passed over.
            }
          }
        }
      }
      if (done == 0) {
        throw const FormatException('고른 음에는 할 수 없는 편집입니다.');
      }
      return XmlEditResult(current, ref);
    });
  }

  static String _spanLabel(AppLocalizations l10n, SpanKind kind) =>
      switch (kind) {
        SpanKind.slur => l10n.slurTool,
        SpanKind.glissando => l10n.glissando,
        SpanKind.crescendo => l10n.crescendo,
        SpanKind.diminuendo => l10n.diminuendo,
        SpanKind.octaveUp => '8va',
        SpanKind.octaveDown => '8vb',
        SpanKind.pedal => l10n.pedalLine,
      };

  /// A key of the keyboard: the picked note or rest takes its pitch.
  void _enterKey(int midi) {
    final index = _noteIndex;
    final summary = _summary;
    if (index == null || summary == null) return;
    if (_chordKeys) {
      _chordKey(midi);
      return;
    }
    if (_keysAppend && _tool == _Tool.note) {
      final before = _xml;
      _apply((xml, ref) {
        final added = _editor.insertEvent(
          xml,
          ref,
          before: false,
          rest: false,
          value: (type: _entryType, dots: _entryDots),
        );
        return _editor.enterPitch(added.xml, added.selection, midi);
      });
      // The bar is full now, or the value did not fit: the keys go on in
      // the next bar.
      final wrote = !identical(before, _xml);
      if (wrote) _soundPicked();
      final more = wrote && (_lengthOff ?? 0) < 0;
      setState(() => _keysAppend = more);
      if (wrote && !more && _measureIndex < _measureCount - 1) {
        _goToMeasure(_measureIndex + 1);
      }
      return;
    }
    final value =
        _tool == _Tool.note &&
        !summary.isGrace &&
        !summary.inTuplet &&
        (summary.type != _entryType || summary.dots != _entryDots);
    if (value || summary.isRest || summary.pitch?.midi != midi) {
      final before = _xml;
      _apply((xml, ref) {
        // With the note tool a key writes a note of the value in hand.
        final sized = _tool == _Tool.note
            ? _withEntryValue(xml, ref)
            : XmlEditResult(xml, ref);
        final now = _editor.describe(sized.xml, sized.selection);
        return now.isRest || now.pitch?.midi != midi
            ? _editor.enterPitch(sized.xml, sized.selection, midi)
            : sized;
      });
      if (identical(before, _xml)) return;
    }
    _soundPicked();
    _afterKey();
  }

  /// On to the next note or rest, not to another note of the same chord:
  /// a line is played in one key after the other.
  void _afterKey() {
    if (_stepEvent(intoNextBar: false)) return;
    if (_tool == _Tool.note && (_lengthOff ?? 0) < 0) {
      // The bar is short of its time: the next key writes into what is
      // missing, a new note after this one.
      setState(() => _keysAppend = true);
    } else if (_measureIndex < _measureCount - 1) {
      _goToMeasure(_measureIndex + 1);
    }
  }

  /// The rest key of the keyboard: a rest of the value in hand where the
  /// cursor is, and on to the next, as a key writes a note.
  void _enterRest() {
    if (_noteIndex == null || _summary == null) return;
    final before = _xml;
    if (_keysAppend && _tool == _Tool.note) {
      _apply(
        (xml, ref) => _editor.insertEvent(
          xml,
          ref,
          before: false,
          rest: true,
          value: (type: _entryType, dots: _entryDots),
        ),
      );
      final wrote = !identical(before, _xml);
      final more = wrote && (_lengthOff ?? 0) < 0;
      setState(() => _keysAppend = more);
      if (wrote && !more && _measureIndex < _measureCount - 1) {
        _goToMeasure(_measureIndex + 1);
      }
      return;
    }
    _apply((xml, ref) {
      var current = _tool == _Tool.note
          ? _withEntryValue(xml, ref)
          : XmlEditResult(xml, ref);
      // A chord goes note by note until a rest is left.
      for (var i = 0; i < 8; i++) {
        if (_editor.describe(current.xml, current.selection).isRest) break;
        current = _editor.deleteNote(current.xml, current.selection);
      }
      return current;
    });
    _afterKey();
  }

  /// Picks the next note, chord or rest of the bar, passing over the other
  /// notes of a chord and over ornament notes; at the end of the bar the
  /// first of the next, with [intoNextBar]. Says whether it moved.
  bool _stepEvent({bool intoNextBar = true}) {
    final index = _noteIndex;
    if (index == null) return false;
    final notes = _bar.notes;
    var next = index + 1;
    while (next < notes.length &&
        (!notes[next].leadsChord || notes[next].isGrace)) {
      next++;
    }
    if (next < notes.length) {
      _selectNote(next);
      return true;
    }
    if (!intoNextBar || _measureIndex >= _measureCount - 1) return false;
    _goToMeasure(_measureIndex + 1);
    return true;
  }

  /// A key in chord mode: the first is the note itself, the ones after it
  /// join it. The cursor stays; the arrow goes on to the next note.
  void _chordKey(int midi) {
    if (_chordNow.contains(midi)) return;
    final before = _xml;
    final first = _chordNow.isEmpty;
    _apply((xml, ref) {
      if (!first) {
        // The picked note stays the one the chord is built on.
        return XmlEditResult(_editor.addChordPitch(xml, ref, midi).xml, ref);
      }
      final sized = _tool == _Tool.note
          ? _withEntryValue(xml, ref)
          : XmlEditResult(xml, ref);
      final now = _editor.describe(sized.xml, sized.selection);
      return now.isRest || now.pitch?.midi != midi
          ? _editor.enterPitch(sized.xml, sized.selection, midi)
          : sized;
    });
    // The first key may find the note as it should be: it still counts.
    if (!first && identical(before, _xml)) return;
    setState(() => _chordNow = [..._chordNow, midi]);
    _soundPicked();
  }

  /// Writes the chord built before on the picked note, and goes on.
  void _repeatChord() {
    final chord = _chordBefore;
    if (chord.isEmpty || _noteIndex == null) return;
    final before = _xml;
    _apply((xml, ref) {
      final sized = _tool == _Tool.note
          ? _withEntryValue(xml, ref)
          : XmlEditResult(xml, ref);
      final now = _editor.describe(sized.xml, sized.selection);
      var current = now.isRest || now.pitch?.midi != chord.first
          ? _editor.enterPitch(sized.xml, sized.selection, chord.first).xml
          : sized.xml;
      for (final midi in chord.skip(1)) {
        try {
          current = _editor.addChordPitch(current, ref, midi).xml;
        } on FormatException {
          // A tone the chord there already has.
        }
      }
      return XmlEditResult(current, ref);
    });
    if (identical(before, _xml)) return;
    _stepEvent();
    // Going on made the repeated chord "the chord before" only if keys
    // were pressed; it stays what it was.
    _chordBefore = chord;
  }

  /// Takes the picked notes to be written elsewhere.
  void _copyNotes() {
    try {
      final clip = _editor.copyNotes(_xml, _pickedRefs);
      setState(() => _noteClip = clip);
      _showMessage(context.l10n.notesCopied(clip.length));
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  /// The note and rest tools: the note or rest nearest to the tap becomes a
  /// note on the line that was tapped, or a rest, of the value in hand.
  void _onNotePlaced(NativeStaffPlace place) {
    if (!_enterBar(place.measureIndex)) return;
    final index = xmlNoteIndexForEvent(
      _shownMeasure(place.measureIndex),
      place.eventIndex,
    );
    if (index == null || index >= _bar.notes.length) return;
    _selectNote(index);
    final target = _bar.notes[index];
    final rest = _tool == _Tool.rest;
    final value =
        !target.isGrace &&
        !target.inTuplet &&
        (target.type != _entryType || target.dots != _entryDots);
    final pitch = target.pitch;
    final moves = rest
        ? !target.isRest
        : target.isRest ||
              pitch == null ||
              pitch.step != place.step ||
              pitch.octave != place.octave;
    // Beside a note, where the bar has room: a new note or rest of the
    // value in hand, not another pitch for the note that is there.
    final beside = place.beside;
    // A finger moved to the side asks for an accidental with the note.
    final sharpen = rest ? 0 : place.alter;
    if (beside == 0 && !value && !moves && sharpen == 0) return;
    _apply((xml, ref) {
      final written = _writeAt(
        xml,
        ref,
        place,
        rest: rest,
        plain: !value && !moves && sharpen == 0,
      );
      if (sharpen == 0) return written;
      final now = _editor.describe(written.xml, written.selection).pitch;
      if (now == null) return written;
      try {
        return _editor.setAlter(
          written.xml,
          written.selection,
          (now.alter + sharpen).clamp(-2, 2),
        );
      } on FormatException {
        return written;
      }
    });
    if (!rest) _soundPicked();
  }

  /// Writes the note or rest [place] asks for at [ref]: a new one beside
  /// the note there where the bar has room, or else that note on the line
  /// pointed at, with the value in hand. With [plain] the note there is
  /// already as asked.
  XmlEditResult _writeAt(
    String xml,
    XmlNoteRef ref,
    NativeStaffPlace place, {
    required bool rest,
    required bool plain,
  }) {
    if (place.beside != 0) {
      try {
        final added = _editor.insertEvent(
          xml,
          ref,
          before: place.beside < 0,
          rest: rest,
          value: (type: _entryType, dots: _entryDots),
        );
        return rest
            ? added
            : _editor.placeNote(
                added.xml,
                added.selection,
                place.step,
                place.octave,
              );
      } on FormatException {
        // No room in the bar: the note that is there is meant, and when
        // there is nothing to change on it either, the bar says why
        // nothing happened.
        if (plain) rethrow;
      }
    }
    final sized = _withEntryValue(xml, ref);
    final now = _editor.describe(sized.xml, sized.selection);
    if (rest) {
      return now.isRest
          ? sized
          : _editor.deleteNote(sized.xml, sized.selection);
    }
    final at = now.pitch;
    return !now.isRest &&
            at != null &&
            at.step == place.step &&
            at.octave == place.octave
        ? sized
        : _editor.placeNote(
            sized.xml,
            sized.selection,
            place.step,
            place.octave,
          );
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

  bool _barPlaying = false;

  /// The player says when the bar starts and stops sounding. It also
  /// speaks from inside the engraving's own build, when nothing may be
  /// rebuilt: the button is then drawn again after the frame.
  void _onPlayback() {
    final playing = _playback.state.playing;
    // Only the picked bars were asked for: the player stops after them.
    final until = _playUntil;
    if (until != null) {
      if (!playing) {
        _playUntil = null;
      } else if (_playback.state.measureNumber - 1 > until) {
        _playUntil = null;
        unawaited(_playback.stop());
      }
    }
    if (playing == _barPlaying || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _barPlaying = _playback.state.playing);
      });
    } else {
      setState(() => _barPlaying = playing);
    }
  }

  /// Plays from the current bar on, or stops.
  Future<void> _playBar() async {
    if (_playback.state.playing) {
      await _playback.stop();
      return;
    }
    await _playback.stop();
    // Picked bars play alone; without any, the score from this bar on.
    final bars = _barSel;
    await _playback.playFromMeasure(bars?.from ?? _measureIndex);
    _playUntil = bars?.to;
  }

  /// How the bar's notes fall short of or run over its time, in beats of
  /// the time signature; null when they fit. A converted bar that does not
  /// add up is the first thing to look at. The first bar may be a pickup.
  double? get _lengthOff {
    final bar = _previewMeasure;
    final time = bar.attributes.time;
    if (time == null || bar.attributes.divisions <= 0) return null;
    if (bar.notes.isEmpty) return null;
    final beat = 4 / time.beatType;
    final off =
        bar.durationDivisions / bar.attributes.divisions / beat - time.beats;
    if (off.abs() < 1e-6) return null;
    if (off < 0 && (_measureIndex == 0 || _signs.pickup)) return null;
    return off;
  }

  /// Corrects the word under the selected note. The keyboard's "next" writes
  /// it and goes on to the next sung note, so a line of misread words is
  /// typed in one go.
  Future<void> _editLyric() async {
    while (mounted) {
      final summary = _summary;
      final index = _noteIndex;
      if (_ref == null || summary == null || index == null) return;
      if (summary.isRest || summary.isGrace) return;
      // As it is typed: a hyphen or a held line shows at its end.
      final initial = summary.lyricTyped(_verse);
      final result = await showDialog<({String text, bool next})>(
        context: context,
        builder: (_) => _LyricDialog(initial: initial),
      );
      if (result == null || !mounted) return;
      final words = result.text.trim().split(RegExp(r'\s+'));
      if (words.length > 1) {
        // A line of words, as it is pasted into a notation program: one
        // to each sung note from here on.
        _spreadLyrics(words);
        return;
      }
      if (result.text != initial) {
        _apply(
          (xml, ref) => _editor.setLyric(
            xml,
            ref,
            result.text,
            verse: _verse,
            typed: true,
          ),
        );
      }
      if (!result.next) return;
      // The next note that is sung: not a rest, an ornament, or another
      // note of the same chord.
      final notes = _bar.notes;
      var next = index + 1;
      while (next < notes.length &&
          (notes[next].isRest ||
              notes[next].isGrace ||
              !notes[next].leadsChord)) {
        next++;
      }
      if (next >= notes.length) return;
      _selectNote(next);
    }
  }

  /// Writes [words] under the sung notes from the picked one on, one to
  /// each, in the staff of the picked note and on into the next bars.
  void _spreadLyrics(List<String> words) {
    final staff = _summary?.staff;
    final count = _measureCount;
    _apply((xml, ref) {
      var current = xml;
      var bar = ref.measureIndex;
      var note = ref.noteIndex;
      var last = ref;
      for (final word in words) {
        XmlNoteRef? at;
        while (bar < count && at == null) {
          final notes = _editor.inspect(current, widget.partIndex, bar).notes;
          while (note < notes.length &&
              (notes[note].isRest ||
                  notes[note].isGrace ||
                  !notes[note].leadsChord ||
                  (staff != null && notes[note].staff != staff))) {
            note++;
          }
          if (note < notes.length) {
            at = ref.inBar(bar, note);
          } else {
            bar++;
            note = 0;
          }
        }
        if (at == null) break;
        current = _editor
            .setLyric(current, at, word, verse: _verse, typed: true)
            .xml;
        last = at;
        note++;
      }
      return XmlEditResult(current, last);
    });
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
      _draftTimer?.cancel();
      _draftTimer = null;
      await service.discardDraft(widget.songId);
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
        // Thrown away on purpose: not offered again.
        _draftTimer?.cancel();
        _draftTimer = null;
        _savedCursor = _cursor;
        await _drafts.discardDraft(widget.songId);
        if (mounted) Navigator.of(context).pop(false);
      case _LeaveChoice.save:
        await _save();
    }
  }

  Widget _engraving(AppLocalizations l10n, int? selectedEvent) {
    final picked = _pickedRefs;
    // With only the outer notes of chords picked, the note the run began
    // on may not be one of them: it is then not shown as picked.
    final anchored = picked.any(
      (ref) => ref.measureIndex == _measureIndex && ref.noteIndex == _noteIndex,
    );
    return LayoutBuilder(
      builder: (context, constraints) => VerovioScoreView(
        key: _scoreKey,
        score: _previewScore,
        // Line by line: an edit engraves the line it is in, not the score.
        engravingChunks: _chunks,
        // A narrower page for the same lines: larger notes.
        engravingPageSize: _noteSize == 1.0
            ? null
            : Size(
                (2100 / _noteSize).roundToDouble(),
                (2970 / _noteSize).roundToDouble(),
              ),
        playbackXml: () => partAloneXml(_xml, widget.partIndex),
        showZoomControls: false,
        semanticsLabel: l10n.proofreadBar(
          _measureIndex + _firstBarNumber,
          _measureCount - 1 + _firstBarNumber,
        ),
        playback: _playback,
        playbackVisible: true,
        // Every edit changes the score: the page stays while the new one
        // is engraved.
        keepPagesOnChange: true,
        // One finger moves the page with every tool. Writing, a tap places
        // the note and a finger held still carries it to its line.
        inputMode: _writing ? 'place' : 'select',
        onEventTapped: _writing ? null : _onEventTapped,
        onNotePlaced: _onNotePlaced,
        // With the select tool a finger also carries the picked notes,
        // picks a run of them when held, and picks a bar tapped twice.
        onSelectionDragged: _tool == _Tool.select ? _onSelectionDragged : null,
        onRangeDragged: _tool == _Tool.select ? _onRangeDragged : null,
        onMeasureDoubleTapped: _tool == _Tool.select
            ? _onBarDoubleTapped
            : null,
        onTextTapped: _tool == _Tool.select && _spanFrom == null && !_ranging
            ? _onTextTapped
            : null,
        // Held and lifted on a note: what can be done to it is offered,
        // as a long press opens the menu of a notation program.
        onLongPressed: _tool == _Tool.select && _spanFrom == null
            ? (address) {
                if (!_enterBar(address.measureIndex)) return;
                final index = xmlNoteIndexForEvent(
                  _shownMeasure(address.measureIndex),
                  address.eventIndex,
                );
                if (index == null) return;
                setState(_dropRange);
                _selectNote(index);
                unawaited(_choosePalette());
              }
            : null,
        // A tap on the bare page lets a run of notes or bars go.
        onBlankTapped: () {
          if (_rangeEnd != null || _barSel != null) setState(_dropRange);
        },
        rangeHandles: _tool == _Tool.select && _rangeEnd != null,
        highlightedMeasureIndex: _barSel == null ? _measureIndex : null,
        highlightedMeasureRange: _barSel == null
            ? null
            : (start: _barSel!.from, end: _barSel!.to),
        selectedNoteAddress: selectedEvent == null || !anchored
            ? null
            : ScoreEventAddress(
                partIndex: 0,
                measureIndex: _measureIndex,
                eventIndex: selectedEvent,
              ),
        alsoSelectedNotes: [
          for (final ref in picked)
            if (ref.measureIndex != _measureIndex ||
                ref.noteIndex != _noteIndex)
              if (eventIndexForXmlNote(
                    _shownMeasure(ref.measureIndex),
                    ref.noteIndex,
                  )
                  case final event?)
                ScoreEventAddress(
                  partIndex: 0,
                  measureIndex: ref.measureIndex,
                  eventIndex: event,
                ),
        ],
      ),
    );
  }

  /// The tools beside the score: what a tap does, the value in hand, and
  /// the ways to the rest.
  List<Widget> _railTools(AppLocalizations l10n) {
    final summary = _summary;
    final hasNote = summary != null && !summary.isRest && !summary.isGrace;
    return [
      EditorToolButton(
        tooltip: l10n.toolSelect,
        selected: _tool == _Tool.select,
        onPressed: () => _setTool(_Tool.select),
        child: const Icon(Icons.highlight_alt_rounded),
      ),
      EditorToolButton(
        tooltip: l10n.toolEraser,
        selected: _tool == _Tool.eraser,
        onPressed: () => _setTool(_Tool.eraser),
        child: const EraserIcon(),
      ),
      // The note tool shows the value it writes; in use, a tap on it
      // opens the values.
      Builder(
        builder: (context) => EditorToolButton(
          tooltip: l10n.toolNote,
          selected: _tool == _Tool.note,
          hasMore: true,
          onPressed: () => _tool == _Tool.note
              ? unawaited(_pickEntryValue(context))
              : _setTool(_Tool.note),
          onLongPress: () => unawaited(_pickEntryValue(context)),
          child: MusicGlyph(MusicGlyphs.duration(_entryType)),
        ),
      ),
      EditorToolButton(
        tooltip: l10n.toolRest,
        selected: _tool == _Tool.rest,
        // A second tap goes back to writing notes.
        onPressed: () =>
            _setTool(_tool == _Tool.rest ? _Tool.note : _Tool.rest),
        child: MusicGlyph(MusicGlyphs.duration(_entryType, rest: true)),
      ),
      EditorToolButton(
        tooltip: l10n.dottedDuration,
        selected: _writing ? _entryDots > 0 : (summary?.dots ?? 0) > 0,
        onPressed: _dot,
        child: const MusicGlyph(MusicGlyphs.augmentationDot),
      ),
      Builder(
        builder: (context) => EditorToolButton(
          tooltip: l10n.toolAccidental,
          hasMore: true,
          onPressed: hasNote ? () => unawaited(_pickAccidental(context)) : null,
          child: const MusicGlyph(MusicGlyphs.accidentalSharp),
        ),
      ),
      EditorToolButton(
        tooltip: l10n.tieTool,
        selected: summary?.tieStart ?? false,
        onPressed: hasNote ? () => _apply(_editor.toggleTie) : null,
        child: const TieIcon(),
      ),
      const EditorRailDivider(),
      EditorToolButton(
        tooltip: l10n.paletteChooser,
        selected: _panel == _Panel.palette,
        hasMore: true,
        onPressed: () => unawaited(_choosePalette()),
        child: const Icon(Icons.apps_rounded),
      ),
      EditorToolButton(
        tooltip: l10n.toolsKeys,
        selected: _panel == _Panel.keys,
        onPressed: () {
          setState(
            () => _panel = _panel == _Panel.keys ? _Panel.none : _Panel.keys,
          );
          _reveal();
        },
        child: const Icon(Icons.piano_rounded),
      ),
    ];
  }

  /// The bar under the score: playing, the bar, and the cursor.
  Widget _transport(AppLocalizations l10n) {
    final index = _noteIndex;
    final count = _previewMeasure.notes.length;
    // Seven keys and the bar: on a small phone they stand closer.
    final compact = _smallTools || MediaQuery.sizeOf(context).width < 400;
    return ColoredBox(
      color: AppColors.canvas,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            TransportButton(
              compact: compact,
              tooltip: l10n.toStart,
              onPressed: _measureIndex > 0 ? () => _goToMeasure(0) : null,
              child: const Icon(Icons.skip_previous_rounded),
            ),
            // The score from this bar on, as it sounds now: a correction is
            // checked by ear as well as against the original.
            TransportButton(
              compact: compact,
              tooltip: _barPlaying ? l10n.stop : l10n.playBar,
              selected: _barPlaying,
              onPressed: _playBar,
              child: Icon(
                _barPlaying
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_fill_rounded,
              ),
            ),
            const Spacer(),
            TransportButton(
              compact: compact,
              tooltip: l10n.previousBar,
              onPressed: _measureIndex > 0
                  ? () => _goToMeasure(_measureIndex - 1)
                  : null,
              child: const Icon(Icons.chevron_left_rounded),
            ),
            TransportButton(
              compact: compact,
              tooltip: l10n.goToBar,
              onPressed: _measureCount > 1 ? () => unawaited(_askBar()) : null,
              child: Text(
                l10n.proofreadBar(
                  _measureIndex + _firstBarNumber,
                  _measureCount - 1 + _firstBarNumber,
                ),
                textScaler: MediaQuery.textScalerOf(
                  context,
                ).clamp(maxScaleFactor: 1.3),
              ),
            ),
            TransportButton(
              compact: compact,
              tooltip: l10n.nextBar,
              onPressed: _measureIndex < _measureCount - 1
                  ? () => _goToMeasure(_measureIndex + 1)
                  : null,
              child: const Icon(Icons.chevron_right_rounded),
            ),
            const Spacer(),
            TransportButton(
              compact: compact,
              tooltip: l10n.previousNote,
              onPressed: (index ?? 0) > 0 || _measureIndex > 0
                  ? () => _stepNote(-1)
                  : null,
              child: const Icon(Icons.arrow_back_rounded),
            ),
            TransportButton(
              compact: compact,
              tooltip: l10n.nextNote,
              onPressed:
                  (index != null && index < count - 1) ||
                      _measureIndex < _measureCount - 1
                  ? () => _stepNote(1)
                  : null,
              child: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = _summary;
    final selectedEvent = _noteIndex == null
        ? null
        : eventIndexForXmlNote(_shownMeasure(_measureIndex), _noteIndex!);
    final hint = switch (_tool) {
      _Tool.note when _keysAppend => l10n.keysAppendHint,
      _Tool.note || _Tool.rest => _toolHint ? l10n.penHint : null,
      _Tool.eraser => _toolHint ? l10n.eraserHint : null,
      _Tool.select => _ranging ? l10n.rangeHint : null,
    };
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmLeave());
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          // No gap before the title: on a small phone the buttons and Save
          // would push the screen's name out.
          titleSpacing: 0,
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
            // What is done to bars as a whole, by name.
            _MenuIconButton(
              tooltip: l10n.barMenuTooltip,
              icon: Icons.more_vert_rounded,
              items: [
                _MenuItem(
                  l10n.insertMeasureAfter,
                  _insertBar,
                  icon: Icons.add_box_outlined,
                ),
                _MenuItem(
                  l10n.duplicateMeasure,
                  _duplicateBar,
                  icon: Icons.copy_all_rounded,
                ),
                _MenuItem(
                  l10n.moveMeasureEarlier,
                  _measureIndex > 0 ? () => _moveBar(-1) : null,
                  icon: Icons.keyboard_double_arrow_left,
                ),
                _MenuItem(
                  l10n.moveMeasureLater,
                  _measureIndex < _measureCount - 1 ? () => _moveBar(1) : null,
                  icon: Icons.keyboard_double_arrow_right,
                ),
                _MenuItem(
                  l10n.barTexts,
                  summary != null && _hasTexts
                      ? () => unawaited(_editTexts())
                      : null,
                  icon: Icons.text_fields_rounded,
                ),
                _MenuItem(
                  l10n.deleteMeasure,
                  _measureCount > 1 ? _deleteBar : null,
                  icon: Icons.delete_outline_rounded,
                ),
                _MenuItem(
                  l10n.barRange,
                  () => unawaited(_askBarRange()),
                  icon: Icons.select_all_rounded,
                ),
                _MenuItem(
                  l10n.soundNotes,
                  () => setState(() => _sounds = !_sounds),
                  icon: Icons.volume_up_outlined,
                  checked: _sounds,
                ),
                _MenuItem(
                  l10n.optRailRight,
                  () => setState(() => _railRight = !_railRight),
                  icon: Icons.swap_horiz_rounded,
                  checked: _railRight,
                ),
                _MenuItem(
                  l10n.optSmallTools,
                  () => setState(() => _smallTools = !_smallTools),
                  icon: Icons.photo_size_select_small_rounded,
                  checked: _smallTools,
                ),
                _MenuItem(
                  l10n.optDarkScore,
                  () => setState(() => _darkScore = !_darkScore),
                  icon: Icons.dark_mode_outlined,
                  checked: _darkScore,
                ),
                _MenuItem(
                  _clip == null
                      ? l10n.pasteBarsNone
                      : l10n.pasteBars(_clip!.length),
                  _clip == null ? null : _pasteBars,
                  icon: Icons.content_paste_rounded,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 8),
              child: FilledButton(
                onPressed: _dirty && !_saving ? () => unawaited(_save()) : null,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
        // An attached keyboard works the editor as it does a notation
        // program on a desk.
        body: CallbackShortcuts(
          bindings: _shortcuts,
          child: Focus(
            autofocus: true,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, area) {
                        // The original beside the score where there is width
                        // for both, above it on a phone held upright.
                        final beside = area.maxWidth >= 700;
                        return Flex(
                          direction: beside ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_showOriginal && _places != null)
                              SizedBox(
                                width: beside ? area.maxWidth * 0.32 : null,
                                height: beside
                                    ? null
                                    : (area.maxHeight * 0.24).clamp(
                                        84.0,
                                        170.0,
                                      ),
                                child: _Captioned(
                                  caption: l10n.scoreOriginal,
                                  child: _OriginalStrip(
                                    place: _place,
                                    image: _place == null
                                        ? null
                                        : _original(_place!.image),
                                    beside: beside,
                                  ),
                                ),
                              ),
                            // Keyed: showing or hiding the original must not
                            // make the engraving start over.
                            Expanded(
                              key: const ValueKey('engraving'),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                textDirection: _railRight
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                children: [
                                  EditorRail(
                                    onRight: _railRight,
                                    compact: _smallTools,
                                    children: _railTools(l10n),
                                  ),
                                  Expanded(
                                    child: Directionality(
                                      textDirection: Directionality.of(context),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: _darkScore
                                                // Light notes on a dark page,
                                                // for a dim room.
                                                ? ColorFiltered(
                                                    colorFilter:
                                                        const ColorFilter.matrix(
                                                          [
                                                            -1, 0, 0, 0, 255, //
                                                            0, -1, 0, 0, 255, //
                                                            0, 0, -1, 0, 255, //
                                                            0, 0, 0, 1, 0,
                                                          ],
                                                        ),
                                                    child: _engraving(
                                                      l10n,
                                                      selectedEvent,
                                                    ),
                                                  )
                                                : _engraving(
                                                    l10n,
                                                    selectedEvent,
                                                  ),
                                          ),
                                          if (hint != null)
                                            Positioned(
                                              left: 8,
                                              top: 6,
                                              right: 8,
                                              child: _HintChip(hint),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_barSel case final bars?)
                    _BarEditBar(
                      label: bars.from == bars.to
                          ? l10n.barPicked(bars.from + _firstBarNumber)
                          : l10n.barsPicked(
                              bars.from + _firstBarNumber,
                              bars.to + _firstBarNumber,
                            ),
                      actions: [
                        (
                          l10n.barRangeCut,
                          Icons.content_cut_rounded,
                          () => _actOnBars(
                            _BarRangeAction.cut,
                            bars.from,
                            bars.to,
                          ),
                        ),
                        (
                          l10n.barRangeCopy,
                          Icons.copy_rounded,
                          () => _actOnBars(
                            _BarRangeAction.copy,
                            bars.from,
                            bars.to,
                          ),
                        ),
                        // Over the picked bars, as a notation program
                        // pastes.
                        (
                          l10n.barEditPaste,
                          Icons.content_paste_rounded,
                          _clip == null
                              ? null
                              : () => _overwriteBars(bars.from),
                        ),
                        // Between the bars, without taking any away.
                        (
                          l10n.barEditPasteInsert,
                          Icons.playlist_add_rounded,
                          _clip == null
                              ? null
                              : () => _pasteBars(after: bars.to),
                        ),
                        (
                          l10n.barEditDuplicate,
                          Icons.copy_all_rounded,
                          () => _duplicateBars(bars.from, bars.to),
                        ),
                        (
                          l10n.barRangeTranspose,
                          Icons.swap_vert_rounded,
                          () => unawaited(
                            _askBarRange(from: bars.from, to: bars.to),
                          ),
                        ),
                        (
                          l10n.barRangeDelete,
                          Icons.backspace_outlined,
                          () => _actOnBars(
                            _BarRangeAction.delete,
                            bars.from,
                            bars.to,
                          ),
                        ),
                        (
                          l10n.deleteMeasure,
                          Icons.delete_outline_rounded,
                          _measureCount > bars.to - bars.from + 1
                              ? () => _actOnBars(
                                  _BarRangeAction.remove,
                                  bars.from,
                                  bars.to,
                                )
                              : null,
                        ),
                      ],
                      close: l10n.close,
                      onClose: () => setState(_dropRange),
                    ),
                  if (_spanFrom case final span?)
                    _SpanBanner(
                      text: l10n.spanPickEnd(_spanLabel(l10n, span.kind)),
                      toSelected: l10n.spanToSelected,
                      onToSelected: _noteIndex == null
                          ? null
                          : () => _finishSpan(_noteIndex!),
                      cancel: l10n.cancel,
                      onCancel: () => setState(() => _spanFrom = null),
                    ),
                  if (_lengthOff case final off?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            off < 0
                                ? l10n.barTooShort(_beats(-off))
                                : l10n.barTooLong(_beats(off)),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 1, color: AppColors.border),
                  // Under the score: the tools of one palette, or the keyboard.
                  if (_panel == _Panel.palette)
                    _PalettePanel(
                      title: _paletteLabel(l10n, _palette),
                      onTitle: () => unawaited(_choosePalette()),
                      close: l10n.close,
                      onClose: () => setState(() => _panel = _Panel.none),
                      children: _paletteTools(l10n),
                    ),
                  if (_panel == _Panel.keys)
                    PianoKeyboard(
                      octave: _keyboardOctave,
                      enabled: summary != null && !summary.isGrace,
                      onKey: _enterKey,
                      onOctave: (by) => setState(
                        () => _keyboardOctave = (_keyboardOctave + by).clamp(
                          1,
                          7,
                        ),
                      ),
                      lowerTooltip: l10n.keyboardLower,
                      higherTooltip: l10n.keyboardHigher,
                      keyWidth: _keyWidths[_keyWidth],
                      buttons: [
                        KeyboardButton(
                          tooltip: l10n.keyRest,
                          icon: Icons.remove_rounded,
                          glyph: MusicGlyphs.restQuarter,
                          onPressed: summary != null && !summary.isGrace
                              ? _enterRest
                              : null,
                        ),
                        KeyboardButton(
                          tooltip: l10n.chordKeys,
                          icon: Icons.layers_rounded,
                          selected: _chordKeys,
                          onPressed: () => setState(() {
                            _chordKeys = !_chordKeys;
                            _endChord();
                          }),
                        ),
                        KeyboardButton(
                          tooltip: l10n.chordRepeat,
                          icon: Icons.replay_rounded,
                          onPressed: _chordBefore.isEmpty ? null : _repeatChord,
                        ),
                        KeyboardButton(
                          tooltip: l10n.keyWidthTool,
                          icon: Icons.width_normal_rounded,
                          onPressed: () => setState(
                            () =>
                                _keyWidth = (_keyWidth + 1) % _keyWidths.length,
                          ),
                        ),
                      ],
                    ),
                  if (_panel != _Panel.none)
                    const Divider(height: 1, color: AppColors.border),
                  _transport(l10n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What the keys of an attached keyboard do.
  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    void move(XmlEditResult Function(String, XmlNoteRef) edit) {
      _applyEach(edit, where: (note) => !note.isRest && !note.isGrace);
      _soundPicked();
    }

    void value(String type) {
      if (_writing) {
        setState(() {
          _entryType = type;
          _entryDots = 0;
        });
      } else {
        _setLength(type, 0);
      }
    }

    return {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _stepNote(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _stepNote(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          move((xml, ref) => _editor.moveDiatonic(xml, ref, 1)),
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          move((xml, ref) => _editor.moveDiatonic(xml, ref, -1)),
      const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
          move((xml, ref) => _editor.shiftOctave(xml, ref, 1)),
      const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () =>
          move((xml, ref) => _editor.shiftOctave(xml, ref, -1)),
      const SingleActivator(LogicalKeyboardKey.delete): _erase,
      const SingleActivator(LogicalKeyboardKey.backspace): _erase,
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          _setTool(_Tool.select),
      const SingleActivator(LogicalKeyboardKey.keyN): () =>
          _setTool(_Tool.note),
      const SingleActivator(LogicalKeyboardKey.keyR): () =>
          _setTool(_Tool.rest),
      const SingleActivator(LogicalKeyboardKey.keyT): () =>
          _apply(_editor.toggleTie),
      const SingleActivator(LogicalKeyboardKey.period): _dot,
      const SingleActivator(LogicalKeyboardKey.space): () =>
          unawaited(_playBar()),
      // The values as a notation program numbers them: 2 a whole note,
      // 4 a quarter, 8 a sixty-fourth.
      for (final (index, type) in noteDurationTypes.indexed)
        SingleActivator(_digitKeys[index + 2]): () => value(type),
      for (final control in const [true, false]) ...{
        SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: control,
          meta: !control,
        ): () {
          if (_cursor > 0) _undo();
        },
        SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: control,
          meta: !control,
          shift: true,
        ): () {
          if (_cursor < _history.length - 1) _redo();
        },
        SingleActivator(
          LogicalKeyboardKey.keyY,
          control: control,
          meta: !control,
        ): () {
          if (_cursor < _history.length - 1) _redo();
        },
        SingleActivator(
          LogicalKeyboardKey.keyC,
          control: control,
          meta: !control,
        ): _copyNotes,
        SingleActivator(
          LogicalKeyboardKey.keyV,
          control: control,
          meta: !control,
        ): () {
          final clip = _noteClip;
          if (clip != null) {
            _apply((xml, ref) => _editor.pasteNotes(xml, ref, clip));
          }
        },
        SingleActivator(
          LogicalKeyboardKey.keyS,
          control: control,
          meta: !control,
        ): () {
          if (_dirty && !_saving) unawaited(_save());
        },
      },
    };
  }

  static const _digitKeys = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  static String _paletteLabel(AppLocalizations l10n, _Palette palette) =>
      switch (palette) {
        _Palette.note => l10n.toolsNote,
        _Palette.length => l10n.toolsLength,
        _Palette.pitch => l10n.toolsPitch,
        _Palette.marks => l10n.toolsMarks,
        _Palette.looks => l10n.toolsLooks,
        _Palette.words => l10n.toolsWords,
        _Palette.bar => l10n.toolsBarSigns,
        _Palette.score => l10n.toolsScore,
      };

  /// Applies an edit of the bar as a whole; the picked note stays picked.
  /// Joins the picked notes under a beam, bar by bar, or takes their beams
  /// off.
  void _beam({required bool join}) {
    final bars = <int, List<int>>{};
    for (final ref in _pickedRefs) {
      bars.putIfAbsent(ref.measureIndex, () => []).add(ref.noteIndex);
    }
    _apply((xml, ref) {
      var current = xml;
      FormatException? refused;
      var done = 0;
      for (final MapEntry(key: bar, value: notes) in bars.entries) {
        try {
          current = _editor
              .setBeam(current, widget.partIndex, bar, notes, join: join)
              .xml;
          done++;
        } on FormatException catch (error) {
          refused = error;
        }
      }
      if (done == 0) throw refused ?? const FormatException('빔을 바꿀 수 없습니다.');
      return XmlEditResult(current, ref);
    }, keepRange: true);
  }

  void _applyBar(XmlEditResult Function(String xml, int measureIndex) edit) {
    final keep = _noteIndex ?? 0;
    _apply((xml, ref) {
      // The edit is of the bar on screen, or of the whole score: either
      // way this bar stays on screen.
      return XmlEditResult(edit(xml, ref.measureIndex).xml, ref.withNote(keep));
    }, bars: (bars, _) => bars);
  }

  List<Widget> _paletteTools(AppLocalizations l10n) {
    final summary = _summary;
    final hasNote = summary != null && !summary.isRest && !summary.isGrace;
    final canRetime = summary != null && !summary.isGrace && !summary.inTuplet;
    final hasEvent = summary != null && !summary.isGrace;
    switch (_palette) {
      case _Palette.note:
        return [
          _ToolButton(
            tooltip: l10n.rangeTool,
            selected: _ranging,
            onPressed: () => setState(() {
              _ranging = !_ranging;
              _dropRange();
              // A run of notes is picked with the select tool.
              if (_ranging) _tool = _Tool.select;
            }),
            child: Text(l10n.rangeTool),
          ),
          const _ToolGap(),
          // One place for the two opposite things: a note becomes a rest,
          // a rest is made a note.
          if (summary != null && summary.isRest)
            _ToolButton(
              tooltip: l10n.restToNote,
              onPressed: () => _apply(_editor.restToNote),
              child: Text(l10n.restToNote),
            )
          else
            _ToolButton(
              tooltip: l10n.noteToRest,
              onPressed: hasNote
                  ? () => _applyEach(
                      _editor.deleteNote,
                      where: (note) => !note.isRest,
                      backwards: true,
                    )
                  : null,
              child: Text(l10n.noteToRest),
            ),
          _ToolButton(
            tooltip: l10n.deleteNote,
            onPressed: summary != null
                ? () => _applyEach(
                    _editor.removeNote,
                    where: (note) => note.leadsChord,
                    backwards: true,
                  )
                : null,
            child: Text(l10n.removeNoteTool),
          ),
          _ToolButton(
            tooltip: l10n.splitNote,
            onPressed: canRetime ? () => _apply(_editor.splitNote) : null,
            child: Text(l10n.splitNote),
          ),
          _MenuButton(
            tooltip: l10n.insertTool,
            label: l10n.insertTool,
            items: [
              for (final (label, before, rest) in [
                (l10n.insertNoteBefore, true, false),
                (l10n.insertNoteAfter, false, false),
                (l10n.insertRestBefore, true, true),
                (l10n.insertRestAfter, false, true),
              ])
                _MenuItem(
                  label,
                  canRetime
                      ? () => _apply(
                          (xml, ref) => _editor.insertEvent(
                            xml,
                            ref,
                            before: before,
                            rest: rest,
                            value: (type: _entryType, dots: _entryDots),
                          ),
                        )
                      : null,
                ),
            ],
          ),
          const _ToolGap(),
          _ToolButton(
            tooltip: l10n.addChordTone,
            onPressed: hasNote ? () => _apply(_editor.addChordNote) : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 18),
                Text(l10n.addChordTone),
              ],
            ),
          ),
          // On a grace note the button is its slash: with it short
          // before the beat, without it leaning on the note it leads to.
          if (summary != null && summary.isGrace)
            _ToolButton(
              tooltip: l10n.graceSlash,
              selected: summary.graceSlash,
              onPressed: () => _apply(_editor.toggleGraceSlash),
              child: Text(l10n.graceSlash),
            )
          else
            _ToolButton(
              tooltip: l10n.graceNote,
              onPressed: hasNote ? () => _apply(_editor.addGraceNote) : null,
              child: Text(l10n.graceNote),
            ),
          _ToolButton(
            tooltip: l10n.tieTool,
            selected: summary?.tieStart ?? false,
            onPressed: hasNote ? () => _apply(_editor.toggleTie) : null,
            child: Text(l10n.tieTool),
          ),
          _MenuButton(
            tooltip: l10n.beamMenu,
            label: l10n.beamMenu,
            items: [
              for (final (label, join) in [
                (l10n.beamJoin, true),
                (l10n.beamBreak, false),
              ])
                _MenuItem(label, hasNote ? () => _beam(join: join) : null),
            ],
          ),
          _MenuButton(
            tooltip: l10n.notesMenu,
            label: l10n.notesMenu,
            items: [
              _MenuItem(
                l10n.notesCopy,
                hasEvent ? _copyNotes : null,
                icon: Icons.copy_rounded,
              ),
              _MenuItem(
                _noteClip == null
                    ? l10n.notesPasteNone
                    : l10n.notesPaste(_noteClip!.length),
                _noteClip != null && hasEvent
                    ? () => _apply(
                        (xml, ref) => _editor.pasteNotes(xml, ref, _noteClip!),
                      )
                    : null,
                icon: Icons.content_paste_rounded,
              ),
              _MenuItem(
                l10n.notesDuplicate,
                hasEvent
                    ? () {
                        final refs = _pickedRefs;
                        _apply((xml, _) => _editor.duplicateNotes(xml, refs));
                      }
                    : null,
                icon: Icons.copy_all_rounded,
              ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.voiceMenu,
            label: l10n.voiceMenu,
            items: [
              _MenuItem(
                l10n.voiceAdd,
                summary != null ? () => _apply(_editor.addVoice) : null,
              ),
              _MenuItem(
                l10n.voiceRemove,
                summary != null ? () => _apply(_editor.removeVoice) : null,
              ),
              _MenuItem(
                l10n.voiceSwap,
                summary != null ? () => _apply(_editor.swapVoices) : null,
              ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.selectMenu,
            label: l10n.selectMenu,
            items: [
              _MenuItem(l10n.selectAll, () => _pickBars(0, _measureCount - 1)),
              _MenuItem(
                l10n.selectBar,
                () => _pickBars(_measureIndex, _measureIndex),
              ),
              for (final (label, only) in [
                (l10n.onlyAll, _Only.all),
                (l10n.onlyTop, _Only.top),
                (l10n.onlyBottom, _Only.bottom),
              ])
                _MenuItem(
                  label,
                  _rangeEnd != null ? () => setState(() => _only = only) : null,
                  checked: _rangeEnd != null && _only == only,
                ),
              _MenuItem(
                l10n.clearLyrics,
                hasEvent
                    ? () => _applyEach(
                        (xml, ref) =>
                            _editor.setLyric(xml, ref, '', verse: _verse),
                        where: (note) => note.lyrics.containsKey(_verse),
                      )
                    : null,
              ),
              _MenuItem(
                l10n.clearChords,
                hasEvent
                    ? () => _applyEach(
                        (xml, ref) => _editor.setHarmony(xml, ref, ''),
                        where: (note) =>
                            note.leadsChord && note.harmony != null,
                      )
                    : null,
              ),
            ],
          ),
        ];
      case _Palette.looks:
        bool sounding(XmlNoteSummary note) => !note.isRest && !note.isGrace;
        bool heads(XmlNoteSummary note) => sounding(note) && note.leadsChord;
        return [
          _MenuButton(
            tooltip: l10n.stemMenu,
            label: l10n.stemMenu,
            items: [
              for (final (label, direction) in [
                (l10n.stemUp, 'up'),
                (l10n.stemDown, 'down'),
                (l10n.stemHide, 'none'),
                (l10n.automatic, null),
              ])
                _MenuItem(
                  label,
                  hasNote
                      ? () => _applyEach(
                          (xml, ref) => _editor.setStem(xml, ref, direction),
                          where: heads,
                        )
                      : null,
                  checked: hasNote && summary.stem == direction,
                ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.noteheadMenu,
            label: l10n.noteheadMenu,
            items: [
              for (final (label, head) in [
                (l10n.noteheadNormal, null),
                (l10n.noteheadSlash, 'slash'),
                (l10n.noteheadGhost, 'parentheses'),
              ])
                _MenuItem(
                  label,
                  hasNote
                      ? () => _applyEach(
                          (xml, ref) => _editor.setNotehead(xml, ref, head),
                          where: sounding,
                        )
                      : null,
                  checked: hasNote && summary.notehead == head,
                ),
            ],
          ),
          _ToolButton(
            tooltip: l10n.otherStaff,
            onPressed: hasEvent
                ? () => _applyEach(
                    _editor.switchStaff,
                    where: (note) => note.leadsChord && !note.isGrace,
                  )
                : null,
            child: Text(l10n.otherStaff),
          ),
          const _ToolGap(),
          _MenuButton(
            tooltip: l10n.markSideMenu,
            label: l10n.markSideMenu,
            items: [
              for (final (label, side) in [
                (l10n.sideAbove, 'above'),
                (l10n.sideBelow, 'below'),
                (l10n.automatic, null),
              ])
                _MenuItem(
                  label,
                  hasEvent
                      ? () => _applyEach(
                          (xml, ref) =>
                              _editor.setMarkPlacement(xml, ref, side),
                          where: (note) =>
                              note.leadsChord &&
                              (note.fermata || note.articulations.isNotEmpty),
                        )
                      : null,
                ),
            ],
          ),
          _ToolButton(
            tooltip: l10n.clearMarksTool,
            onPressed: hasEvent
                ? () => _applyEach(
                    _editor.clearMarks,
                    where: (note) =>
                        note.leadsChord &&
                        (note.fermata || note.articulations.isNotEmpty),
                  )
                : null,
            child: Text(l10n.clearMarksTool),
          ),
          _ToolButton(
            tooltip: l10n.clearAccidentalTool,
            onPressed: hasNote
                ? () => _applyEach(_editor.clearAccidental, where: sounding)
                : null,
            child: Text(l10n.clearAccidentalTool),
          ),
          const _ToolGap(),
          _MenuButton(
            tooltip: l10n.doubleMenu,
            label: l10n.doubleMenu,
            items: [
              for (final (label, steps) in [
                (l10n.doubleThirdUp, 2),
                (l10n.doubleSixthUp, 5),
                (l10n.doubleOctaveUp, 7),
                (l10n.doubleThirdDown, -2),
                (l10n.doubleOctaveDown, -7),
              ])
                _MenuItem(
                  label,
                  hasNote
                      ? () => _applyEach(
                          (xml, ref) => _editor.doubleAt(xml, ref, steps),
                          where: sounding,
                          // Each adds a note: the last first, so the
                          // ones before keep their numbers.
                          backwards: true,
                        )
                      : null,
                ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.jazzMenu,
            label: l10n.jazzMenu,
            items: [
              // Named as jazz players name them.
              for (final (label, name) in const [
                ('Scoop', 'scoop'),
                ('Plop', 'plop'),
                ('Doit', 'doit'),
                ('Fall', 'falloff'),
              ])
                _MenuItem(
                  label,
                  hasNote ? () => _toggleMark(name, restsToo: false) : null,
                  checked: summary?.articulations.contains(name) ?? false,
                ),
            ],
          ),
        ];
      case _Palette.length:
        return [
          for (final type in noteDurationTypes)
            _ToolButton(
              tooltip: '${l10n.noteValue} ${_fractionOf[type]}',
              selected: summary?.type == type,
              onPressed: canRetime ? () => _setLength(type, 0) : null,
              child: MusicGlyph(
                MusicGlyphs.duration(type, rest: summary?.isRest ?? false),
              ),
            ),
          const _ToolGap(),
          _MenuButton(
            tooltip: l10n.tuplet,
            label: l10n.tuplet,
            items: [
              for (final choice in tupletChoices)
                _MenuItem(
                  l10n.tupletOf(choice.actual),
                  canRetime
                      ? () => _apply(
                          (xml, ref) => _editor.makeTuplet(
                            xml,
                            ref,
                            choice.actual,
                            choice.normal,
                          ),
                        )
                      : null,
                ),
              // Notes that are there already, read too long: three of
              // them in the time of two.
              _MenuItem(
                l10n.tupletGroup,
                _rangeEnd != null && _pickedRefs.length >= 3
                    ? () {
                        final picked = _pickedRefs;
                        final bar = picked.first.measureIndex;
                        if (picked.any((ref) => ref.measureIndex != bar)) {
                          _showMessage(l10n.tupletOneBar);
                          return;
                        }
                        _apply(
                          (xml, ref) => _editor.groupTuplet(
                            xml,
                            widget.partIndex,
                            bar,
                            [for (final ref in picked) ref.noteIndex],
                          ),
                        );
                      }
                    : null,
              ),
              _MenuItem(
                l10n.tupletRemove,
                summary != null && summary.inTuplet
                    ? () => _apply(_editor.removeTuplet)
                    : null,
              ),
            ],
          ),
        ];
      case _Palette.pitch:
        return [
          _ToolButton(
            tooltip: l10n.noteStepUp,
            onPressed: hasNote
                ? () => _applyEach(
                    (xml, ref) => _editor.moveDiatonic(xml, ref, 1),
                    where: (note) => !note.isRest && !note.isGrace,
                  )
                : null,
            child: const Icon(Icons.arrow_upward_rounded),
          ),
          _ToolButton(
            tooltip: l10n.noteStepDown,
            onPressed: hasNote
                ? () => _applyEach(
                    (xml, ref) => _editor.moveDiatonic(xml, ref, -1),
                    where: (note) => !note.isRest && !note.isGrace,
                  )
                : null,
            child: const Icon(Icons.arrow_downward_rounded),
          ),
          // "8" is how an octave is written on a score (8va).
          _ToolButton(
            tooltip: l10n.octaveUp,
            onPressed: hasNote
                ? () => _applyEach(
                    (xml, ref) => _editor.shiftOctave(xml, ref, 1),
                    where: (note) => !note.isRest && !note.isGrace,
                  )
                : null,
            child: const _OctaveLabel(up: true),
          ),
          _ToolButton(
            tooltip: l10n.octaveDown,
            onPressed: hasNote
                ? () => _applyEach(
                    (xml, ref) => _editor.shiftOctave(xml, ref, -1),
                    where: (note) => !note.isRest && !note.isGrace,
                  )
                : null,
            child: const _OctaveLabel(up: false),
          ),
          const _ToolGap(),
          for (final (alter, label) in [
            (1, l10n.noteSharp),
            (-1, l10n.noteFlat),
            (0, l10n.noteNatural),
            (2, l10n.doubleSharp),
            (-2, l10n.doubleFlat),
          ])
            _ToolButton(
              tooltip: label,
              selected: hasNote && summary.pitch?.alter == alter,
              onPressed: hasNote
                  ? () => _applyEach(
                      (xml, ref) => _editor.setAlter(xml, ref, alter),
                      where: (note) => !note.isRest && !note.isGrace,
                    )
                  : null,
              child: MusicGlyph(MusicGlyphs.accidental(alter)),
            ),
          // The same sound written the other way: F sharp, G flat.
          _ToolButton(
            tooltip: l10n.respell,
            onPressed: hasNote
                ? () =>
                      _applyEach(_editor.respell, where: (note) => !note.isRest)
                : null,
            child: const Text('♯↔♭'),
          ),
          // A run of notes written all with flats, or all with sharps.
          for (final (label, text, sharps) in [
            (l10n.favourFlats, '→♭', false),
            (l10n.favourSharps, '→♯', true),
          ])
            _ToolButton(
              tooltip: label,
              onPressed: hasNote
                  ? () => _applyEach((xml, ref) {
                      final alter = _editor.describe(xml, ref).pitch?.alter;
                      if (alter == null || (sharps ? alter >= 0 : alter <= 0)) {
                        throw const FormatException('이미 그렇게 적혀 있습니다.');
                      }
                      return _editor.respell(xml, ref);
                    }, where: (note) => note.pitch != null)
                  : null,
              child: Text(text),
            ),
        ];
      case _Palette.marks:
        return [
          for (final (name, label, glyph) in [
            ('staccato', l10n.staccato, MusicGlyphs.articStaccatoAbove),
            (
              'staccatissimo',
              l10n.staccatissimo,
              MusicGlyphs.articStaccatissimoAbove,
            ),
            ('tenuto', l10n.tenuto, MusicGlyphs.articTenutoAbove),
            ('accent', l10n.accent, MusicGlyphs.articAccentAbove),
            ('strong-accent', l10n.marcato, MusicGlyphs.articMarcatoAbove),
          ])
            _ToolButton(
              tooltip: label,
              selected: summary?.articulations.contains(name) ?? false,
              onPressed: hasNote
                  ? () => _toggleMark(name, restsToo: false)
                  : null,
              child: MusicGlyph(glyph),
            ),
          _ToolButton(
            tooltip: l10n.fermata,
            selected: summary?.fermata ?? false,
            onPressed: hasEvent
                ? () => _toggleMark('fermata', restsToo: true)
                : null,
            child: const MusicGlyph(MusicGlyphs.fermataAbove),
          ),
          _ToolButton(
            tooltip: l10n.breathMark,
            selected: summary?.articulations.contains('breath-mark') ?? false,
            onPressed: hasNote
                ? () => _toggleMark('breath-mark', restsToo: false)
                : null,
            child: const MusicGlyph(MusicGlyphs.breathMarkComma),
          ),
          const _ToolGap(),
          _MenuButton(
            tooltip: l10n.dynamics,
            label: summary?.dynamic ?? l10n.dynamics,
            italic: summary?.dynamic != null,
            items: [
              for (final mark in dynamicMarks)
                _MenuItem(
                  mark,
                  hasEvent
                      ? () => _apply(
                          (xml, ref) => _editor.setDynamic(xml, ref, mark),
                        )
                      : null,
                  checked: summary?.dynamic == mark,
                ),
              _MenuItem(
                l10n.dynamicsNone,
                summary?.dynamic != null
                    ? () => _apply(
                        (xml, ref) => _editor.setDynamic(xml, ref, null),
                      )
                    : null,
              ),
            ],
          ),
          // Lines from one note to another: the first is the picked note,
          // the last is picked next. On a note that has the line, the tool
          // takes it away.
          _ToolButton(
            tooltip: l10n.slurTool,
            selected: summary?.spans.contains(SpanKind.slur) ?? false,
            onPressed: hasNote ? () => _startSpan(SpanKind.slur) : null,
            child: Text(l10n.slurTool),
          ),
          _MenuButton(
            tooltip: l10n.linesMenu,
            label: l10n.linesMenu,
            items: [
              for (final kind in const [
                SpanKind.crescendo,
                SpanKind.diminuendo,
                SpanKind.octaveUp,
                SpanKind.octaveDown,
                SpanKind.pedal,
                SpanKind.glissando,
              ])
                _MenuItem(
                  _spanLabel(l10n, kind),
                  (kind.onNotes ? hasNote : hasEvent)
                      ? () => _startSpan(kind)
                      : null,
                  checked: summary?.spans.contains(kind) ?? false,
                ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.ornamentsMenu,
            label: l10n.ornamentsMenu,
            items: [
              for (final (name, label) in [
                ('trill-mark', l10n.trill),
                ('mordent', l10n.mordent),
                ('inverted-mordent', l10n.invertedMordent),
                ('turn', l10n.turnOrnament),
                ('tremolo', l10n.tremolo),
                ('arpeggiate', l10n.arpeggio),
              ])
                _MenuItem(
                  label,
                  hasNote
                      ? () => _apply(
                          (xml, ref) => _editor.toggleOrnament(xml, ref, name),
                        )
                      : null,
                  checked: summary?.ornaments.contains(name) ?? false,
                ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.fingeringMenu,
            label: summary?.fingering == null
                ? l10n.fingeringMenu
                : '${l10n.fingeringMenu} ${summary!.fingering}',
            items: [
              for (var finger = 1; finger <= 5; finger++)
                _MenuItem(
                  '$finger',
                  hasNote
                      ? () => _applyEach(
                          (xml, ref) => _editor.setFingering(xml, ref, finger),
                          where: (note) => !note.isRest && !note.isGrace,
                        )
                      : null,
                  checked: summary?.fingering == '$finger',
                ),
              _MenuItem(
                l10n.remove,
                summary?.fingering != null
                    ? () => _applyEach(
                        (xml, ref) => _editor.setFingering(xml, ref, null),
                        where: (note) => note.fingering != null,
                      )
                    : null,
              ),
            ],
          ),
        ];
      case _Palette.words:
        return [
          _ToolButton(
            tooltip: l10n.chordSymbol,
            onPressed: hasEvent ? () => unawaited(_editChordSymbol()) : null,
            child: _ValueLabel(
              value: summary?.harmony,
              empty: l10n.chordSymbol,
            ),
          ),
          // What a converted lead sheet gets wrong most often after the
          // notes themselves.
          _ToolButton(
            tooltip: l10n.lyric,
            onPressed: hasNote ? () => unawaited(_editLyric()) : null,
            child: _ValueLabel(
              value: summary?.lyrics[_verse],
              empty: l10n.lyric,
            ),
          ),
          _MenuButton(
            tooltip: l10n.verseMenu,
            label: l10n.verseOf(_verse),
            items: [
              for (final verse in const [1, 2, 3, 4])
                _MenuItem(
                  l10n.verseOf(verse),
                  () => setState(() => _verse = verse),
                  checked: _verse == verse,
                ),
            ],
          ),
        ];
      case _Palette.bar:
        final signs = _signs;
        final attributes = _previewMeasure.attributes;
        final staff = _noteIndex == null
            ? 1
            : _previewMeasure.notes.elementAt(_noteIndex!).staff;
        final clef = attributes.clefs[staff];
        return [
          // Shorter than its time on purpose: not counted, not warned of.
          _ToolButton(
            tooltip: l10n.pickupBar,
            selected: signs.pickup,
            onPressed: () => _applyBar(
              (xml, measure) => _editor.setPickup(
                xml,
                widget.partIndex,
                measure,
                pickup: !signs.pickup,
              ),
            ),
            child: Text(l10n.pickupBar),
          ),
          _ToolButton(
            tooltip: l10n.keyAndTime,
            onPressed: () => unawaited(_editKeyAndTime()),
            child: Text(l10n.keyAndTime),
          ),
          _MenuButton(
            tooltip: l10n.clef,
            label: l10n.clef,
            items: [
              for (final (sign, line, label) in [
                ('G', 2, l10n.clefTreble),
                ('F', 4, l10n.clefBass),
                ('C', 3, l10n.clefAlto),
                ('C', 4, l10n.clefTenor),
              ])
                _MenuItem(
                  label,
                  () => _applyBar(
                    (xml, measure) => _editor.setClef(
                      xml,
                      widget.partIndex,
                      measure,
                      staff,
                      sign,
                      line,
                    ),
                  ),
                  checked:
                      clef != null && clef.sign == sign && clef.line == line,
                ),
            ],
          ),
          const _ToolGap(),
          _ToolButton(
            tooltip: l10n.repeatStart,
            selected: signs.repeatStart,
            onPressed: () => _applyBar(
              (xml, measure) => _editor.toggleRepeat(
                xml,
                widget.partIndex,
                measure,
                start: true,
              ),
            ),
            child: const MusicGlyph(MusicGlyphs.repeatLeft),
          ),
          _ToolButton(
            tooltip: l10n.repeatEnd,
            selected: signs.repeatEnd,
            onPressed: () => _applyBar(
              (xml, measure) => _editor.toggleRepeat(
                xml,
                widget.partIndex,
                measure,
                start: false,
              ),
            ),
            child: const MusicGlyph(MusicGlyphs.repeatRight),
          ),
          _MenuButton(
            tooltip: l10n.barlineTool,
            label: l10n.barlineTool,
            items: [
              for (final (style, label) in [
                ('regular', l10n.barlineRegular),
                ('light-light', l10n.barlineDouble),
                ('light-heavy', l10n.barlineFinal),
              ])
                _MenuItem(
                  label,
                  () => _applyBar(
                    (xml, measure) => _editor.setBarStyle(
                      xml,
                      widget.partIndex,
                      measure,
                      style,
                    ),
                  ),
                  checked: signs.barStyle == style,
                ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.endings,
            label: l10n.endings,
            items: [
              for (final number in const [1, 2, 3]) ...[
                _MenuItem(
                  l10n.endingStart(number),
                  () => _applyBar(
                    (xml, measure) => _editor.toggleEnding(
                      xml,
                      widget.partIndex,
                      measure,
                      number,
                      start: true,
                    ),
                  ),
                  checked: signs.endingStart == number,
                ),
                _MenuItem(
                  l10n.endingEnd(number),
                  () => _applyBar(
                    (xml, measure) => _editor.toggleEnding(
                      xml,
                      widget.partIndex,
                      measure,
                      number,
                      start: false,
                    ),
                  ),
                  checked: signs.endingEnd == number,
                ),
              ],
            ],
          ),
          _MenuButton(
            tooltip: l10n.navigationSigns,
            label: l10n.navigationSigns,
            items: [
              for (final sign in NavigationSign.values)
                _MenuItem(
                  sign.words,
                  () => _applyBar(
                    (xml, measure) => _editor.setNavigationSign(
                      xml,
                      widget.partIndex,
                      measure,
                      sign,
                      on: !signs.navigation.contains(sign),
                    ),
                  ),
                  checked: signs.navigation.contains(sign),
                ),
            ],
          ),
          const _ToolGap(),
          _ToolButton(
            tooltip: l10n.tempoMark,
            onPressed: () => unawaited(_editTempo()),
            child: _ValueLabel(
              value: signs.tempoBpm == null ? null : '♩ = ${signs.tempoBpm}',
              empty: l10n.tempoMark,
            ),
          ),
          _ToolButton(
            tooltip: l10n.rehearsalMark,
            onPressed: () => unawaited(_editRehearsal()),
            child: _ValueLabel(
              value: signs.rehearsal,
              empty: l10n.rehearsalMark,
            ),
          ),
          _ToolButton(
            tooltip: l10n.addText,
            onPressed: () => unawaited(_addText()),
            child: Text(l10n.addText),
          ),
          // The words a player slows down and speeds up by, and goes back
          // to the tempo by. They are played as they are written.
          _MenuButton(
            tooltip: l10n.tempoChange,
            label: l10n.tempoChange,
            items: [
              for (final word in const ['rit.', 'accel.', 'a tempo'])
                _MenuItem(
                  word,
                  () => _applyBar(
                    (xml, measure) =>
                        _editor.addWords(xml, widget.partIndex, measure, word),
                  ),
                ),
            ],
          ),
          // Written as jazz charts write it; the player swings from the
          // word on, and plays even again from "Straight".
          _MenuButton(
            tooltip: 'Swing',
            label: 'Swing',
            items: [
              for (final word in const ['Swing', 'Straight'])
                _MenuItem(
                  word,
                  () => _applyBar(
                    (xml, measure) =>
                        _editor.addWords(xml, widget.partIndex, measure, word),
                  ),
                ),
            ],
          ),
          const _ToolGap(),
          // Where the bar stands on the page: the first bar begins a line
          // and a page anyway.
          for (final (page, label, on) in [
            (false, l10n.lineBreakTool, signs.lineBreak),
            (true, l10n.pageBreakTool, signs.pageBreak),
          ])
            _ToolButton(
              tooltip: label,
              selected: on,
              onPressed: _measureIndex > 0
                  ? () => _applyBar((xml, measure) {
                      // One written break makes the viewer keep to written
                      // lines only. In a score that writes none, the lines
                      // it is shown in are written first, so that every
                      // other bar stays on the line it is on.
                      var current = xml;
                      if (writtenLineStarts(xml, widget.partIndex).isEmpty) {
                        final shown = _lineStartsFor(xml);
                        for (final start in shown.skip(1)) {
                          current = _editor
                              .toggleBreak(
                                current,
                                widget.partIndex,
                                start,
                                page: false,
                              )
                              .xml;
                        }
                        // The bar begins a line already: that line is
                        // written now, which is what was asked for.
                        if (!page && shown.contains(measure)) {
                          return XmlEditResult(
                            current,
                            XmlNoteRef(
                              partIndex: widget.partIndex,
                              measureIndex: measure,
                              noteIndex: 0,
                            ),
                          );
                        }
                      }
                      return _editor.toggleBreak(
                        current,
                        widget.partIndex,
                        measure,
                        page: page,
                      );
                    })
                  : null,
              child: Text(label),
            ),
        ];
      case _Palette.score:
        final instrument = _editor.instrumentOf(_xml, widget.partIndex);
        final staves = _editor.staffCount(_xml, widget.partIndex);
        return [
          _MenuButton(
            tooltip: l10n.instrumentMenu,
            label: instrument.name.isEmpty
                ? l10n.instrumentMenu
                : instrument.name,
            items: [
              // Instrument names are written as scores write them.
              for (final choice in partInstruments)
                _MenuItem(
                  choice.name,
                  () => _applyBar(
                    (xml, _) => _editor.setInstrument(
                      xml,
                      widget.partIndex,
                      choice.name,
                      choice.program,
                    ),
                  ),
                  checked: instrument.program == choice.program,
                ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.noteSizeMenu,
            label: l10n.noteSizeMenu,
            items: [
              for (final (label, size) in [
                (l10n.noteSizeSmall, _noteSizes[0]),
                (l10n.noteheadNormal, _noteSizes[1]),
                (l10n.noteSizeLarge, _noteSizes[2]),
                (l10n.noteSizeLarger, _noteSizes[3]),
              ])
                _MenuItem(
                  label,
                  () => setState(() => _noteSize = size),
                  checked: _noteSize == size,
                ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.barsPerLine,
            label: l10n.barsPerLine,
            items: [
              _MenuItem(
                l10n.barsPerLineAuto,
                () => _applyBar(
                  (xml, _) =>
                      _editor.setBarsPerLine(xml, widget.partIndex, null),
                ),
              ),
              for (final count in const [2, 3, 4, 5, 6, 8])
                _MenuItem(
                  l10n.barsPerLineOf(count),
                  () => _applyBar(
                    (xml, _) =>
                        _editor.setBarsPerLine(xml, widget.partIndex, count),
                  ),
                ),
            ],
          ),
          _MenuButton(
            tooltip: l10n.staffMenu,
            label: l10n.staffMenu,
            items: [
              _MenuItem(
                l10n.staffAdd,
                staves == 1
                    ? () => _applyBar(
                        (xml, _) => _editor.addStaff(xml, widget.partIndex),
                      )
                    : null,
              ),
              _MenuItem(
                l10n.staffRemove,
                staves == 2
                    ? () => _applyBar(
                        (xml, _) => _editor.removeStaff(xml, widget.partIndex),
                      )
                    : null,
              ),
            ],
          ),
        ];
    }
  }

  Future<void> _editKeyAndTime() async {
    final measure = _previewMeasure;
    final result = await showMeasureSettingsSheet(context, measure: measure);
    if (result == null || !mounted) return;
    final attributes = measure.attributes;
    final time = attributes.time;
    final keyChanged = result.keyFifths != attributes.keyFifths;
    final timeChanged =
        time == null ||
        result.time.beats != time.beats ||
        result.time.beatType != time.beatType ||
        result.time.symbol != time.symbol;
    if (!keyChanged && !timeChanged) return;
    _applyBar((xml, measureIndex) {
      var current = xml;
      if (keyChanged) {
        current = _editor
            .setKeySignature(
              current,
              widget.partIndex,
              measureIndex,
              result.keyFifths,
            )
            .xml;
      }
      if (timeChanged) {
        current = _editor
            .setTimeSignature(
              current,
              widget.partIndex,
              measureIndex,
              result.time.beats,
              result.time.beatType,
              symbol: switch (result.time.symbol) {
                MusicTimeSymbol.common => 'common',
                MusicTimeSymbol.cut => 'cut',
                null => null,
              },
            )
            .xml;
      }
      return XmlEditResult(
        current,
        XmlNoteRef(
          partIndex: widget.partIndex,
          measureIndex: measureIndex,
          noteIndex: 0,
        ),
      );
    });
  }

  Future<void> _editTempo() async {
    final l10n = context.l10n;
    final result = await showDialog<({int? bpm, String text, bool remove})>(
      context: context,
      builder: (_) => _TempoDialog(initialBpm: _signs.tempoBpm),
    );
    if (result == null || !mounted) return;
    if (result.remove) {
      _applyBar(
        (xml, measure) =>
            _editor.setTempo(xml, widget.partIndex, measure, null),
      );
      return;
    }
    final bpm = result.bpm;
    if (bpm == null) {
      _showMessage(l10n.tempoBpmLabel);
      return;
    }
    _applyBar(
      (xml, measure) => _editor.setTempo(
        xml,
        widget.partIndex,
        measure,
        bpm,
        text: result.text,
      ),
    );
  }

  Future<void> _editRehearsal() async {
    final l10n = context.l10n;
    final initial = _signs.rehearsal ?? '';
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: l10n.rehearsalMark,
        initial: initial,
        hint: l10n.rehearsalHint,
      ),
    );
    if (text == null || !mounted || text == initial) return;
    _applyBar(
      (xml, measure) =>
          _editor.setRehearsalMark(xml, widget.partIndex, measure, text),
    );
  }

  Future<void> _addText() async {
    final l10n = context.l10n;
    final text = await showDialog<String>(
      context: context,
      builder: (_) =>
          _TextDialog(title: l10n.addText, initial: '', hint: l10n.addTextHint),
    );
    if (text == null || !mounted || text.isEmpty) return;
    _applyBar(
      (xml, measure) => _editor.addWords(xml, widget.partIndex, measure, text),
    );
  }
}

/// The palettes of tools under the bar.
enum _Palette { note, length, pitch, marks, looks, words, bar, score }

/// Which notes of a run of chords the tools work on.
enum _Only { all, top, bottom }

/// What a tap on the score does.
enum _Tool { select, eraser, note, rest }

/// What stands under the score.
enum _Panel { none, palette, keys }

/// What [_ScoreProofreadScreenState._inspect] reads of a state of the score.
typedef _Read = ({
  XmlBarInspection bar,
  MusicScore barScore,
  MusicScore score,
  List<String> chunks,
  XmlBarSigns signs,
});

/// A palette to choose, in the list of palettes.
class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.ink;
    return Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.1)
          : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 104,
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 34,
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(color: color, size: 28),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: color),
                      child: child,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tools of the open palette under the score, with the palette's name
/// and a way to put them away.
class _PalettePanel extends StatelessWidget {
  const _PalettePanel({
    required this.title,
    required this.onTitle,
    required this.close,
    required this.onClose,
    required this.children,
  });

  final String title;

  /// A tap on the palette's name: the other palettes, without going back
  /// to the rail for them.
  final VoidCallback onTitle;
  final String close;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: onTitle,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedInk,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 18,
                              color: AppColors.mutedInk,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: close,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
          ),
          _PaletteRow(children: children),
        ],
      ),
    );
  }
}

/// A word over the score on what a tap does now.
class _HintChip extends StatelessWidget {
  const _HintChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon that opens a list of things to do, by name.
class _MenuIconButton extends StatelessWidget {
  const _MenuIconButton({
    required this.tooltip,
    required this.icon,
    required this.items,
  });

  final String tooltip;
  final IconData icon;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: tooltip,
      icon: Icon(icon),
      onSelected: (index) => items[index].onPressed?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            enabled: items[i].onPressed != null,
            child: Row(
              children: [
                Icon(items[i].icon, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(items[i].label)),
              ],
            ),
          ),
      ],
    );
  }
}

/// What is done to a run of bars. Cutting and deleting empty the bars and
/// leave them standing, as in a notation program; removing takes the bars
/// themselves out.
enum _BarRangeAction { copy, cut, delete, remove, transpose }

/// What the bar range dialog was asked to do: bars [from]..[to] as the
/// score numbers them, and for a transposition by how many semitones.
typedef _BarRangeChoice = ({
  int from,
  int to,
  _BarRangeAction action,
  int semitones,
});

/// Asks for a run of bars and what to do with it.
class _BarRangeDialog extends StatefulWidget {
  const _BarRangeDialog({
    required this.current,
    required this.currentTo,
    required this.first,
    required this.last,
  });

  final int current;
  final int currentTo;
  final int first;
  final int last;

  @override
  State<_BarRangeDialog> createState() => _BarRangeDialogState();
}

class _BarRangeDialogState extends State<_BarRangeDialog> {
  late final _from = TextEditingController(text: '${widget.current}');
  late final _to = TextEditingController(text: '${widget.currentTo}');
  var _semitones = 2;
  var _invalid = false;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _submit(_BarRangeAction action) {
    final from = int.tryParse(_from.text.trim());
    final to = int.tryParse(_to.text.trim());
    if (from == null ||
        to == null ||
        from < widget.first ||
        to > widget.last ||
        to < from) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(
      context,
    ).pop((from: from, to: to, action: action, semitones: _semitones));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget field(TextEditingController controller, String label) => Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          helperText: '${widget.first}–${widget.last}',
        ),
      ),
    );
    final sign = _semitones > 0 ? '+' : '';
    return AlertDialog(
      title: Text(l10n.barRangeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                field(_from, l10n.barRangeFrom),
                const SizedBox(width: 12),
                field(_to, l10n.barRangeTo),
              ],
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.barRangeInvalid,
                  style: const TextStyle(color: AppColors.accent),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _submit(_BarRangeAction.copy),
                  child: Text(l10n.barRangeCopy),
                ),
                OutlinedButton(
                  onPressed: () => _submit(_BarRangeAction.cut),
                  child: Text(l10n.barRangeCut),
                ),
                OutlinedButton(
                  onPressed: () => _submit(_BarRangeAction.delete),
                  child: Text(l10n.barRangeDelete),
                ),
                OutlinedButton(
                  onPressed: () => _submit(_BarRangeAction.remove),
                  child: Text(l10n.deleteMeasure),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                IconButton(
                  tooltip: '−',
                  onPressed: _semitones > -12
                      ? () => setState(
                          () => _semitones -= _semitones == 1 ? 2 : 1,
                        )
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Text(
                    l10n.semitoneCount('$sign$_semitones'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '+',
                  onPressed: _semitones < 12
                      ? () => setState(
                          () => _semitones += _semitones == -1 ? 2 : 1,
                        )
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _submit(_BarRangeAction.transpose),
                  child: Text(l10n.barRangeTranspose),
                ),
              ],
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

/// Says that a line is being drawn and what ends it.
class _SpanBanner extends StatelessWidget {
  const _SpanBanner({
    required this.text,
    required this.toSelected,
    required this.onToSelected,
    required this.cancel,
    required this.onCancel,
  });

  final String text;
  final String toSelected;
  final VoidCallback? onToSelected;
  final String cancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(onPressed: onToSelected, child: Text(toSelected)),
            TextButton(onPressed: onCancel, child: Text(cancel)),
          ],
        ),
      ),
    );
  }
}

/// What is done to the picked bars, in a row under the score: it is there
/// the moment the bars are picked, and scrolls where a phone is narrow.
class _BarEditBar extends StatelessWidget {
  const _BarEditBar({
    required this.label,
    required this.actions,
    required this.close,
    required this.onClose,
  });

  final String label;
  final List<(String, IconData, VoidCallback?)> actions;
  final String close;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSoft,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (name, icon, onPressed) in actions)
                    TextButton.icon(
                      onPressed: onPressed,
                      icon: Icon(icon, size: 18),
                      label: Text(name),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: close,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// The tools of the open palette, on as many lines as they need: a tool
/// that had to be scrolled to would be a tool nobody finds.
class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) => _ToolSize(
          compact: constraints.maxWidth < 400,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 4,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for one line of text. Pops with the trimmed text, or null.
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.hint,
  });

  final String title;
  final String initial;
  final String hint;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
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
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
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

/// Asks for a tempo: beats per minute and a word such as "Andante". Pops
/// with the answer, with `remove` when the mark is to be taken away, or
/// null.
class _TempoDialog extends StatefulWidget {
  const _TempoDialog({required this.initialBpm});

  final int? initialBpm;

  @override
  State<_TempoDialog> createState() => _TempoDialogState();
}

class _TempoDialogState extends State<_TempoDialog> {
  late final _bpm = TextEditingController(
    text: widget.initialBpm?.toString() ?? '',
  );
  final _text = TextEditingController();

  @override
  void dispose() {
    _bpm.dispose();
    _text.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop((
    bpm: int.tryParse(_bpm.text.trim()),
    text: _text.text.trim(),
    remove: false,
  ));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.tempoMark),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _bpm,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.tempoBpmLabel,
              prefixText: '♩ = ',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            decoration: InputDecoration(labelText: l10n.tempoText),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        if (widget.initialBpm != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((bpm: null, text: '', remove: true)),
            child: Text(l10n.tempoRemove),
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

enum _LeaveChoice { discard, save }

const _fractionOf = {
  'whole': '1',
  'half': '1/2',
  'quarter': '1/4',
  'eighth': '1/8',
  '16th': '1/16',
  '32nd': '1/32',
  '64th': '1/64',
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

/// Tool buttons are smaller on a narrow phone, so a group stays on one
/// line there too.
class _ToolSize extends InheritedWidget {
  const _ToolSize({required this.compact, required super.child});

  final bool compact;

  static bool compactOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ToolSize>()?.compact ?? false;

  @override
  bool updateShouldNotify(_ToolSize oldWidget) => oldWidget.compact != compact;
}

/// What is written at the note (a chord name, a syllable), or the name of
/// the thing when nothing is.
class _ValueLabel extends StatelessWidget {
  const _ValueLabel({required this.value, required this.empty});

  final String? value;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim() ?? '';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Text(
        text.isEmpty ? empty : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: text.isEmpty
            ? null
            : const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// "8" with an arrow: an octave up or down.
class _OctaveLabel extends StatelessWidget {
  const _OctaveLabel({required this.up});

  final bool up;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('8', style: TextStyle(fontWeight: FontWeight.w700)),
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 16,
        ),
      ],
    );
  }
}

class _ToolGap extends StatelessWidget {
  const _ToolGap();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10);
}

/// "1", "1.5", "0.25": a number of beats without needless digits.
String _beats(double value) {
  final text = value.toStringAsFixed(2);
  return text.contains('.')
      ? text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : text;
}

/// [child] with a small name in its corner.
class _Captioned extends StatelessWidget {
  const _Captioned({required this.caption, required this.child});

  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    if (caption == null) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 8,
          top: 6,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.canvas.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  caption,
                  // Larger letters, but not so large that the name lies
                  // over what it names.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.3),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedInk,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A tool button that opens a list of things to do, each by name.
/// One choice of a [_MenuButton].
class _MenuItem {
  const _MenuItem(
    this.label,
    this.onPressed, {
    this.icon,
    this.checked = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Whether the choice is the one in force: it is shown with a check.
  final bool checked;
}

/// A tool that opens a list of choices by name.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.tooltip,
    required this.label,
    required this.items,
    this.italic = false,
  });

  final String tooltip;
  final String label;
  final List<_MenuItem> items;

  /// For a dynamic mark, written in italics as on the score.
  final bool italic;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            enabled: items[i].onPressed != null,
            child: Row(
              children: [
                Icon(
                  items[i].icon ??
                      (items[i].checked ? Icons.check_rounded : null),
                  size: 20,
                ),
                const SizedBox(width: 12),
                // A long name takes a second line rather than run off the
                // menu.
                Flexible(child: Text(items[i].label)),
              ],
            ),
          ),
      ],
    );
    if (picked != null) items[picked].onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => _ToolButton(
        tooltip: tooltip,
        onPressed: () => unawaited(_open(context)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: italic
                  ? const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontFamily: 'serif',
                      fontSize: 18,
                    )
                  : null,
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.selected = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final compact = _ToolSize.compactOf(context);
    return EditorToolButton(
      tooltip: tooltip,
      onPressed: onPressed,
      selected: selected,
      width: compact ? 42 : 46,
      height: compact ? 42 : 46,
      child: child,
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

class _LyricDialog extends StatefulWidget {
  const _LyricDialog({required this.initial});

  final String initial;

  @override
  State<_LyricDialog> createState() => _LyricDialogState();
}

class _LyricDialogState extends State<_LyricDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit({required bool next}) {
    Navigator.of(context).pop((text: _controller.text.trim(), next: next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.lyric),
      content: TextField(
        controller: _controller,
        autofocus: true,
        // A hyphen or a held line may follow the syllable, and a line of
        // words may be typed at once.
        maxLength: 240,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          helperText: '${l10n.lyricNextHint}\n${l10n.lyricJoinHint}',
          helperMaxLines: 5,
          counterText: '',
        ),
        onSubmitted: (_) => _submit(next: true),
      ),
      actions: [
        if (widget.initial.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop((text: '', next: false)),
            child: Text(l10n.remove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _submit(next: false),
          child: Text(l10n.save),
        ),
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
