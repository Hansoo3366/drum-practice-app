import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
  Future<bool> Function(int measureIndex)? _playFromMeasure;

  ScorePlaybackState get state => _state;

  void attach({
    required Future<bool> Function() playPause,
    required Future<bool> Function() stop,
    required Future<bool> Function(double positionMs) seek,
    Future<bool> Function(int measureIndex)? playFromMeasure,
  }) {
    _playPause = playPause;
    _stop = stop;
    _seek = seek;
    _playFromMeasure = playFromMeasure;
  }

  void detach() {
    _playPause = null;
    _stop = null;
    _seek = null;
    _playFromMeasure = null;
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

  /// Moves to the start of the written bar [measureIndex]: playing goes on
  /// from there, a paused player waits there. False when the order does not
  /// play that bar.
  Future<bool> playFromMeasure(int measureIndex) async =>
      await _playFromMeasure?.call(measureIndex) ?? false;
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
  NativeScoreLayout? _renderedLayout;
  nm.Score? _engraved;
  nm.SmuflMetadata? _smufl;
  nm.GrandStaffPainter? _painter;
  double _documentWidth = 360;
  double _documentHeight = 600;
  List<ScoreSystemSpan> _renderedSystems = const <ScoreSystemSpan>[];
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
  Size? _lastScreenViewport;
  double _engravingStaffSpace = _baseStaffSpace;

  static const _baseStaffSpace = 10.0;
  static const _minimumScreenStaffSpace = 8.5;
  static const _maximumScreenStaffSpace = 11.0;

  double _staffSpaceForScreen(double viewW) {
    if (!viewW.isFinite || viewW <= 0) {
      return _baseStaffSpace;
    }
    // Screen view is continuous, so staff size is chosen in screen logical
    // pixels instead of being derived from an A4 page scale. This prevents a
    // narrow phone from shrinking every note just to preserve paper ratio.
    final widthScale = (viewW / 600).clamp(0.0, 1.0);
    return (_minimumScreenStaffSpace +
            (_maximumScreenStaffSpace - _minimumScreenStaffSpace) * widthScale)
        .clamp(_minimumScreenStaffSpace, _maximumScreenStaffSpace)
        .toDouble();
  }

  @override
  void initState() {
    super.initState();
    widget.playback.attach(playPause: _playPause, stop: _stop, seek: _seek);
    _smufl = nm.SmuflMetadata();
    unawaited(
      _smufl!.load().then((_) {
        if (!mounted) return;
        _refreshPainter();
        _notifySystemsChanged();
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
    _notifySystemsChanged();

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

  void _refreshPainter({Size? viewportSize}) {
    if (viewportSize != null &&
        viewportSize.width > 0 &&
        viewportSize.height > 0) {
      _lastScreenViewport = viewportSize;
      _engravingStaffSpace = _staffSpaceForScreen(viewportSize.width);
    }
    final lastWidth = _lastScreenViewport?.width;
    final screenWidth = lastWidth != null && lastWidth.isFinite && lastWidth > 0
        ? lastWidth
        : scorePageWidthPx;
    final engraved = _engraved;
    final metadata = _smufl;
    if (engraved == null || metadata == null || _parseError != null) {
      _painter = null;
      _renderedLayout = null;
      _documentWidth = screenWidth;
      _documentHeight = 600;
      _renderedSystems = const <ScoreSystemSpan>[];
      return;
    }
    // The live score is a continuous, screen-width layout. A4 remains an
    // export concern; it must not decide the staff size or page breaks here.
    _painter = nm.GrandStaffPainter(
      groups: engraved.staffGroups,
      staffSpace: _engravingStaffSpace,
      metadata: metadata,
      theme: _theme,
      availableWidth: screenWidth,
      staffGap: _engravingStaffSpace * 12,
    );
    _documentWidth = math.max(screenWidth, _painter!.contentWidth);
    _documentHeight = _painter!.totalHeight;
    _renderedLayout = layoutRenderedScoreForScreen(
      score: widget.score,
      painter: _painter!,
      documentWidth: _documentWidth,
    );
    _renderedSystems = _systemsFromPainter(_painter!);
  }

  void _notifySystemsChanged() {
    final fallback = _layout;
    final systems = _renderedSystems.isNotEmpty
        ? _renderedSystems
        : fallback == null
        ? const <ScoreSystemSpan>[]
        : [
            for (var i = 0; i < fallback.systemStarts.length; i++)
              ScoreSystemSpan(
                startMeasureIndex: fallback.systemStarts[i],
                endMeasureIndex: i + 1 < fallback.systemStarts.length
                    ? fallback.systemStarts[i + 1] - 1
                    : math.max(0, widget.score.measureCount - 1),
              ),
          ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSystemsChanged?.call(systems);
    });
  }

  void _resetToViewport() {
    // The continuous screen layout is already fitted to the viewport width.
    // Reset means returning to 1x, not scaling an A4 document into the screen.
    _transform.value = Matrix4.identity();
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
    final layout = _renderedLayout ?? _layout;
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
    final layout = _renderedLayout ?? _layout;
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
                        widget
                            .score
                            .parts
                            .first
                            .measures[note.measureIndex]
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
    final layout =
        _renderedLayout ?? _layout ?? layoutNativeScore(widget.score);
    final engraved = _engraved;
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: ColoredBox(
        color: AppColors.canvas,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 360.0;
            final viewH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 600.0;

            final painter = _painter;
            final docW = painter == null
                ? viewW
                : math.max(viewW, _documentWidth).toDouble();
            final docH = painter == null
                ? math.max(viewH, 240).toDouble()
                : _documentHeight;

            final viewport = Size(viewW, viewH);
            final shouldRefresh =
                viewW > 0 &&
                viewH > 0 &&
                (_lastScreenViewport == null ||
                    (viewport.width - _lastScreenViewport!.width).abs() > 0.5);
            if (shouldRefresh) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _refreshPainter(viewportSize: viewport);
                _resetToViewport();
                setState(() {});
              });
            }

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
                    width: docW,
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
                        painter: _ContinuousScoreDocumentPainter(
                          inner: painter,
                          parseError: engraved == null
                              ? (_parseError ?? '악보 없음')
                              : _parseError,
                          loading: engraved != null && painter == null,
                        ),
                        size: Size(docW, docH),
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
                          size: Size(docW, docH),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    left: false,
                    top: false,
                    minimum: const EdgeInsets.only(right: 8, bottom: 8),
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
                              _resetToViewport();
                              setState(() {});
                            },
                            icon: const Icon(Icons.fit_screen_rounded),
                          ),
                        ],
                      ),
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

/// A4 조판(document)을 **균일 배율**로 뷰포트 너비에 맞춘다. 세로는 레터박스(중앙).
@visibleForTesting
Matrix4 a4FitWidthLetterboxTransform({
  required double viewW,
  required double viewH,
  required double docH,
  double pageW = scorePageWidthPx,
}) {
  if (viewW <= 0 || pageW <= 0 || docH <= 0) {
    return Matrix4.identity();
  }
  final scale = viewW / pageW;
  final scaledH = docH * scale;
  final dy = scaledH < viewH ? (viewH - scaledH) / 2 : 0.0;
  return Matrix4.identity()
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(0, dy / scale, 0, 1);
}

/// 시스템을 A4 종이 높이에 맞게 넘긴다. 한 시스템이 페이지 경계에서 잘리지 않는다.
@visibleForTesting
List<List<int>> paginateSystemsOntoA4Pages(
  nm.GrandStaffPainter painter, {
  double pagePad = 16,
  List<double> systemScales = const <double>[],
}) {
  final n = painter.systemCount;
  if (n <= 0) return const [<int>[]];

  final usable = scorePageHeightPx - pagePad * 2;
  final block = painter.systemBlockHeight;
  final topInset = painter.contentTopInset;
  final bottomInset = math.max(0.0, painter.totalHeight - n * block - topInset);
  final pages = <List<int>>[];
  var current = <int>[];
  var used = 0.0;

  double scaleFor(int systemIndex) {
    if (systemIndex < 0 || systemIndex >= systemScales.length) return 1.0;
    return systemScales[systemIndex].clamp(0.05, 1.0).toDouble();
  }

  for (var sys = 0; sys < n; sys++) {
    final head = current.isEmpty ? topInset : 0.0;
    final scale = scaleFor(sys);
    final need = head + block * scale;
    // Bottom inset belongs only after the final system. Reserving it below
    // every intermediate page wastes a full system on narrow screens and is
    // especially visible once a readable minimum staff size is applied.
    final tail = sys == n - 1 ? bottomInset * scale : 0.0;
    if (current.isNotEmpty && used + need + tail > usable) {
      pages.add(current);
      current = <int>[];
      used = 0;
    }
    final headNow = current.isEmpty ? topInset : 0.0;
    current.add(sys);
    used += headNow + block * scale;
  }
  if (current.isNotEmpty) pages.add(current);
  return pages;
}

/// Fits each rendered system into the A4 content column without distorting
/// its horizontal proportions. Notemus aligns simultaneous onsets across a
/// grand staff after it chooses line breaks, so a dense piano system can be
/// wider than the original A4 estimate even when its individual bars fit.
/// Scaling the complete system (x and y together) keeps noteheads, stems and
/// staff spacing proportional; a horizontal-only scale would make the music
/// look stretched.
@visibleForTesting
List<double> a4SystemScales(
  nm.GrandStaffPainter painter, {
  double pagePad = 16,
}) {
  final targetWidth = scorePageWidthPx - pagePad * 2;
  final bracePad = painter.staffSpace * 2.2;
  // PositionedElement exposes the origin, not the full painted ink extent.
  // Leave enough room for flags, beams, slurs and the final barline.
  final inkSafety = painter.staffSpace * 8;
  final scales = <double>[];

  for (var systemIndex = 0; systemIndex < painter.systemCount; systemIndex++) {
    // ignore: invalid_use_of_visible_for_testing_member
    final aligned = painter.alignedSystem(systemIndex);
    final maxPositionX = aligned
        .expand((staff) => staff)
        .map((positioned) => positioned.position.dx)
        .fold<double>(0, (max, x) => x > max ? x : max);
    final paintedWidth = bracePad + maxPositionX + inkSafety;
    scales.add(
      (targetWidth / math.max(1.0, paintedWidth)).clamp(0.05, 1.0).toDouble(),
    );
  }
  return scales;
}

double _a4DocumentHeight(List<List<int>> pages) {
  final pageCount = math.max(1, pages.length);
  return pageCount * scorePageHeightPx + (pageCount - 1) * scorePageGapPx;
}

List<ScoreSystemSpan> _systemsFromPainter(nm.GrandStaffPainter painter) {
  final systems = <ScoreSystemSpan>[];
  var absoluteMeasureStart = 0;
  for (var systemIndex = 0; systemIndex < painter.systemCount; systemIndex++) {
    final localMeasureIndices = <int>{};
    // ignore: invalid_use_of_visible_for_testing_member
    for (final staff in painter.alignedSystem(systemIndex)) {
      for (final positioned in staff) {
        if (positioned.measureIndex >= 0) {
          localMeasureIndices.add(positioned.measureIndex);
        }
      }
    }
    if (localMeasureIndices.isEmpty) continue;
    final ordered = localMeasureIndices.toList()..sort();
    systems.add(
      ScoreSystemSpan(
        startMeasureIndex: absoluteMeasureStart,
        endMeasureIndex: absoluteMeasureStart + ordered.length - 1,
      ),
    );
    absoluteMeasureStart += ordered.length;
  }
  return systems;
}

Map<(int, int), Offset> _renderedNoteCenters({
  required List<List<nm.PositionedElement>> aligned,
  required MusicPart part,
  required Map<int, int> absoluteMeasureByLocal,
  required int absoluteMeasureStart,
  required nm.GrandStaffPainter painter,
  required double pagePad,
  required double bracePad,
  required double systemTop,
  required double systemScale,
}) {
  final centers = <(int, int), Offset>{};
  final used = <(int, int)>{};
  for (var staffIndex = 0; staffIndex < aligned.length; staffIndex++) {
    for (final positioned in aligned[staffIndex]) {
      final element = positioned.element;
      if (element is! nm.Note) continue;

      final measureIndex = absoluteMeasureByLocal[positioned.measureIndex];
      if (measureIndex == null || measureIndex >= part.measures.length) {
        continue;
      }
      final measure = part.measures[measureIndex];
      final measureOffset = _measureOffsetWhole(
        part,
        start: absoluteMeasureStart,
        count: measureIndex - absoluteMeasureStart,
      );
      final targetOnset = positioned.onset - measureOffset;
      final candidates = <(int, MusicNote)>[];
      for (
        var eventIndex = 0;
        eventIndex < measure.events.length;
        eventIndex++
      ) {
        final event = measure.events[eventIndex];
        if (event is! MusicNote || event.isRest || event.pitch == null) {
          continue;
        }
        if (midiForPitch(event.pitch!) != element.pitch.midiNumber) {
          continue;
        }
        candidates.add((eventIndex, event));
      }
      if (candidates.isEmpty) continue;

      var bestIndex = -1;
      var bestScore = double.infinity;
      for (final candidate in candidates) {
        final key = (measureIndex, candidate.$1);
        if (used.contains(key)) continue;
        final event = candidate.$2;
        final onsetDelta =
            (event.onset / math.max(1, measure.attributes.divisions) -
                    targetOnset)
                .abs();
        final staffPenalty = event.staff == staffIndex + 1 ? 0.0 : 1.0;
        final score = staffPenalty * 1000 + onsetDelta;
        if (score < bestScore) {
          bestScore = score;
          bestIndex = candidate.$1;
        }
      }
      if (bestIndex < 0) continue;

      final key = (measureIndex, bestIndex);
      used.add(key);
      centers[key] = Offset(
        pagePad + systemScale * (bracePad + positioned.position.dx),
        systemTop +
            systemScale *
                (staffIndex * painter.staffGap + positioned.position.dy),
      );
    }
  }
  return centers;
}

double _measureOffsetWhole(
  MusicPart part, {
  required int start,
  required int count,
}) {
  var offset = 0.0;
  for (var index = 0; index < count; index++) {
    final measureIndex = start + index;
    if (measureIndex < 0 || measureIndex >= part.measures.length) break;
    final measure = part.measures[measureIndex];
    final duration = math.max(
      measure.durationDivisions,
      measureCapacity(measure.attributes),
    );
    offset += duration / math.max(1, measure.attributes.divisions);
  }
  return offset;
}

NativeScoreLayout _buildRenderedScoreLayout({
  required MusicScore score,
  required nm.GrandStaffPainter painter,
  required List<List<int>> pages,
  required double pagePad,
  List<double> systemScales = const <double>[],
  double documentWidth = scorePageWidthPx,
  double? documentHeight,
}) {
  final part = score.parts.isEmpty ? null : score.parts.first;
  if (part == null) return layoutNativeScore(score);

  final placementBySystem = <int, ({int pageIndex, int order})>{};
  for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
    final systems = pages[pageIndex];
    for (var order = 0; order < systems.length; order++) {
      placementBySystem[systems[order]] = (pageIndex: pageIndex, order: order);
    }
  }

  final measures = <NativeMeasureBox>[];
  final notes = <NativeNotePlacement>[];
  final systemStarts = <int>[];
  final bracePad = painter.staffSpace * 2.2;
  final baseline = painter.staffSpace * 5;
  final fallbackWidth =
      math.max(80.0, painter.availableWidth - bracePad - painter.staffSpace) /
      math.max(1, nativeMeasuresPerSystem);
  var absoluteMeasureStart = 0;

  double scaleFor(int systemIndex) {
    if (systemIndex < 0 || systemIndex >= systemScales.length) return 1.0;
    return systemScales[systemIndex].clamp(0.05, 1.0).toDouble();
  }

  for (var systemIndex = 0; systemIndex < painter.systemCount; systemIndex++) {
    final placement = placementBySystem[systemIndex];
    if (placement == null) continue;

    // ignore: invalid_use_of_visible_for_testing_member
    final aligned = painter.alignedSystem(systemIndex);
    final localMeasureIndices = <int>{};
    for (final staff in aligned) {
      for (final positioned in staff) {
        if (positioned.measureIndex >= 0) {
          localMeasureIndices.add(positioned.measureIndex);
        }
      }
    }
    if (localMeasureIndices.isEmpty) continue;
    final orderedLocalMeasures = localMeasureIndices.toList()..sort();
    final absoluteMeasureByLocal = <int, int>{
      for (var i = 0; i < orderedLocalMeasures.length; i++)
        orderedLocalMeasures[i]: absoluteMeasureStart + i,
    };
    final orderedMeasures = [
      for (final localIndex in orderedLocalMeasures)
        absoluteMeasureByLocal[localIndex]!,
    ];
    systemStarts.add(orderedMeasures.first);

    final rightByMeasure = <int, double>{};
    final List<nm.PositionedElement> firstStaff = aligned.isEmpty
        ? const <nm.PositionedElement>[]
        : aligned.first;
    for (final positioned in firstStaff) {
      if (positioned.element is! nm.Barline || positioned.measureIndex < 0) {
        continue;
      }
      final measureIndex = absoluteMeasureByLocal[positioned.measureIndex];
      if (measureIndex == null) continue;
      final right = bracePad + positioned.position.dx;
      final previous = rightByMeasure[measureIndex];
      if (previous == null || right > previous) {
        rightByMeasure[measureIndex] = right;
      }
    }
    if (rightByMeasure.isEmpty) {
      for (final staff in aligned) {
        for (final positioned in staff) {
          if (positioned.element is! nm.Barline ||
              positioned.measureIndex < 0) {
            continue;
          }
          final measureIndex = absoluteMeasureByLocal[positioned.measureIndex];
          if (measureIndex == null) continue;
          final right = bracePad + positioned.position.dx;
          final previous = rightByMeasure[measureIndex];
          if (previous == null || right > previous) {
            rightByMeasure[measureIndex] = right;
          }
        }
      }
    }

    final systemTop = _renderedSystemTop(
      painter: painter,
      placement: placement,
      pagePad: pagePad,
      pages: pages,
      systemScales: systemScales,
    );
    final systemScale = scaleFor(systemIndex);
    final staffCount = math.max(1, aligned.length);
    final trebleTop =
        systemTop + systemScale * (baseline - painter.staffSpace * 2);
    final bassTop = staffCount > 1
        ? systemTop +
              systemScale *
                  (painter.staffGap + baseline - painter.staffSpace * 2)
        : trebleTop;
    final bottomStaffTop =
        systemTop +
        systemScale *
            ((staffCount - 1) * painter.staffGap +
                baseline -
                painter.staffSpace * 2);
    final actualNoteCenters = _renderedNoteCenters(
      aligned: aligned,
      part: part,
      absoluteMeasureByLocal: absoluteMeasureByLocal,
      absoluteMeasureStart: absoluteMeasureStart,
      painter: painter,
      pagePad: pagePad,
      bracePad: bracePad,
      systemTop: systemTop,
      systemScale: systemScale,
    );

    var left = bracePad;
    for (var order = 0; order < orderedMeasures.length; order++) {
      final measureIndex = orderedMeasures[order];
      var right = rightByMeasure[measureIndex] ?? left + fallbackWidth;
      if (right <= left + 1) right = left + fallbackWidth;

      final destinationLeft = pagePad + systemScale * left;
      final destinationRight = pagePad + systemScale * right;
      final box = NativeMeasureBox(
        measureIndex: measureIndex,
        rect: Rect.fromLTRB(
          destinationLeft,
          trebleTop - systemScale * 12,
          destinationRight,
          bottomStaffTop + systemScale * (painter.staffSpace * 4 + 12),
        ),
        trebleStaffTop: trebleTop,
        bassStaffTop: bassTop,
        lineGap: systemScale * painter.staffSpace,
        contentLeft: destinationLeft + systemScale * 8,
        contentWidth: math.max(12, systemScale * (right - left - 16)),
      );
      measures.add(box);

      if (measureIndex < part.measures.length) {
        final musicMeasure = part.measures[measureIndex];
        final capacity = math.max(1, measureCapacity(musicMeasure.attributes));
        for (
          var eventIndex = 0;
          eventIndex < musicMeasure.events.length;
          eventIndex++
        ) {
          final event = musicMeasure.events[eventIndex];
          if (event is! MusicNote) continue;
          final staff = event.staff.clamp(1, 2);
          final staffTop = staff >= 2 ? bassTop : trebleTop;
          final x =
              box.contentLeft +
              systemScale * 10 +
              (event.onset / capacity) *
                  math.max(1, box.contentWidth - systemScale * 20);
          final y = event.isRest
              ? staffTop - 2 * box.lineGap
              : staffYForMidi(
                  midiForPitch(event.pitch!),
                  staffTop: staffTop,
                  lineGap: box.lineGap,
                  bass: staff >= 2,
                );
          final center =
              actualNoteCenters[(measureIndex, eventIndex)] ?? Offset(x, y);
          notes.add(
            NativeNotePlacement(
              partIndex: 0,
              measureIndex: measureIndex,
              eventIndex: eventIndex,
              staff: staff,
              onset: event.onset,
              midi: event.isRest ? null : midiForPitch(event.pitch!),
              center: center,
              isRest: event.isRest,
            ),
          );
        }
      }
      left = right;
    }
    absoluteMeasureStart += orderedLocalMeasures.length;
  }

  return NativeScoreLayout(
    contentSize: Size(
      documentWidth,
      documentHeight ?? _a4DocumentHeight(pages),
    ),
    measures: measures,
    notes: notes,
    systemStarts: systemStarts,
  );
}

/// Projects editor hit-testing onto the continuous screen layout. The score
/// keeps the native staff size and simply stacks every rendered system in one
/// vertically scrollable document; no A4 page break or paper scale is used.
@visibleForTesting
NativeScoreLayout layoutRenderedScoreForScreen({
  required MusicScore score,
  required nm.GrandStaffPainter painter,
  double? documentWidth,
}) {
  final systems = [
    [for (var index = 0; index < painter.systemCount; index++) index],
  ];
  return _buildRenderedScoreLayout(
    score: score,
    painter: painter,
    pages: systems,
    pagePad: 0,
    systemScales: List<double>.filled(painter.systemCount, 1.0),
    documentWidth: documentWidth ?? painter.contentWidth,
    documentHeight: painter.totalHeight,
  );
}

/// Projects the editor's hit-test model onto the same A4/page coordinates used
/// by [GrandStaffPainter]. Kept visible for regression tests around page 2 and
/// later, where the old fixed-four-measures layout drifted from the engraving.
@visibleForTesting
NativeScoreLayout layoutRenderedScoreForA4({
  required MusicScore score,
  required nm.GrandStaffPainter painter,
  required List<List<int>> pages,
  double pagePad = 16,
  List<double> systemScales = const <double>[],
}) {
  final scales = systemScales.isEmpty
      ? a4SystemScales(painter, pagePad: pagePad)
      : systemScales;
  return _buildRenderedScoreLayout(
    score: score,
    painter: painter,
    pages: pages,
    pagePad: pagePad,
    systemScales: scales,
  );
}

double _renderedSystemTop({
  required nm.GrandStaffPainter painter,
  required ({int pageIndex, int order}) placement,
  required double pagePad,
  required List<List<int>> pages,
  required List<double> systemScales,
}) {
  final pageTop = placement.pageIndex * (scorePageHeightPx + scorePageGapPx);
  final firstPageInset = placement.pageIndex == 0
      ? painter.contentTopInset
      : 0.0;
  var precedingHeight = 0.0;
  final pageSystems = pages[placement.pageIndex];
  for (var i = 0; i < placement.order; i++) {
    final systemIndex = pageSystems[i];
    final scale = systemIndex < systemScales.length
        ? systemScales[systemIndex].clamp(0.05, 1.0).toDouble()
        : 1.0;
    precedingHeight += painter.systemBlockHeight * scale;
  }
  return pageTop + pagePad + firstPageInset + precedingHeight;
}

/// Paints the live practice view as one continuous score. The underlying
/// Notemus painter owns line wrapping and staff geometry; this wrapper only
/// adds the error state and deliberately avoids paper backgrounds, A4 page
/// breaks, and document-wide scaling.
class _ContinuousScoreDocumentPainter extends CustomPainter {
  _ContinuousScoreDocumentPainter({
    required this.inner,
    required this.parseError,
    required this.loading,
  });

  final nm.GrandStaffPainter? inner;
  final String? parseError;
  final bool loading;

  @override
  void paint(Canvas canvas, Size size) {
    final error = parseError;
    if (error != null) {
      final text = TextPainter(
        text: TextSpan(
          text: error,
          style: const TextStyle(color: AppColors.ink, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(1, size.width - 32));
      text.paint(canvas, const Offset(16, 24));
      return;
    }
    if (loading || inner == null) return;
    _paintSharedGrandStaffLines(canvas, inner!);
    inner!.paint(canvas, size);
  }

  void _paintSharedGrandStaffLines(
    Canvas canvas,
    nm.GrandStaffPainter painter,
  ) {
    final lineThickness =
        painter.metadata.getEngravingDefault('staffLineThickness', 0.13) *
        painter.staffSpace;
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = lineThickness
      ..style = PaintingStyle.stroke;

    // GrandStaffPainter delegates staff-line extents to each StaffRenderer.
    // When the lower staff has fewer visible elements, that renderer ends its
    // lines early. Draw one common system end underneath the package output so
    // both staves share the same barline-aligned span.
    canvas.save();
    canvas.translate(painter.staffSpace * 2.2, painter.contentTopInset);
    final baseline = painter.staffSpace * 5;
    final staffCount = painter.groups.fold<int>(
      0,
      (count, group) => count + group.staves.length,
    );
    for (
      var systemIndex = 0;
      systemIndex < painter.systemCount;
      systemIndex++
    ) {
      // ignore: invalid_use_of_visible_for_testing_member
      final aligned = painter.alignedSystem(systemIndex);
      final endX = grandStaffSystemEndX(
        aligned,
        staffSpace: painter.staffSpace,
      );
      canvas.save();
      canvas.translate(0, systemIndex * painter.systemBlockHeight);
      for (var staffIndex = 0; staffIndex < staffCount; staffIndex++) {
        final staffBaseline = baseline + staffIndex * painter.staffGap;
        for (var line = 1; line <= 5; line++) {
          final y = staffBaseline - (line - 3) * painter.staffSpace;
          canvas.drawLine(Offset.zero.translate(0, y), Offset(endX, y), paint);
        }
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ContinuousScoreDocumentPainter oldDelegate) {
    return oldDelegate.inner != inner ||
        oldDelegate.parseError != parseError ||
        oldDelegate.loading != loading;
  }
}

/// Returns the shared horizontal endpoint for every staff in one grand-staff
/// system. The latest barline wins; if a malformed/imported system has no
/// barline, the furthest positioned element is used as a safe fallback.
@visibleForTesting
double grandStaffSystemEndX(
  List<List<nm.PositionedElement>> aligned, {
  required double staffSpace,
}) {
  var maxPosition = 0.0;
  double? lastBarline;
  for (final staff in aligned) {
    for (final positioned in staff) {
      if (positioned.position.dx > maxPosition) {
        maxPosition = positioned.position.dx;
      }
      if (positioned.element is nm.Barline &&
          (lastBarline == null || positioned.position.dx > lastBarline)) {
        lastBarline = positioned.position.dx;
      }
    }
  }
  return (lastBarline ?? maxPosition) + staffSpace * 1.2;
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
