import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/native_score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';

class PianoScorePlaybackController extends ChangeNotifier {
  ScorePlaybackState _state = const ScorePlaybackState();
  Future<bool> Function()? _playPause;
  Future<bool> Function()? _stop;
  Future<bool> Function(double positionMs)? _seek;

  ScorePlaybackState get state => _state;

  void attach({
    required Future<bool> Function() playPause,
    required Future<bool> Function() stop,
    required Future<bool> Function(double positionMs) seek,
  }) {
    _playPause = playPause;
    _stop = stop;
    _seek = seek;
  }

  void detach() {
    _playPause = null;
    _stop = null;
    _seek = null;
  }

  void replaceState(ScorePlaybackState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  Future<bool> playPause() async => await _playPause?.call() ?? false;

  Future<bool> stop() async => await _stop?.call() ?? false;

  Future<bool> seek(double positionMs) async =>
      await _seek?.call(positionMs) ?? false;
}

class PianoScoreView extends StatefulWidget {
  const PianoScoreView({
    required this.score,
    required this.semanticsLabel,
    required this.playback,
    this.playbackVisible = false,
    this.onNoteTapped,
    this.onStaffTapped,
    this.onMeasureTapped,
    this.onMeasureMoved,
    this.onSystemsChanged,
    this.onNoteDragged,
    this.onPlayerIssue,
    this.highlightedMeasureIndex,
    this.absorbMeasureTaps = false,
    this.oneFingerPan = true,
    this.inputMode = 'off',
    this.inputDurationType = 'quarter',
    this.inputRest = false,
    super.key,
  });

  final MusicScore score;
  final String semanticsLabel;
  final PianoScorePlaybackController playback;
  final bool playbackVisible;
  final ValueChanged<AlphaTabNoteTappedEvent>? onNoteTapped;
  final ValueChanged<AlphaTabStaffTappedEvent>? onStaffTapped;
  final ValueChanged<int>? onMeasureTapped;
  final void Function(int fromIndex, int toIndex)? onMeasureMoved;
  final ValueChanged<List<ScoreSystemSpan>>? onSystemsChanged;
  final ValueChanged<AlphaTabNoteDraggedEvent>? onNoteDragged;
  final VoidCallback? onPlayerIssue;
  final int? highlightedMeasureIndex;
  final bool absorbMeasureTaps;
  final bool oneFingerPan;
  final String inputMode;
  final String inputDurationType;
  final bool inputRest;

  @override
  State<PianoScoreView> createState() => PianoScoreViewState();
}

class PianoScoreViewState extends State<PianoScoreView> {
  static const _codec = MusicXmlCodec();
  static const _theme = nm.MusicScoreTheme(
    staffLineColor: AppColors.ink,
    noteheadColor: AppColors.ink,
    stemColor: AppColors.ink,
    clefColor: AppColors.ink,
    barlineColor: AppColors.ink,
    timeSignatureColor: AppColors.ink,
    keySignatureColor: AppColors.ink,
    restColor: AppColors.ink,
    articulationColor: AppColors.ink,
    showMeasureNumbers: true,
  );

  final _transform = TransformationController();
  final _audio = const nm.MethodChannelMidiNativeAudioBackend();
  late final _bridge = nm.MidiNativeSequenceBridge(_audio);

  NativeScoreLayout? _layout;
  nm.Score? _engraved;
  nm.SmuflMetadata? _smufl;
  nm.GrandStaffPainter? _painter;
  String? _parseError;
  Offset? _ghostCenter;
  int? _ghostMidi;
  bool _ghostRest = false;
  int? _measureDragFrom;
  int? _measureDragTo;
  Timer? _playbackTimer;
  DateTime? _playbackAnchor;
  double _playbackAnchorMs = 0;
  bool _audioReady = false;
  double? _viewportWidth;

  static const _pagePad = 16.0;
  static const _staffSpace = 10.0;

  @override
  void initState() {
    super.initState();
    widget.playback.attach(
      playPause: _playPause,
      stop: _stop,
      seek: _seek,
    );
    _smufl = nm.SmuflMetadata();
    unawaited(
      _smufl!.load().then((_) {
        if (!mounted) return;
        _refreshPainter();
        setState(() {});
      }),
    );
    _rebuildScore();
    unawaited(_ensureAudio());
  }

  @override
  void didUpdateWidget(covariant PianoScoreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.score, widget.score) ||
        oldWidget.score.noteCount != widget.score.noteCount ||
        oldWidget.score.measureCount != widget.score.measureCount ||
        oldWidget.score.tempoBpm != widget.score.tempoBpm) {
      final wasPlaying = widget.playback.state.playing;
      if (wasPlaying) {
        unawaited(_stop());
      }
      _rebuildScore();
    }
    if (oldWidget.playbackVisible != widget.playbackVisible &&
        !widget.playbackVisible) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    widget.playback.detach();
    _transform.dispose();
    unawaited(_audio.stop());
    unawaited(_audio.dispose());
    super.dispose();
  }

  Future<void> startMeasureDrag(int measureIndex) async {
    setState(() {
      _measureDragFrom = measureIndex;
      _measureDragTo = measureIndex;
    });
  }

  Future<void> cancelMeasureDrag() async {
    setState(() {
      _measureDragFrom = null;
      _measureDragTo = null;
    });
  }

  Future<void> _ensureAudio() async {
    try {
      final ok = await _audio.initialize(primarySoundFontPath: '');
      if (!mounted) return;
      _audioReady = ok;
      if (!ok) {
        widget.onPlayerIssue?.call();
      }
    } catch (_) {
      if (!mounted) return;
      _audioReady = false;
      widget.onPlayerIssue?.call();
    }
  }

  void _rebuildScore() {
    final layout = layoutNativeScore(widget.score);
    _layout = layout;
    try {
      final xml = utf8.decode(_codec.encodeMusicXml(widget.score));
      _engraved = nm.MusicXMLParser.scoreFromMusicXML(xml);
      _parseError = null;
    } catch (_) {
      _engraved = null;
      _parseError = '악보를 표시할 수 없습니다.';
    }
    _refreshPainter();

    final systems = <ScoreSystemSpan>[
      for (var i = 0; i < layout.systemStarts.length; i++)
        ScoreSystemSpan(
          startMeasureIndex: layout.systemStarts[i],
          endMeasureIndex: i + 1 < layout.systemStarts.length
              ? layout.systemStarts[i + 1] - 1
              : math.max(0, widget.score.measureCount - 1),
        ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSystemsChanged?.call(systems);
    });

    final duration = estimateScoreDurationMs(widget.score);
    widget.playback.replaceState(
      widget.playback.state.copyWith(
        ready: true,
        loaded: true,
        durationMs: duration,
        playing: false,
        currentTimeMs: 0,
        measureNumber: 1,
        beatIndex: 0,
      ),
    );
  }

  void _refreshPainter({double? viewportWidth}) {
    if (viewportWidth != null && viewportWidth > 0) {
      _viewportWidth = viewportWidth;
    }
    final engraved = _engraved;
    final metadata = _smufl;
    if (engraved == null || metadata == null || _parseError != null) {
      _painter = null;
      return;
    }
    // A4 폭으로 조판한다. 화면 폭에 맞추지 않는다.
    final innerWidth = scorePageWidthPx - _pagePad * 2;
    _painter = nm.GrandStaffPainter(
      groups: engraved.staffGroups,
      staffSpace: _staffSpace,
      metadata: metadata,
      theme: _theme,
      availableWidth: innerWidth,
      staffGap: _staffSpace * 12,
    );
  }

  void _fitToViewport(double viewW) {
    if (viewW <= 0) return;
    final scale = viewW / scorePageWidthPx;
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  Future<bool> _playPause() async {
    if (!widget.playbackVisible) {
      widget.onPlayerIssue?.call();
      return false;
    }
    if (!_audioReady) {
      await _ensureAudio();
      if (!_audioReady) {
        widget.onPlayerIssue?.call();
        return false;
      }
    }

    final playing = widget.playback.state.playing;
    if (playing) {
      await _audio.stop();
      _playbackTimer?.cancel();
      _playbackTimer = null;
      widget.playback.replaceState(
        widget.playback.state.copyWith(playing: false),
      );
      return true;
    }

    final engraved = _engraved;
    if (engraved == null) {
      widget.onPlayerIssue?.call();
      return false;
    }

    try {
      final sequence = nm.MidiMapper.fromScore(
        engraved,
        options: nm.MidiGenerationOptions(
          defaultBpm: (widget.score.tempoBpm ?? 120).round(),
          includeMetronome: false,
        ),
      );
      await _bridge.uploadAndStart(sequence, includeMetronome: false);
    } catch (_) {
      widget.onPlayerIssue?.call();
      return false;
    }

    _playbackAnchor = DateTime.now();
    _playbackAnchorMs = widget.playback.state.currentTimeMs;
    widget.playback.replaceState(widget.playback.state.copyWith(playing: true));
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _playbackAnchor == null) return;
      final elapsed =
          _playbackAnchorMs +
          DateTime.now().difference(_playbackAnchor!).inMilliseconds;
      final duration = widget.playback.state.durationMs;
      if (elapsed >= duration) {
        unawaited(_stop());
        return;
      }
      final measure = _measureForTime(elapsed);
      widget.playback.replaceState(
        widget.playback.state.copyWith(
          currentTimeMs: elapsed.toDouble(),
          measureNumber: measure + 1,
          beatIndex: 0,
        ),
      );
      setState(() {});
    });
    return true;
  }

  Future<bool> _stop() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackAnchor = null;
    try {
      await _audio.stop();
      await _audio.clearScheduledEvents();
    } catch (_) {}
    widget.playback.replaceState(
      widget.playback.state.copyWith(
        playing: false,
        currentTimeMs: 0,
        measureNumber: 1,
        beatIndex: 0,
      ),
    );
    if (mounted) setState(() {});
    return true;
  }

  Future<bool> _seek(double positionMs) async {
    final wasPlaying = widget.playback.state.playing;
    if (wasPlaying) {
      await _stop();
    }
    final duration = widget.playback.state.durationMs;
    final clamped = positionMs.clamp(0, duration).toDouble();
    widget.playback.replaceState(
      widget.playback.state.copyWith(
        currentTimeMs: clamped,
        measureNumber: _measureForTime(clamped) + 1,
      ),
    );
    if (mounted) setState(() {});
    if (wasPlaying) {
      return _playPause();
    }
    return true;
  }

  int _measureForTime(num ms) {
    final total = math.max(1, widget.score.measureCount);
    final duration = math.max(1.0, widget.playback.state.durationMs);
    return ((ms / duration) * total).floor().clamp(0, total - 1);
  }

  void _clearGhost() {
    if (_ghostCenter == null && _ghostMidi == null) return;
    setState(() {
      _ghostCenter = null;
      _ghostMidi = null;
    });
  }

  void _updateInputAt(Offset content) {
    final layout = _layout;
    if (layout == null) return;
    if (_measureDragFrom != null) {
      final measure = layout.measureAt(content);
      if (measure != null) {
        setState(() => _measureDragTo = measure.measureIndex);
      }
      return;
    }
    if (widget.inputMode == 'select') {
      return;
    }
    if (widget.inputMode != 'note' && widget.inputMode != 'rest') {
      _clearGhost();
      return;
    }
    final hit = layout.hitStaff(
      content,
      durationType: widget.inputDurationType,
      score: widget.score,
    );
    if (hit == null) return;
    setState(() {
      _ghostCenter = hit.ghostCenter;
      _ghostMidi = hit.midi;
      _ghostRest = widget.inputRest || widget.inputMode == 'rest';
    });
  }

  void _commitInputAt(Offset content) {
    final layout = _layout;
    if (layout == null) return;

    if (_measureDragFrom != null) {
      final from = _measureDragFrom!;
      final to = _measureDragTo ?? from;
      setState(() {
        _measureDragFrom = null;
        _measureDragTo = null;
      });
      if (from != to) widget.onMeasureMoved?.call(from, to);
      return;
    }

    if (widget.inputMode == 'select' || widget.inputMode == 'off') {
      final note = layout.noteAt(content);
      if (note != null && !note.isRest && note.midi != null) {
        widget.onNoteTapped?.call(
          AlphaTabNoteTappedEvent(
            partIndex: note.partIndex,
            measureIndex: note.measureIndex,
            staff: note.staff,
            voiceIndex: note.staff - 1,
            onsetTicks:
                (note.onset *
                        alphaTabQuarterTicks /
                        widget.score.parts.first.measures[note.measureIndex]
                            .attributes
                            .divisions)
                    .round(),
            midi: note.midi!,
            noteIndex: note.eventIndex,
          ),
        );
        widget.onMeasureTapped?.call(note.measureIndex);
        return;
      }
      final measure = layout.measureAt(content);
      if (measure != null) widget.onMeasureTapped?.call(measure.measureIndex);
      return;
    }

    final hit = layout.hitStaff(
      content,
      durationType: widget.inputDurationType,
      score: widget.score,
    );
    _clearGhost();
    if (hit == null) return;
    widget.onStaffTapped?.call(
      AlphaTabStaffTappedEvent(
        partIndex: hit.partIndex,
        measureIndex: hit.measureIndex,
        staff: hit.staff,
        onsetTicks: hit.onsetTicks,
        midi: hit.midi,
      ),
    );
    widget.onMeasureTapped?.call(hit.measureIndex);
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout ?? layoutNativeScore(widget.score);
    final engraved = _engraved;
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: ColoredBox(
        // 종이 밖은 회색. 흰 A4만 종이로 보인다.
        color: AppColors.surfaceSoft,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewW = constraints.maxWidth;
            if (viewW > 0 &&
                (_viewportWidth == null ||
                    (viewW - _viewportWidth!).abs() > 0.5)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _refreshPainter(viewportWidth: viewW);
                _fitToViewport(viewW);
                setState(() {});
              });
            }

            final painter = _painter;
            const paperW = scorePageWidthPx;
            const pageH = scorePageHeightPx;
            const pageGap = scorePageGapPx;
            final pages = painter == null
                ? const <List<int>>[
                    <int>[],
                  ]
                : paginateSystemsOntoA4Pages(painter);
            final pageCount = math.max(1, pages.length);
            final docH = pageCount * pageH + (pageCount - 1) * pageGap;

            return Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(48),
                  clipBehavior: Clip.hardEdge,
                  minScale: 0.35,
                  maxScale: 4,
                  panEnabled:
                      widget.oneFingerPan ||
                      widget.inputMode == 'off' ||
                      widget.inputMode == 'select',
                  scaleEnabled: true,
                  onInteractionEnd: (_) => setState(() {}),
                  child: SizedBox(
                    width: paperW,
                    height: docH,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        if (widget.inputMode == 'note' ||
                            widget.inputMode == 'rest' ||
                            _measureDragFrom != null) {
                          _updateInputAt(event.localPosition);
                        }
                      },
                      onPointerMove: (event) {
                        if (widget.inputMode == 'note' ||
                            widget.inputMode == 'rest' ||
                            _measureDragFrom != null) {
                          _updateInputAt(event.localPosition);
                        }
                      },
                      onPointerUp: (event) {
                        _commitInputAt(event.localPosition);
                      },
                      onPointerCancel: (_) => _clearGhost(),
                      child: CustomPaint(
                        painter: _A4ScoreDocumentPainter(
                          inner: painter,
                          pages: pages,
                          pagePad: _pagePad,
                          parseError: engraved == null
                              ? (_parseError ?? '악보 없음')
                              : _parseError,
                          loading: engraved != null && painter == null,
                        ),
                        size: Size(paperW, docH),
                        child: CustomPaint(
                          painter: _OverlayPainter(
                            layout: layout,
                            highlightedMeasureIndex:
                                widget.highlightedMeasureIndex,
                            playbackMeasure:
                                widget.playbackVisible &&
                                    widget.playback.state.playing
                                ? widget.playback.state.measureNumber - 1
                                : null,
                            ghostCenter: _ghostCenter,
                            ghostRest: _ghostRest,
                            measureDragTo: _measureDragTo,
                          ),
                          size: Size(paperW, docH),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Material(
                    color: AppColors.canvas.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.l10n.zoomIn,
                          onPressed: () => _zoomBy(1.35, constraints),
                          icon: const Icon(Icons.add_rounded),
                        ),
                        IconButton(
                          tooltip: context.l10n.zoomOut,
                          onPressed: () => _zoomBy(1 / 1.35, constraints),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        IconButton(
                          tooltip: context.l10n.layoutFit,
                          onPressed: () {
                            _fitToViewport(constraints.maxWidth);
                            setState(() {});
                          },
                          icon: const Icon(Icons.fit_screen_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _zoomBy(double factor, BoxConstraints constraints) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.5, 4.0);
    final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    final scene = MatrixUtils.transformPoint(
      Matrix4.tryInvert(_transform.value) ?? Matrix4.identity(),
      center,
    );
    _transform.value = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(next, next, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
    setState(() {});
  }
}

/// 시스템을 A4 종이 높이에 맞게 넘긴다. 한 시스템이 페이지 경계에서 잘리지 않는다.
@visibleForTesting
List<List<int>> paginateSystemsOntoA4Pages(
  nm.GrandStaffPainter painter, {
  double pagePad = 16,
}) {
  final n = painter.systemCount;
  if (n <= 0) return const [<int>[]];

  final usable = scorePageHeightPx - pagePad * 2;
  final block = painter.systemBlockHeight;
  final topInset = painter.contentTopInset;
  final bottomInset =
      math.max(0.0, painter.totalHeight - n * block - topInset);
  // 마지막 줄 아래 음표·줄기 여유. 꽉 채우면 오선 하단이 잘린다.
  final safety = block * 0.75;
  final pages = <List<int>>[];
  var current = <int>[];
  var used = 0.0;

  for (var sys = 0; sys < n; sys++) {
    final head = current.isEmpty ? topInset : 0.0;
    final need = head + block;
    if (current.isNotEmpty && used + need + bottomInset + safety > usable) {
      pages.add(current);
      current = <int>[];
      used = 0;
    }
    final headNow = current.isEmpty ? topInset : 0.0;
    current.add(sys);
    used += headNow + block;
  }
  if (current.isNotEmpty) pages.add(current);
  return pages;
}

double _systemBarAbsoluteRight(nm.GrandStaffPainter painter, int systemIndex) {
  var maxBar = 0.0;
  var maxAny = 0.0;
  // ignore: invalid_use_of_visible_for_testing_member
  for (final staff in painter.alignedSystem(systemIndex)) {
    for (final pe in staff) {
      final x = pe.position.dx;
      if (x > maxAny) maxAny = x;
      if (pe.element is nm.Barline && x > maxBar) maxBar = x;
    }
  }
  // 오선·마디선 끝만 본다. 슬러 오버행은 빼서 짧은 줄이 늘어나게 한다.
  final local = maxBar > 0
      ? maxBar + painter.staffSpace * 0.8
      : maxAny + painter.staffSpace * 0.5;
  final bracePad = painter.staffSpace * 2.2;
  return bracePad + math.max(local, painter.staffSpace * 4);
}

/// A4 흰 종이에 시스템을 배치한다.
/// - 세로: 페이지마다 시스템 밴드를 통째로 옮김 (중간 절단 없음)
/// - 가로: 줄마다 A4 안쪽 폭에 맞춤
class _A4ScoreDocumentPainter extends CustomPainter {
  _A4ScoreDocumentPainter({
    required this.inner,
    required this.pages,
    required this.pagePad,
    required this.parseError,
    required this.loading,
  });

  final nm.GrandStaffPainter? inner;
  final List<List<int>> pages;
  final double pagePad;
  final String? parseError;
  final bool loading;

  @override
  void paint(Canvas canvas, Size size) {
    final pageCount = math.max(1, pages.length);
    final paperPaint = Paint()..color = AppColors.canvas;
    for (var i = 0; i < pageCount; i++) {
      final top = i * (scorePageHeightPx + scorePageGapPx);
      canvas.drawRect(
        Rect.fromLTWH(0, top, scorePageWidthPx, scorePageHeightPx),
        paperPaint,
      );
    }

    if (parseError != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: parseError,
          style: const TextStyle(color: AppColors.ink, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: scorePageWidthPx - pagePad * 2);
      tp.paint(canvas, Offset(pagePad, pagePad + 24));
      return;
    }
    if (loading || inner == null) return;

    final painter = inner!;
    final innerW = scorePageWidthPx - pagePad * 2;
    final block = painter.systemBlockHeight;
    final topInset = painter.contentTopInset;
    final n = painter.systemCount;
    final bottomInset = math.max(
      0.0,
      painter.totalHeight - n * block - topInset,
    );

    final recorder = ui.PictureRecorder();
    final layer = Canvas(recorder);
    painter.paint(
      layer,
      Size(math.max(innerW, painter.contentWidth), painter.totalHeight),
    );
    final picture = recorder.endRecording();

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final systems = pages[pageIndex];
      if (systems.isEmpty) continue;
      final pageTop = pageIndex * (scorePageHeightPx + scorePageGapPx);
      final pageRect = Rect.fromLTWH(
        0,
        pageTop,
        scorePageWidthPx,
        scorePageHeightPx,
      );
      // 첫 페이지만 머리 여백. 이후 페이지에 넣으면 이전 줄 하단이 보인다.
      final extraTop = pageIndex == 0 ? topInset : 0.0;

      var destY = pageTop + pagePad + extraTop;
      for (var i = 0; i < systems.length; i++) {
        final sys = systems[i];
        final srcY = topInset + sys * block;
        final absBar = _systemBarAbsoluteRight(painter, sys);
        var scaleX = absBar > 0 ? innerW / absBar : 1.0;
        if (scaleX < 0.35) scaleX = 0.35;
        if (scaleX > 2.75) scaleX = 2.75;

        final isFirst = i == 0;
        final isLastOverall = sys == n - 1;

        // 밴드 위쪽(srcY 미만 = 이전 줄)은 클립 밖.
        final bandTop = isFirst ? pageTop + pagePad : destY;
        var bandH = (isFirst ? extraTop : 0.0) + block;
        if (isLastOverall) bandH += bottomInset;
        final maxBottom = pageTop + scorePageHeightPx - pagePad;
        if (bandTop + bandH > maxBottom) bandH = maxBottom - bandTop;
        if (bandH <= 0) break;

        canvas.save();
        canvas.clipRect(pageRect);
        canvas.clipRect(Rect.fromLTWH(pagePad, bandTop, innerW, bandH));
        canvas.translate(pagePad, destY - srcY);
        canvas.scale(scaleX, 1);
        canvas.drawPicture(picture);
        canvas.restore();

        destY += block;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _A4ScoreDocumentPainter oldDelegate) {
    return oldDelegate.inner != inner ||
        oldDelegate.pages != pages ||
        oldDelegate.parseError != parseError ||
        oldDelegate.loading != loading;
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.layout,
    required this.highlightedMeasureIndex,
    required this.playbackMeasure,
    required this.ghostCenter,
    required this.ghostRest,
    required this.measureDragTo,
  });

  final NativeScoreLayout layout;
  final int? highlightedMeasureIndex;
  final int? playbackMeasure;
  final Offset? ghostCenter;
  final bool ghostRest;
  final int? measureDragTo;

  @override
  void paint(Canvas canvas, Size size) {
    final highlight = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    for (final measure in layout.measures) {
      if (measure.measureIndex == highlightedMeasureIndex ||
          measure.measureIndex == playbackMeasure ||
          measure.measureIndex == measureDragTo) {
        canvas.drawRect(measure.rect, highlight);
      }
    }

    final ghost = ghostCenter;
    if (ghost != null) {
      final paint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;
      if (ghostRest) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: ghost, width: 18, height: 10),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: ghost, width: 14, height: 10),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.highlightedMeasureIndex != highlightedMeasureIndex ||
        oldDelegate.playbackMeasure != playbackMeasure ||
        oldDelegate.ghostCenter != ghostCenter ||
        oldDelegate.ghostRest != ghostRest ||
        oldDelegate.measureDragTo != measureDragTo;
  }
}
