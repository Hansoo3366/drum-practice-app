import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  /// Whether a tap picks the other end of a run of notes, and that end: the
  /// tools for pitch and marks then work on every note from the picked one
  /// to it.
  var _ranging = false;
  int? _rangeTo;

  /// The notes the tools work on: the picked one, or with a run picked every
  /// note of its staff from one end to the other.
  List<int> get _picked {
    final from = _noteIndex;
    if (from == null) return const [];
    final to = _rangeTo;
    if (!_ranging || to == null) return [from];
    final notes = _previewMeasure.notes.toList();
    if (from >= notes.length || to >= notes.length) return [from];
    final staff = notes[from].staff;
    return [
      for (var i = math.min(from, to); i <= math.max(from, to); i++)
        if (notes[i].staff == staff) i,
    ];
  }

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
  }

  Future<void> _loadPlaces() async {
    final places = await ref
        .read(omrConvertServiceProvider)
        .barPlaces(widget.songId);
    if (mounted && places != null) setState(() => _places = places);
  }

  @override
  void dispose() {
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
        // A run of notes stays picked only for edits that leave every note
        // where it is.
        final end = _rangeTo;
        _rangeTo =
            keepRange && end != null && end < _previewMeasure.notes.length
            ? end
            : null;
      });
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  void _undo() {
    if (_cursor == 0) return;
    setState(() {
      _spanFrom = null;
      _rangeTo = null;
      final edit = _edits[_cursor - 1];
      _cursor--;
      _measureIndex = edit.measure;
      _refresh(select: edit.before);
    });
    _reveal();
  }

  void _redo() {
    if (_cursor >= _history.length - 1) return;
    setState(() {
      _spanFrom = null;
      _rangeTo = null;
      final edit = _edits[_cursor];
      _cursor++;
      _measureIndex = edit.measureAfter;
      _refresh(select: edit.after);
    });
    _reveal();
  }

  void _goToMeasure(int index, {int select = 0}) {
    if (index < 0 || index >= _measureCount || index == _measureIndex) return;
    setState(() {
      _measureIndex = index;
      _rangeTo = null;
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
        _rangeTo = null;
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
    final index = _noteIndex;
    final count = _previewMeasure.notes.length;
    if (index != null && index + by >= 0 && index + by < count) {
      _selectNote(index + by);
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
      _noteIndex = index;
      _summary = index < _bar.notes.length ? _bar.notes[index] : null;
    });
  }

  void _onEventTapped(ScoreEventAddress address) {
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
    if (_ranging && _noteIndex != null) {
      setState(() => _rangeTo = index);
      return;
    }
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

  void _setTool(_Tool tool) => setState(() {
    _tool = tool;
    if (tool != _Tool.select) {
      _ranging = false;
      _rangeTo = null;
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
    _apply((xml, ref) => _editor.setDuration(xml, ref, type, dots));
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
    final picked = _picked;
    if (picked.length <= 1) {
      _apply(edit);
      return;
    }
    final notes = _bar.notes;
    _apply((xml, ref) {
      var current = xml;
      var done = 0;
      for (final index in backwards ? picked.reversed : picked) {
        if (index >= notes.length) continue;
        if (where != null && !where(notes[index])) continue;
        try {
          current = edit(current, ref.withNote(index)).xml;
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
  }

  /// Puts an articulation on every picked note, or takes it off them all
  /// when every one of them has it.
  void _toggleMark(String name, {required bool restsToo}) {
    bool has(XmlNoteSummary note) =>
        name == 'fermata' ? note.fermata : note.articulations.contains(name);
    bool takes(XmlNoteSummary note) =>
        note.leadsChord && !note.isGrace && (restsToo || !note.isRest);
    final notes = _bar.notes;
    final all = [
      for (final index in _picked)
        if (index < notes.length && takes(notes[index])) notes[index],
    ];
    final allHave = all.isNotEmpty && all.every(has);
    _applyEach(
      (xml, ref) => _editor.toggleArticulation(xml, ref, name),
      where: (note) => takes(note) && has(note) == allHave,
    );
  }

  Future<void> _askBarRange() async {
    final l10n = context.l10n;
    final first = _firstBarNumber;
    final choice = await showDialog<_BarRangeChoice>(
      context: context,
      builder: (_) => _BarRangeDialog(
        current: _measureIndex + first,
        first: first,
        last: _measureCount - 1 + first,
      ),
    );
    if (choice == null || !mounted) return;
    final from = choice.from - first;
    final to = choice.to - first;
    if (choice.action == _BarRangeAction.copy ||
        choice.action == _BarRangeAction.cut) {
      try {
        final clip = _editor.copyMeasures(_xml, from, to);
        setState(() => _clip = clip);
        if (choice.action == _BarRangeAction.copy) {
          _showMessage(l10n.barsCopied(clip.length));
          return;
        }
      } on FormatException catch (error) {
        _showMessage(error.message);
        return;
      }
    }
    switch (choice.action) {
      case _BarRangeAction.copy:
        break;
      case _BarRangeAction.cut || _BarRangeAction.delete:
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
            choice.semitones,
          ),
          bars: (bars, _) => bars,
        );
    }
  }

  void _pasteBars() {
    final clip = _clip;
    if (clip == null) return;
    _apply(
      (xml, ref) => _editor.pasteMeasures(xml, ref, clip),
      bars: (bars, at) => [...bars]
        ..insertAll(at + 1, [
          for (var i = 0; i < clip.length; i++) _nextBarId++,
        ]),
    );
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
    // On to the next note or rest, not to another note of the same chord:
    // a line is played in one key after the other.
    final notes = _bar.notes;
    var next = (_noteIndex ?? index) + 1;
    while (next < notes.length &&
        (!notes[next].leadsChord || notes[next].isGrace)) {
      next++;
    }
    if (next < notes.length) {
      _selectNote(next);
    } else if (_measureIndex < _measureCount - 1) {
      _goToMeasure(_measureIndex + 1);
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
    if (beside == 0 && !value && !moves) return;
    _apply((xml, ref) {
      if (beside != 0) {
        try {
          final added = _editor.insertEvent(
            xml,
            ref,
            before: beside < 0,
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
          // No room in the bar: the note that is there is meant, and
          // when there is nothing to change on it either, the bar says
          // why nothing happened.
          if (!value && !moves) rethrow;
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
    });
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
    await _playback.playFromMeasure(_measureIndex);
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
    if (_measureIndex == 0 && off < 0) return null;
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
      final initial = summary.lyrics[_verse] ?? '';
      final result = await showDialog<({String text, bool next})>(
        context: context,
        builder: (_) => _LyricDialog(initial: initial),
      );
      if (result == null || !mounted) return;
      if (result.text != initial) {
        _apply(
          (xml, ref) => _editor.setLyric(xml, ref, result.text, verse: _verse),
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
        key: _scoreKey,
        score: _previewScore,
        // Line by line: an edit engraves the line it is in, not the score.
        engravingChunks: _chunks,
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
        // Writing, a finger on the staff carries the note, so it must not
        // move the page as well; two fingers do.
        inputMode: _writing ? 'place' : 'select',
        oneFingerPan: !_writing,
        onEventTapped: _writing ? null : _onEventTapped,
        onNotePlaced: _onNotePlaced,
        highlightedMeasureIndex: _measureIndex,
        selectedNoteAddress: selectedEvent == null
            ? null
            : ScoreEventAddress(
                partIndex: 0,
                measureIndex: _measureIndex,
                eventIndex: selectedEvent,
              ),
        alsoSelectedNotes: [
          for (final index in _picked)
            if (index != _noteIndex)
              if (eventIndexForXmlNote(_shownMeasure(_measureIndex), index)
                  case final event?)
                ScoreEventAddress(
                  partIndex: 0,
                  measureIndex: _measureIndex,
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
        onPressed: () => _setTool(_Tool.rest),
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
    final compact = MediaQuery.sizeOf(context).width < 400;
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
      _Tool.note || _Tool.rest => l10n.penHint,
      _Tool.eraser => l10n.eraserHint,
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
        body: SafeArea(
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
                                : (area.maxHeight * 0.24).clamp(84.0, 170.0),
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
                            children: [
                              EditorRail(children: _railTools(l10n)),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: _engraving(l10n, selectedEvent),
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
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
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
                    () => _keyboardOctave = (_keyboardOctave + by).clamp(1, 7),
                  ),
                  lowerTooltip: l10n.keyboardLower,
                  higherTooltip: l10n.keyboardHigher,
                ),
              if (_panel != _Panel.none)
                const Divider(height: 1, color: AppColors.border),
              _transport(l10n),
            ],
          ),
        ),
      ),
    );
  }

  static String _paletteLabel(AppLocalizations l10n, _Palette palette) =>
      switch (palette) {
        _Palette.note => l10n.toolsNote,
        _Palette.length => l10n.toolsLength,
        _Palette.pitch => l10n.toolsPitch,
        _Palette.marks => l10n.toolsMarks,
        _Palette.words => l10n.toolsWords,
        _Palette.bar => l10n.toolsBarSigns,
        _Palette.score => l10n.toolsScore,
      };

  /// Applies an edit of the bar as a whole; the picked note stays picked.
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
              _rangeTo = null;
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
            ],
          ),
        ];
      case _Palette.length:
        return [
          for (final type in noteDurationTypes)
            _ToolButton(
              tooltip: '${l10n.noteValue} ${_fractionOf[type]}',
              selected: summary?.type == type,
              onPressed: canRetime
                  ? () => _apply(
                      (xml, ref) => _editor.setDuration(xml, ref, type, 0),
                    )
                  : null,
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
                  ? () {
                      // One written break makes the viewer keep to written
                      // lines only: in a score that reflows, every other
                      // bar would end up on one line.
                      if (!_xml.contains('new-system="yes"') &&
                          !_xml.contains('new-page="yes"')) {
                        _showMessage(l10n.breaksReflow);
                        return;
                      }
                      _applyBar(
                        (xml, measure) => _editor.toggleBreak(
                          xml,
                          widget.partIndex,
                          measure,
                          page: page,
                        ),
                      );
                    }
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
enum _Palette { note, length, pitch, marks, words, bar, score }

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
    required this.close,
    required this.onClose,
    required this.children,
  });

  final String title;
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
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mutedInk,
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

enum _BarRangeAction { copy, cut, delete, transpose }

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
    required this.first,
    required this.last,
  });

  final int current;
  final int first;
  final int last;

  @override
  State<_BarRangeDialog> createState() => _BarRangeDialogState();
}

class _BarRangeDialogState extends State<_BarRangeDialog> {
  late final _from = TextEditingController(text: '${widget.current}');
  late final _to = TextEditingController(text: '${widget.current}');
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
        maxLength: maxLyricLength,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          helperText: l10n.lyricNextHint,
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
