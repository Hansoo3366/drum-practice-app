import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_quality.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/omr_original_crop.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_proofread_screen.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';

/// Goes through the measures the conversion is unsure about, one at a time:
/// the original crop, what was recognised, why it is doubted and what the AI
/// review suggests. Nothing is changed here; a measure is fixed in the
/// proofreading editor, which saves a new version.
/// Pops with `true` after a version was saved.
class OmrReviewScreen extends ConsumerStatefulWidget {
  const OmrReviewScreen({
    required this.songId,
    required this.musicXml,
    required this.catalog,
    required this.bars,
    this.checked = const {},
    this.annotations = const [],
    super.key,
  });

  final String songId;
  final String musicXml;
  final ScoreVersionCatalog catalog;
  final List<OmrReviewBar> bars;
  final Set<String> checked;
  final List<OmrAnnotation> annotations;

  @override
  ConsumerState<OmrReviewScreen> createState() => _OmrReviewScreenState();
}

class _OmrReviewScreenState extends ConsumerState<OmrReviewScreen> {
  static const _codec = MusicXmlCodec();
  static const _editor = XmlMeasureEditor();

  final _playback = PianoScorePlaybackController();
  final _images = <String, Future<Uint8List?>>{};
  final _originals = <String, Future<Uint8List?>>{};
  late String _xml = widget.musicXml;
  late ScoreVersionCatalog _catalog = widget.catalog;
  late final Set<String> _checked = {...widget.checked};
  late int _index = _firstOpen();
  var _saved = false;

  List<int>? _origins;

  /// Where the conversion placed every measure on the original, when known:
  /// a bar without a crop of its own is shown on its staff line.
  List<List<OmrBarPlace?>>? _places;
  final _texts = <int, List<Set<String>>>{};

  String? _preview;
  MusicScore? _previewScore;

  /// Note suggestions the user took into the score, by bar key and the
  /// suggestion's index in that bar: the score on screen is the version
  /// with these written in. They become a version with "저장".
  final _approved = <String, Set<int>>{};

  /// The version on screen before any approved suggestion: the one opened,
  /// then each one saved from here.
  late String _baseXml = widget.musicXml;
  var _saving = false;

  bool get _dirty => _approved.values.any((set) => set.isNotEmpty);

  OmrReviewBar get _bar => widget.bars[_index];

  /// Where [bar], counted as the conversion left it, is in the version on
  /// screen: bars may have been added or removed since. Null when it is gone.
  int? _barIndex(OmrReviewBar bar) {
    final origins = _origins;
    if (origins == null) return bar.measureIndex;
    final index = origins.indexOf(bar.measureIndex);
    return index < 0 ? null : index;
  }

  int _firstOpen() {
    final open = widget.bars.indexWhere((bar) => !_checked.contains(bar.key));
    return open < 0 ? 0 : open;
  }

  @override
  void initState() {
    super.initState();
    _readVersion();
    _engrave();
    unawaited(_loadPlaces());
  }

  Future<void> _loadPlaces() async {
    final places = await ref
        .read(omrConvertServiceProvider)
        .barPlaces(widget.songId);
    if (mounted && places != null) setState(() => _places = places);
  }

  /// The original of [bar]: the server's crop around it, or its staff line.
  ({Future<Uint8List?> image, (double, double)? focus, double? around})?
  _originalOf(OmrReviewBar bar) {
    if (bar.image case final name?) {
      return (image: _image(name), focus: bar.focus, around: null);
    }
    final part = _places?.elementAtOrNull(bar.partIndex);
    final place = part?.elementAtOrNull(bar.measureIndex);
    if (place == null) return null;
    return (
      image: _originals.putIfAbsent(
        place.image,
        () => ref
            .read(omrConvertServiceProvider)
            .systemImage(widget.songId, place.image),
      ),
      focus: place.focus,
      around: 1.0,
    );
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  /// The bar as it is recognised now, on its own.
  void _engrave() {
    try {
      final isolated = isolateMeasureXml(
        _xml,
        _bar.partIndex,
        _barIndex(_bar) ?? -1,
      );
      _previewScore = _codec.decodeXml(isolated);
      _preview = isolated;
    } on Object {
      // A bar the version no longer has (bars were removed since).
      _preview = null;
      _previewScore = null;
    }
  }

  /// The reasons that still hold for [bar] in the version on screen. The
  /// server's report is from the conversion: a leftover text that has been
  /// removed since is no longer a reason.
  List<OmrReviewIssue> _openIssues(OmrReviewBar bar) {
    final index = _barIndex(bar);
    final part = _textsOf(bar.partIndex);
    if (index == null || index >= part.length) return bar.issues;
    final texts = part[index];
    return [
      for (final issue in bar.issues)
        if (issue.leftover case final leftover?
            when !texts.contains(leftover.replaceAll(RegExp(r'\s+'), '')))
          ...const <OmrReviewIssue>[]
        else
          issue,
    ];
  }

  /// Reads from the version on screen what the review needs of every bar.
  /// Once per version: the score is large, and this is asked from `build`.
  void _readVersion() {
    _origins = barOrigins(_xml);
    _texts.clear();
  }

  /// The texts of every bar of a part, without their spaces.
  List<Set<String>> _textsOf(int partIndex) =>
      _texts.putIfAbsent(partIndex, () {
        try {
          return [
            for (final texts in _editor.allMeasureTexts(_xml, partIndex))
              {for (final text in texts) text.replaceAll(RegExp(r'\s+'), '')},
          ];
        } on FormatException {
          return const [];
        }
      });

  bool _settled(OmrReviewBar bar) =>
      _openIssues(bar).isEmpty &&
      bar.suggestions.isEmpty &&
      bar.uncertain.isEmpty;

  void _go(int index) {
    if (index < 0 || index >= widget.bars.length) return;
    setState(() {
      _index = index;
      _engrave();
    });
  }

  Future<Uint8List?> _image(String name) => _images.putIfAbsent(
    name,
    () => ref.read(omrConvertServiceProvider).suspectImage(widget.songId, name),
  );

  Future<void> _toggleChecked() async {
    final key = _bar.key;
    final nowChecked = !_checked.contains(key);
    setState(() {
      nowChecked ? _checked.add(key) : _checked.remove(key);
      // Accepting a bar moves on to the next one still open.
      if (nowChecked) {
        final next = [
          for (var i = _index + 1; i < widget.bars.length; i++) i,
          for (var i = 0; i < _index; i++) i,
        ].where((i) => !_checked.contains(widget.bars[i].key)).firstOrNull;
        if (next != null) {
          _index = next;
          _engrave();
        }
      }
    });
    await ref
        .read(songFileStorageProvider)
        .saveOmrReviewState(widget.songId, omrReviewStateJson(_checked));
  }

  /// Writes [suggestion] of [bar] into the score on screen, or takes it out
  /// again. Done from the version as opened, so approvals of one bar never
  /// depend on the order they were given in.
  void _toggleApproval(OmrReviewBar bar, int suggestionIndex) {
    final set = _approved.putIfAbsent(bar.key, () => {});
    final adding = !set.contains(suggestionIndex);
    if (adding) {
      set.add(suggestionIndex);
    } else {
      set.remove(suggestionIndex);
    }
    try {
      final xml = _withApprovals(_baseXml);
      setState(() {
        _xml = xml;
        _readVersion();
        _engrave();
      });
    } on FormatException catch (error) {
      if (adding) set.remove(suggestionIndex);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// [xml] with every approved suggestion written in.
  String _withApprovals(String xml) {
    var result = xml;
    for (final bar in widget.bars) {
      final chosen = _approved[bar.key];
      if (chosen == null || chosen.isEmpty) continue;
      final index = _barIndexIn(result, bar);
      if (index == null) {
        throw const FormatException('이 버전에는 없는 마디입니다.');
      }
      // A whole melody first: single notes are then addressed in it. The
      // lengths go in together, so each names the note it was made for and
      // the bar closes up behind them.
      final order = chosen.toList()
        ..sort((a, b) {
          int rank(int i) => bar.suggestions[i].field == 'melody' ? 0 : 1;
          return rank(a) != rank(b) ? rank(a) - rank(b) : a - b;
        });
      final lengths = <int, ({String type, int dots})>{};
      for (final i in order) {
        final suggestion = bar.suggestions[i];
        final note = XmlNoteRef(
          partIndex: bar.partIndex,
          measureIndex: index,
          noteIndex: (suggestion.note ?? 1) - 1,
        );
        switch (suggestion.field) {
          case 'melody':
            result = _editor
                .replaceMelody(
                  result,
                  bar.partIndex,
                  index,
                  suggestion.suggested,
                )
                .xml;
          case 'pitch' when suggestion.note != null:
            result = _editor
                .setNotePitch(result, note, suggestion.suggested)
                .xml;
          case 'duration' when suggestion.note != null:
            lengths[note.noteIndex] = _suggestedLength(
              result,
              note,
              suggestion,
            );
          default:
            throw const FormatException('이 제안은 바로 넣을 수 없습니다.');
        }
      }
      if (lengths.isNotEmpty) {
        result = _editor
            .setNoteLengths(result, bar.partIndex, index, lengths)
            .xml;
      }
    }
    return result;
  }

  /// The length a duration suggestion asks for ("8.", "q", "D5 8": its last
  /// token). It names a note of the bar as converted. When that note no
  /// longer has the length the suggestion saw, the bar has changed since
  /// (an earlier approval or a fix), and writing it would change some other
  /// note.
  ({String type, int dots}) _suggestedLength(
    String xml,
    XmlNoteRef ref,
    OmrReviewSuggestion suggestion,
  ) {
    MelodyToken length(String text) => parseMelodyTokens(
      'C4 ${text.trim().split(RegExp(r'\s+')).last}',
    ).single;
    final token = length(suggestion.suggested);
    MelodyToken? seen;
    try {
      seen = length(suggestion.current);
    } on FormatException {
      // No length to compare with.
    }
    if (seen != null) {
      final now = _editor.describe(xml, ref);
      if (now.type != seen.type || now.dots != seen.dots) {
        throw const FormatException('마디가 바뀌어 이 제안은 넣을 수 없습니다.');
      }
    }
    return (type: token.type, dots: token.dots);
  }

  /// Where [bar] is in [xml], by the bar origins written in it.
  int? _barIndexIn(String xml, OmrReviewBar bar) {
    final origins = barOrigins(xml);
    if (origins == null) return bar.measureIndex;
    final index = origins.indexOf(bar.measureIndex);
    return index < 0 ? null : index;
  }

  /// Saves the score with the approved suggestions as a new version.
  Future<void> _saveApprovals() async {
    if (_saving || !_dirty) return;
    final service = ref.read(digitalScoreEditorServiceProvider);
    final name = await showDialog<String>(
      context: context,
      builder: (_) =>
          _VersionNameDialog(initial: 'AI 승인 ${_catalog.versions.length + 1}'),
    );
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      final sequence = await service.loadSequence(
        widget.songId,
        versionId: _catalog.activeId,
      );
      final catalog = await service.addXmlVersion(
        songId: widget.songId,
        musicXml: _xml,
        catalog: _catalog,
        name: name,
        // Same bars: the sections and order carry over.
        sequence: sequence,
      );
      if (!mounted) return;
      setState(() {
        _saved = true;
        _catalog = catalog;
        // What comes next is added to the version just saved.
        _baseXml = _xml;
        _approved.clear();
        // Bars whose suggestions went in need no second look.
        for (final bar in widget.bars) {
          if (_settled(bar)) _checked.add(bar.key);
        }
      });
      await ref
          .read(songFileStorageProvider)
          .saveOmrReviewState(widget.songId, omrReviewStateJson(_checked));
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _fix() async {
    if (_dirty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('넣은 제안을 먼저 저장하거나 되돌리세요.')));
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScoreProofreadScreen(
          songId: widget.songId,
          musicXml: _xml,
          catalog: _catalog,
          partIndex: _bar.partIndex,
          measureIndex: _barIndex(_bar) ?? 0,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final service = ref.read(digitalScoreEditorServiceProvider);
    final catalog = await service.loadVersionCatalog(widget.songId);
    final xml = await service.loadVersionXml(widget.songId, catalog.activeId);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _catalog = catalog;
      if (xml != null) _baseXml = _xml = xml;
      _readVersion();
      _engrave();
      // Fixed bars need no second look.
      for (final bar in widget.bars) {
        if (_settled(bar)) _checked.add(bar.key);
      }
    });
    await ref
        .read(songFileStorageProvider)
        .saveOmrReviewState(widget.songId, omrReviewStateJson(_checked));
  }

  void _showAnnotations() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                '분리한 필기 ${widget.annotations.length}개',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '색 펜과 형광펜은 악보를 읽기 전에 떼어 냈습니다. 원본 파일에는 그대로 있습니다.',
                style: TextStyle(color: AppColors.mutedInk),
              ),
              const SizedBox(height: 8),
              for (final item in widget.annotations)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.highlight
                        ? Icons.border_color_outlined
                        : Icons.edit_outlined,
                  ),
                  title: Text(item.text ?? item.label),
                  subtitle: Text(
                    item.text == null
                        ? '${item.page}쪽'
                        : '${item.label} · ${item.page}쪽',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bar = _bar;
    final checked = _checked.contains(bar.key);
    final done = widget.bars.where((b) => _checked.contains(b.key)).length;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dirty) {
          unawaited(_confirmLeave());
        } else {
          Navigator.of(context).pop(_saved);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('변환 검토'),
          actions: [
            if (_dirty)
              TextButton(
                onPressed: _saving ? null : () => unawaited(_saveApprovals()),
                child: const Text('저장'),
              ),
            if (widget.annotations.isNotEmpty)
              IconButton(
                tooltip: '분리한 필기',
                onPressed: _showAnnotations,
                icon: const Icon(Icons.draw_outlined),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('확인 $done/${widget.bars.length}'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '마디 ${bar.measure}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    if (checked)
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.mutedInk,
                      ),
                    const Spacer(),
                    Text(
                      '${_index + 1} / ${widget.bars.length}',
                      style: const TextStyle(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final panes = [
                      Expanded(
                        child: _Pane(
                          title: '원본',
                          child: _Original(
                            image: _originalOf(bar)?.image,
                            focus: _originalOf(bar)?.focus,
                            around: _originalOf(bar)?.around,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _Pane(
                          title: '현재 인식',
                          child: _recognised(constraints.maxWidth),
                        ),
                      ),
                    ];
                    return constraints.maxWidth >= 700
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: panes,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: panes,
                          );
                  },
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                flex: 2,
                child: _Findings(
                  bar: bar,
                  issues: _openIssues(bar),
                  approved: _approved[bar.key] ?? const {},
                  onToggle: (index) => _toggleApproval(bar, index),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '이전 마디',
                      onPressed: _index > 0 ? () => _go(_index - 1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton(
                      tooltip: '다음 마디',
                      onPressed: _index < widget.bars.length - 1
                          ? () => _go(_index + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _preview == null
                          ? null
                          : () => unawaited(_fix()),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('고치기'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => unawaited(_toggleChecked()),
                      icon: Icon(
                        checked ? Icons.undo_rounded : Icons.check_rounded,
                      ),
                      label: Text(checked ? '확인 취소' : '문제 없음'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recognised(double width) {
    final preview = _preview;
    final score = _previewScore;
    if (preview == null || score == null) {
      return const Center(
        child: Text(
          '이 버전에는 없는 마디입니다.',
          style: TextStyle(color: AppColors.mutedInk),
        ),
      );
    }
    return VerovioScoreView(
      // A new bar is a new engraving, not a change to the last one.
      key: ValueKey('${_bar.key}/${preview.hashCode}'),
      score: score,
      engravingXml: preview,
      engravingPageSize: Size(
        (width * 1.1).clamp(800, 1100).roundToDouble(),
        1400,
      ),
      semanticsLabel: '마디 ${_bar.measure} 현재 인식',
      playback: _playback,
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRect(child: SizedBox.expand(child: child)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Original extends StatelessWidget {
  const _Original({required this.image, this.focus, this.around});

  final Future<Uint8List?>? image;

  /// Where the measure is in the crop; its neighbours are dimmed.
  final (double, double)? focus;

  /// How much of the picture beside the measure to show (see
  /// [OmrOriginalCrop.around]); all of it when null.
  final double? around;

  @override
  Widget build(BuildContext context) {
    const missing = Center(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          '원본 조각이 없습니다.',
          style: TextStyle(color: AppColors.mutedInk),
        ),
      ),
    );
    if (image == null) return missing;
    return FutureBuilder<Uint8List?>(
      future: image,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) return missing;
        return OmrOriginalCrop(
          bytes: bytes,
          focus: focus,
          around: around,
          missing: missing,
        );
      },
    );
  }
}

class _Findings extends StatelessWidget {
  const _Findings({
    required this.bar,
    required this.issues,
    required this.approved,
    required this.onToggle,
  });

  final OmrReviewBar bar;

  /// The reasons that still hold.
  final List<OmrReviewIssue> issues;

  /// Indexes of the bar's suggestions written into the score on screen.
  final Set<int> approved;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.labelLarge;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      children: [
        if (issues.isEmpty && bar.suggestions.isEmpty && bar.uncertain.isEmpty)
          const _Line(
            icon: Icons.check_circle_outline,
            text: '남은 확인 사항이 없습니다.',
          ),
        if (issues.isNotEmpty) ...[
          Text('확인할 점', style: heading),
          for (final issue in issues)
            _Line(
              icon: switch (issue.severity) {
                OmrIssueSeverity.high => Icons.error_outline,
                OmrIssueSeverity.medium => Icons.warning_amber_outlined,
                OmrIssueSeverity.low => Icons.info_outline,
              },
              text: issue.text,
            ),
        ],
        if (bar.suggestions.isNotEmpty || bar.uncertain.isNotEmpty) ...[
          if (issues.isNotEmpty) const SizedBox(height: 12),
          Text('AI 제안', style: heading),
          for (final (index, suggestion) in bar.suggestions.indexed)
            _Line(
              icon: suggestion.applied
                  ? Icons.auto_fix_high_outlined
                  : Icons.lightbulb_outline,
              text:
                  '${suggestion.label}: '
                  '${suggestion.current.isEmpty ? '(없음)' : suggestion.current}'
                  ' → ${suggestion.suggested}',
              note: [
                if (suggestion.confidence case final confidence?)
                  '확신 ${(confidence * 100).round()}%',
                approved.contains(index) ? '넣음 · 저장하면 새 버전' : suggestion.advice,
              ].join(' · '),
              // A note suggestion is taken into the score by hand, here.
              action: suggestion.canApply
                  ? TextButton(
                      onPressed: () => onToggle(index),
                      child: Text(approved.contains(index) ? '빼기' : '이 마디에 넣기'),
                    )
                  : null,
            ),
          for (final reason in bar.uncertain)
            _Line(icon: Icons.help_outline, text: reason, note: 'AI가 읽지 못함'),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.note, this.action});

  final IconData icon;
  final String text;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.tertiaryInk),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (note != null)
                  Text(
                    note!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedInk,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Asks what to do with approved suggestions when leaving.
extension on _OmrReviewScreenState {
  Future<void> _confirmLeave() async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('넣은 제안이 저장되지 않았습니다'),
        content: const Text('저장하지 않으면 넣은 제안은 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('버리기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice) {
      await _saveApprovals();
      if (mounted && !_dirty) Navigator.of(context).pop(_saved);
    } else {
      Navigator.of(context).pop(_saved);
    }
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('버전 이름'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
