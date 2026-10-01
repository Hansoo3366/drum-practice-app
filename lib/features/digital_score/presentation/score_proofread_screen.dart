import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/three_staff_arrangement.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/note_duration_icon.dart';
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
    super.key,
  });

  final String songId;
  final String musicXml;
  final ScoreVersionCatalog catalog;
  final int partIndex;
  final int measureIndex;

  @override
  ConsumerState<ScoreProofreadScreen> createState() =>
      _ScoreProofreadScreenState();
}

class _ScoreProofreadScreenState extends ConsumerState<ScoreProofreadScreen> {
  static const _historyLimit = 100;

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
  final List<({int measure, int before, int after})> _edits = [];
  var _cursor = 0;
  var _savedCursor = 0;
  late int _measureIndex = widget.measureIndex;
  late final int _measureCount = measureCountOf(
    widget.musicXml,
    widget.partIndex,
  );
  int? _noteIndex;
  late String _preview;
  late MusicScore _previewScore;
  XmlNoteSummary? _summary;
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

  @override
  void initState() {
    super.initState();
    _measureIndex = _measureIndex.clamp(0, _measureCount - 1);
    _refresh(select: 0);
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  /// Re-engraves the current bar and keeps [select] (or the current note)
  /// selected when it still exists.
  void _refresh({int? select}) {
    final isolated = isolateMeasureXml(_xml, widget.partIndex, _measureIndex);
    _previewScore = _codec.decodeXml(isolated);
    _preview = tagIsolatedNotes(isolated, _previewMeasure);
    final count = _previewMeasure.notes.length;
    final index = select ?? _noteIndex;
    _noteIndex = count == 0 || index == null ? null : index.clamp(0, count - 1);
    _summary = _ref == null ? null : _editor.describe(_xml, _ref!);
  }

  void _apply(XmlEditResult Function(String xml, XmlNoteRef ref) edit) {
    final ref = _ref;
    if (ref == null) return;
    try {
      final result = edit(_xml, ref);
      _codec.decodeXml(result.xml);
      setState(() {
        _history
          ..removeRange(_cursor + 1, _history.length)
          ..add(result.xml);
        _edits
          ..removeRange(_cursor, _edits.length)
          ..add((
            measure: ref.measureIndex,
            before: ref.noteIndex,
            after: result.selection.noteIndex,
          ));
        _cursor = _history.length - 1;
        if (_history.length > _historyLimit + 1) {
          _history.removeAt(0);
          _edits.removeAt(0);
          _cursor--;
          _savedCursor--;
        }
        _refresh(select: result.selection.noteIndex);
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
      _measureIndex = edit.measure;
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
    setState(() => _refresh(select: index));
  }

  void _onEventTapped(ScoreEventAddress address) {
    final index = xmlNoteIndexForEvent(_previewMeasure, address.eventIndex);
    if (index != null) _selectNote(index);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _askBar() async {
    final number = await showDialog<int>(
      context: context,
      builder: (_) =>
          _BarNumberDialog(current: _measureIndex + 1, count: _measureCount),
    );
    if (number != null && mounted) _goToMeasure(number - 1);
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
      await ref
          .read(digitalScoreEditorServiceProvider)
          .addXmlVersion(
            songId: widget.songId,
            // Generated parts follow the edited melody and chords.
            musicXml: regenerateAccompaniment(_xml),
            catalog: widget.catalog,
            name: name,
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
                  builder: (context, constraints) => VerovioScoreView(
                    score: _previewScore,
                    engravingXml: _preview,
                    engravingPageSize: _pageSizeFor(constraints.maxWidth),
                    semanticsLabel: l10n.proofreadBar(
                      _measureIndex + 1,
                      _measureCount,
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
                          l10n.proofreadBar(_measureIndex + 1, _measureCount),
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
  const _BarNumberDialog({required this.current, required this.count});

  final int current;
  final int count;

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
    if (value == null || value < 1 || value > widget.count) {
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
          hintText: '1–${widget.count}',
          errorText: _invalid ? '1–${widget.count}' : null,
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
