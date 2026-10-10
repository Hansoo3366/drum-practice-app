import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
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
import 'package:page_a_diddle/features/digital_score/presentation/playback_follow.dart';
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
    this.tempoPercent = 100,
    this.showZoomControls = true,
    required this.semanticsLabel,
    required this.playback,
    this.playbackVisible = false,
    this.onNoteTapped,
    this.onEventTapped,
    this.onStaffTapped,
    this.onNotePlaced,
    this.onSelectionDragged,
    this.onRangeDragged,
    this.onMeasureDoubleTapped,
    this.onTextTapped,
    this.metronome = false,
    this.soundingRange,
    this.onBlankTapped,
    this.onLongPressed,
    this.rangeHandles = false,
    this.onMeasureTapped,
    this.onMeasureMoved,
    this.onSystemsChanged,
    this.onNoteDragged,
    this.onPlayerIssue,
    this.highlightedMeasureIndex,
    this.highlightedMeasureRange,
    this.rehearsalMarks,
    this.selectedNoteAddress,
    this.alsoSelectedNotes = const [],
    this.keepPagesOnChange = false,
    this.engravingChunks,
    this.playbackXml,
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

  /// How fast the score plays, in percent of its written tempo.
  final int tempoPercent;

  /// The zoom buttons over the score. A view of one bar does without them:
  /// they would stand on the bar, and two fingers zoom as everywhere.
  final bool showZoomControls;
  final String semanticsLabel;
  final PianoScorePlaybackController playback;
  final bool playbackVisible;
  final ValueChanged<AlphaTabNoteTappedEvent>? onNoteTapped;

  /// Fires for notes and rests alike in `select` mode. When set, a drag that
  /// moves beyond the touch slop is treated as a pan, not a selection.
  final ValueChanged<ScoreEventAddress>? onEventTapped;
  final ValueChanged<AlphaTabStaffTappedEvent>? onStaffTapped;

  /// Fires in `place` mode: a line or space of the staff was pointed at,
  /// over one of the notes or rests that are there.
  final ValueChanged<NativeStaffPlace>? onNotePlaced;

  /// Fires in `select` mode when a finger that went down on a picked note
  /// ([selectedNoteAddress], [alsoSelectedNotes]) was moved and lifted: up
  /// or down by [steps] lines and spaces (up is positive), or to the side
  /// for an accidental ([alter]: +1 sharper, -1 flatter). The picked notes
  /// are what is moved; a finger on any other note moves the page.
  final void Function(int steps, int alter)? onSelectionDragged;

  /// Fires in `select` mode while a finger that was held down and then
  /// moved goes over the score, and while a range handle is dragged: the
  /// notes from [from] to [to] are meant. [from] stays where it began.
  final void Function(ScoreEventAddress from, ScoreEventAddress to)?
  onRangeDragged;

  /// Fires in `select` mode for two taps in a row on a bar.
  final ValueChanged<int>? onMeasureDoubleTapped;

  /// Fires in `select` mode for a tap on words of the score: a chord symbol
  /// (`harm`), a syllable (`verse`), a tempo mark (`tempo`) or written
  /// words (`dir`), as [kind] says. [address] is the note or rest they
  /// stand at.
  final void Function(ScoreEventAddress address, String kind)? onTextTapped;

  /// A click on every beat while the score plays, higher on the first of
  /// a bar.
  final bool metronome;

  /// The lowest and highest pitch the instrument (or a voice) reaches:
  /// notes outside it are marked in red. Null marks none.
  final ({int low, int high})? soundingRange;

  /// Fires in `select` mode for a tap on the page where nothing is: what
  /// was picked is let go, as when one clicks away from it.
  final VoidCallback? onBlankTapped;

  /// Fires in `select` mode when a finger held down on the score is lifted
  /// where it went down: the note or rest there is asked about, as with a
  /// long press or a right click in a notation program.
  final ValueChanged<ScoreEventAddress>? onLongPressed;

  /// Draws a round handle at each end of the picked notes; dragging one
  /// moves that end ([onRangeDragged]).
  final bool rangeHandles;
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

  /// More notes outlined along with [selectedNoteAddress]: a run of notes.
  final List<ScoreEventAddress> alsoSelectedNotes;

  /// Keeps the pages on screen while a changed score is engraved, instead
  /// of a blank page: an editor changes the score with every edit. Taps wait
  /// for the new pages, which the notes are counted by.
  final bool keepPagesOnChange;

  /// The score as a run of small scores, each engraved on its own and one
  /// under the other (the bars of [score] in order). In place of
  /// [engravingXml] for an editor: a chunk whose text is the same as before
  /// is not engraved again, so an edit costs one chunk and not the score.
  final List<String>? engravingChunks;

  /// With [engravingChunks]: the whole score as MusicXML for the player,
  /// asked for when it is to be played and not with every change.
  final String Function()? playbackXml;
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

  /// What each of [_chordRects] is ([VerovioTextLabel.kind]).
  List<String?> _chordKinds = const [];

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

  /// Whether a score is loaded for the engraver (and so for the player).
  var _engravable = false;
  String? _parseError;
  Offset? _ghostCenter;
  bool _ghostRest = false;
  double _ghostLineGap = nativeStaffLineGap;
  String _ghostDurationType = 'quarter';
  int _ghostAlter = 0;

  /// The pitch of the note to come, written above the finger that hides
  /// it.
  String? _ghostLabel;

  /// A picked note under a finger: where the finger went down, and how far
  /// it has carried the note.
  ({Offset down, NativeNotePlacement note, double gap})? _noteDrag;
  var _dragSteps = 0;
  var _dragAlter = 0;

  /// A run of notes being picked by a finger: the end that stays, and the
  /// end under the finger.
  ScoreEventAddress? _rangeFrom;
  ScoreEventAddress? _rangeAt;
  Timer? _holdTimer;

  /// Where the finger went down in `place` mode. The note or rest meant is
  /// the one under that point; moving the finger then chooses the line, and
  /// to the side an accidental.
  ({Offset view, Offset scene})? _placeDown;
  Duration? _lastTapAt;
  Offset? _lastTapPosition;

  /// How long a finger rests before what it does next picks a run of notes
  /// instead of moving the page.
  static const _holdTime = Duration(milliseconds: 350);
  static const _doubleTapTime = Duration(milliseconds: 320);

  bool get _fingerEdits => _noteDrag != null || _rangeFrom != null || _aiming;

  /// In `place` mode: a finger was held still, and now carries the note to
  /// come up and down the staff until it is lifted. A finger that moves
  /// before that moves the page; one that is lifted at once places the
  /// note where it tapped.
  var _aiming = false;

  /// In `place` mode: the finger went on to move the page.
  var _placePanned = false;
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
    widget.playback.attach(
      playPause: _playPause,
      stop: _stop,
      seek: _seek,
      playFromMeasure: _playFromMeasure,
    );
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
        !listEquals(oldWidget.engravingChunks, widget.engravingChunks) ||
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
      // Only the section boxes changed: the same music stays on screen
      // while the new boxes are engraved, instead of a blank page each time
      // a section is named.
      final sameMusic =
          oldWidget.engravingXml == widget.engravingXml &&
          oldWidget.engravingPageSize == widget.engravingPageSize &&
          identical(oldWidget.score, widget.score);
      _rebuildScore(
        keepPages: (sameMusic || widget.keepPagesOnChange) && _pages.isNotEmpty,
      );
      // The pages that stay show another score than the one now held.
      _pagesStale = !sameMusic && _pages.isNotEmpty;
    } else if (playbackConfigurationChanged) {
      if (widget.playback.state.playing) unawaited(_stop());
      _resetPlaybackState();
    } else if (oldWidget.tempoPercent != widget.tempoPercent) {
      unawaited(_retime(oldWidget.tempoPercent));
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
    _followTimer?.cancel();
    widget.playback.detach();
    _transform.dispose();
    // A view that never opened its player has no backend to stop; the
    // backend answers that with an error.
    unawaited(_audio.stop().then((_) {}, onError: (Object _) {}));
    unawaited(_audio.dispose().then((_) {}, onError: (Object _) {}));
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

  /// Sounds [midis] together for a moment, as a notation program lets a
  /// note be heard when it is written or moved. Not while the score plays.
  Future<void> sound(List<int> midis) async {
    if (!mounted || midis.isEmpty || widget.playback.state.playing) return;
    if (!_audioReady) await _ensureAudio();
    if (!mounted || !_audioReady || widget.playback.state.playing) return;
    try {
      await _audio.stop();
      await _audio.clearScheduledEvents();
      await _audio.setTicksPerQuarter(480);
      await _audio.setTempo(120);
      for (final midi in midis) {
        await _audio.scheduleNote(
          midiNote: midi.clamp(0, 127),
          startTick: 0,
          durationTicks: 400,
          velocity: 84,
        );
      }
      await _audio.start();
    } on Object {
      // No sound is not a reason to stop writing.
    }
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

  void _rebuildScore({bool keepPages = false}) {
    final generation = ++_renderGeneration;
    if (widget.engravingChunks case final chunks?) {
      _engravable = true;
      _parseError = null;
      if (!keepPages) {
        _pages = const <_VerovioPage>[];
        _layout = null;
      }
      _rendering = _renderChunks(
        chunks,
        generation,
        publishWhenDone: keepPages,
      );
      _resetPlaybackState();
      return;
    }
    try {
      // The engraver reads the document in its own isolate, and the player
      // builds its MIDI in another: nothing parses the score here, which on
      // a long score made Android appear to hang before Verovio started.
      final writtenXml =
          widget.engravingXml ??
          utf8.decode(_codec.encodeMusicXml(widget.score));
      final marks = widget.rehearsalMarks;
      final visualXml = marks == null
          ? writtenXml
          : withSectionRehearsals(writtenXml, marks);
      _engravable = true;
      _parseError = null;
      if (!keepPages) {
        _pages = const <_VerovioPage>[];
        _layout = null;
      }
      _rendering = _renderWithVerovio(
        visualXml,
        generation,
        publishWhenDone: keepPages,
      );
    } catch (_) {
      _engravable = false;
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
    // An editor's score changes with every edit: its MIDI is made when it
    // is played.
    if (widget.playbackVisible && widget.playbackXml == null) {
      unawaited(_playbackMidi().then((_) {}, onError: (Object _) {}));
    }
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
      return quarters * 60000 / bpm / _speed;
    } on FormatException {
      return estimateScoreDurationMs(widget.playbackScore ?? widget.score) /
          _speed;
    }
  }

  /// The practice tempo as a factor: every time the player shows is the
  /// time the listener hears, at this speed.
  double get _speed => widget.tempoPercent.clamp(10, 400) / 100;

  /// The tempo was changed: the place in the music stays, its time and the
  /// length of the piece change, and what is playing goes on at the new
  /// tempo.
  Future<void> _retime(int fromPercent) async {
    final state = widget.playback.state;
    final ratio = fromPercent / widget.tempoPercent;
    final wasPlaying = state.playing;
    if (wasPlaying) {
      _playbackTimer?.cancel();
      _playbackTimer = null;
      try {
        await _audio.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    widget.playback.replaceState(
      widget.playback.state.copyWith(
        playing: false,
        currentTimeMs: state.currentTimeMs * ratio,
        durationMs: state.durationMs * ratio,
      ),
    );
    if (wasPlaying) await _playPause();
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

  /// The pages of each chunk already engraved ([VerovioScoreView
  /// .engravingChunks]), by the chunk's text, for [_chunkPageSize].
  Map<String, List<_VerovioPage>> _chunkPages = {};
  Size? _chunkPageSize;

  /// Engraves [chunks] one under the other. A chunk engraved before is
  /// taken as it is. Pages come on screen as they are ready, or with
  /// [publishWhenDone] all at once.
  Future<void> _renderChunks(
    List<String> chunks,
    int generation, {
    bool publishWhenDone = false,
  }) async {
    try {
      final timeout = _verovioOperationTimeout;
      final service = await _getService().timeout(timeout);
      _lineStarts = const [];
      if (_chunkPageSize != widget.engravingPageSize) {
        _chunkPages = {};
        _chunkPageSize = widget.engravingPageSize;
      }
      var optionsSet = false;
      final kept = <String, List<_VerovioPage>>{};
      final pages = <_VerovioPage>[];
      for (var index = 0; index < chunks.length; index++) {
        final chunk = chunks[index];
        var made = _chunkPages[chunk] ?? kept[chunk];
        if (made == null) {
          if (!optionsSet) {
            await service
                .setOptionsJson(
                  jsonEncode({
                    ..._verovioOptions,
                    // Every chunk is one line of the score, whatever its
                    // bars hold: no break is written in it, so its bars are
                    // set on one line of the full width.
                    'breaks': 'line',
                    'minLastJustification': 0,
                    if (widget.engravingPageSize case final size?) ...{
                      'pageWidth': size.width.round(),
                      'pageHeight': size.height.round(),
                    },
                  }),
                )
                .timeout(timeout);
            optionsSet = true;
          }
          await service.loadData(chunk).timeout(timeout);
          final pageCount = await service.pageCount.timeout(timeout);
          made = <_VerovioPage>[];
          for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
            final svg = await service
                .renderToSvg(pageIndex + 1)
                .timeout(timeout);
            final hitMap = await service
                .parseHitMap(
                  svg,
                  pageIndex: pageIndex,
                  config: const ParseConfig(
                    captureClasses: {
                      'note',
                      'rest',
                      'measure',
                      'staff',
                      'clef',
                    },
                  ),
                )
                .timeout(timeout);
            final prepared = await prepareVerovioPage(svg);
            made.add(
              _VerovioPage(
                svg: prepared.svg,
                hitMap: hitMap,
                chords: prepared.labels,
                staves: prepared.staves,
              ),
            );
          }
          if (!mounted || generation != _renderGeneration) return;
        }
        kept[chunk] = made;
        pages.addAll(made);
        final last = index == chunks.length - 1;
        // A long score comes on screen a few lines at a time.
        if (!last && (publishWhenDone || index % 4 != 3)) continue;
        _pages = List<_VerovioPage>.unmodifiable(pages);
        _pagesStale = false;
        _parseError = null;
        _rebuildRenderedLayout(_lastViewportWidth ?? 360);
        _notifySystemsChanged();
        setState(() {});
      }
      _chunkPages = kept;
    } catch (error) {
      if (!mounted || generation != _renderGeneration) return;
      if (_pages.isEmpty) {
        _layout = null;
        _parseError = error is TimeoutException
            ? '악보 렌더링 시간이 초과되었습니다.'
            : '악보를 표시할 수 없습니다.';
      }
      _pagesStale = false;
      setState(() {});
    }
  }

  /// Engraves [xml] page by page. Pages replace what is on screen as they
  /// arrive, or, with [publishWhenDone], all at once at the end (the pages
  /// shown meanwhile are those of the same music).
  Future<void> _renderWithVerovio(
    String xml,
    int generation, {
    bool publishWhenDone = false,
  }) async {
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
      await service.loadData(engravingMusicXml(xml)).timeout(timeout);
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
        final prepared = await prepareVerovioPage(svg);
        pages.add(
          _VerovioPage(
            svg: prepared.svg,
            hitMap: hitMap,
            chords: prepared.labels,
            staves: prepared.staves,
          ),
        );
        if (!mounted || generation != _renderGeneration) return;
        if (publishWhenDone && pageIndex < pageCount - 1) continue;
        // Publish each page as soon as it is ready. Large scores can contain
        // many A4 pages; waiting for every page made the entire viewer look
        // stuck even when the first page had already been engraved.
        _pages = List<_VerovioPage>.unmodifiable(pages);
        _pagesStale = false;
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

  /// Whether the pages on screen are still those of the score before the
  /// last change ([VerovioScoreView.keepPagesOnChange]).
  bool _pagesStale = false;

  /// Brings a bar into view, as playback does for the bar being played.
  void showMeasure(int measureIndex) => _followPlayback(measureIndex);

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
      await service.loadData(engravingMusicXml(xml)).timeout(timeout);
      final pageCount = await service.pageCount.timeout(timeout);
      final pages = <EngravedPage>[];
      for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
        final svg = await service.renderToSvg(pageIndex + 1).timeout(timeout);
        final box = RegExp(
          r'<svg\b[^>]*\bviewBox="([^"]+)"',
        ).firstMatch(svg)?.group(1);
        final size = box == null ? null : _parseSvgViewBoxSize(box);
        if (size == null) continue;
        final prepared = await prepareVerovioPage(svg);
        pages.add(
          EngravedPage(
            svg: prepared.svg,
            labels: prepared.labels,
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
    final chordKinds = <String?>[];
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
      // Bars whose staff lines were read from the drawing: their pitches are
      // where the lines are, and need not be estimated from the notes.
      final drawnStaves = <int, Map<int, _StaffGeometry>>{};
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
        final lines = [
          for (final staff in page.staves)
            if (hit.bbox.inflate(4).contains(staff.center)) staff,
        ]..sort((a, b) => a.top.compareTo(b.top));
        final drawn = <int, _StaffGeometry>{};
        if (lines.length >= math.min(2, staffCount)) {
          final clefs = measureIndex < (part?.measures.length ?? 0)
              ? part!.measures[measureIndex].attributes.clefs
              : const <int, MusicClef>{};
          for (var staff = 1; staff <= math.min(2, staffCount); staff++) {
            final gap = lines[staff - 1].gap * scale;
            drawn[staff] = _StaffGeometry(
              top: staffAnchorFromLines(
                bottomLine: _scaledPoint(
                  Offset(0, lines[staff - 1].bottom),
                  scale,
                  pageTop,
                ).dy,
                lineGap: gap,
                clef: clefs[staff],
                staff: staff,
              ),
              lineGap: gap,
            );
          }
          drawnStaves[measureIndex] = drawn;
        }
        final box = NativeMeasureBox(
          measureIndex: measureIndex,
          rect: rect.inflate(2),
          trebleStaffTop: drawn[1]?.top ?? frame.trebleStaffTop,
          bassStaffTop: drawn[2]?.top ?? frame.bassStaffTop,
          lineGap: drawn[1]?.lineGap ?? frame.lineGap,
          contentLeft: contentLeft,
          contentWidth: math.max(12, rect.left + rect.width - 8 - contentLeft),
          staffTops: {
            1: drawn[1]?.top ?? frame.trebleStaffTop,
            if (staffCount > 1) 2: drawn[2]?.top ?? frame.bassStaffTop,
          },
          staffLineGaps: {
            1: drawn[1]?.lineGap ?? frame.lineGap,
            if (staffCount > 1) 2: drawn[2]?.lineGap ?? frame.lineGap,
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
            final drawn = drawnStaves[absoluteIndex];
            for (var staff = 1; staff <= math.min(2, staffCount); staff++) {
              final geometry = drawn?[staff] ?? fittedByStaff[staff]!;
              staffTops[staff] = geometry.top;
              staffLineGaps[staff] = geometry.lineGap;
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
        chordKinds.add(chord.kind);
      }
      pageTop += pageHeight;
    }

    _documentWidth = viewWidth;
    _documentHeight = math.max(pageTop, 240);
    _chordRects = List.unmodifiable(chordRects);
    _chordKinds = List.unmodifiable(chordKinds);
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
      // The bar that plays is drawn from the playing state.
      if (mounted) setState(() {});
      return true;
    }
    if (!_engravable) {
      widget.onPlayerIssue?.call();
      return false;
    }
    final nm.MidiSequence sequence;
    final MidiTiming timing;
    try {
      final midi = await _playbackMidi();
      final speed = _speed;
      timing = _timingOf(midi);
      // The player starts at its first tick and keeps one tempo: the place
      // to go on from, the score's tempo changes and the practice tempo
      // are written into what it is given.
      sequence = playableSequence(
        widget.metronome ? _withClicks(midi.sequence) : midi.sequence,
        timing,
        fromMs: widget.playback.state.currentTimeMs * speed,
        speed: speed,
      );
      await _setInstruments(midi);
      if (widget.metronome) {
        try {
          await _audio.setChannelProgram(
            channel: metronomeChannel,
            program: metronomeProgram,
            volume: 1,
          );
        } on Object {
          // The click then sounds like the piano.
        }
      }
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
        durationMs: timing.durationMs / _speed,
        measureNumber: _measureForTime(widget.playback.state.currentTimeMs) + 1,
      ),
    );
    // The playing bar shows from the first moment, not from the next bar.
    if (mounted) setState(() {});
    _followPlayback(widget.playback.state.measureNumber - 1);
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
      final moved = widget.playback.state.measureNumber != measure + 1;
      // The playback bar follows the controller; the score itself only
      // changes when playing reaches another bar.
      widget.playback.replaceState(
        widget.playback.state.copyWith(
          currentTimeMs: elapsed.toDouble(),
          measureNumber: measure + 1,
          beatIndex: 0,
        ),
      );
      if (moved) {
        setState(() {});
        _followPlayback(measure);
      }
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
    // The timing read from the MIDI before goes with it.
    _timing = null;
    _starts = null;
    _midiFor = (
      xml: widget.engravingXml,
      score: widget.score,
      sequence: widget.playbackSequence,
      arrangement: widget.playbackArrangement,
      bpm: bpm,
    );
    final future = buildPlaybackMidiInBackground(
      engravingXml: widget.playbackXml?.call() ?? widget.engravingXml,
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
        final before = widget.playback.state;
        final duration = _timingOf(midi).durationMs / _speed;
        // A place already chosen (a pressed bar, a moved slider) keeps its
        // share of the piece.
        final share = before.durationMs > 0
            ? before.currentTimeMs / before.durationMs
            : 0.0;
        widget.playback.replaceState(
          before.copyWith(
            durationMs: duration,
            currentTimeMs: share * duration,
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

  /// [sequence] with a click on every beat of the bars as they are played.
  nm.MidiSequence _withClicks(nm.MidiSequence sequence) {
    _measureForTime(0);
    final timeline = _timeline;
    if (timeline == null || widget.score.parts.isEmpty) return sequence;
    final measures = widget.score.parts.first.measures;
    return withMetronomeClicks(sequence, [
      for (final index in timeline.map)
        if (index < timeline.lengths.length && index < measures.length)
          (
            quarters: timeline.lengths[index],
            beat: switch (measures[index].attributes.time) {
              // Three eighths to the beat in 6/8, 9/8 and 12/8.
              final time? when time.beatType == 8 && time.beats % 3 == 0 => 1.5,
              final time? => 4 / time.beatType,
              null => 1.0,
            },
          ),
    ]);
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
    _followPlayback(widget.playback.state.measureNumber - 1);
    return true;
  }

  /// Plays from the start of the written bar [measureIndex]: what a press
  /// on a bar means while the player is open.
  Future<bool> _playFromMeasure(int measureIndex) async {
    if (!widget.playbackVisible) return false;
    final state = widget.playback.state;
    final duration = state.durationMs;
    if (!duration.isFinite || duration <= 0) return false;
    _measureForTime(state.currentTimeMs);
    final timeline = _timeline;
    if (timeline == null) return false;
    final starts = _barStarts(timeline.map, timeline.lengths);
    double? at;
    if (starts != null) {
      // Of the times the order plays this bar, the one nearest to now.
      for (var i = 0; i < timeline.map.length; i++) {
        if (timeline.map[i] != measureIndex) continue;
        if (at == null ||
            (starts[i] - state.currentTimeMs).abs() <
                (at - state.currentTimeMs).abs()) {
          at = starts[i];
        }
      }
    } else {
      final start = performanceStartOf(
        timeline.map,
        timeline.lengths,
        measureIndex,
        near: state.currentTimeMs / duration,
      );
      at = start == null ? null : start * duration;
    }
    if (at == null) return false;
    // A moment inside the bar: its first instant is also the last of the
    // bar before.
    await _seek(at + 1);
    if (!widget.playback.state.playing) return _playPause();
    return true;
  }

  Timer? _followTimer;
  Size? _viewport;

  /// Moves the score so the bar being played is on screen, unless a finger
  /// is on it: the reader's own move wins.
  void _followPlayback(int measureIndex) {
    final layout = _layout;
    final viewport = _viewport;
    if (!mounted || layout == null || viewport == null) return;
    if (_activePointers.isNotEmpty) return;
    Rect? bar;
    for (final measure in layout.measures) {
      if (measure.measureIndex != measureIndex) continue;
      bar = bar == null ? measure.rect : bar.expandToInclude(measure.rect);
    }
    if (bar == null) return;
    final from = _transform.value.getTranslation();
    final scale = _transform.value.getMaxScaleOnAxis();
    final start = Offset(from.x, from.y);
    final target = playbackFollowTranslation(
      bar: bar,
      viewport: viewport,
      document: Size(
        math.max(viewport.width, _documentWidth),
        math.max(viewport.height, _documentHeight),
      ),
      scale: scale,
      translation: start,
    );
    if (target == null) return;
    _followTimer?.cancel();
    const steps = 14;
    var step = 0;
    _followTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _activePointers.isNotEmpty) {
        timer.cancel();
        return;
      }
      step++;
      final t = Curves.easeOutCubic.transform(step / steps);
      final at = Offset.lerp(start, target, t)!;
      _transform.value = Matrix4.identity()
        ..translateByDouble(at.dx, at.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      if (step >= steps) timer.cancel();
    });
  }

  /// Written bar playing at [ms]. The performance may repeat or skip bars,
  /// so the playback position maps through the performance bar order and
  /// each bar's real length rather than a uniform bar count.
  int _measureForTime(num ms) {
    final duration = math.max(1.0, widget.playback.state.durationMs);
    // Asked twenty times a second while playing: the bar order and the bar
    // lengths are worked out once per score and order.
    var timeline = _timeline;
    if (timeline == null ||
        !identical(timeline.score, widget.score) ||
        timeline.sequence != widget.playbackSequence) {
      timeline = _timeline = (
        score: widget.score,
        sequence: widget.playbackSequence,
        map: performanceMeasureMap(widget.score, widget.playbackSequence),
        lengths: measureQuarterLengths(widget.score),
      );
    }
    final starts = _barStarts(timeline.map, timeline.lengths);
    if (starts != null) {
      // The last bar that has begun.
      var low = 0;
      var high = starts.length - 1;
      while (low < high) {
        final mid = (low + high + 1) >> 1;
        if (starts[mid] <= ms) {
          low = mid;
        } else {
          high = mid - 1;
        }
      }
      return timeline.map[low];
    }
    return writtenMeasureAt(timeline.map, timeline.lengths, ms / duration);
  }

  /// The timing of the MIDI that plays, read once per MIDI.
  MidiTiming _timingOf(PlaybackMidi midi) {
    final known = _timing;
    if (known != null && identical(known.midi, midi)) return known.timing;
    final timing = MidiTiming(
      midi.sequence,
      fallbackBpm: (widget.score.tempoBpm ?? 120).round(),
    );
    _timing = (midi: midi, timing: timing);
    _starts = null;
    return timing;
  }

  ({PlaybackMidi midi, MidiTiming timing})? _timing;
  ({List<int> map, int percent, MidiTiming timing, List<double> ms})? _starts;

  /// When each bar of the order begins, in the listener's time, once the
  /// MIDI is known: a ritardando makes bars longer than their note values
  /// say, and the bar shown has to be the bar heard. Null before the MIDI
  /// exists; the bars are then spread evenly.
  List<double>? _barStarts(List<int> map, List<double> lengths) {
    final timing = _timing?.timing;
    if (timing == null || map.isEmpty) return null;
    final known = _starts;
    if (known != null &&
        identical(known.map, map) &&
        identical(known.timing, timing) &&
        known.percent == widget.tempoPercent) {
      return known.ms;
    }
    final total = map.fold<double>(0, (sum, index) => sum + lengths[index]);
    if (total <= 0) return null;
    final speed = _speed;
    final ms = <double>[];
    var elapsed = 0.0;
    for (final index in map) {
      ms.add(timing.msAt(elapsed / total * timing.totalTicks) / speed);
      elapsed += lengths[index];
    }
    _starts = (map: map, percent: widget.tempoPercent, timing: timing, ms: ms);
    return ms;
  }

  ({
    MusicScore score,
    PlaybackSequence sequence,
    List<int> map,
    List<double> lengths,
  })?
  _timeline;

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
      _ghostLabel = null;
    });
  }

  double get _viewScale => _transform.value.getMaxScaleOnAxis();

  /// Whether [content] is on the staff [place] is of, or within a few
  /// lines and spaces of it: where a quick tap may write a note.
  bool _nearStaff(
    NativeScoreLayout layout,
    NativeStaffPlace place,
    Offset content,
  ) {
    for (final box in layout.measures) {
      if (box.measureIndex != place.measureIndex) continue;
      final gap = box.lineGapFor(place.staff);
      final bottom = box.staffTopFor(place.staff);
      final top = bottom - 4 * gap;
      final away = content.dy < top
          ? top - content.dy
          : (content.dy > bottom ? content.dy - bottom : 0.0);
      return away <= gap * tapReachSpaces;
    }
    return true;
  }

  /// The words of the score under [content], if any: whether they stand
  /// above their staff or under it, and the note or rest they belong to.
  ({ScoreEventAddress address, String kind})? _textAt(
    NativeScoreLayout layout,
    Offset content,
  ) {
    final reach = 4 / _viewScale;
    for (final (index, rect) in _chordRects.indexed) {
      if (!rect.inflate(reach).contains(content)) continue;
      // Bar numbers, ending numbers and section boxes are not words to
      // correct here.
      final kind = index < _chordKinds.length ? _chordKinds[index] : null;
      if (!const {'harm', 'verse', 'tempo', 'dir'}.contains(kind)) continue;
      final center = rect.center;
      // The bar the words are over or under: the nearest of those at
      // their place across the page.
      NativeMeasureBox? box;
      var nearest = double.infinity;
      for (final measure in layout.measures) {
        final bar = measure.rect;
        if (center.dx < bar.left || center.dx > bar.right) continue;
        final away = center.dy < bar.top
            ? bar.top - center.dy
            : (center.dy > bar.bottom ? center.dy - bar.bottom : 0.0);
        if (away < nearest) {
          nearest = away;
          box = measure;
        }
      }
      if (box == null) continue;
      final staves = box.staffTops.keys.toList()..sort();
      if (staves.isEmpty) staves.add(1);
      final top =
          box.staffTopFor(staves.first) - 4 * box.lineGapFor(staves.first);
      // A chord symbol and a tempo mark stand over the staff; a syllable
      // belongs to the staff it is under.
      final above = kind != 'verse' && center.dy < top;
      // Words under a staff belong to the staff they are under.
      var staff = staves.first;
      if (!above) {
        var found = false;
        for (final candidate in staves) {
          if (box.staffTopFor(candidate) < center.dy) {
            staff = candidate;
            found = true;
          }
        }
        if (!found) continue;
      }
      NativeNotePlacement? note;
      var off = double.infinity;
      for (final candidate in layout.notes) {
        if (candidate.measureIndex != box.measureIndex ||
            candidate.staff != staff) {
          continue;
        }
        // A chord symbol begins at its note; a syllable is centred on it.
        final distance = (candidate.center.dx - (above ? rect.left : center.dx))
            .abs();
        if (distance < off) {
          off = distance;
          note = candidate;
        }
      }
      if (note == null) continue;
      return (
        address: ScoreEventAddress(
          partIndex: note.partIndex,
          measureIndex: note.measureIndex,
          eventIndex: note.eventIndex,
        ),
        kind: kind!,
      );
    }
    return null;
  }

  /// The place meant in `place` mode by a finger at [content]: the note or
  /// rest under the point where it went down, on the line it is on now.
  NativeStaffPlace? _placeUnderFinger(
    NativeScoreLayout layout,
    Offset content,
    Offset? view,
  ) {
    final down = _placeDown;
    if (down == null || view == null) {
      return layout.placeAt(content, score: widget.score);
    }
    final place = layout.placeAt(
      Offset(down.scene.dx, content.dy),
      score: widget.score,
    );
    if (place == null) return null;
    if (!_aiming) return place;
    final alter = fingerCarry(
      view - down.view,
      lineGap: place.lineGap,
      scale: _viewScale,
    ).alter;
    return alter == 0 ? place : place.withAlter(alter);
  }

  static String _pitchName(PitchStep step, int octave, int alter) {
    final sign = switch (alter) {
      > 0 => '♯',
      < 0 => '♭',
      _ => '',
    };
    return '${step.name.toUpperCase()}$sign$octave';
  }

  bool _isPicked(NativeNotePlacement note) {
    bool same(ScoreEventAddress? address) =>
        address != null &&
        address.partIndex == note.partIndex &&
        address.measureIndex == note.measureIndex &&
        address.eventIndex == note.eventIndex;
    return same(widget.selectedNoteAddress) ||
        widget.alsoSelectedNotes.any(same);
  }

  /// The note or rest a finger at [content] means: the one it is on, or
  /// the one of the staff under it that is nearest in time.
  ScoreEventAddress? _eventNear(NativeScoreLayout layout, Offset content) {
    final note = layout.noteAt(content, includeRests: true);
    if (note != null) {
      return ScoreEventAddress(
        partIndex: note.partIndex,
        measureIndex: note.measureIndex,
        eventIndex: note.eventIndex,
      );
    }
    final place = layout.placeAt(content, score: widget.score);
    if (place == null) return null;
    return ScoreEventAddress(
      partIndex: 0,
      measureIndex: place.measureIndex,
      eventIndex: place.eventIndex,
    );
  }

  /// The two ends of the picked notes as they are drawn, first and last in
  /// reading order, with the point where each one's handle stands.
  ({
    ScoreEventAddress first,
    Offset firstAt,
    ScoreEventAddress last,
    Offset lastAt,
  })?
  _handles(NativeScoreLayout layout) {
    if (!widget.rangeHandles) return null;
    final picked = [?widget.selectedNoteAddress, ...widget.alsoSelectedNotes];
    if (picked.length < 2) return null;
    picked.sort(
      (a, b) => a.measureIndex != b.measureIndex
          ? a.measureIndex.compareTo(b.measureIndex)
          : a.eventIndex.compareTo(b.eventIndex),
    );
    Offset? at(ScoreEventAddress address, {required bool left}) {
      for (final note in layout.notes) {
        if (note.measureIndex != address.measureIndex ||
            note.eventIndex != address.eventIndex ||
            note.partIndex != address.partIndex) {
          continue;
        }
        NativeMeasureBox? box;
        for (final measure in layout.measures) {
          if (measure.measureIndex == note.measureIndex) {
            box = measure;
            break;
          }
        }
        final bounds = note.bounds;
        final x = bounds == null
            ? note.center.dx
            : (left ? bounds.left : bounds.right);
        // Under the staff, clear of the notes it would cover.
        final y = math.max(
          box?.rect.bottom ?? note.center.dy,
          (bounds?.bottom ?? note.center.dy),
        );
        return Offset(x, y);
      }
      return null;
    }

    final firstAt = at(picked.first, left: true);
    final lastAt = at(picked.last, left: false);
    if (firstAt == null || lastAt == null) return null;
    return (
      first: picked.first,
      firstAt: firstAt,
      last: picked.last,
      lastAt: lastAt,
    );
  }

  /// The radius of a range handle on the page, the same on screen at any
  /// zoom.
  double get _handleRadius => 9 / _viewScale;

  void _beginRange(ScoreEventAddress from, ScoreEventAddress at) {
    _holdTimer?.cancel();
    setState(() {
      _rangeFrom = from;
      _rangeAt = at;
    });
    widget.onRangeDragged?.call(from, at);
  }

  void _endFingerEdit() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!_fingerEdits && _ghostCenter == null && !_placePanned) return;
    setState(() {
      _noteDrag = null;
      _dragSteps = 0;
      _dragAlter = 0;
      _rangeFrom = null;
      _rangeAt = null;
      _aiming = false;
      _placePanned = false;
      _ghostCenter = null;
      _ghostRest = false;
      _ghostLabel = null;
    });
  }

  /// What a finger going down in `select` mode starts: carrying the picked
  /// notes, moving an end of the run, or, held still, picking a run.
  void _beginSelectGesture(PointerDownEvent event) {
    final layout = _layout;
    if (layout == null || _pagesStale) return;
    final scene = _scenePosition(event);
    if (widget.onRangeDragged != null) {
      final handles = _handles(layout);
      if (handles != null) {
        final reach = _handleRadius * 2.2;
        if ((handles.lastAt.translate(0, _handleRadius) - scene).distance <=
            reach) {
          _beginRange(handles.first, handles.last);
          return;
        }
        if ((handles.firstAt.translate(0, _handleRadius) - scene).distance <=
            reach) {
          _beginRange(handles.last, handles.first);
          return;
        }
      }
    }
    final note = layout.noteAt(scene);
    if (note != null && widget.onSelectionDragged != null && _isPicked(note)) {
      NativeMeasureBox? box;
      for (final measure in layout.measures) {
        if (measure.measureIndex == note.measureIndex) {
          box = measure;
          break;
        }
      }
      setState(() {
        _noteDrag = (
          down: event.localPosition,
          note: note,
          gap: box?.lineGapFor(note.staff) ?? nativeStaffLineGap,
        );
        _dragSteps = 0;
        _dragAlter = 0;
      });
      return;
    }
    if (widget.onRangeDragged == null) return;
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdTime, () {
      _holdTimer = null;
      if (!mounted || _activePointers.length != 1 || _multiPointerGesture) {
        return;
      }
      final now = _layout;
      if (now == null || _pagesStale) return;
      final from = _eventNear(now, scene);
      if (from == null) return;
      unawaited(HapticFeedback.selectionClick());
      _beginRange(from, from);
    });
  }

  void _moveSelectGesture(PointerMoveEvent event) {
    final start = _pointerDownAt;
    if (_holdTimer != null &&
        start != null &&
        (event.position - start).distance > kTouchSlop) {
      // Moved before it was held: the page is what moves.
      _holdTimer?.cancel();
      _holdTimer = null;
    }
    final layout = _layout;
    if (layout == null) return;
    if (_noteDrag case final drag?) {
      final (:steps, :alter) = fingerCarry(
        event.localPosition - drag.down,
        lineGap: drag.gap,
        scale: _viewScale,
      );
      if (steps == _dragSteps && alter == _dragAlter) return;
      setState(() {
        _dragSteps = steps;
        _dragAlter = alter;
        if (steps == 0 && alter == 0) {
          _ghostCenter = null;
        } else {
          _ghostCenter = drag.note.center.translate(0, -steps * drag.gap / 2);
          _ghostRest = false;
          _ghostLineGap = drag.gap;
          _ghostDurationType = 'quarter';
          _ghostAlter = alter;
          _ghostLabel = null;
        }
      });
      return;
    }
    final from = _rangeFrom;
    if (from != null) {
      final at = _eventNear(layout, _scenePosition(event));
      if (at == null || at == _rangeAt) return;
      setState(() => _rangeAt = at);
      widget.onRangeDragged?.call(from, at);
    }
  }

  void _updateInputAt(Offset content, {Offset? view}) {
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
    if (widget.inputMode == 'place') {
      final place = _placeUnderFinger(layout, content, view);
      if (place == null) {
        _clearGhost();
        return;
      }
      setState(() {
        _ghostCenter = place.ghostCenter;
        _ghostRest = false;
        _ghostLineGap = place.lineGap;
        _ghostDurationType = 'quarter';
        _ghostAlter = place.alter;
        _ghostLabel = _pitchName(place.step, place.octave, place.alter);
      });
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

  void _commitInputAt(Offset content, {Offset? view}) {
    final layout = _layout;
    if (layout == null) return;
    // What is on screen is the score before the last edit: its notes are
    // not counted as the notes of the score now.
    if (_pagesStale) return;
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
      if (widget.onTextTapped != null && widget.inputMode == 'select') {
        if (_textAt(layout, content) case final text?) {
          widget.onTextTapped!(text.address, text.kind);
          return;
        }
      }
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
        } else {
          widget.onBlankTapped?.call();
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
    if (widget.inputMode == 'place') {
      final place = _placeUnderFinger(layout, content, view);
      _clearGhost();
      if (place == null) return;
      // A tap writes where it falls only on the staff or near it: one on
      // the words under the staff, or between two lines of the score, is
      // not a note four ledger lines down. A finger held still may carry
      // the note as far as ledger lines reach.
      if (!_aiming && view != null && !_nearStaff(layout, place, content)) {
        return;
      }
      widget.onNotePlaced?.call(place);
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
    // The score is on white paper whatever the app's theme: what is drawn
    // over it (zoom buttons) takes the light theme's colours, or it would
    // be light on white in a dark theme.
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: Theme(
        data: AppTheme.light,
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
              _viewport = Size(viewW, viewH);
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
                        // Room to pull past the top and the bottom, none to
                        // the sides: a score as wide as the screen that
                        // slides sideways is a score cut off at one side.
                        boundaryMargin: const EdgeInsets.symmetric(
                          vertical: 48,
                        ),
                        clipBehavior: Clip.hardEdge,
                        minScale: 0.35,
                        maxScale: 4,
                        scaleFactor: _mouseScrollScaleFactor,
                        // Trackpad scroll is a pan in MuseScore/forScore-style
                        // score navigation. Pinch remains the zoom gesture.
                        trackpadScrollCausesScale: false,
                        // A finger carrying a note or picking a run of
                        // notes does not move the page as well.
                        panEnabled:
                            !_fingerEdits &&
                            (widget.oneFingerPan ||
                                widget.inputMode == 'off' ||
                                _multiPointerGesture),
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
                                        alsoSelected: widget.alsoSelectedNotes,
                                        // The bar being played, and when
                                        // paused the bar it stopped in.
                                        playbackMeasure:
                                            widget.playbackVisible &&
                                                (widget
                                                        .playback
                                                        .state
                                                        .playing ||
                                                    widget
                                                            .playback
                                                            .state
                                                            .currentTimeMs >
                                                        0)
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
                                        soundingRange: widget.soundingRange,
                                        ghostLabel: _ghostLabel,
                                        viewScale: _viewScale,
                                        handles: _handles(layout),
                                        handleRadius: _handleRadius,
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
                  if (widget.showZoomControls)
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
    var x = translation.x - delta.dx;
    var y = translation.y - delta.dy;
    // Like a finger, a wheel does not move the score off the screen.
    if (_viewport case final viewport?) {
      final scale = next.getMaxScaleOnAxis();
      x = x.clamp(math.min(0.0, viewport.width - _documentWidth * scale), 0.0);
      y = y.clamp(
        math.min(0.0, viewport.height - _documentHeight * scale) - 48,
        48.0,
      );
    }
    next.setTranslationRaw(x, y, translation.z);
    _transform.value = next;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _pointerDownAt = event.position;
    if (_activePointers.length > 1) {
      // Two fingers move and zoom the page, whatever one had begun.
      _placeDown = null;
      _endFingerEdit();
      if (!_multiPointerGesture) {
        _multiPointerGesture = true;
        _clearGhost();
        setState(() {});
      }
      return;
    }
    if (widget.inputMode == 'select') _beginSelectGesture(event);
    if (_handlesPointerInput) {
      final scene = _scenePosition(event);
      _placePanned = false;
      if (widget.inputMode == 'place' &&
          event.kind != PointerDeviceKind.mouse) {
        _placeDown = (view: event.localPosition, scene: scene);
        // Held still, the finger takes the note to come and carries it.
        _holdTimer?.cancel();
        _holdTimer = Timer(_holdTime, () {
          _holdTimer = null;
          if (!mounted ||
              _placeDown == null ||
              _placePanned ||
              _activePointers.length != 1 ||
              _multiPointerGesture) {
            return;
          }
          unawaited(HapticFeedback.selectionClick());
          setState(() => _aiming = true);
        });
      } else {
        _placeDown = widget.inputMode == 'place'
            ? (view: event.localPosition, scene: scene)
            : null;
        // A mouse has its wheel for the page: its button carries the note
        // from the start.
        if (_placeDown != null) _aiming = true;
      }
      _updateInputAt(scene, view: event.localPosition);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_multiPointerGesture || _activePointers.length != 1) return;
    if (widget.inputMode == 'select') _moveSelectGesture(event);
    if (_handlesPointerInput) {
      if (widget.inputMode == 'place' && !_aiming) {
        final start = _pointerDownAt;
        if (!_placePanned &&
            start != null &&
            (event.position - start).distance > kTouchSlop) {
          // Moved before it was held: the page is what moves.
          _holdTimer?.cancel();
          _holdTimer = null;
          _placePanned = true;
          _clearGhost();
        }
        return;
      }
      _updateInputAt(_scenePosition(event), view: event.localPosition);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final start = _pointerDownAt;
    final panned =
        (widget.onEventTapped != null || widget.inputMode == 'select') &&
        start != null &&
        (event.position - start).distance > kTouchSlop;
    final single = !_multiPointerGesture && _activePointers.length == 1;
    // A finger that carried the picked notes or picked a run of them has
    // done its work: it is not a tap as well.
    final steps = _dragSteps;
    final alter = _dragAlter;
    final carried = _noteDrag != null && (steps != 0 || alter != 0);
    final ranged = _rangeFrom != null;
    // Held and lifted without going anywhere: not a run, a question.
    final pressed = _rangeFrom != null && _rangeAt == _rangeFrom
        ? _rangeFrom
        : null;
    final placePanned = _placePanned;
    final shouldCommit =
        single && !panned && !carried && !ranged && !placePanned;
    // The note is placed while the finger still counts as carrying it:
    // where it went down and what it asked for are read then.
    if (shouldCommit && _handlesPointerInput) {
      final scene = _scenePosition(event);
      if (!_doubleTapped(event, scene)) {
        _commitInputAt(scene, view: event.localPosition);
      }
    }
    _endFingerEdit();
    if (single && carried && !_pagesStale) {
      widget.onSelectionDragged?.call(steps, alter);
    }
    if (single && pressed != null) widget.onLongPressed?.call(pressed);
    _placeDown = null;
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty && _multiPointerGesture) {
      setState(() => _multiPointerGesture = false);
    }
  }

  /// Whether this tap is the second of two on a bar, and was told as such.
  bool _doubleTapped(PointerUpEvent event, Offset scene) {
    final before = _lastTapAt;
    final where = _lastTapPosition;
    _lastTapAt = event.timeStamp;
    _lastTapPosition = event.position;
    if (widget.inputMode != 'select' ||
        widget.onMeasureDoubleTapped == null ||
        before == null ||
        where == null ||
        _pagesStale) {
      return false;
    }
    final since = event.timeStamp - before;
    if (since <= Duration.zero ||
        since > _doubleTapTime ||
        (event.position - where).distance > 36) {
      return false;
    }
    final measure = _layout?.measureAt(scene);
    if (measure == null) return false;
    _lastTapAt = null;
    widget.onMeasureDoubleTapped!(measure.measureIndex);
    return true;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _placeDown = null;
    _endFingerEdit();
    _activePointers.remove(event.pointer);
    if (_activePointers.isEmpty && _multiPointerGesture) {
      setState(() => _multiPointerGesture = false);
    }
    _clearGhost();
  }
}
