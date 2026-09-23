import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/native_score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/performance_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:verovio_flutter/verovio_flutter.dart';

/// MusicXML score view backed by Verovio's native engraving engine.
///
/// Verovio owns notation layout and emits SVG. Flutter only owns the viewport,
/// gestures, selection overlays, and the existing playback/editor callbacks.
/// The visible [score] remains the written notation. [playbackScore] can be a
/// derived, expanded score for audio playback without forcing the practice
/// viewport to re-engrave a long repeated performance document.
class VerovioScoreView extends StatefulWidget {
  const VerovioScoreView({
    required this.score,
    this.playbackScore,
    this.playbackSequence = PlaybackSequence.empty,
    this.playbackArrangement = ArrangementProfile.off,
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
    this.inputAlter = 0,
    super.key,
  });

  final MusicScore score;
  final MusicScore? playbackScore;
  final PlaybackSequence playbackSequence;
  final ArrangementProfile playbackArrangement;
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
  final int inputAlter;

  @override
  State<VerovioScoreView> createState() => VerovioScoreViewState();
}

class VerovioScoreViewState extends State<VerovioScoreView> {
  static const _codec = MusicXmlCodec();
  // Flutter's InteractiveViewer uses this same value for mouse-wheel zoom.
  // We keep the value explicit because the score editor follows desktop
  // notation conventions: an ordinary wheel scrolls the document, while a
  // Ctrl/Cmd-modified wheel zooms it.
  static const _mouseScrollScaleFactor = 200.0;
  // Verovio uses 1/100 mm for page dimensions: 2100 x 2970 is A4.
  // Pages are concatenated without a visual gap by _VerovioPages, so the
  // practice screen remains a continuous document while each native render
  // stays bounded. A 60000-unit page made Android render/hit-test a single
  // multi-metre SVG and could leave the screen spinning indefinitely.
  static const _verovioPageWidth = 2100;
  static const _verovioPageHeight = 2970;
  // Cold-starting the native Verovio worker on an Android emulator can take
  // longer than a normal page render. Keep a finite guard, but do not replace
  // a valid score with a timeout screen during a slow first load.
  static const _verovioOperationTimeout = Duration(seconds: 60);
  static const _verovioOptions = <String, Object>{
    'pageWidth': _verovioPageWidth,
    'pageHeight': _verovioPageHeight,
    'pageMarginTop': 70,
    'pageMarginBottom': 70,
    'pageMarginLeft': 80,
    'pageMarginRight': 80,
    'scale': 40,
    'breaks': 'auto',
    'adjustPageHeight': false,
    'svgViewBox': true,
    'svgHtml5': false,
    'header': 'none',
    'footer': 'none',
    'minLastJustification': 0.0,
  };

  final _transform = TransformationController();
  final _audio = const nm.MethodChannelMidiNativeAudioBackend();
  late final _bridge = nm.MidiNativeSequenceBridge(_audio);

  VerovioAsyncService? _service;
  Future<void>? _serviceReady;
  List<_VerovioPage> _pages = const <_VerovioPage>[];
  NativeScoreLayout? _layout;
  nm.Score? _engraved;
  String? _parseError;
  Offset? _ghostCenter;
  bool _ghostRest = false;
  double _ghostLineGap = nativeStaffLineGap;
  String _ghostDurationType = 'quarter';
  int _ghostAlter = 0;
  int? _measureDragFrom;
  int? _measureDragTo;
  Timer? _playbackTimer;
  DateTime? _playbackAnchor;
  double _playbackAnchorMs = 0;
  bool _audioReady = false;
  double _documentWidth = 360;
  double _documentHeight = 600;
  double? _lastViewportWidth;
  int _renderGeneration = 0;
  final Set<int> _activePointers = <int>{};
  bool _multiPointerGesture = false;

  @override
  void initState() {
    super.initState();
    widget.playback.attach(playPause: _playPause, stop: _stop, seek: _seek);
    _rebuildScore();
    if (widget.playbackVisible) unawaited(_ensureAudio());
  }

  @override
  void didUpdateWidget(covariant VerovioScoreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inputMode != widget.inputMode ||
        oldWidget.inputDurationType != widget.inputDurationType ||
        oldWidget.inputAlter != widget.inputAlter) {
      _ghostCenter = null;
      _ghostRest = false;
    }
    final visualScoreChanged =
        !identical(oldWidget.score, widget.score) ||
        oldWidget.score.noteCount != widget.score.noteCount ||
        oldWidget.score.measureCount != widget.score.measureCount ||
        oldWidget.score.tempoBpm != widget.score.tempoBpm;
    final playbackConfigurationChanged =
        !identical(oldWidget.playbackScore, widget.playbackScore) ||
        oldWidget.playbackScore?.noteCount != widget.playbackScore?.noteCount ||
        oldWidget.playbackScore?.measureCount !=
            widget.playbackScore?.measureCount ||
        oldWidget.playbackScore?.tempoBpm != widget.playbackScore?.tempoBpm ||
        oldWidget.playbackSequence != widget.playbackSequence ||
        oldWidget.playbackArrangement != widget.playbackArrangement;
    if (visualScoreChanged) {
      final wasPlaying = widget.playback.state.playing;
      if (wasPlaying) unawaited(_stop());
      _rebuildScore();
    } else if (playbackConfigurationChanged) {
      if (widget.playback.state.playing) unawaited(_stop());
      _resetPlaybackState();
    }
    if (oldWidget.playbackVisible != widget.playbackVisible &&
        !widget.playbackVisible) {
      unawaited(_stop());
    } else if (oldWidget.playbackVisible != widget.playbackVisible &&
        widget.playbackVisible) {
      unawaited(_ensureAudio());
    }
  }

  @override
  void dispose() {
    _renderGeneration++;
    _playbackTimer?.cancel();
    widget.playback.detach();
    _transform.dispose();
    unawaited(_audio.stop());
    unawaited(_audio.dispose());
    final service = _service;
    if (service != null) unawaited(service.dispose());
    super.dispose();
  }

  Future<void> startMeasureDrag(int measureIndex) async {
    if (!mounted) return;
    setState(() {
      _measureDragFrom = measureIndex;
      _measureDragTo = measureIndex;
    });
  }

  Future<void> cancelMeasureDrag() async {
    if (!mounted) return;
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
      if (!ok) widget.onPlayerIssue?.call();
    } catch (_) {
      if (!mounted) return;
      _audioReady = false;
      widget.onPlayerIssue?.call();
    }
  }

  void _rebuildScore() {
    final generation = ++_renderGeneration;
    try {
      // Only the written document is parsed on the UI isolate. A repeated
      // performance document can be much longer than the visible score and
      // parsing it here made Android appear to hang before Verovio started.
      final visualXml = utf8.decode(_codec.encodeMusicXml(widget.score));
      _engraved = nm.MusicXMLParser.scoreFromMusicXML(visualXml);
      _parseError = null;
      _pages = const <_VerovioPage>[];
      _layout = null;
      unawaited(_renderWithVerovio(visualXml, generation));
    } catch (_) {
      _engraved = null;
      _parseError = '악보를 표시할 수 없습니다.';
      _pages = const <_VerovioPage>[];
      _layout = null;
    }

    _resetPlaybackState();
  }

  void _resetPlaybackState() {
    final duration = estimateScoreDurationMs(
      widget.playbackScore ?? widget.score,
    );
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
    if (mounted) setState(() {});
  }

  Future<void> _renderWithVerovio(String xml, int generation) async {
    try {
      final timeout = _verovioOperationTimeout;
      final service = await _getService().timeout(timeout);
      await service
          .setOptionsJson(jsonEncode(_verovioOptions))
          .timeout(timeout);
      await service.loadData(xml).timeout(timeout);
      final pageCount = await service.pageCount.timeout(timeout);
      if (pageCount <= 0) throw StateError('Verovio returned no pages.');

      final pages = <_VerovioPage>[];
      for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        // Verovio's native renderToSvg API is 1-based, while the Flutter
        // hit-map API uses a 0-based page index.  verovio_flutter 0.3.3's
        // combined helper forwards the 0-based value to renderToSvg, which
        // can crash in the native library on the first page.  Keep the two
        // calls explicit until the wrapper fixes that mismatch.
        final svg = await service.renderToSvg(pageIndex + 1).timeout(timeout);
        final hitMap = await service
            .parseHitMap(
              svg,
              pageIndex: pageIndex,
              config: const ParseConfig.defaultForInteractive(),
            )
            .timeout(timeout);
        pages.add(
          _VerovioPage(
            svg: _normalizeVerovioSvgForFlutter(svg),
            hitMap: hitMap,
          ),
        );
        if (!mounted || generation != _renderGeneration) return;
        // Publish each page as soon as it is ready. Large scores can contain
        // many A4 pages; waiting for every page made the entire viewer look
        // stuck even when the first page had already been engraved.
        _pages = List<_VerovioPage>.unmodifiable(pages);
        _parseError = null;
        final width = _lastViewportWidth ?? 360;
        _rebuildRenderedLayout(width);
        _notifySystemsChanged();
        setState(() {});
      }
    } catch (error) {
      if (!mounted || generation != _renderGeneration) return;
      if (_pages.isEmpty) {
        _layout = null;
        _parseError = error is TimeoutException
            ? '악보 렌더링 시간이 초과되었습니다.'
            : error is VerovioException
            ? '악보를 표시할 수 없습니다.'
            : '악보 엔진을 초기화할 수 없습니다.';
      } else {
        // Keep already-rendered pages visible if a later page exceeds the
        // native operation budget. The user can still practice the available
        // portion instead of losing the whole score to an error state.
        _parseError = null;
      }
      setState(() {});
    }
  }

  Future<VerovioAsyncService> _getService() async {
    final existing = _service;
    if (existing != null) return existing;
    final ready = _serviceReady;
    if (ready != null) {
      await ready;
      return _service!;
    }
    final future = () async {
      final resourcePath =
          await VerovioResourceManager.ensureVerovioAssetsReady();
      _service = await VerovioAsyncService.spawn(resourcePath: resourcePath);
    }();
    _serviceReady = future;
    await future;
    return _service!;
  }

  void _rebuildRenderedLayout(double viewWidth) {
    if (viewWidth <= 0 || _pages.isEmpty) return;
    _lastViewportWidth = viewWidth;
    final measures = <NativeMeasureBox>[];
    final notes = <NativeNotePlacement>[];
    final systemStarts = <int>[];
    final part = widget.score.parts.isEmpty ? null : widget.score.parts.first;
    var pageTop = 0.0;
    var measureIndex = 0;

    for (final page in _pages) {
      final viewBox = page.hitMap.viewBox;
      if (viewBox.width <= 0 || viewBox.height <= 0) continue;
      final scale = viewWidth / viewBox.width;
      final pageHeight = viewBox.height * scale;
      final measureHits =
          page.hitMap.byType.where((hit) => hit.type == 'measure').toList()
            ..sort(_compareMeasurePosition);
      final pageMeasures = <_MeasureGeometry>[];
      final pageMeasureSlots = <int, int>{};
      final pageMeasureSystems = <int, int>{};
      final systemTops = <double>[];

      for (final hit in measureHits) {
        final rect = _scaledRect(hit.bbox, scale, pageTop);
        final rowTolerance = math.max(12.0, math.min(36.0, rect.height * 0.2));
        var system = -1;
        for (var index = 0; index < systemTops.length; index++) {
          if ((systemTops[index] - rect.top).abs() <= rowTolerance) {
            system = index;
            systemTops[index] = (systemTops[index] * 3 + rect.top) / 4;
            break;
          }
        }
        if (system < 0) {
          system = systemTops.length;
          systemTops.add(rect.top);
        }
        pageMeasureSystems[measureIndex] = system;
        final staffCount = measureIndex < (part?.measures.length ?? 0)
            ? part!.measures[measureIndex].attributes.staves
            : 2;
        final height = math.max(36.0, rect.height);
        final lineGap = math.max(3.0, height * (staffCount > 1 ? 0.045 : 0.09));
        final trebleTop = rect.top + height * (staffCount > 1 ? 0.19 : 0.28);
        final bassTop = staffCount > 1 ? rect.top + height * 0.65 : trebleTop;
        final box = NativeMeasureBox(
          measureIndex: measureIndex,
          rect: rect.inflate(2),
          trebleStaffTop: trebleTop,
          bassStaffTop: bassTop,
          lineGap: lineGap,
          contentLeft: rect.left + math.min(12, rect.width * 0.08),
          contentWidth: math.max(12, rect.width * 0.84),
        );
        pageMeasureSlots[measureIndex] = measures.length;
        measures.add(box);
        pageMeasures.add(
          _MeasureGeometry(measureIndex: measureIndex, element: hit, box: box),
        );
        systemStarts.add(measureIndex);
        measureIndex++;
      }

      if (part != null) {
        final notesByMeasure = <int, List<ElementHit>>{};
        final systemStaffGeometry = <int, Map<int, _StaffGeometry>>{};
        for (final hit in page.hitMap.byType) {
          if (hit.type != 'note' && hit.type != 'rest') continue;
          final geometry = _measureForHit(hit, pageMeasures);
          if (geometry == null) continue;
          notesByMeasure.putIfAbsent(geometry.measureIndex, () => []).add(hit);
        }
        for (final entry in notesByMeasure.entries) {
          final absoluteIndex = entry.key;
          if (absoluteIndex < 0 || absoluteIndex >= part.measures.length) {
            continue;
          }
          final musicMeasure = part.measures[absoluteIndex];
          final sourceNotes = <(int, MusicNote)>[
            for (var index = 0; index < musicMeasure.events.length; index++)
              if (musicMeasure.events[index] case final MusicNote note)
                (index, note),
          ];
          // Rest elements have their own hit boxes and do not carry a pitch.
          // Never use a rest box to fit the staff geometry for pitched notes:
          // a rest can be vertically far from the staff line that a touch is
          // meant to address, especially in a two-voice piano measure.
          final pitchedSourceNotes = sourceNotes
              .where((source) => !source.$2.isRest && source.$2.pitch != null)
              .toList(growable: false);
          final noteHits = entry.value
              .where((hit) => hit.type == 'note')
              .toList(growable: false);
          final matches = _matchRenderedNotes(
            hits: noteHits,
            sourceNotes: pitchedSourceNotes,
            partIndex: 0,
            measureIndex: absoluteIndex,
          );
          final anchorXs = <int, List<double>>{};
          final staffPoints = <int, List<_StaffMetricPoint>>{};
          for (final match in matches) {
            final note = match.note;
            final center = _scaledPoint(match.hit.bbox.center, scale, pageTop);
            anchorXs.putIfAbsent(note.onset, () => []).add(center.dx);
            if (!note.isRest) {
              staffPoints
                  .putIfAbsent(note.staff.clamp(1, 2), () => [])
                  .add(
                    _StaffMetricPoint(
                      steps: _diatonicStepsForPitch(note.pitch!),
                      y: center.dy,
                    ),
                  );
            }
            notes.add(
              NativeNotePlacement(
                partIndex: 0,
                measureIndex: absoluteIndex,
                eventIndex: match.eventIndex,
                staff: note.staff.clamp(1, 2),
                onset: note.onset,
                midi: note.isRest ? null : midiForPitch(note.pitch!),
                center: center,
                isRest: note.isRest || match.hit.type == 'rest',
              ),
            );
          }

          final geometry = _measureForHit(entry.value.first, pageMeasures);
          final slot = pageMeasureSlots[absoluteIndex];
          if (geometry != null && slot != null) {
            final box = geometry.box;
            final staffCount = math.max(1, musicMeasure.attributes.staves);
            final staffTops = <int, double>{};
            final staffLineGaps = <int, double>{};
            final system = pageMeasureSystems[absoluteIndex] ?? 0;
            var fittedByStaff = systemStaffGeometry[system];
            if (fittedByStaff == null) {
              fittedByStaff = <int, _StaffGeometry>{};
              for (var staff = 1; staff <= math.min(2, staffCount); staff++) {
                final fallbackTop = staff >= 2
                    ? box.bassStaffTop
                    : box.trebleStaffTop;
                final fallbackGap = box.lineGap;
                fittedByStaff[staff] = _fitStaffGeometry(
                  staffPoints[staff] ?? const <_StaffMetricPoint>[],
                  fallbackTop: fallbackTop,
                  fallbackGap: fallbackGap,
                  bass: staff >= 2,
                );
              }
              // A grand staff uses one engraving scale for both staves. A
              // sparse bass voice can otherwise make its fitted slope noisy,
              // which makes the input pitch grid jump inside one system.
              if (fittedByStaff.length > 1) {
                final sharedGap = fittedByStaff[1]!.lineGap;
                fittedByStaff = {
                  for (final entry in fittedByStaff.entries)
                    entry.key: _StaffGeometry(
                      top: entry.value.top,
                      lineGap: sharedGap,
                    ),
                };
              }
              systemStaffGeometry[system] = fittedByStaff;
            }
            for (var staff = 1; staff <= math.min(2, staffCount); staff++) {
              final fitted = fittedByStaff[staff]!;
              staffTops[staff] = fitted.top;
              staffLineGaps[staff] = fitted.lineGap;
            }
            final capacity = math.max(
              1,
              measureCapacity(musicMeasure.attributes),
            );
            final anchorXsWithBoundaries = <int, List<double>>{
              0: [box.contentLeft],
              capacity: [box.contentLeft + box.contentWidth],
            };
            for (final entry in anchorXs.entries) {
              anchorXsWithBoundaries
                  .putIfAbsent(entry.key, () => [])
                  .addAll(entry.value);
            }
            final anchors = [
              for (final entry in anchorXsWithBoundaries.entries)
                NativeOnsetAnchor(
                  onset: entry.key,
                  x: entry.value.reduce((a, b) => a + b) / entry.value.length,
                ),
            ]..sort((a, b) => a.onset.compareTo(b.onset));
            measures[slot] = NativeMeasureBox(
              measureIndex: box.measureIndex,
              rect: box.rect,
              trebleStaffTop: box.trebleStaffTop,
              bassStaffTop: box.bassStaffTop,
              lineGap: box.lineGap,
              contentLeft: box.contentLeft,
              contentWidth: box.contentWidth,
              staffTops: staffTops,
              staffLineGaps: staffLineGaps,
              onsetAnchors: anchors,
            );
          }
        }
      }
      pageTop += pageHeight;
    }

    _documentWidth = viewWidth;
    _documentHeight = math.max(pageTop, 240);
    _layout = NativeScoreLayout(
      contentSize: Size(_documentWidth, _documentHeight),
      measures: measures,
      notes: notes,
      systemStarts: systemStarts,
    );
  }

  void _notifySystemsChanged() {
    final layout = _layout;
    if (layout == null) return;
    final systems = <ScoreSystemSpan>[];
    final sorted = [...layout.measures]
      ..sort((a, b) => a.rect.top.compareTo(b.rect.top));
    if (sorted.isNotEmpty) {
      var start = sorted.first.measureIndex;
      var end = start;
      var top = sorted.first.rect.top;
      for (final measure in sorted.skip(1)) {
        final sameSystem =
            (measure.rect.top - top).abs() <
            math.max(10, sorted.first.rect.height * 0.22);
        if (sameSystem) {
          end = measure.measureIndex;
        } else {
          systems.add(
            ScoreSystemSpan(startMeasureIndex: start, endMeasureIndex: end),
          );
          start = measure.measureIndex;
          end = start;
          top = measure.rect.top;
        }
      }
      systems.add(
        ScoreSystemSpan(startMeasureIndex: start, endMeasureIndex: end),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSystemsChanged?.call(systems);
    });
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
    if (widget.playback.state.playing) {
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
      final sequence = await _buildPlaybackMidiSequence(
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

  Future<nm.MidiSequence> _buildPlaybackMidiSequence(
    nm.Score writtenScore, {
    required nm.MidiGenerationOptions options,
  }) async {
    final sequence = widget.playbackSequence;
    if (sequence.isEmpty) {
      if (widget.playbackArrangement.isOff) {
        return nm.MidiMapper.fromScore(writtenScore, options: options);
      }
      final arranged = composePerformanceScore(
        widget.score,
        arrangement: widget.playbackArrangement,
        ignoreErrors: true,
      );
      return _midiForDomainScore(arranged, options: options);
    }

    final ranges = discoverScoreSections(widget.score);
    if (ranges.isEmpty) {
      return nm.MidiMapper.fromScore(writtenScore, options: options);
    }

    final cached = <String, _PlaybackMidiSegment>{};
    final segments = <_PlaybackMidiSegment>[];
    for (final item in sequence.items) {
      final matching = ranges.where((range) => range.section == item.section);
      if (matching.isEmpty) {
        return nm.MidiMapper.fromScore(writtenScore, options: options);
      }
      for (final range in matching) {
        final key =
            '${range.section}:${range.startMeasureIndex}:${range.endMeasureIndex}';
        final segment = cached[key] ??= _PlaybackMidiSegment.fromScore(
          _scoreForSectionRange(widget.score, range),
          arrangement: widget.playbackArrangement,
          options: options,
        );
        for (var repeat = 0; repeat < item.repeats; repeat++) {
          segments.add(segment);
        }
      }
    }
    return _concatenateMidiSegments(segments, options.ticksPerQuarter);
  }

  nm.MidiSequence _midiForDomainScore(
    MusicScore score, {
    required nm.MidiGenerationOptions options,
  }) {
    final xml = utf8.decode(_codec.encodeMusicXml(score));
    final engraved = nm.MusicXMLParser.scoreFromMusicXML(xml);
    return nm.MidiMapper.fromScore(engraved, options: options);
  }

  nm.MidiSequence _concatenateMidiSegments(
    List<_PlaybackMidiSegment> segments,
    int ticksPerQuarter,
  ) {
    if (segments.isEmpty) {
      return nm.MidiSequence(
        ticksPerQuarter: ticksPerQuarter,
        tracks: const <nm.MidiTrack>[],
      );
    }

    final tracks = <({String name, int channel, List<nm.MidiEvent> events})>[];
    var offset = 0;
    for (final segment in segments) {
      for (var index = 0; index < segment.sequence.tracks.length; index++) {
        final source = segment.sequence.tracks[index];
        while (tracks.length <= index) {
          tracks.add((name: source.name, channel: source.channel, events: []));
        }
        tracks[index].events.addAll([
          for (final event in source.events) _shiftMidiEvent(event, offset),
        ]);
      }
      offset += segment.durationTicks;
    }
    return nm.MidiSequence(
      ticksPerQuarter: ticksPerQuarter,
      tracks: [
        for (final track in tracks)
          nm.MidiTrack(
            name: track.name,
            channel: track.channel,
            events: track.events,
          ),
      ],
    );
  }

  nm.MidiEvent _shiftMidiEvent(nm.MidiEvent event, int offset) {
    final tick = event.tick + offset;
    return switch (event.type) {
      nm.MidiEventType.noteOn => nm.MidiEvent.noteOn(
        tick: tick,
        channel: event.channel,
        note: event.note ?? 0,
        velocity: event.velocity ?? 0,
      ),
      nm.MidiEventType.noteOff => nm.MidiEvent.noteOff(
        tick: tick,
        channel: event.channel,
        note: event.note ?? 0,
        velocity: event.velocity ?? 0,
      ),
      nm.MidiEventType.tempo => nm.MidiEvent.tempo(
        tick: tick,
        bpm: event.bpm ?? 120,
      ),
      nm.MidiEventType.programChange => nm.MidiEvent.programChange(
        tick: tick,
        channel: event.channel,
        program: event.program ?? 0,
      ),
      nm.MidiEventType.controlChange => nm.MidiEvent.controlChange(
        tick: tick,
        channel: event.channel,
        controller: event.controller ?? 0,
        value: event.value ?? 0,
      ),
      nm.MidiEventType.timeSignature => nm.MidiEvent.timeSignature(
        tick: tick,
        numerator: event.numerator ?? 4,
        denominator: event.denominator ?? 4,
      ),
      nm.MidiEventType.marker => nm.MidiEvent.marker(
        tick: tick,
        text: event.markerText ?? '',
      ),
    };
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
    if (wasPlaying) await _stop();
    final duration = widget.playback.state.durationMs;
    final clamped = positionMs.clamp(0, duration).toDouble();
    widget.playback.replaceState(
      widget.playback.state.copyWith(
        currentTimeMs: clamped,
        measureNumber: _measureForTime(clamped) + 1,
      ),
    );
    if (mounted) setState(() {});
    if (wasPlaying) return _playPause();
    return true;
  }

  int _measureForTime(num ms) {
    final total = math.max(
      1,
      (widget.playbackScore ?? widget.score).measureCount,
    );
    final duration = math.max(1.0, widget.playback.state.durationMs);
    return ((ms / duration) * total).floor().clamp(0, total - 1);
  }

  List<String?> get _sectionMarks => measureSectionMarks(widget.score);

  void _clearGhost() {
    if (_ghostCenter == null && !_ghostRest) return;
    setState(() {
      _ghostCenter = null;
      _ghostRest = false;
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
    if (widget.inputMode == 'select') return;
    if (widget.inputMode != 'note' && widget.inputMode != 'rest') {
      _clearGhost();
      return;
    }
    final hit = layout.hitStaff(
      content,
      durationType: widget.inputDurationType,
      score: widget.score,
    );
    if (hit == null) {
      _clearGhost();
      return;
    }
    setState(() {
      _ghostCenter = hit.ghostCenter;
      _ghostRest = widget.inputRest || widget.inputMode == 'rest';
      _ghostLineGap = hit.lineGap;
      _ghostDurationType = widget.inputDurationType;
      _ghostAlter = widget.inputAlter;
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
        final part = widget.score.parts[note.partIndex];
        final measure = part.measures[note.measureIndex];
        widget.onNoteTapped?.call(
          AlphaTabNoteTappedEvent(
            partIndex: note.partIndex,
            measureIndex: note.measureIndex,
            staff: note.staff,
            voiceIndex: note.staff - 1,
            onsetTicks:
                (note.onset *
                        alphaTabQuarterTicks /
                        measure.attributes.divisions)
                    .round(),
            midi: note.midi!,
            noteIndex: note.eventIndex,
          ),
        );
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
  }

  @override
  Widget build(BuildContext context) {
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
            if ((_lastViewportWidth == null ||
                    (_lastViewportWidth! - viewW).abs() > 0.5) &&
                _pages.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _rebuildRenderedLayout(viewW);
                _notifySystemsChanged();
                setState(() {});
              });
            }
            final layout = _layout;
            final docW = math.max(viewW, _documentWidth);
            final docH = math.max(viewH, _documentHeight);
            return Stack(
              children: [
                if (_parseError != null && _pages.isEmpty)
                  _ScoreError(message: _parseError!)
                else if (_pages.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerHover: _handlePointerHover,
                    onPointerSignal: _handlePointerSignal,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerCancel,
                    child: InteractiveViewer(
                      transformationController: _transform,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(48),
                      clipBehavior: Clip.hardEdge,
                      minScale: 0.35,
                      maxScale: 4,
                      scaleFactor: _mouseScrollScaleFactor,
                      // Trackpad scroll is a pan in MuseScore/forScore-style
                      // score navigation. Pinch remains the zoom gesture.
                      trackpadScrollCausesScale: false,
                      panEnabled:
                          widget.oneFingerPan || widget.inputMode == 'off',
                      scaleEnabled: true,
                      onInteractionEnd: (_) => setState(() {}),
                      child: SizedBox(
                        width: docW,
                        height: docH,
                        child: Stack(
                          children: [
                            _VerovioPages(
                              pages: _pages,
                              width: docW,
                              onHeightChanged: (height) {
                                if ((_documentHeight - height).abs() > 0.5 &&
                                    mounted) {
                                  setState(() => _documentHeight = height);
                                }
                              },
                            ),
                            if (layout != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _VerovioOverlayPainter(
                                      layout: layout,
                                      sectionMarks: _sectionMarks,
                                      highlightedMeasureIndex:
                                          widget.highlightedMeasureIndex,
                                      playbackMeasure:
                                          widget.playbackVisible &&
                                              widget.playback.state.playing
                                          ? widget
                                                    .playback
                                                    .state
                                                    .measureNumber -
                                                1
                                          : null,
                                      ghostCenter: _ghostCenter,
                                      ghostRest: _ghostRest,
                                      ghostLineGap: _ghostLineGap,
                                      ghostDurationType: _ghostDurationType,
                                      ghostAlter: _ghostAlter,
                                      measureDragTo: _measureDragTo,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                            tooltip: '확대',
                            onPressed: () => _zoomBy(1.35, constraints),
                            icon: const Icon(Icons.add_rounded),
                          ),
                          IconButton(
                            tooltip: '축소',
                            onPressed: () => _zoomBy(1 / 1.35, constraints),
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          IconButton(
                            tooltip: '화면에 맞춤',
                            onPressed: () {
                              _transform.value = Matrix4.identity();
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
    final scene = _transform.toScene(center);
    _transform.value = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(next, next, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
    setState(() {});
  }

  bool get _handlesPointerInput {
    return widget.inputMode != 'off' || _measureDragFrom != null;
  }

  Offset _scenePosition(PointerEvent event) {
    // This Listener is outside InteractiveViewer, so its local coordinates
    // are viewport coordinates. Convert exactly once to the score scene.
    return _transform.toScene(event.localPosition);
  }

  bool get _zoomModifierPressed {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isControlPressed || keyboard.isMetaPressed;
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (_multiPointerGesture || !_handlesPointerInput) return;
    if (widget.inputMode != 'note' && widget.inputMode != 'rest') return;
    // Desktop notation editors show the shadow note under the pointer before
    // the click. Touch devices still use the down/up path below.
    _updateInputAt(_scenePosition(event));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    // Scrolling changes the document under the pointer. A stale shadow note
    // is more confusing than no preview, so the next hover/move recomputes it.
    _clearGhost();
    if (_zoomModifierPressed) {
      // InteractiveViewer handles Ctrl/Cmd + wheel as zoom, preserving the
      // standard desktop shortcut used by MuseScore and Dorico.
      return;
    }

    final delta = event.scrollDelta;
    if (delta == Offset.zero) return;

    if (event.kind == PointerDeviceKind.trackpad) {
      // InteractiveViewer already treats an unmodified trackpad scroll as a
      // pan when this flag is false. Edit mode disables InteractiveViewer's
      // one-finger pan to protect tap-to-input, so provide the same pan only
      // for that mode.
      if (widget.oneFingerPan || widget.inputMode == 'off') return;
      _panByViewportDelta(delta);
      return;
    }

    // InteractiveViewer's built-in mouse-wheel path is zoom-only. Let that
    // handler run, then undo only its scale in the same event turn and apply
    // the benchmarked scroll. This keeps pinch zoom and regular pan gestures
    // on the framework widget while making mouse wheel behavior match desktop
    // notation apps.
    scheduleMicrotask(() {
      if (!mounted) return;
      _undoMouseWheelScale(event.localPosition, delta.dy);
      _panByViewportDelta(delta);
    });
  }

  void _undoMouseWheelScale(Offset focalPoint, double scrollDy) {
    if (scrollDy == 0) return;
    final scaleChange = math.exp(-scrollDy / _mouseScrollScaleFactor);
    if (!scaleChange.isFinite || scaleChange == 0) return;

    final current = _transform.value;
    final currentScale = current.getMaxScaleOnAxis();
    var restoredScale = currentScale / scaleChange;
    // InteractiveViewer clamps at these limits. Do not turn a wheel event at
    // an edge into an accidental zoom-out/zoom-in while restoring the scale.
    if (scrollDy < 0 && currentScale >= 4.0 - 0.0001) {
      restoredScale = currentScale;
    } else if (scrollDy > 0 && currentScale <= 0.35 + 0.0001) {
      restoredScale = currentScale;
    }

    final translation = current.getTranslation();
    final nextTx =
        focalPoint.dx - (focalPoint.dx - translation.x) / scaleChange;
    final nextTy =
        focalPoint.dy - (focalPoint.dy - translation.y) / scaleChange;
    _transform.value = Matrix4.identity()
      ..translateByDouble(nextTx, nextTy, 0, 1)
      ..scaleByDouble(restoredScale, restoredScale, 1, 1);
  }

  void _panByViewportDelta(Offset delta) {
    if (delta == Offset.zero) return;
    final next = _transform.value.clone();
    final translation = next.getTranslation();
    next.setTranslationRaw(
      translation.x - delta.dx,
      translation.y - delta.dy,
      translation.z,
    );
    _transform.value = next;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) {
      _multiPointerGesture = true;
      _clearGhost();
      return;
    }
    if (_handlesPointerInput) {
      _updateInputAt(_scenePosition(event));
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_multiPointerGesture || _activePointers.length != 1) return;
    if (_handlesPointerInput) {
      _updateInputAt(_scenePosition(event));
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final shouldCommit = !_multiPointerGesture && _activePointers.length == 1;
    if (shouldCommit && _handlesPointerInput) {
      _commitInputAt(_scenePosition(event));
    }
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) _multiPointerGesture = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty) _multiPointerGesture = false;
    _clearGhost();
  }
}

MusicScore _scoreForSectionRange(MusicScore score, ScoreSectionRange range) {
  if (range.startMeasureIndex < 0 ||
      range.endMeasureIndex < range.startMeasureIndex) {
    throw const FormatException('A section range is invalid.');
  }
  if (score.parts.any(
    (part) => range.endMeasureIndex >= part.measures.length,
  )) {
    throw const FormatException('A section is outside the score.');
  }
  return score.copyWith(
    parts: [
      for (final part in score.parts)
        part.copyWith(
          measures: [
            for (
              var index = range.startMeasureIndex;
              index <= range.endMeasureIndex;
              index++
            )
              part.measures[index].copyWith(
                number: '${index - range.startMeasureIndex + 1}',
              ),
          ],
        ),
    ],
  );
}

class _PlaybackMidiSegment {
  const _PlaybackMidiSegment({
    required this.sequence,
    required this.durationTicks,
  });

  factory _PlaybackMidiSegment.fromScore(
    MusicScore score, {
    required ArrangementProfile arrangement,
    required nm.MidiGenerationOptions options,
  }) {
    final performance = composePerformanceScore(
      score,
      arrangement: arrangement,
      ignoreErrors: true,
    );
    final xml = utf8.decode(const MusicXmlCodec().encodeMusicXml(performance));
    final engraved = nm.MusicXMLParser.scoreFromMusicXML(xml);
    return _PlaybackMidiSegment(
      sequence: nm.MidiMapper.fromScore(engraved, options: options),
      durationTicks: _musicScoreDurationTicks(
        performance,
        options.ticksPerQuarter,
      ),
    );
  }

  final nm.MidiSequence sequence;
  final int durationTicks;
}

int _musicScoreDurationTicks(MusicScore score, int ticksPerQuarter) {
  if (score.parts.isEmpty) return 0;
  return score.parts.first.measures.fold<int>(0, (sum, measure) {
    final time =
        measure.attributes.time ??
        const MusicTimeSignature(beats: 4, beatType: 4);
    final quarterNotes = time.beats * 4 / time.beatType;
    return sum + (quarterNotes * ticksPerQuarter).round();
  });
}

class _VerovioPage {
  const _VerovioPage({required this.svg, required this.hitMap});

  final String svg;
  final PageHitMap hitMap;
}

String _normalizeVerovioSvgForFlutter(String source) {
  final rootViewBox = RegExp(
    r'<svg\b[^>]*\bviewBox="([^"]+)"',
  ).firstMatch(source)?.group(1);
  final definitionMatch = RegExp(
    r'<svg\b(?=[^>]*\bclass="definition-scale")([^>]*)>',
  ).firstMatch(source);
  if (rootViewBox == null || definitionMatch == null) return source;

  final rootSize = _parseSvgViewBoxSize(rootViewBox);
  final definitionViewBox = RegExp(
    r'\bviewBox="([^"]+)"',
  ).firstMatch(definitionMatch.group(0)!)?.group(1);
  final definitionSize = definitionViewBox == null
      ? null
      : _parseSvgViewBoxSize(definitionViewBox);
  if (rootSize == null || definitionSize == null) return source;
  if (definitionSize.width <= 0 || definitionSize.height <= 0) return source;

  final openStart = definitionMatch.start;
  final openEnd = definitionMatch.end;
  final closeStart = source.indexOf('</svg>', openEnd);
  if (closeStart < 0) return source;
  final scaleX = rootSize.width / definitionSize.width;
  final scaleY = rootSize.height / definitionSize.height;
  final opening = '<g transform="scale($scaleX $scaleY)">';
  final normalizedBuffer = StringBuffer()
    ..write(source.substring(0, openStart))
    ..write(opening)
    ..write(source.substring(openEnd, closeStart))
    ..write('</g>')
    ..write(source.substring(closeStart + '</svg>'.length));
  var normalized = normalizedBuffer.toString();

  // Verovio uses a small CSS rule to make open paths inherit the page color.
  // flutter_svg does not apply that stylesheet, so carry the stroke onto
  // shapes that explicitly declare a stroke width.
  normalized = normalized.replaceAllMapped(
    RegExp(
      r"""<(path|ellipse|polygon|polyline|rect)\b[^>]*\bstroke-width\s*=\s*["'][^"']+["'][^>]*>""",
    ),
    (match) {
      final element = match.group(0)!;
      if (RegExp(r'\bstroke\s*=').hasMatch(element)) return element;
      final insertAt = element.endsWith('/>')
          ? element.length - 2
          : element.length - 1;
      return '${element.substring(0, insertAt)} stroke="black"${element.substring(insertAt)}';
    },
  );
  // flutter_svg cannot load Verovio's embedded SMuFL WOFF2 font into the
  // device font registry.  Symbols embedded in text (most notably the
  // metronome note) would otherwise fall back to an unrelated private-use
  // glyph and appear as a large, overlapping block in the top-left corner.
  // Keep the engraving intact and use the platform music-note glyph for this
  // small class of inline symbols.
  normalized = normalized.replaceAllMapped(
    RegExp(r'[\uE000-\uF8FF]'),
    (_) => '♩',
  );
  normalized = normalized.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (
    match,
  ) {
    final codePoint = int.tryParse(match.group(1)!, radix: 16);
    if (codePoint == null || codePoint < 0xE000 || codePoint > 0xF8FF) {
      return match.group(0)!;
    }
    return '♩';
  });
  // flutter_svg does not preserve the positions of Verovio's direction and
  // tempo text inside the flattened definition-scale viewport. Leaving those
  // text nodes in place makes later annotations jump to the first system and
  // overlap the clefs. Keep pure measure numbers for navigation; the source
  // MusicXML and PDF export still retain all annotations.
  normalized = normalized.replaceAllMapped(
    RegExp(r'<text\b[^>]*>[\s\S]*?</text>'),
    (match) {
      final plainText = match
          .group(0)!
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      return RegExp(r'^\d+$').hasMatch(plainText) ? match.group(0)! : '';
    },
  );
  return normalized.replaceAll(
    RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true),
    '',
  );
}

Size? _parseSvgViewBoxSize(String value) {
  final values = value
      .trim()
      .split(RegExp(r'[ ,]+'))
      .map(double.tryParse)
      .toList();
  if (values.length != 4 || values.any((value) => value == null)) return null;
  return Size(values[2]!, values[3]!);
}

class _VerovioPages extends StatelessWidget {
  const _VerovioPages({
    required this.pages,
    required this.width,
    required this.onHeightChanged,
  });

  final List<_VerovioPage> pages;
  final double width;
  final ValueChanged<double> onHeightChanged;

  @override
  Widget build(BuildContext context) {
    var top = 0.0;
    final children = <Widget>[];
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      final viewBox = page.hitMap.viewBox;
      final height = viewBox.width <= 0
          ? 0.0
          : width * viewBox.height / viewBox.width;
      children.add(
        Positioned(
          left: 0,
          top: top,
          width: width,
          height: height,
          child: SvgPicture.string(
            page.svg,
            fit: BoxFit.fill,
            alignment: Alignment.topCenter,
          ),
        ),
      );
      top += height;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeightChanged(top));
    return Stack(children: children);
  }
}

class _MeasureGeometry {
  const _MeasureGeometry({
    required this.measureIndex,
    required this.element,
    required this.box,
  });

  final int measureIndex;
  final ElementHit element;
  final NativeMeasureBox box;
}

_MeasureGeometry? _measureForHit(
  ElementHit hit,
  List<_MeasureGeometry> measures,
) {
  if (hit.parentId != null) {
    for (final measure in measures) {
      if (measure.element.id == hit.parentId) return measure;
    }
  }
  final center = hit.bbox.center;
  for (final measure in measures) {
    if (measure.element.bbox.contains(center)) return measure;
  }
  return null;
}

List<_RenderedNoteMatch> _matchRenderedNotes({
  required List<ElementHit> hits,
  required List<(int, MusicNote)> sourceNotes,
  required int partIndex,
  required int measureIndex,
}) {
  final sourceByIndex = <int, MusicNote>{
    for (final source in sourceNotes) source.$1: source.$2,
  };
  final used = <int>{};
  final matches = <_RenderedNoteMatch>[];

  // MusicXML ids are added by MusicXmlCodec before Verovio renders the score.
  // Prefer them over visual sorting so chords and multiple voices keep their
  // actual event addresses.
  for (final hit in hits) {
    final encoded = _parseNoteEventId(hit.id);
    if (encoded == null ||
        encoded.partIndex != partIndex ||
        encoded.measureIndex != measureIndex ||
        used.contains(encoded.eventIndex)) {
      continue;
    }
    final note = sourceByIndex[encoded.eventIndex];
    if (note == null) continue;
    used.add(encoded.eventIndex);
    matches.add(
      _RenderedNoteMatch(eventIndex: encoded.eventIndex, note: note, hit: hit),
    );
  }

  // Imported MusicXML may not carry a usable id through Verovio's MusicXML
  // converter. Fall back to horizontal engraving order, which is the correct
  // order for onset mapping (the old top-first order put later chord notes in
  // front of earlier beats).
  final remainingHits =
      hits
          .where((hit) => !matches.any((match) => identical(match.hit, hit)))
          .toList()
        ..sort(_compareNotePosition);
  final remainingSources =
      sourceNotes.where((source) => !used.contains(source.$1)).toList()
        ..sort((a, b) {
          final onset = a.$2.onset.compareTo(b.$2.onset);
          if (onset != 0) return onset;
          final staff = a.$2.staff.compareTo(b.$2.staff);
          return staff == 0 ? a.$1.compareTo(b.$1) : staff;
        });
  final count = math.min(remainingHits.length, remainingSources.length);
  for (var index = 0; index < count; index++) {
    final source = remainingSources[index];
    matches.add(
      _RenderedNoteMatch(
        eventIndex: source.$1,
        note: source.$2,
        hit: remainingHits[index],
      ),
    );
  }
  return matches;
}

({int partIndex, int measureIndex, int eventIndex})? _parseNoteEventId(
  String id,
) {
  final match = RegExp(r'(?:^|-)p(\d+)-m(\d+)-e(\d+)(?:-|$)').firstMatch(id);
  if (match == null) return null;
  return (
    partIndex: int.parse(match.group(1)!),
    measureIndex: int.parse(match.group(2)!),
    eventIndex: int.parse(match.group(3)!),
  );
}

_StaffGeometry _fitStaffGeometry(
  List<_StaffMetricPoint> points, {
  required double fallbackTop,
  required double fallbackGap,
  required bool bass,
}) {
  final reference = bass ? -2 : 2;
  if (points.isEmpty) {
    return _StaffGeometry(top: fallbackTop, lineGap: fallbackGap);
  }

  // A measure can contain a single pitched event (or the hit map can expose
  // only one reliable note box). Keep that note on its rendered pitch instead
  // of falling back to a guessed position that may move the ghost several
  // staff steps away from the touch.
  if (points.length == 1) {
    final point = points.single;
    final top = point.y + (point.steps - reference) * fallbackGap / 2;
    return _StaffGeometry(top: top, lineGap: fallbackGap);
  }

  // Fit all note boxes instead of using only the two most distant notes.
  // Stem/flag extents can move an individual hit-box centre; least-squares
  // fitting makes the staff estimate stable across mixed rhythms and chords.
  final meanSteps =
      points.fold<double>(0, (sum, point) => sum + point.steps) / points.length;
  final meanY =
      points.fold<double>(0, (sum, point) => sum + point.y) / points.length;
  var covariance = 0.0;
  var variance = 0.0;
  for (final point in points) {
    final stepsDelta = point.steps - meanSteps;
    covariance += stepsDelta * (point.y - meanY);
    variance += stepsDelta * stepsDelta;
  }
  if (variance <= 0) {
    final point = points.first;
    final top = point.y + (point.steps - reference) * fallbackGap / 2;
    return _StaffGeometry(top: top, lineGap: fallbackGap);
  }
  final slope = covariance / variance;
  if (!slope.isFinite || slope.abs() < 0.1) {
    final point = points.first;
    final top = point.y + (point.steps - reference) * fallbackGap / 2;
    return _StaffGeometry(top: top, lineGap: fallbackGap);
  }
  final lineGap = (slope.abs() * 2).clamp(
    math.max(2.0, fallbackGap * 0.55),
    math.max(4.0, fallbackGap * 1.8),
  );
  final intercept = meanY - slope * meanSteps;
  final top = intercept + slope * reference;
  return _StaffGeometry(top: top, lineGap: lineGap.toDouble());
}

int _diatonicStepsForPitch(MusicPitch pitch) {
  return (pitch.octave - 4) * 7 + pitch.step.index;
}

int _compareMeasurePosition(ElementHit a, ElementHit b) {
  final top = a.bbox.top.compareTo(b.bbox.top);
  if (top != 0) return top;
  return a.bbox.left.compareTo(b.bbox.left);
}

int _compareNotePosition(ElementHit a, ElementHit b) {
  final left = a.bbox.left.compareTo(b.bbox.left);
  if (left != 0) return left;
  return a.bbox.top.compareTo(b.bbox.top);
}

class _RenderedNoteMatch {
  const _RenderedNoteMatch({
    required this.eventIndex,
    required this.note,
    required this.hit,
  });

  final int eventIndex;
  final MusicNote note;
  final ElementHit hit;
}

class _StaffMetricPoint {
  const _StaffMetricPoint({required this.steps, required this.y});

  final int steps;
  final double y;
}

class _StaffGeometry {
  const _StaffGeometry({required this.top, required this.lineGap});

  final double top;
  final double lineGap;
}

Rect _scaledRect(Rect rect, double scale, double pageTop) {
  return Rect.fromLTRB(
    rect.left * scale,
    pageTop + rect.top * scale,
    rect.right * scale,
    pageTop + rect.bottom * scale,
  );
}

Offset _scaledPoint(Offset point, double scale, double pageTop) {
  return Offset(point.dx * scale, pageTop + point.dy * scale);
}

class _VerovioOverlayPainter extends CustomPainter {
  const _VerovioOverlayPainter({
    required this.layout,
    required this.sectionMarks,
    required this.highlightedMeasureIndex,
    required this.playbackMeasure,
    required this.ghostCenter,
    required this.ghostRest,
    required this.ghostLineGap,
    required this.ghostDurationType,
    required this.ghostAlter,
    required this.measureDragTo,
  });

  final NativeScoreLayout layout;
  final List<String?> sectionMarks;
  final int? highlightedMeasureIndex;
  final int? playbackMeasure;
  final Offset? ghostCenter;
  final bool ghostRest;
  final double ghostLineGap;
  final String ghostDurationType;
  final int ghostAlter;
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
      final section = measure.measureIndex < sectionMarks.length
          ? sectionMarks[measure.measureIndex]
          : null;
      if (section != null && section.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: section,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: math.max(24, measure.rect.width - 8));
        textPainter.paint(
          canvas,
          Offset(measure.rect.left + 20, measure.rect.top + 2),
        );
      }
    }
    final ghost = ghostCenter;
    if (ghost == null) return;
    if (ghostRest) {
      _drawGhostRest(canvas, ghost);
    } else {
      _drawGhostNote(canvas, ghost);
    }
  }

  void _drawGhostNote(Canvas canvas, Offset center) {
    final gap = ghostLineGap.clamp(4.0, 18.0).toDouble();
    final color = AppColors.accent.withValues(alpha: 0.78);
    final noteHeadCodePoint = switch (ghostDurationType) {
      'whole' => 0xE0A2,
      'half' => 0xE0A3,
      _ => 0xE0A4,
    };
    final noteHead = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(noteHeadCodePoint),
        style: TextStyle(
          color: color,
          fontFamily: 'Bravura',
          fontSize: gap * 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final noteWidth = math.max(gap, noteHead.width);
    noteHead.paint(
      canvas,
      Offset(center.dx - noteHead.width / 2, center.dy - noteHead.height / 2),
    );

    if (ghostDurationType != 'whole') {
      final stem = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, gap * 0.16)
        ..strokeCap = StrokeCap.square;
      final stemX = center.dx + noteWidth * 0.45;
      final stemTop = center.dy - gap * 3.4;
      canvas.drawLine(Offset(stemX, center.dy), Offset(stemX, stemTop), stem);
      if (ghostDurationType == 'eighth' || ghostDurationType == '16th') {
        final flag = Path()
          ..moveTo(stemX, stemTop)
          ..quadraticBezierTo(
            stemX + gap * 1.15,
            stemTop + gap * 0.35,
            stemX + gap * 0.25,
            stemTop + gap * 0.95,
          );
        canvas.drawPath(flag, stem);
        if (ghostDurationType == '16th') {
          final second = Path()
            ..moveTo(stemX, stemTop + gap * 0.65)
            ..quadraticBezierTo(
              stemX + gap * 1.05,
              stemTop + gap,
              stemX + gap * 0.25,
              stemTop + gap * 1.6,
            );
          canvas.drawPath(second, stem);
        }
      }
    }

    if (ghostAlter != 0) {
      final accidental = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(ghostAlter > 0 ? 0xE262 : 0xE260),
          style: TextStyle(
            color: color,
            fontFamily: 'Bravura',
            fontSize: gap * 1.65,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      accidental.paint(
        canvas,
        Offset(
          center.dx - noteWidth * 0.9 - accidental.width,
          center.dy - accidental.height * 0.58,
        ),
      );
    }
  }

  void _drawGhostRest(Canvas canvas, Offset center) {
    final gap = ghostLineGap.clamp(4.0, 18.0).toDouble();
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, gap * 0.2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(center.dx - gap * 0.7, center.dy - gap * 0.7)
      ..lineTo(center.dx + gap * 0.6, center.dy - gap * 0.05)
      ..lineTo(center.dx - gap * 0.35, center.dy + gap * 0.55)
      ..lineTo(center.dx + gap * 0.75, center.dy + gap * 0.85);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VerovioOverlayPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.sectionMarks != sectionMarks ||
        oldDelegate.highlightedMeasureIndex != highlightedMeasureIndex ||
        oldDelegate.playbackMeasure != playbackMeasure ||
        oldDelegate.ghostCenter != ghostCenter ||
        oldDelegate.ghostRest != ghostRest ||
        oldDelegate.ghostLineGap != ghostLineGap ||
        oldDelegate.ghostDurationType != ghostDurationType ||
        oldDelegate.ghostAlter != ghostAlter ||
        oldDelegate.measureDragTo != measureDragTo;
  }
}

class _ScoreError extends StatelessWidget {
  const _ScoreError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: const TextStyle(color: AppColors.ink),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
