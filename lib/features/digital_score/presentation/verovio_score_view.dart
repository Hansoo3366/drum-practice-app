import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_notemus/flutter_notemus.dart' as nm;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';
import 'package:page_a_diddle/features/digital_score/data/engraved_pdf_exporter.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/data/score_sound_font.dart';
import 'package:page_a_diddle/features/digital_score/domain/arrangement_profile.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/native_score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_editor.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:page_a_diddle/features/digital_score/domain/xml_measure_editor.dart';
import 'package:page_a_diddle/features/digital_score/presentation/midi_duration.dart';
import 'package:page_a_diddle/features/digital_score/presentation/piano_score_view.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_text_labels.dart';
import 'package:verovio_flutter/verovio_flutter.dart';

part 'verovio_score_layout.dart';
part 'verovio_overlay_painter.dart';

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
    this.onEventTapped,
    this.onStaffTapped,
    this.onMeasureTapped,
    this.onMeasureMoved,
    this.onSystemsChanged,
    this.onNoteDragged,
    this.onPlayerIssue,
    this.highlightedMeasureIndex,
    this.highlightedMeasureRange,
    this.rehearsalMarks,
    this.selectedNoteAddress,
    this.absorbMeasureTaps = false,
    this.oneFingerPan = true,
    this.inputMode = 'off',
    this.inputDurationType = 'quarter',
    this.inputRest = false,
    this.inputAlter = 0,
    this.inputDots = 0,
    this.inputCaret,
    this.engravingXml,
    this.engravingPageSize,
    super.key,
  });

  final MusicScore score;

  /// When set, Verovio engraves this MusicXML instead of a codec round-trip.
  final String? engravingXml;

  /// Verovio page size in 1/10 mm. A narrow page engraves larger on screen,
  /// which the one-bar proofreading editor uses. Defaults to A4.
  final Size? engravingPageSize;
  final MusicScore? playbackScore;
  final PlaybackSequence playbackSequence;
  final ArrangementProfile playbackArrangement;
  final String semanticsLabel;
  final PianoScorePlaybackController playback;
  final bool playbackVisible;
  final ValueChanged<AlphaTabNoteTappedEvent>? onNoteTapped;

  /// Fires for notes and rests alike in `select` mode. When set, a drag that
  /// moves beyond the touch slop is treated as a pan, not a selection.
  final ValueChanged<ScoreEventAddress>? onEventTapped;
  final ValueChanged<AlphaTabStaffTappedEvent>? onStaffTapped;
  final ValueChanged<int>? onMeasureTapped;
  final void Function(int fromIndex, int toIndex)? onMeasureMoved;
  final ValueChanged<List<ScoreSystemSpan>>? onSystemsChanged;
  final ValueChanged<AlphaTabNoteDraggedEvent>? onNoteDragged;
  final VoidCallback? onPlayerIssue;
  final int? highlightedMeasureIndex;

  /// Inclusive bar range tinted while choosing a section.
  final ({int start, int end})? highlightedMeasureRange;

  /// Sections to label above the score. Defaults to rehearsal marks.
  /// The user's sections, drawn as the score's rehearsal boxes in place of
  /// the printed ones. Null draws the score as written. Display only.
  final List<({int measureIndex, String label})>? rehearsalMarks;
  final ScoreEventAddress? selectedNoteAddress;
  final bool absorbMeasureTaps;
  final bool oneFingerPan;
  final String inputMode;
  final String inputDurationType;
  final bool inputRest;
  final int inputAlter;
  final int inputDots;
  final NoteCaret? inputCaret;

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
    'autoBeam': true,
    // Verovio does not count ties below the notes as obstacles; keep lyrics
    // clear of them (the option's maximum).
    'lyricTopMinMargin': 8,
  };

  final _transform = TransformationController();
  final _audio = const nm.MethodChannelMidiNativeAudioBackend();
  late final _bridge = nm.MidiNativeSequenceBridge(_audio);

  VerovioAsyncService? _service;
  Future<void>? _serviceReady;
  List<_VerovioPage> _pages = const <_VerovioPage>[];
  NativeScoreLayout? _layout;

  /// Chord symbol boxes in scene coordinates, kept clear by section labels.
  List<Rect> _chordRects = const [];

  /// The MIDI being made or already made, and what it was made for; see
  /// [_playbackMidi].
  Future<PlaybackMidi>? _midi;
  ({
    String? xml,
    MusicScore? score,
    PlaybackSequence? sequence,
    ArrangementProfile? arrangement,
    int bpm,
  })
  _midiFor = (
    xml: null,
    score: null,
    sequence: null,
    arrangement: null,
    bpm: 0,
  );
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
        oldWidget.engravingXml != widget.engravingXml ||
        !_sameMarks(oldWidget.rehearsalMarks, widget.rehearsalMarks) ||
        oldWidget.engravingPageSize != widget.engravingPageSize ||
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
      unawaited(_playbackMidi().then((_) {}, onError: (Object _) {}));
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
      // With the SoundFont the parts sound like their instruments; without
      // it (not bundled, or not readable) the synthesizer uses waveforms.
      final ok = await _audio.initialize(
        primarySoundFontPath: await scoreSoundFontPath(),
      );
      if (kDebugMode && ok) {
        debugPrint(
          'Score audio: ${await _audio.hasSoundFont() ? 'SoundFont' : 'waveforms'}',
        );
      }
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
      final writtenXml =
          widget.engravingXml ??
          utf8.decode(_codec.encodeMusicXml(widget.score));
      final marks = widget.rehearsalMarks;
      final visualXml = marks == null
          ? writtenXml
          : withSectionRehearsals(writtenXml, marks);
      _engraved = nm.MusicXMLParser.scoreFromMusicXML(visualXml);
      _parseError = null;
      _pages = const <_VerovioPage>[];
      _layout = null;
      _rendering = _renderWithVerovio(visualXml, generation);
    } catch (_) {
      _engraved = null;
      _parseError = '악보를 표시할 수 없습니다.';
      _pages = const <_VerovioPage>[];
      _layout = null;
    }

    _resetPlaybackState();
  }

  void _resetPlaybackState() {
    widget.playback.replaceState(
      widget.playback.state.copyWith(
        ready: true,
        loaded: true,
        durationMs: _estimatedDurationMs(),
        playing: false,
        currentTimeMs: 0,
        measureNumber: 1,
        beatIndex: 0,
      ),
    );
    if (mounted) setState(() {});
    if (widget.playbackVisible)
      unawaited(_playbackMidi().then((_) {}, onError: (Object _) {}));
  }

  /// Length of the performance before its MIDI exists: every bar the order
  /// plays, repeats included, at the tempo the player will use. Playing
  /// replaces it with the MIDI's own length.
  double _estimatedDurationMs() {
    final bpm = widget.score.tempoBpm ?? 120;
    try {
      final lengths = measureQuarterLengths(widget.score);
      final quarters = performanceMeasureMap(
        widget.score,
        widget.playbackSequence,
      ).fold<double>(0, (sum, index) => sum + lengths[index]);
      return quarters * 60000 / bpm;
    } on FormatException {
      return estimateScoreDurationMs(widget.playbackScore ?? widget.score);
    }
  }

  /// Measure indices (first part) that start a written line, or empty.
  static List<int> _writtenLineStarts(String xml) {
    final open = RegExp(r'<part\s[^>]*>').firstMatch(xml);
    if (open == null) return const [];
    final close = xml.indexOf('</part>', open.end);
    final body = xml.substring(open.end, close < 0 ? xml.length : close);
    final starts = <int>[];
    var index = 0;
    for (final measure in RegExp(
      r'<measure\b[\s\S]*?</measure>',
    ).allMatches(body)) {
      if (index == 0 ||
          RegExp(
            r'<print\b[^>]*new-(?:system|page)="yes"',
          ).hasMatch(measure.group(0)!)) {
        starts.add(index);
      }
      index++;
    }
    return starts.length > 1 ? starts : const [];
  }

  /// Written line starts of the score on screen; empty when lines reflow.
  List<int> _lineStarts = const [];

  Future<void> _renderWithVerovio(String xml, int generation) async {
    try {
      final timeout = _verovioOperationTimeout;
      final service = await _getService().timeout(timeout);
      _lineStarts = _writtenLineStarts(xml);
      await service
          .setOptionsJson(
            jsonEncode({
              ..._verovioOptions,
              // Lines as on the page (converted scores record them); pages
              // still break automatically. Scores without line breaks reflow.
              if (_lineStarts.isNotEmpty) 'breaks': 'line',
              if (widget.engravingPageSize case final size?) ...{
                'pageWidth': size.width.round(),
                'pageHeight': size.height.round(),
              },
            }),
          )
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
              config: const ParseConfig(
                captureClasses: {'note', 'rest', 'measure', 'staff', 'clef'},
              ),
            )
            .timeout(timeout);
        pages.add(
          _VerovioPage(
            svg: normalizeVerovioSvgForFlutter(svg),
            hitMap: hitMap,
            chords: extractVerovioTextLabels(svg),
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

  /// The engraving of the pages on screen, while it runs.
  Future<void> _rendering = Future.value();

  /// Exports wait for each other: the engraver holds one document at a
  /// time.
  Future<void> _exportQueue = Future.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _exportQueue.then((_) => job());
    _exportQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Engraves [xml] on A4 pages for export, whatever the screen shows: the
  /// same engraver and options as the viewer, so the file looks like the
  /// screen. The pages on screen are not touched.
  Future<List<EngravedPage>> engravePages(String xml) {
    return _serial(() async {
      // Not while the screen's own pages are being engraved.
      await _rendering;
      const timeout = _verovioOperationTimeout;
      final service = await _getService().timeout(timeout);
      await service
          .setOptionsJson(
            jsonEncode({
              ..._verovioOptions,
              if (_writtenLineStarts(xml).isNotEmpty) 'breaks': 'line',
            }),
          )
          .timeout(timeout);
      await service.loadData(xml).timeout(timeout);
      final pageCount = await service.pageCount.timeout(timeout);
      final pages = <EngravedPage>[];
      for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        final svg = await service.renderToSvg(pageIndex + 1).timeout(timeout);
        final box = RegExp(
          r'<svg\b[^>]*\bviewBox="([^"]+)"',
        ).firstMatch(svg)?.group(1);
        final size = box == null ? null : _parseSvgViewBoxSize(box);
        if (size == null) continue;
        pages.add(
          EngravedPage(
            svg: normalizeVerovioSvgForFlutter(svg),
            labels: extractVerovioTextLabels(svg),
            width: size.width,
            height: size.height,
          ),
        );
      }
      return pages;
    });
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
    final chordRects = <Rect>[];
    final part = widget.score.parts.isEmpty ? null : widget.score.parts.first;
    var pageTop = 0.0;
    var measureIndex = 0;

    for (final page in _pages) {
      final viewBox = page.hitMap.viewBox;
      if (viewBox.width <= 0 || viewBox.height <= 0) continue;
      final scale = viewWidth / viewBox.width;
      final pageHeight = page.visibleHeight * scale;
      final measureHits = orderMeasureBoxes(
        page.hitMap.byType.where((hit) => hit.type == 'measure').toList(),
        (hit) => hit.bbox,
      );
      final staffHits = page.hitMap.byType
          .where((hit) => hit.type == 'staff')
          .toList();
      final clefHits = page.hitMap.byType
          .where((hit) => hit.type == 'clef')
          .toList();
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
        final staffRects = [
          for (final staff in staffHits)
            if (staff.parentId == hit.id ||
                hit.bbox.contains(staff.bbox.center))
              _scaledRect(staff.bbox, scale, pageTop),
        ];
        final clefRects = [
          for (final clef in clefHits)
            if (clef.parentId == hit.id || hit.bbox.contains(clef.bbox.center))
              _scaledRect(clef.bbox, scale, pageTop),
        ];
        final frame = grandStaffFrameFromStaffRects(
          staffRects,
          rect,
          staves: staffCount,
        );
        final contentLeft = contentLeftAfterClefs(
          measure: rect,
          clefs: clefRects,
          measureIndex: measureIndex,
        );
        final box = NativeMeasureBox(
          measureIndex: measureIndex,
          rect: rect.inflate(2),
          trebleStaffTop: frame.trebleStaffTop,
          bassStaffTop: frame.bassStaffTop,
          lineGap: frame.lineGap,
          contentLeft: contentLeft,
          contentWidth: math.max(12, rect.left + rect.width - 8 - contentLeft),
          staffTops: {
            1: frame.trebleStaffTop,
            if (staffCount > 1) 2: frame.bassStaffTop,
          },
          staffLineGaps: {
            1: frame.lineGap,
            if (staffCount > 1) 2: frame.lineGap,
          },
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
                bounds: Rect.fromPoints(
                  _scaledPoint(match.hit.bbox.topLeft, scale, pageTop),
                  _scaledPoint(match.hit.bbox.bottomRight, scale, pageTop),
                ),
                isRest: note.isRest || match.hit.type == 'rest',
              ),
            );
          }

          // Rests carry the codec's event id too. Map them only by that id:
          // guessing by position could select the wrong rest in two voices.
          for (final hit in entry.value) {
            if (hit.type != 'rest') continue;
            final encoded = _parseNoteEventId(hit.id);
            if (encoded == null ||
                encoded.measureIndex != absoluteIndex ||
                encoded.eventIndex >= musicMeasure.events.length) {
              continue;
            }
            final event = musicMeasure.events[encoded.eventIndex];
            if (event is! MusicNote || !event.isRest) continue;
            notes.add(
              NativeNotePlacement(
                partIndex: 0,
                measureIndex: absoluteIndex,
                eventIndex: encoded.eventIndex,
                staff: event.staff.clamp(1, 2),
                onset: event.onset,
                midi: null,
                center: _scaledPoint(hit.bbox.center, scale, pageTop),
                bounds: Rect.fromPoints(
                  _scaledPoint(hit.bbox.topLeft, scale, pageTop),
                  _scaledPoint(hit.bbox.bottomRight, scale, pageTop),
                ),
                isRest: true,
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
            final anchors = buildOnsetAnchors(
              contentLeft: box.contentLeft,
              contentWidth: box.contentWidth,
              capacity: capacity,
              noteXs: anchorXs,
            );
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
      for (final chord in page.chords) {
        final size = chord.fontSize * scale;
        final width = chord.text.length * size * 0.62;
        final left = switch (chord.anchor) {
          TextAlign.center => chord.x * scale - width / 2,
          TextAlign.right => chord.x * scale - width,
          _ => chord.x * scale,
        };
        chordRects.add(
          Rect.fromLTWH(
            left,
            pageTop + chord.baselineY * scale - size * 0.9,
            width,
            size * 1.1,
          ),
        );
      }
      pageTop += pageHeight;
    }

    _documentWidth = viewWidth;
    _documentHeight = math.max(pageTop, 240);
    _chordRects = List.unmodifiable(chordRects);
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
    if (_lineStarts.isNotEmpty) {
      // Lines follow the written breaks, so the file says where each starts
      // (measure boxes vary in height with marks above them).
      final count = layout.measures.length;
      for (var i = 0; i < _lineStarts.length; i++) {
        final start = _lineStarts[i];
        final end = i + 1 < _lineStarts.length
            ? _lineStarts[i + 1] - 1
            : count - 1;
        if (start < count && end >= start) {
          systems.add(
            ScoreSystemSpan(startMeasureIndex: start, endMeasureIndex: end),
          );
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSystemsChanged?.call(systems);
      });
      return;
    }
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
    final nm.MidiSequence sequence;
    try {
      final midi = await _playbackMidi();
      sequence = midi.sequence;
      await _setInstruments(midi);
      await _bridge.uploadAndStart(sequence, includeMetronome: false);
    } catch (_) {
      widget.onPlayerIssue?.call();
      return false;
    }
    _playbackAnchor = DateTime.now();
    _playbackAnchorMs = widget.playback.state.currentTimeMs;
    widget.playback.replaceState(
      widget.playback.state.copyWith(
        playing: true,
        durationMs: midiSequenceDurationMs(
          sequence,
          fallbackBpm: (widget.score.tempoBpm ?? 120).round(),
        ),
      ),
    );
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

  /// The playback MIDI, made in the background as soon as the player shows
  /// and kept while the score, order and accompaniment stay the same, so
  /// play, pause and seek do not make it again.
  Future<PlaybackMidi> _playbackMidi() {
    final bpm = (widget.score.tempoBpm ?? 120).round();
    final current = _midi;
    if (current != null &&
        identical(_midiFor.xml, widget.engravingXml) &&
        identical(_midiFor.score, widget.score) &&
        _midiFor.sequence == widget.playbackSequence &&
        _midiFor.arrangement == widget.playbackArrangement &&
        _midiFor.bpm == bpm) {
      return current;
    }
    _midiFor = (
      xml: widget.engravingXml,
      score: widget.score,
      sequence: widget.playbackSequence,
      arrangement: widget.playbackArrangement,
      bpm: bpm,
    );
    final future = buildPlaybackMidiInBackground(
      engravingXml: widget.engravingXml,
      score: widget.score,
      sequence: widget.playbackSequence,
      arrangement: widget.playbackArrangement,
      bpm: bpm,
    );
    _midi = future;
    future.then(
      (midi) {
        // The exact length replaces the estimate while nothing plays.
        if (!mounted || !identical(_midi, future)) return;
        if (widget.playback.state.playing) return;
        widget.playback.replaceState(
          widget.playback.state.copyWith(
            durationMs: midiSequenceDurationMs(midi.sequence, fallbackBpm: bpm),
          ),
        );
        setState(() {});
      },
      onError: (Object _) {
        // A failed build is made again on the next play.
        if (identical(_midi, future)) _midi = null;
      },
    );
    return future;
  }

  /// Tells the synthesizer which instrument plays each channel (the piano
  /// unless the score names another, as a generated strings or brass part
  /// does) and how loud, so the accompaniment stays behind the melody.
  Future<void> _setInstruments(PlaybackMidi midi) async {
    try {
      for (var channel = 0; channel < 16; channel++) {
        await _audio.setChannelProgram(
          channel: channel,
          program: midi.programs[channel] ?? 0,
          volume: midi.levels[channel] ?? 1.0,
        );
      }
    } on Object {
      // A synthesizer without instruments plays every part alike.
    }
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

  /// Written bar playing at [ms]. The performance may repeat or skip bars,
  /// so the playback position maps through the performance bar order and
  /// each bar's real length rather than a uniform bar count.
  int _measureForTime(num ms) {
    final duration = math.max(1.0, widget.playback.state.durationMs);
    final map = performanceMeasureMap(widget.score, widget.playbackSequence);
    return writtenMeasureAt(
      map,
      measureQuarterLengths(widget.score),
      ms / duration,
    );
  }

  static bool _sameMarks(
    List<({int measureIndex, String label})>? a,
    List<({int measureIndex, String label})>? b,
  ) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Rect? _caretRect(NativeScoreLayout layout) {
    final caret = widget.inputCaret;
    if (caret == null) return null;
    if (widget.inputMode != 'note' && widget.inputMode != 'rest') return null;
    if (caret.partIndex < 0 || caret.partIndex >= widget.score.parts.length) {
      return null;
    }
    final measures = widget.score.parts[caret.partIndex].measures;
    if (caret.measureIndex < 0 || caret.measureIndex >= measures.length) {
      return null;
    }
    NativeMeasureBox? box;
    for (final measure in layout.measures) {
      if (measure.measureIndex == caret.measureIndex) {
        box = measure;
        break;
      }
    }
    if (box == null) return null;
    final capacity = measureCapacity(measures[caret.measureIndex].attributes);
    final x = box.xForOnset(caret.onset.clamp(0, capacity).toInt(), capacity);
    final staffTop = box.staffTopFor(caret.staff);
    final gap = box.lineGapFor(caret.staff);
    // Treble staffTop is E4 (bottom line). Draw from F5 so the caret sits on
    // the staff the user is editing, not the gap below it.
    final topLine = caret.staff >= 2 ? staffTop : staffTop - 4 * gap;
    return Rect.fromLTWH(
      x,
      topLine - gap * 0.4,
      math.max(1.6, gap * 0.18),
      gap * 5.0,
    );
  }

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
      final note = layout.noteAt(
        content,
        includeRests: widget.onEventTapped != null,
      );
      if (widget.onEventTapped != null) {
        if (note != null) {
          widget.onEventTapped!(
            ScoreEventAddress(
              partIndex: note.partIndex,
              measureIndex: note.measureIndex,
              eventIndex: note.eventIndex,
            ),
          );
        }
        return;
      }
      if (note != null &&
          !note.isRest &&
          note.midi != null &&
          widget.onNoteTapped != null) {
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
                          widget.oneFingerPan ||
                          widget.inputMode == 'off' ||
                          _multiPointerGesture,
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
                                      keyNames: measureKeyNames(widget.score),
                                      chordRects: _chordRects,
                                      highlightedMeasureIndex:
                                          widget.highlightedMeasureIndex,
                                      highlightedRange:
                                          widget.highlightedMeasureRange,
                                      selectedNoteAddress:
                                          widget.selectedNoteAddress,
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
                                      ghostDots: widget.inputDots,
                                      caret: _caretRect(layout),
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

  Offset? _pointerDownAt;

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
    _pointerDownAt = event.position;
    if (_activePointers.length > 1) {
      if (!_multiPointerGesture) {
        _multiPointerGesture = true;
        _clearGhost();
        setState(() {});
      }
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
    final start = _pointerDownAt;
    final panned =
        (widget.onEventTapped != null || widget.inputMode == 'select') &&
        start != null &&
        (event.position - start).distance > kTouchSlop;
    final shouldCommit =
        !_multiPointerGesture && _activePointers.length == 1 && !panned;
    if (shouldCommit && _handlesPointerInput) {
      _commitInputAt(_scenePosition(event));
    }
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty && _multiPointerGesture) {
      setState(() => _multiPointerGesture = false);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty && _multiPointerGesture) {
      setState(() => _multiPointerGesture = false);
    }
    _clearGhost();
  }
}
