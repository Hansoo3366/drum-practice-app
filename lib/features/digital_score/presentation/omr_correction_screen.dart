import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_ai_reviewer.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_page_crop.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_patch.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_ai_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';
import 'package:xml/xml.dart';

class OmrCorrectionScreen extends ConsumerStatefulWidget {
  const OmrCorrectionScreen({
    required this.songId,
    required this.musicXml,
    required this.catalog,
    super.key,
  });

  final String songId;
  final String musicXml;
  final ScoreVersionCatalog catalog;

  @override
  ConsumerState<OmrCorrectionScreen> createState() =>
      _OmrCorrectionScreenState();
}

class _OmrCorrectionScreenState extends ConsumerState<OmrCorrectionScreen> {
  late String _xml = widget.musicXml;
  late ScoreVersionCatalog _catalog = widget.catalog;
  final _name = TextEditingController();
  final _history = <({String xml, String activeId})>[];
  Uint8List? _pdf;
  Uint8List? _pagePng;
  Uint8List? _cropPng;
  int _page = 0;
  int _pageCount = 0;
  double _aspect = 1;
  int _part = 0;
  int _measure = 0;
  Rect? _region;
  Offset? _start;
  OmrAiPatch? _target;
  OmrAiReview? _review;
  final _selected = <int>{};
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<XmlElement> get _parts =>
      XmlDocument.parse(_xml).rootElement.findElements('part').toList();
  List<XmlElement> get _measures =>
      _parts[_part].findElements('measure').toList();

  Future<void> _load() async {
    try {
      final source = await ref
          .read(songFileStorageProvider)
          .loadOmrSource(widget.songId);
      if (source == null || !source.fileName.toLowerCase().endsWith('.pdf')) {
        throw const FormatException('원본 PDF가 없습니다. PDF를 다시 변환하세요.');
      }
      _pdf = Uint8List.fromList(source.bytes);
      await _loadPage();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _resetProposal() {
    _review = null;
    _target = null;
    _cropPng = null;
    _selected.clear();
  }

  Future<void> _loadPage() async {
    final page = await ref.read(omrPageCropProvider).loadPage(_pdf!, _page);
    if (mounted) {
      setState(() {
        _pagePng = page.png;
        _aspect = page.aspect;
        _pageCount = page.pageCount;
        _region = null;
        _resetProposal();
      });
    }
  }

  Future<void> _changePage(int delta) async {
    setState(() {
      _busy = true;
      _error = null;
      _page += delta;
      _pagePng = null;
      _region = null;
      _resetProposal();
    });
    try {
      await _loadPage();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareCrop() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final png = await ref
          .read(omrPageCropProvider)
          .renderRegion(pdfBytes: _pdf!, pageIndex: _page, region: _region!);
      if (mounted) {
        setState(() {
          _cropPng = png;
          _target = OmrAiPatch(_xml, _part, _measure);
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _compare() async {
    setState(() {
      _busy = true;
      _error = null;
      _review = null;
      _selected.clear();
    });
    try {
      final review = await ref
          .read(omrAiReviewerProvider)
          .reviewRegion(pngBytes: _cropPng!, target: _target!);
      if (mounted) setState(() => _review = review);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '버전 이름을 입력하세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final patched = _target!.apply(_xml, [
        for (var i = 0; i < _review!.corrections.length; i++)
          if (_selected.contains(i)) _review!.corrections[i],
      ]);
      final next = await ref
          .read(digitalScoreEditorServiceProvider)
          .addXmlVersion(
            songId: widget.songId,
            musicXml: patched,
            catalog: _catalog,
            name: _name.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _history.add((xml: _xml, activeId: _catalog.activeId));
        _xml = patched;
        _catalog = next;
        _resetProposal();
        _region = null;
        _name.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('수정 버전을 저장했습니다.')));
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    try {
      final candidate = _target!.apply(_xml, [
        for (var i = 0; i < _review!.corrections.length; i++)
          if (_selected.contains(i)) _review!.corrections[i],
      ]);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _CorrectionPreview(
            source: _cropPng!,
            before: _target!.previewXml(_xml),
            after: _target!.previewXml(candidate),
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _undo() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(digitalScoreEditorServiceProvider);
      final latest = await service.loadVersionCatalog(widget.songId);
      if (latest.activeId != _catalog.activeId) {
        throw const FormatException('활성 버전이 변경되었습니다. 악보를 다시 여세요.');
      }
      final previous = _history.last;
      final next = latest.copyWith(activeId: previous.activeId);
      await service.saveVersionCatalog(widget.songId, next);
      if (mounted) {
        setState(() {
          _history.removeLast();
          _xml = previous.xml;
          _catalog = next;
          _resetProposal();
          _region = null;
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts;
    final measures = parts.isEmpty ? <XmlElement>[] : _measures;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('원본 대조'),
          actions: [
            IconButton(
              tooltip: '이전 버전으로 복귀',
              onPressed: !_busy && _history.isNotEmpty ? _undo : null,
              icon: const Icon(Icons.undo),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Text(
              _catalog.find(_catalog.activeId)?.name ?? '원본',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (parts.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: _part,
                decoration: const InputDecoration(labelText: '파트'),
                items: [
                  for (var i = 0; i < parts.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(parts[i].getAttribute('id') ?? '${i + 1}'),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _part = value!;
                        _measure = 0;
                        _region = null;
                        _resetProposal();
                      }),
              ),
            const SizedBox(height: 8),
            if (measures.isNotEmpty)
              DropdownButtonFormField<int>(
                key: ValueKey(_part),
                initialValue: _measure,
                decoration: const InputDecoration(labelText: '마디'),
                items: [
                  for (var i = 0; i < measures.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${measures[i].getAttribute('number')} (${i + 1})',
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _measure = value!;
                        _region = null;
                        _resetProposal();
                      }),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '이전 PDF 페이지',
                  onPressed: !_busy && _page > 0 ? () => _changePage(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_page + 1} / $_pageCount'),
                IconButton(
                  tooltip: '다음 PDF 페이지',
                  onPressed: !_busy && _page + 1 < _pageCount
                      ? () => _changePage(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (_pagePng != null) ...[
              const Text('선택한 파트·마디 전체를 드래그하세요.'),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: _aspect,
                child: LayoutBuilder(
                  builder: (context, box) {
                    Offset normalize(Offset p) => Offset(
                      (p.dx / box.maxWidth).clamp(0, 1),
                      (p.dy / box.maxHeight).clamp(0, 1),
                    );
                    return Semantics(
                      label: '원본 PDF 마디 영역 지정',
                      child: GestureDetector(
                        onPanStart: _busy
                            ? null
                            : (d) => setState(() {
                                _start = normalize(d.localPosition);
                                _region = null;
                                _resetProposal();
                              }),
                        onPanUpdate: _busy
                            ? null
                            : (d) => setState(() {
                                _region = Rect.fromPoints(
                                  _start!,
                                  normalize(d.localPosition),
                                );
                              }),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_pagePng!, fit: BoxFit.fill),
                            if (_region != null)
                              Positioned(
                                left: _region!.left * box.maxWidth,
                                top: _region!.top * box.maxHeight,
                                width: _region!.width * box.maxWidth,
                                height: _region!.height * box.maxHeight,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.12),
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              OutlinedButton(
                onPressed: !_busy && _region != null ? _prepareCrop : null,
                child: const Text('선택 영역 확인'),
              ),
            ],
            if (_cropPng != null) ...[
              const SizedBox(height: 16),
              Image.memory(_cropPng!, semanticLabel: 'AI와 대조할 원본 마디'),
              const SizedBox(height: 8),
              const Text(
                '이 영역이 선택한 파트·마디인지 확인하세요. 이미지와 악보 정보가 xAI로 전송되며 API 요금이 발생할 수 있습니다.',
              ),
              FilledButton(
                onPressed: !_busy ? _compare : null,
                child: const Text('확인하고 AI 비교'),
              ),
            ],
            if (_review != null) ...[
              const SizedBox(height: 16),
              const Text('AI도 잘못 읽을 수 있습니다. 원본과 대조하고 승인할 항목만 선택하세요.'),
              if (_review!.corrections.isEmpty) const Text('검증 가능한 수정안이 없습니다.'),
              for (var i = 0; i < _review!.corrections.length; i++)
                _correctionTile(i),
              if (_review!.corrections.isNotEmpty) ...[
                OutlinedButton(
                  onPressed: !_busy && _selected.isNotEmpty ? _preview : null,
                  child: const Text('수정 전후 악보 보기'),
                ),
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: '버전 이름'),
                ),
                FilledButton(
                  onPressed: !_busy && _selected.isNotEmpty ? _save : null,
                  child: const Text('선택한 수정 저장'),
                ),
              ],
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _correctionTile(int index) {
    final correction = _review!.corrections[index];
    final noteIndex = int.tryParse(
      correction.elementId?.split('_n').last ?? '',
    );
    final property = switch (correction.property) {
      'pitch' => '음높이',
      'duration' => '음가',
      _ => correction.property,
    };
    final reason = _review!.hasError
        ? _target!.rejection(correction)
        : 'AI가 오류로 판정하지 않았습니다.';
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: _selected.contains(index),
      onChanged: _busy || reason != null
          ? null
          : (value) => setState(() {
              if (value == true) {
                _selected.add(index);
              } else {
                _selected.remove(index);
              }
            }),
      title: Text(
        '${noteIndex == null ? '대상 미확인' : '음표 ${noteIndex + 1}'} · $property',
      ),
      subtitle: Text(
        '${correction.currentValue} → ${correction.suggestedValue}${reason == null ? '' : '\n$reason'}',
      ),
    );
  }
}

class _CorrectionPreview extends StatefulWidget {
  const _CorrectionPreview({
    required this.source,
    required this.before,
    required this.after,
  });
  final Uint8List source;
  final String before;
  final String after;

  @override
  State<_CorrectionPreview> createState() => _CorrectionPreviewState();
}

class _CorrectionPreviewState extends State<_CorrectionPreview> {
  final _beforePlayback = PianoScorePlaybackController();
  final _afterPlayback = PianoScorePlaybackController();

  @override
  void dispose() {
    _beforePlayback.dispose();
    _afterPlayback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('마디 비교'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '원본 PDF'),
            Tab(text: '수정 전'),
            Tab(text: '수정 후'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          InteractiveViewer(
            child: Center(
              child: Image.memory(
                widget.source,
                semanticLabel: '지정한 원본 PDF 마디',
              ),
            ),
          ),
          VerovioScoreView(
            score: const MusicXmlCodec().decodeXml(widget.before),
            engravingXml: widget.before,
            semanticsLabel: '수정 전 마디',
            playback: _beforePlayback,
          ),
          VerovioScoreView(
            score: const MusicXmlCodec().decodeXml(widget.after),
            engravingXml: widget.after,
            semanticsLabel: '수정 후 마디',
            playback: _afterPlayback,
          ),
        ],
      ),
    ),
  );
}
