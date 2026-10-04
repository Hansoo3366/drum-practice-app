import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_system_ui.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/core/audio/audio_engine_provider.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/session/jam_clock_sync.dart';
import 'package:page_a_diddle/core/session/jam_metronome_sync.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_controller.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/presentation/edit_song_sheet.dart';
import 'package:page_a_diddle/features/practice/data/practice_session_repository.dart';
import 'package:page_a_diddle/features/practice/domain/practice_stats.dart';
import 'package:page_a_diddle/features/score_viewer/data/annotated_pdf_exporter.dart';
import 'package:page_a_diddle/features/score_viewer/data/score_viewer_data.dart';
import 'package:page_a_diddle/features/score_viewer/data/viewer_prefs_store.dart';
import 'package:page_a_diddle/features/score_viewer/domain/annotation_stroke.dart';
import 'package:page_a_diddle/features/score_viewer/presentation/annotation_dock.dart';
import 'package:page_a_diddle/features/score_viewer/presentation/viewer_badges.dart';
import 'package:page_a_diddle/features/score_viewer/presentation/viewer_chrome.dart';
import 'package:page_a_diddle/features/score_viewer/presentation/viewer_floating_hint.dart';
import 'package:page_a_diddle/features/score_viewer/presentation/viewer_settings_sheet.dart';
import 'package:page_a_diddle/features/score_viewer/presentation/viewer_top_chrome_layer.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_controller.dart';
import 'package:page_a_diddle/features/smart_score/data/audio_anchor_repository.dart';
import 'package:page_a_diddle/features/smart_score/data/cue_repository.dart';
import 'package:page_a_diddle/features/smart_score/data/measure_repository.dart';
import 'package:page_a_diddle/features/smart_score/data/tempo_map_repository.dart';
import 'package:page_a_diddle/features/smart_score/data/time_signature_map_repository.dart';
import 'package:page_a_diddle/features/stage/data/performance_key_map_store.dart';
import 'package:page_a_diddle/features/stage/data/stage_mode_controller.dart';
import 'package:page_a_diddle/features/stage/domain/pedal_gesture_interpreter.dart';
import 'package:page_a_diddle/features/stage/domain/performance_action.dart';
import 'package:page_a_diddle/features/stage/domain/performance_key_map.dart';
import 'package:page_a_diddle/features/stage/domain/stage_performance_lock.dart';
import 'package:page_a_diddle/features/stage/domain/stage_section_preview.dart';
import 'package:page_a_diddle/features/stage/domain/stage_setlist_progress.dart';
import 'package:page_a_diddle/features/tools/data/metronome_click_player.dart';
import 'package:page_a_diddle/features/tools/data/metronome_settings.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';
import 'package:page_a_diddle/features/tools/presentation/metronome_subdivision_icon.dart';
import 'package:page_a_diddle/features/tools/presentation/tempo_trainer_screen.dart';
import 'package:pdfrx/pdfrx.dart';

enum _ProgressMode { follow, page }

enum _PdfViewMode { auto, fit, twoPage, scroll }

enum _PedalMapTarget { left, right, playPause, loop }

Widget _stageSheet(Widget child) => Theme(data: AppTheme.stage, child: child);

class ScoreViewerScreen extends ConsumerWidget {
  const ScoreViewerScreen({
    required this.songId,
    this.setlistId,
    this.startJam = false,
    this.stageMode = false,
    super.key,
  });

  final String songId;
  final String? setlistId;
  final bool startJam;
  final bool stageMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(scoreViewerDataProvider(songId));

    return data.when(
      data: (viewerData) {
        final currentSetlistId = setlistId;
        StageSetlistProgress? setlistProgress;
        if (currentSetlistId != null) {
          final items = ref
              .watch(setlistItemsProvider(currentSetlistId))
              .asData
              ?.value;
          if (items != null) {
            setlistProgress = calculateStageSetlistProgress(
              items.map(
                (item) => StageSetlistItem(
                  songId: item.song.id,
                  title: item.song.title,
                  offlineAvailable: item.song.offlineAvailable,
                  bpm: item.tempo,
                ),
              ),
              currentSongId: songId,
            );
          }
        }

        return _PdfScoreViewer(
          data: viewerData,
          setlistId: currentSetlistId,
          startJam: startJam,
          setlistProgress: setlistProgress,
          stageMode: stageMode,
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.stage,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.score)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error is StateError
                    ? error.message.toString()
                    : l10n.openFailed,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PdfScoreViewer extends ConsumerStatefulWidget {
  const _PdfScoreViewer({
    required this.data,
    required this.stageMode,
    this.setlistId,
    this.startJam = false,
    this.setlistProgress,
  });

  final ScoreViewerData data;
  final String? setlistId;
  final bool startJam;
  final StageSetlistProgress? setlistProgress;
  final bool stageMode;

  @override
  ConsumerState<_PdfScoreViewer> createState() => _PdfScoreViewerState();
}

class _PdfScoreViewerState extends ConsumerState<_PdfScoreViewer> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  bool get _allowsEditing =>
      widget.data.song.sourceProvider != jamHostSourceProvider &&
      stageAllowsEditing(widget.stageMode);

  static const _chromeHideDelay = Duration(seconds: 3);
  static const _sectionOptions = [
    'INTRO',
    'VERSE',
    'PRE',
    'CHORUS',
    'BRIDGE',
    'OUTRO',
  ];
  final _controller = PdfViewerController();
  final _pointers = <int, Offset>{};
  StreamSubscription<void>? _audioEndSubscription;
  Timer? _audioPositionTimer;
  AudioSource? _audioSource;
  SoundHandle? _audioHandle;
  bool _audioPlaying = false;
  bool _audioLoading = false;
  double? _audioTimeSeconds;
  double _audioSpeed = 1;
  int? _loopStartMeasure;
  int? _loopEndMeasure;
  String? _loopSection;
  bool _loopEnabled = false;
  final _metronomeSequence = MetronomeSequence();
  Timer? _metronomeTimer;
  DateTime? _jamSyncStartAt;
  int? _jamSyncLastStep;
  Duration _jamClockOffset = Duration.zero;
  DateTime? _pendingClockStartAt;
  StreamSubscription<Duration>? _clockOffsetSubscription;
  final _metronomeClicks = MetronomeClickPlayer();
  int _metronomeBpm = 120;
  bool _metronomeHaptics = true;
  var _metronomeSettingsHydrated = false;
  final _metronomeBpmController = TextEditingController(text: '120');
  MetronomeMeter _metronomeMeter = const MetronomeMeter(4, 4);
  int _metronomeBeat = 0;
  MetronomeSubdivision _metronomeSubdivision = MetronomeSubdivision.quarter;
  List<MetronomeAccentLevel> _metronomeAccentPattern = [
    MetronomeAccentLevel.strong,
    MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal,
    MetronomeAccentLevel.normal,
  ];
  int _metronomeCountInBars = 1;
  bool _metronomeIsCountIn = false;
  bool _metronomeRunning = false;
  bool _metronomeLoading = false;
  bool _measureEditing = false;
  String? _selectedMeasureId;
  int? _currentMeasureNumber;
  DateTime? _practiceStartedAt;
  DateTime? _viewerOpenedAt;
  int _practiceBpm = 120;
  int? _practiceTargetBpm;
  _ProgressMode _progressMode = _ProgressMode.page;
  bool _autoPaused = false;
  _PdfViewMode _viewMode = _PdfViewMode.fit;
  bool _annotationsVisible = true;
  bool _annotationMode = false;
  bool _exportingAnnotatedPdf = false;
  final Map<int, List<AnnotationStroke>> _annotationStrokes = {};

  /// Chronological undo stack — last stroke drawn, any page / pen.
  final List<({int page, AnnotationStroke stroke})> _annotationHistory = [];
  int? _draftAnnotationPage;
  AnnotationStroke? _draftAnnotation;
  Color _annotationColor = annotationPalette.first;
  AnnotationPen _annotationPen = AnnotationPen.medium;
  bool _statusBarVisible = true;
  Rect? _editingMeasureRect;
  int? _draftMeasurePage;
  Offset? _draftMeasureStart;
  Rect? _draftMeasureRect;
  int _pageNumber = 1;
  int? _normalizationTargetPage;
  int _pageCount = 0;
  bool _applyingJamRemote = false;
  bool _jamFollowConductor = true;
  bool _jamInitialSnapshotScheduled = false;
  bool _startJamRequested = false;
  Timer? _jamPositionPublishTimer;
  Timer? _jamMusicPublishTimer;
  Offset? _gestureDocumentFocalPoint;
  Offset? _gestureInitialLocalFocalPoint;
  double? _gestureInitialDistance;
  double? _gestureInitialZoom;
  bool _twoFingerGestureActive = false;
  bool _twoFingerGestureMoved = false;
  DateTime? _lastTwoFingerTap;
  DateTime? _suppressTapUntil;
  Offset? _singleFingerStart;
  Timer? _chromeHideTimer;
  bool _chromeVisible = true;
  StageModeController? _stageModeController;
  final _pedalInterpreter = PedalGestureInterpreter();
  final Map<PedalSlot, Timer> _pedalLongTimers = {};
  final Map<PedalSlot, Timer> _pedalFlushTimers = {};
  void Function(LogicalKeyboardKey key)? _onMapKey;
  Size _viewerViewportSize = Size.zero;
  Size? _lastMediaSize;
  Timer? _viewportRelayoutTimer;

  int get _metronomeBeatsPerBar => _metronomeMeter.numerator;

  _PdfViewMode get _effectiveViewMode {
    if (_viewMode != _PdfViewMode.auto) {
      return _viewMode;
    }
    final size = MediaQuery.sizeOf(context);
    return size.width >= size.height
        ? _PdfViewMode.twoPage
        : _PdfViewMode.scroll;
  }

  String get _viewModeLabel => switch (_viewMode) {
    _PdfViewMode.auto => l10n.layoutAuto,
    _PdfViewMode.fit => l10n.layoutFit,
    _PdfViewMode.twoPage => l10n.layoutTwoUp,
    _PdfViewMode.scroll => l10n.layoutScroll,
  };

  /// First page of the current two-up spread (1, 3, 5, …).
  int _spreadFirstPage(int page) => ((page - 1) ~/ 2) * 2 + 1;

  int _normalizePageNumber(int page) {
    if (_effectiveViewMode != _PdfViewMode.twoPage) return page;
    return _spreadFirstPage(page);
  }

  String get _loopLabel {
    if (!_loopEnabled || _loopStartMeasure == null || _loopEndMeasure == null) {
      return l10n.off;
    }
    final range = l10n.loopMeasures(_loopStartMeasure!, _loopEndMeasure!);
    return _loopSection == null ? range : '${_loopSection!} · $range';
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    _viewerOpenedAt = DateTime.now();
    _practiceTargetBpm = widget.data.song.targetBpm;
    _loadAnnotations();
    unawaited(_loadViewerPrefs());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _hydrateMetronomeSettings();
      }
    });
    if (widget.stageMode) {
      _measureEditing = false;
      _annotationMode = false;
      _selectedMeasureId = null;
      _editingMeasureRect = null;
      _draftMeasurePage = null;
      _draftMeasureStart = null;
      _draftMeasureRect = null;
      _draftAnnotationPage = null;
      _draftAnnotation = null;
      _stageModeController = ref.read(stageModeControllerProvider);
      unawaited(_enterStageMode());
    }
  }

  Future<void> _loadViewerPrefs() async {
    final prefs = await ref.read(viewerPrefsStoreProvider).read();
    if (!mounted) return;
    final mode = switch (prefs.viewMode) {
      'auto' => _PdfViewMode.auto,
      'twoPage' => _PdfViewMode.twoPage,
      'scroll' => _PdfViewMode.scroll,
      _ => _PdfViewMode.fit,
    };
    final modeChanged = mode != _viewMode;
    setState(() {
      _viewMode = mode;
      _statusBarVisible = prefs.statusBarVisible;
      _annotationsVisible = prefs.annotationsVisible;
    });
    if (!prefs.statusBarVisible) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (modeChanged && _controller.isReady) {
      _controller.invalidate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isReady) {
          _fitCurrentPage();
        }
      });
    }
  }

  Future<void> _persistViewerPrefs() async {
    await ref
        .read(viewerPrefsStoreProvider)
        .write(
          ViewerPrefs(
            viewMode: _viewMode.name,
            statusBarVisible: _statusBarVisible,
            annotationsVisible: _annotationsVisible,
          ),
        );
  }

  Future<void> _enterStageMode() async {
    try {
      await _stageModeController!.enter();
    } on PlatformException {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.wakeLockFailed)));
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant _PdfScoreViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.song.targetBpm != widget.data.song.targetBpm) {
      _practiceTargetBpm = widget.data.song.targetBpm;
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _onMapKey = null;
    for (final timer in _pedalLongTimers.values) {
      timer.cancel();
    }
    for (final timer in _pedalFlushTimers.values) {
      timer.cancel();
    }
    _chromeHideTimer?.cancel();
    _viewportRelayoutTimer?.cancel();
    _jamPositionPublishTimer?.cancel();
    _jamMusicPublishTimer?.cancel();
    unawaited(_clockOffsetSubscription?.cancel());
    _clockOffsetSubscription = null;
    _metronomeTimer?.cancel();
    _audioPositionTimer?.cancel();
    _metronomeBpmController.dispose();
    unawaited(_audioEndSubscription?.cancel());
    final source = _audioSource;
    if (source != null && SoLoud.instance.isInitialized) {
      unawaited(SoLoud.instance.disposeSource(source));
    }
    if (SoLoud.instance.isInitialized) {
      unawaited(_disposeMetronome());
    }
    if (_stageModeController case final controller?) {
      unawaited(_exitStageMode(controller));
    }
    _finalizePassivePracticeSession();
    // Leave immersive / transparent viewer chrome; restore readable app bars.
    final brightness = Theme.of(context).brightness;
    unawaited(AppSystemUi.restoreAppChrome(brightness));
    super.dispose();
  }

  void _finalizePassivePracticeSession() {
    if (_practiceStartedAt != null) {
      return;
    }
    final opened = _viewerOpenedAt;
    if (opened == null) {
      return;
    }
    final ended = DateTime.now();
    final seconds = ended.difference(opened).inSeconds;
    if (seconds < 45) {
      return;
    }
    final defaultBpm = widget.data.song.defaultTempo ?? _metronomeBpm;
    final bpm = _metronomeRunning ? _metronomeBpm : defaultBpm;
    unawaited(
      ref
          .read(practiceSessionRepositoryProvider)
          .save(
            songId: widget.data.song.id,
            startedAt: opened,
            endedAt: ended,
            bpm: bpm.clamp(40, 240),
            id: 'auto-${widget.data.song.id}-${opened.microsecondsSinceEpoch}',
          ),
    );
  }

  Future<void> _exitStageMode(StageModeController controller) async {
    try {
      await controller.exit();
    } on PlatformException catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'stage mode',
        ),
      );
    }
  }

  String _scorePath(String songId) {
    final query = <String, String>{
      if (widget.setlistId case final setlistId?) 'setlistId': setlistId,
      if (widget.stageMode) 'stage': 'true',
    };
    return Uri(path: '/score/$songId', queryParameters: query).toString();
  }

  void _openSetlistSong(String songId) {
    context.pushReplacement(_scorePath(songId));
  }

  void _scheduleChromeHide() {
    if (_measureEditing || _chromeHideTimer != null) {
      return;
    }
    _chromeHideTimer = Timer(_chromeHideDelay, () {
      _chromeHideTimer = null;
      if (mounted) {
        setState(() => _chromeVisible = false);
      }
    });
  }

  void _toggleChrome() {
    _chromeHideTimer?.cancel();
    _chromeHideTimer = null;
    HapticFeedback.selectionClick();
    setState(() => _chromeVisible = !_chromeVisible);
    if (_chromeVisible) {
      _scheduleChromeHide();
    }
  }

  Future<void> _toggleAudio() async {
    final audioFile = widget.data.audioFile;
    if (audioFile == null || _audioLoading) {
      return;
    }
    setState(() => _audioLoading = true);

    try {
      final engine = await ref.read(audioEngineProvider.future);
      final source =
          _audioSource ??
          await engine.loadFile(audioFile.path, mode: LoadMode.disk);
      _audioSource = source;
      _audioEndSubscription ??= source.allInstancesFinished.listen((_) {
        final shouldAdvanceSetlist = !_autoPaused;
        if (mounted) {
          _audioPositionTimer?.cancel();
          setState(() {
            _audioHandle = null;
            _audioPlaying = false;
            _autoPaused = false;
          });
          if (shouldAdvanceSetlist) {
            unawaited(_turnSetlistSong(1));
          }
        }
      });

      final handle = _audioHandle;
      if (handle == null || !engine.getIsValidVoiceHandle(handle)) {
        _audioHandle = await engine.play(source);
        engine.setRelativePlaySpeed(_audioHandle!, _audioSpeed);
        _audioPlaying = true;
        _autoPaused = false;
        _startAudioPositionTimer();
      } else {
        engine.setPause(handle, _audioPlaying);
        _audioPlaying = !_audioPlaying;
        if (_audioPlaying) {
          _startAudioPositionTimer();
        } else {
          _audioPositionTimer?.cancel();
        }
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.audioError)));
      }
    } finally {
      if (mounted) {
        setState(() => _audioLoading = false);
      }
    }
  }

  void _setAudioSpeed(double value) {
    final speed = (value * 10).round() / 10;
    setState(() => _audioSpeed = speed.clamp(.5, 1.5).toDouble());
    final handle = _audioHandle;
    if (handle == null ||
        !SoLoud.instance.isInitialized ||
        !SoLoud.instance.getIsValidVoiceHandle(handle)) {
      return;
    }
    try {
      SoLoud.instance.setRelativePlaySpeed(handle, _audioSpeed);
    } on Object catch (_) {
      _showMeasureError();
    }
  }

  void _startAudioPositionTimer() {
    _audioPositionTimer?.cancel();
    _audioPositionTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _syncAudioTimeline(),
    );
  }

  void _syncAudioTimeline() {
    final handle = _audioHandle;
    final engine = SoLoud.instance;
    if (handle == null ||
        !engine.isInitialized ||
        !engine.getIsValidVoiceHandle(handle)) {
      return;
    }
    try {
      final position = engine.getPosition(handle);
      final seconds = position.inMicroseconds / Duration.microsecondsPerSecond;
      final anchors = ref
          .read(audioAnchorsProvider(widget.data.song.id))
          .asData
          ?.value;
      final measures = ref
          .read(measuresProvider(widget.data.song.id))
          .asData
          ?.value;
      _audioTimeSeconds = seconds;
      if (anchors == null || anchors.isEmpty || measures == null) {
        return;
      }
      final startMeasure = _loopStartMeasure;
      final endMeasure = _loopEndMeasure;
      if (_loopEnabled && startMeasure != null && endMeasure != null) {
        final startAnchor = anchors
            .where((anchor) => anchor.measureNumber == startMeasure)
            .firstOrNull;
        final endAnchor = anchors
            .where((anchor) => anchor.measureNumber == endMeasure)
            .firstOrNull;
        if (startAnchor != null &&
            endAnchor != null &&
            endAnchor.audioTime > startAnchor.audioTime &&
            seconds >= endAnchor.audioTime) {
          engine.seek(
            handle,
            Duration(
              microseconds:
                  (startAnchor.audioTime * Duration.microsecondsPerSecond)
                      .round(),
            ),
          );
          _audioTimeSeconds = startAnchor.audioTime;
          if (mounted) {
            setState(() => _currentMeasureNumber = startMeasure);
            _scheduleJamPositionPublish();
          }
          return;
        }
      }
      final measureNumber = _measureAtAudioTime(seconds, anchors);
      if (measureNumber == null ||
          measureNumber == _currentMeasureNumber ||
          _autoPaused) {
        return;
      }
      final measure = measures
          .where((item) => item.number == measureNumber)
          .firstOrNull;
      if (measure == null || !mounted) {
        return;
      }
      setState(() => _currentMeasureNumber = measure.number);
      _scheduleJamPositionPublish();
      if (_progressMode == _ProgressMode.page &&
          _controller.isReady &&
          measure.page != _pageNumber) {
        unawaited(_goToViewerPage(measure.page, duration: Duration.zero));
      }
    } on Object catch (_) {
      // The handle can end between the validity check and getPosition().
    }
  }

  int? _measureAtAudioTime(double seconds, List<AudioAnchor> anchors) {
    final sorted = [...anchors]
      ..sort((first, second) => first.audioTime.compareTo(second.audioTime));
    if (seconds < sorted.first.audioTime) {
      return null;
    }
    for (var index = 0; index < sorted.length - 1; index++) {
      final first = sorted[index];
      final second = sorted[index + 1];
      if (seconds < second.audioTime) {
        final span = second.audioTime - first.audioTime;
        final progress = span <= 0 ? 0.0 : (seconds - first.audioTime) / span;
        return (first.measureNumber +
                (second.measureNumber - first.measureNumber) * progress)
            .round();
      }
    }
    return sorted.last.measureNumber;
  }

  Future<void> _showPlaybackSpeedSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _stageSheet(
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.playbackSpeed,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${_audioSpeed.toStringAsFixed(1)}x',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: _audioSpeed,
                        min: .5,
                        max: 1.5,
                        divisions: 10,
                        label: '${_audioSpeed.toStringAsFixed(1)}x',
                        activeColor: AppColors.accent,
                        inactiveColor: AppColors.stageOutline,
                        onChanged: (value) {
                          _setAudioSpeed(value);
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.stageOutline),
                        ),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSyncAnchorSheet(
    List<Measure> measures,
    List<AudioAnchor> anchors,
  ) async {
    if (!_allowsEditing) return;
    if (measures.isEmpty) {
      return;
    }
    var selectedNumber =
        anchors.firstOrNull?.measureNumber ?? measures.first.number;
    final timeController = TextEditingController(
      text:
          anchors.firstOrNull?.audioTime.toStringAsFixed(3) ??
          _audioTimeSeconds?.toStringAsFixed(3) ??
          '',
    );
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.stageElevated,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              AudioAnchor? selectedAnchor() => anchors
                  .where((anchor) => anchor.measureNumber == selectedNumber)
                  .firstOrNull;

              return _stageSheet(
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.syncAnchor,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.anchorLinkHint,
                          style: TextStyle(color: AppColors.stageMuted),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: ValueKey(selectedNumber),
                          initialValue: selectedNumber,
                          dropdownColor: AppColors.stagePanel,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: l10n.measure,
                            labelStyle: TextStyle(color: AppColors.stageMuted),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.stageOutline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                          ),
                          items: [
                            for (final measure in measures)
                              DropdownMenuItem<int>(
                                value: measure.number,
                                child: Text(
                                  '${measure.number}',
                                  style: const TextStyle(
                                    color: AppColors.canvas,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (number) {
                            if (number == null) {
                              return;
                            }
                            selectedNumber = number;
                            final anchor = selectedAnchor();
                            timeController.text =
                                anchor?.audioTime.toStringAsFixed(3) ??
                                _audioTimeSeconds?.toStringAsFixed(3) ??
                                '';
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: timeController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: l10n.audioSeconds,
                                  suffixText: 's',
                                  labelStyle: TextStyle(
                                    color: AppColors.stageMuted,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppColors.stageOutline,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _audioTimeSeconds == null
                                  ? null
                                  : () {
                                      timeController.text = _audioTimeSeconds!
                                          .toStringAsFixed(3);
                                      setSheetState(() {});
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: AppColors.stageOutline,
                                ),
                              ),
                              child: Text(l10n.currentPosition),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () async {
                            final audioTime = double.tryParse(
                              timeController.text.trim(),
                            );
                            if (audioTime == null || audioTime < 0) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(l10n.checkTime)),
                              );
                              return;
                            }
                            try {
                              await ref
                                  .read(audioAnchorRepositoryProvider)
                                  .save(
                                    songId: widget.data.song.id,
                                    measureNumber: selectedNumber,
                                    audioTime: audioTime,
                                    id: selectedAnchor()?.id,
                                  );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } on Object catch (_) {
                              _showMeasureError();
                            }
                          },
                          child: Text(l10n.save),
                        ),
                        if (selectedAnchor() case final anchor?)
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(audioAnchorRepositoryProvider)
                                  .delete(anchor);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF8A65),
                            ),
                            child: Text(l10n.deleteAnchorHere),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      timeController.dispose();
    }
  }

  String _displaySectionLabel(String value) {
    return switch (value.trim().toUpperCase()) {
      'INTRO' => l10n.sectionIntro,
      'VERSE' => l10n.sectionVerse,
      'PRE' => l10n.sectionPre,
      'CHORUS' => l10n.sectionChorus,
      'BRIDGE' => l10n.sectionBridge,
      'OUTRO' => l10n.sectionOutro,
      _ => value,
    };
  }

  Future<void> _showLoopSheet(
    List<Measure> measures,
    List<AudioAnchor> anchors,
  ) async {
    final anchoredMeasures = measures
        .where(
          (measure) =>
              anchors.any((anchor) => anchor.measureNumber == measure.number),
        )
        .toList();
    if (anchoredMeasures.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.needTwoAnchors)));
      }
      return;
    }
    final sectionNames = <String>[];
    for (final measure in anchoredMeasures) {
      final section = measure.section;
      if (section != null &&
          section.isNotEmpty &&
          !sectionNames.contains(section)) {
        sectionNames.add(section);
      }
    }
    var selectedSection = sectionNames.contains(_loopSection)
        ? _loopSection
        : null;
    var startMeasure = _loopStartMeasure ?? anchoredMeasures.first.number;
    var endMeasure = _loopEndMeasure ?? anchoredMeasures.last.number;
    if (startMeasure >= endMeasure) {
      startMeasure = anchoredMeasures.first.number;
      endMeasure = anchoredMeasures.last.number;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            DropdownButtonFormField<int> field({
              required String label,
              required int value,
              required ValueChanged<int?> onChanged,
            }) {
              return DropdownButtonFormField<int>(
                key: ValueKey('$label-$value'),
                initialValue: value,
                dropdownColor: AppColors.stagePanel,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: AppColors.stageMuted),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.stageOutline),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
                items: [
                  for (final measure in anchoredMeasures)
                    DropdownMenuItem<int>(
                      value: measure.number,
                      child: Text(
                        '${measure.number}',
                        style: const TextStyle(color: AppColors.canvas),
                      ),
                    ),
                ],
                onChanged: onChanged,
              );
            }

            return _stageSheet(
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.loopSection,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.loopRangeHint,
                        style: TextStyle(color: AppColors.stageMuted),
                      ),
                      const SizedBox(height: 16),
                      if (sectionNames.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedSection ?? '__measure__'),
                          initialValue: selectedSection ?? '__measure__',
                          dropdownColor: AppColors.stagePanel,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: l10n.loopRange,
                            labelStyle: TextStyle(color: AppColors.stageMuted),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.stageOutline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '__measure__',
                              child: Text(
                                l10n.measureRange,
                                style: const TextStyle(color: AppColors.canvas),
                              ),
                            ),
                            for (final section in sectionNames)
                              DropdownMenuItem<String>(
                                value: section,
                                child: Text(
                                  _displaySectionLabel(section),
                                  style: const TextStyle(
                                    color: AppColors.canvas,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            selectedSection = value == '__measure__'
                                ? null
                                : value;
                            if (selectedSection != null) {
                              final sectionMeasures = anchoredMeasures
                                  .where(
                                    (measure) =>
                                        measure.section == selectedSection,
                                  )
                                  .toList();
                              if (sectionMeasures.length >= 2) {
                                startMeasure = sectionMeasures.first.number;
                                endMeasure = sectionMeasures.last.number;
                              }
                            }
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: field(
                              label: l10n.startMeasure,
                              value: startMeasure,
                              onChanged: (value) {
                                if (value == null) return;
                                startMeasure = value;
                                setSheetState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: field(
                              label: l10n.endMeasure,
                              value: endMeasure,
                              onChanged: (value) {
                                if (value == null) return;
                                endMeasure = value;
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (selectedSection != null &&
                          anchoredMeasures
                                  .where(
                                    (measure) =>
                                        measure.section == selectedSection,
                                  )
                                  .length <
                              2)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            l10n.needTwoSectionAnchors,
                            style: TextStyle(color: Color(0xFFFF8A65)),
                          ),
                        ),
                      FilledButton(
                        onPressed:
                            startMeasure >= endMeasure ||
                                (selectedSection != null &&
                                    anchoredMeasures
                                            .where(
                                              (measure) =>
                                                  measure.section ==
                                                  selectedSection,
                                            )
                                            .length <
                                        2)
                            ? null
                            : () {
                                setState(() {
                                  _loopStartMeasure = startMeasure;
                                  _loopEndMeasure = endMeasure;
                                  _loopSection = selectedSection;
                                  _loopEnabled = true;
                                });
                                unawaited(
                                  _publishJamLoop(
                                    enabled: true,
                                    startMeasure: startMeasure,
                                    endMeasure: endMeasure,
                                    section: selectedSection,
                                  ),
                                );
                                Navigator.pop(sheetContext);
                              },
                        child: Text(l10n.startLoop),
                      ),
                      if (_loopEnabled)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _loopEnabled = false;
                              _loopStartMeasure = null;
                              _loopEndMeasure = null;
                              _loopSection = null;
                            });
                            unawaited(_publishJamLoop(enabled: false));
                            Navigator.pop(sheetContext);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF8A65),
                          ),
                          child: Text(l10n.clearLoop),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCueSheet(List<Measure> measures, List<Cue> cues) async {
    if (!_allowsEditing) return;
    if (measures.isEmpty) {
      return;
    }
    var selectedNumber =
        _currentMeasureNumber ??
        cues.firstOrNull?.measureNumber ??
        measures.first.number;
    if (!measures.any((measure) => measure.number == selectedNumber)) {
      selectedNumber = measures.first.number;
    }
    final labelController = TextEditingController(
      text: cues
          .where((cue) => cue.measureNumber == selectedNumber)
          .firstOrNull
          ?.label,
    );
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.stageElevated,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final existing = cues
                  .where((cue) => cue.measureNumber == selectedNumber)
                  .firstOrNull;
              return _stageSheet(
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      24 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.cue,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          key: ValueKey(selectedNumber),
                          initialValue: selectedNumber,
                          dropdownColor: AppColors.stagePanel,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: l10n.measure,
                            labelStyle: TextStyle(color: AppColors.stageMuted),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.stageOutline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                          ),
                          items: [
                            for (final measure in measures)
                              DropdownMenuItem<int>(
                                value: measure.number,
                                child: Text(
                                  '${measure.number}',
                                  style: const TextStyle(
                                    color: AppColors.canvas,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            selectedNumber = value;
                            labelController.text =
                                cues
                                    .where((cue) => cue.measureNumber == value)
                                    .firstOrNull
                                    ?.label ??
                                '';
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: labelController,
                          autofocus: existing == null,
                          maxLength: 40,
                          maxLines: 1,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: l10n.display,
                            labelStyle: TextStyle(color: AppColors.stageMuted),
                            counterStyle: TextStyle(
                              color: AppColors.stageMuted,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.stageOutline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () async {
                            final value = labelController.text.trim();
                            if (value.isEmpty) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(l10n.enterLabel)),
                              );
                              return;
                            }
                            try {
                              await ref
                                  .read(cueRepositoryProvider)
                                  .save(
                                    songId: widget.data.song.id,
                                    measureNumber: selectedNumber,
                                    label: value,
                                    id: existing?.id,
                                  );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } on Object catch (_) {
                              _showMeasureError();
                            }
                          },
                          child: Text(l10n.save),
                        ),
                        if (existing != null)
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(cueRepositoryProvider)
                                  .delete(existing);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF8A65),
                            ),
                            child: Text(l10n.delete),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      labelController.dispose();
    }
  }

  Future<void> _showDifficultMeasureSheet(List<Measure> measures) async {
    if (measures.isEmpty) {
      return;
    }
    var selectedNumber =
        _currentMeasureNumber != null &&
            measures.any((measure) => measure.number == _currentMeasureNumber)
        ? _currentMeasureNumber!
        : measures.first.number;
    final difficultByMeasure = {
      for (final measure in measures) measure.number: measure.isDifficult,
    };
    var isDifficult = difficultByMeasure[selectedNumber] ?? false;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedMeasure = measures.firstWhere(
              (measure) => measure.number == selectedNumber,
            );
            return _stageSheet(
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.hardMeasures,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: ValueKey(selectedNumber),
                        initialValue: selectedNumber,
                        dropdownColor: AppColors.stagePanel,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: l10n.measure,
                          labelStyle: TextStyle(color: AppColors.stageMuted),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.stageOutline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.accent),
                          ),
                        ),
                        items: [
                          for (final measure in measures)
                            DropdownMenuItem<int>(
                              value: measure.number,
                              child: Text(
                                '${measure.number}',
                                style: const TextStyle(color: AppColors.canvas),
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          selectedNumber = value;
                          isDifficult = difficultByMeasure[value] ?? false;
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.hardBadge,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: isDifficult,
                        onChanged: (value) async {
                          try {
                            await ref
                                .read(measureRepositoryProvider)
                                .updateDifficult(
                                  measure: selectedMeasure,
                                  isDifficult: value,
                                );
                            difficultByMeasure[selectedNumber] = value;
                            isDifficult = value;
                            if (sheetContext.mounted) {
                              setSheetState(() {});
                            }
                          } on Object catch (_) {
                            _showMeasureError();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPracticeSheet(List<PracticeSession> sessions) async {
    final defaultBpm = _metronomeRunning
        ? _metronomeBpm
        : widget.data.song.defaultTempo ?? _practiceBpm;
    final bpmController = TextEditingController(text: '$defaultBpm');
    final targetController = TextEditingController(
      text: _practiceTargetBpm?.toString() ?? '',
    );
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.stageElevated,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, _) {
              final stats = PracticeStats.from(sessions);
              final targetLabel = _practiceTargetBpm == null
                  ? ''
                  : l10n.targetSuffix(_practiceTargetBpm!);
              return _stageSheet(
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      24 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.practiceLog,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (sessions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              l10n.practiceStatsLine(
                                stats.sessionCount,
                                _practiceDurationLabel(stats.totalSeconds),
                                stats.averageBpm,
                              ),
                              style: const TextStyle(
                                color: AppColors.stageMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.maxBpmLabel(stats.maxBpm, targetLabel),
                              style: const TextStyle(
                                color: AppColors.stageMuted,
                              ),
                            ),
                            if (_practiceTargetBpm case final target?)
                              Text(
                                stats.maxBpm >= target
                                    ? l10n.targetAchieved
                                    : l10n.targetRemaining(
                                        target - stats.maxBpm,
                                      ),
                                style: TextStyle(
                                  color: stats.maxBpm >= target
                                      ? const Color(0xFF8FD694)
                                      : const Color(0xFFFFC107),
                                ),
                              ),
                          ],
                          const SizedBox(height: 16),
                          if (_practiceStartedAt case final startedAt?) ...[
                            Text(
                              l10n.practiceInProgress(
                                _practiceBpm,
                                _practiceDateLabel(startedAt),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                            if (_practiceTargetBpm case final target?)
                              Text(
                                l10n.targetBpmValue(target),
                                style: const TextStyle(
                                  color: AppColors.stageMuted,
                                ),
                              ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(practiceSessionRepositoryProvider)
                                      .save(
                                        songId: widget.data.song.id,
                                        startedAt: startedAt,
                                        endedAt: DateTime.now(),
                                        bpm: _practiceBpm,
                                      );
                                  if (mounted) {
                                    setState(() => _practiceStartedAt = null);
                                  }
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } on Object catch (_) {
                                  _showMeasureError();
                                }
                              },
                              child: Text(l10n.endRecording),
                            ),
                          ] else ...[
                            TextField(
                              controller: bpmController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: l10n.tempo,
                                labelStyle: const TextStyle(
                                  color: AppColors.stageMuted,
                                ),
                                filled: true,
                                fillColor: AppColors.stagePanel,
                                enabledBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.stageOutline,
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: targetController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: l10n.targetBpm,
                                hintText: l10n.optional,
                                labelStyle: TextStyle(
                                  color: AppColors.stageMuted,
                                ),
                                hintStyle: TextStyle(color: Color(0xFF777A80)),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.stageOutline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () async {
                                final bpm = int.tryParse(bpmController.text);
                                if (bpm == null || bpm < 40 || bpm > 240) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(content: Text(l10n.bpmRangeError)),
                                  );
                                  return;
                                }
                                final targetText = targetController.text.trim();
                                final target = targetText.isEmpty
                                    ? null
                                    : int.tryParse(targetText);
                                if (targetText.isNotEmpty &&
                                    (target == null ||
                                        target < 40 ||
                                        target > 240 ||
                                        target < bpm)) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.targetBpmAboveCurrent),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await ref
                                      .read(songRepositoryProvider)
                                      .updateTargetBpm(
                                        id: widget.data.song.id,
                                        targetBpm: target,
                                      );
                                  ref.invalidate(
                                    scoreViewerDataProvider(
                                      widget.data.song.id,
                                    ),
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _practiceStartedAt = DateTime.now();
                                      _practiceBpm = bpm;
                                      _practiceTargetBpm = target;
                                    });
                                  }
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } on Object catch (_) {
                                  _showMeasureError();
                                }
                              },
                              child: Text(l10n.startPractice),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final bpm = int.tryParse(bpmController.text);
                                final target = int.tryParse(
                                  targetController.text.trim(),
                                );
                                if (bpm == null ||
                                    bpm < 40 ||
                                    bpm > 240 ||
                                    target == null ||
                                    target < bpm ||
                                    target > 240) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.checkStartTargetBpm),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await ref
                                      .read(songRepositoryProvider)
                                      .updateTargetBpm(
                                        id: widget.data.song.id,
                                        targetBpm: target,
                                      );
                                  ref.invalidate(
                                    scoreViewerDataProvider(
                                      widget.data.song.id,
                                    ),
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _practiceBpm = bpm;
                                      _practiceTargetBpm = target;
                                    });
                                  }
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  if (mounted) {
                                    await this.context.push(
                                      '/tools/tempo-trainer',
                                      extra: TempoTrainerLaunch(
                                        songId: widget.data.song.id,
                                        startBpm: bpm,
                                        targetBpm: target,
                                      ),
                                    );
                                  }
                                } on Object catch (_) {
                                  _showMeasureError();
                                }
                              },
                              icon: const Icon(Icons.trending_up_rounded),
                              label: Text(l10n.tempoTrainer),
                            ),
                          ],
                          if (sessions.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              l10n.recent,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            for (final session in sessions.take(5))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Text(
                                  '${session.bpm}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFC107),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                title: Text(
                                  _practiceDurationLabel(
                                    session.durationSeconds,
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  _practiceDateLabel(session.startedAt),
                                  style: const TextStyle(
                                    color: AppColors.stageMuted,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      bpmController.dispose();
      targetController.dispose();
    }
  }

  String _practiceDurationLabel(int seconds) {
    if (seconds < 60) {
      return l10n.durationSeconds(seconds);
    }
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return remainder == 0
        ? l10n.durationMinutes(minutes)
        : l10n.minutesSeconds(minutes, remainder);
  }

  String _practiceDateLabel(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  String _practiceSettingsLabel(int sessionCount) {
    final targetLabel = _practiceTargetBpm == null
        ? ''
        : l10n.targetSuffix(_practiceTargetBpm!);
    if (_practiceStartedAt != null) {
      return l10n.inProgressLabel(targetLabel);
    }
    return sessionCount == 0
        ? l10n.noneWithTarget(targetLabel)
        : l10n.sessionsWithTarget(sessionCount, targetLabel);
  }

  void _hydrateMetronomeSettings() {
    if (_metronomeSettingsHydrated) {
      return;
    }
    _metronomeSettingsHydrated = true;
    final settings = ref.read(metronomeSettingsProvider);
    final jamMusic = _jamMusicForCurrentSong();
    final remoteMeter =
        jamMusic == null ||
            jamMusic.meterNumerator == null ||
            jamMusic.meterDenominator == null
        ? null
        : metronomeMeters
              .where(
                (meter) =>
                    meter.numerator == jamMusic.meterNumerator &&
                    meter.denominator == jamMusic.meterDenominator,
              )
              .firstOrNull;
    final meter = remoteMeter ?? settings.meter;
    final remoteSubdivision = jamMusic?.subdivision == null
        ? null
        : MetronomeSubdivision.values
              .where((value) => value.name == jamMusic!.subdivision)
              .firstOrNull;
    final subdivision = remoteSubdivision ?? settings.subdivision;
    final remoteAccents = jamMusic?.accents;
    final accents = List.generate(meter.numerator, (index) {
      final raw = remoteAccents != null && index < remoteAccents.length
          ? remoteAccents[index]
          : null;
      if (raw != null) {
        return MetronomeAccentLevel.values[raw
            .clamp(0, MetronomeAccentLevel.values.length - 1)
            .toInt()];
      }
      return index < settings.accents.length
          ? settings.accents[index]
          : index == 0
          ? MetronomeAccentLevel.strong
          : MetronomeAccentLevel.normal;
    });
    final songTempo = jamMusic?.bpm ?? widget.data.song.defaultTempo;
    setState(() {
      _metronomeBpm = (songTempo ?? settings.bpm).clamp(40, 240);
      _metronomeBpmController.text = '$_metronomeBpm';
      _metronomeMeter = meter;
      _metronomeSubdivision = subdivision;
      _metronomeAccentPattern = accents;
      _metronomeCountInBars = settings.countInBars;
      _metronomeHaptics = settings.haptics;
    });
    _metronomeSequence.configure(
      beatsPerBar: meter.numerator,
      stepsPerBeat: subdivision.stepsPerBeat,
      accentPattern: accents,
    );
    unawaited(_preloadMetronomeClicks());
    _scheduleJamMusicPublish();
  }

  JamMusicState? _jamMusicForCurrentSong() {
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return null;
    }
    final session = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    final shared = session?.currentSong;
    if (shared == null ||
        shared.title.trim().toLowerCase() !=
            widget.data.song.title.trim().toLowerCase()) {
      return null;
    }
    return session?.music ?? jamMusicForSong(shared);
  }

  Future<void> _preloadMetronomeClicks() async {
    try {
      final engine = await ref.read(audioEngineProvider.future);
      if (!mounted) {
        return;
      }
      await _metronomeClicks.ensureLoaded(engine);
    } on Object catch (_) {
      // 첫 재생 때 다시 시도한다.
    }
  }

  Future<void> _toggleMetronome({
    bool publish = true,
    DateTime? jamStartAt,
  }) async {
    if (_metronomeLoading) {
      return;
    }
    if (_metronomeRunning) {
      _stopMetronome(publish: publish);
      return;
    }
    _hydrateMetronomeSettings();
    setState(() => _metronomeLoading = true);
    try {
      final engine = await ref.read(audioEngineProvider.future);
      await _metronomeClicks.ensureLoaded(engine);
      if (!_metronomeClicks.isReady) {
        throw StateError('metronome clicks not ready');
      }
      DateTime? startAt = jamStartAt;
      if (publish) {
        await _publishJamMusic();
        startAt = await ref
            .read(activeJamProvider.notifier)
            .updatePlaying(true);
      }
      await _waitForJamStart(startAt);
      if (!mounted) {
        return;
      }
      _metronomeSequence.configure(
        beatsPerBar: _metronomeBeatsPerBar,
        stepsPerBeat: _metronomeSubdivision.stepsPerBeat,
        accentPattern: _metronomeAccentPattern,
      );
      _metronomeSequence.start(countInBars: _metronomeCountInBars);
      _jamSyncStartAt = startAt;
      _jamSyncLastStep = null;
      if (mounted) {
        setState(() {
          _metronomeRunning = true;
          _metronomeBeat = 0;
          _metronomeIsCountIn = false;
        });
      }
      if (_jamSyncStartAt != null) {
        _tickJamSyncedMetronome(engine);
        _armJamSyncedMetronomeTimer(engine);
      } else {
        _tickMetronome(engine);
        _startMetronomeTimer(engine);
      }
    } on Object catch (error, stackTrace) {
      _stopMetronome(publish: publish);
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'metronome start',
        ),
      );
      if (mounted) {
        final message =
            error is JamSessionException &&
                error.message == JamSessionException.notReady
            ? l10n.jamNotReady
            : l10n.metronomeError;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _metronomeLoading = false);
      }
    }
  }

  Future<void> _waitForJamStart(DateTime? startAt) async {
    if (startAt == null) {
      return;
    }
    final localStartAt = jamClockAdjustedStartAt(startAt, _jamClockOffset);
    final delay = jamWaitUntilStart(localStartAt, DateTime.now());
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
  }

  void _startMetronomeTimer(SoLoud engine) {
    _metronomeTimer?.cancel();
    _metronomeTimer = Timer.periodic(
      MetronomeSequence.intervalFor(
        _metronomeBpm,
        stepsPerBeat: _metronomeSubdivision.stepsPerBeat,
      ),
      (_) => _tickMetronome(engine),
    );
  }

  void _subscribeClockOffset() {
    if (_clockOffsetSubscription != null) {
      return;
    }
    final store = ref.read(jamSessionStoreProvider);
    _jamClockOffset = store.clockOffset;
    _clockOffsetSubscription = store.clockOffsetStream.listen((offset) {
      final startAt = _jamSyncStartAt;
      if (startAt == null || !_metronomeRunning) {
        _jamClockOffset = offset;
        return;
      }
      final now = DateTime.now();
      final lastStep = _jamSyncLastStep ?? 0;
      final newExpected = jamClockExpectedStep(
        startAt: startAt,
        localNow: now,
        offset: offset,
        bpm: _metronomeBpm,
        stepsPerBeat: _metronomeSubdivision.stepsPerBeat,
      );
      final drift = jamClockDriftSteps(
        expectedStep: newExpected,
        localStep: lastStep,
      );
      if (!jamClockNeedsCorrection(
        driftSteps: drift,
        bpm: _metronomeBpm,
        stepsPerBeat: _metronomeSubdivision.stepsPerBeat,
      )) {
        _jamClockOffset = offset;
        return;
      }
      // Keep the current bar on the old clock, then use the newly measured
      // member offset from the next bar onward. The pending value is stored as
      // an already-adjusted local start so _tickJamSyncedMetronome can switch
      // without applying the offset twice.
      _pendingClockStartAt = jamClockAdjustedStartAt(startAt, offset);
    });
  }

  void _armJamSyncedMetronomeTimer(SoLoud engine) {
    final startAt = _jamSyncStartAt;
    if (startAt == null) {
      _startMetronomeTimer(engine);
      return;
    }
    final effectiveStart = startAt.add(_jamClockOffset);
    _metronomeTimer?.cancel();
    final delay = jamMetronomeDelayUntilNext(
      startAt: effectiveStart,
      now: DateTime.now(),
      bpm: _metronomeBpm,
      stepsPerBeat: _metronomeSubdivision.stepsPerBeat,
    );
    _metronomeTimer = Timer(delay, () {
      if (!_metronomeRunning || !SoLoud.instance.isInitialized) {
        return;
      }
      _tickJamSyncedMetronome(engine);
      if (_metronomeRunning) {
        _armJamSyncedMetronomeTimer(engine);
      }
    });
  }

  void _tickJamSyncedMetronome(SoLoud engine) {
    final startAt = _jamSyncStartAt;
    if (startAt == null) {
      _tickMetronome(engine);
      return;
    }
    final pending = _pendingClockStartAt;
    final effectiveStart = startAt.add(_jamClockOffset);
    final step = jamMetronomeStepIndex(
      startAt: effectiveStart,
      now: DateTime.now(),
      bpm: _metronomeBpm,
      stepsPerBeat: _metronomeSubdivision.stepsPerBeat,
    );
    if (step < 0 || step == _jamSyncLastStep) {
      return;
    }
    if (pending != null) {
      final stepsPerBar =
          _metronomeBeatsPerBar * _metronomeSubdivision.stepsPerBeat;
      if (stepsPerBar > 0 && step % stepsPerBar == 0) {
        _jamSyncStartAt = pending;
        _jamClockOffset = Duration.zero;
        _pendingClockStartAt = null;
      }
    }
    _jamSyncLastStep = step;
    final beat = _metronomeSequence.beatAt(
      step,
      countInBars: _metronomeCountInBars,
    );
    if (mounted) {
      setState(() {
        _metronomeBeat = beat.number;
        _metronomeIsCountIn = beat.isCountIn;
      });
    }
    unawaited(_playMetronomeClick(engine, beat));
  }

  void _restartMetronomeClock(SoLoud engine) {
    if (_jamSyncStartAt != null) {
      _jamSyncLastStep = null;
      _tickJamSyncedMetronome(engine);
      _armJamSyncedMetronomeTimer(engine);
      return;
    }
    _startMetronomeTimer(engine);
  }

  void _setMetronomeSubdivision(MetronomeSubdivision subdivision) {
    setState(() {
      _metronomeSubdivision = subdivision;
      _metronomeSequence.configure(stepsPerBeat: subdivision.stepsPerBeat);
    });
    _persistMetronomeSettings();
    _scheduleJamMusicPublish();
    if (_metronomeRunning && SoLoud.instance.isInitialized) {
      _restartMetronomeClock(SoLoud.instance);
    }
  }

  void _setMetronomeMeter(MetronomeMeter meter) {
    final beatsPerBar = meter.numerator;
    final pattern = List.generate(
      beatsPerBar,
      (index) => index < _metronomeAccentPattern.length
          ? _metronomeAccentPattern[index]
          : MetronomeAccentLevel.normal,
    );
    setState(() {
      _metronomeMeter = meter;
      _metronomeAccentPattern = pattern;
      _metronomeSequence.configure(
        beatsPerBar: beatsPerBar,
        accentPattern: pattern,
      );
      if (_metronomeRunning) {
        _metronomeSequence.start(countIn: false);
      }
    });
    _persistMetronomeSettings();
    _scheduleJamMusicPublish();
    if (_metronomeRunning && SoLoud.instance.isInitialized) {
      _restartMetronomeClock(SoLoud.instance);
    }
  }

  void _setMetronomeAccent(int beat, MetronomeAccentLevel level) {
    final pattern = List<MetronomeAccentLevel>.of(_metronomeAccentPattern);
    while (pattern.length < _metronomeBeatsPerBar) {
      pattern.add(MetronomeAccentLevel.normal);
    }
    pattern[beat - 1] = level;
    setState(() {
      _metronomeAccentPattern = pattern;
      _metronomeSequence.configure(accentPattern: pattern);
    });
    _persistMetronomeSettings();
    _scheduleJamMusicPublish();
  }

  void _cycleMetronomeAccent(int beat) {
    _setMetronomeAccent(beat, _metronomeAccentPattern[beat - 1].next);
  }

  void _setMetronomeBpm(
    int value, {
    bool publish = true,
    bool persist = true,
    bool restart = true,
  }) {
    final bpm = value.clamp(40, 240).toInt();
    setState(() {
      _metronomeBpm = bpm;
      _metronomeBpmController.value = TextEditingValue(
        text: '$bpm',
        selection: TextSelection.collapsed(offset: '$bpm'.length),
      );
    });
    if (persist) {
      _persistMetronomeSettings();
    }
    if (restart && _metronomeRunning && SoLoud.instance.isInitialized) {
      _restartMetronomeClock(SoLoud.instance);
    }
    if (publish) {
      _scheduleJamMusicPublish();
    }
  }

  void _commitMetronomeBpm(String value) {
    final bpm = int.tryParse(value);
    if (bpm == null) {
      _setMetronomeBpm(_metronomeBpm);
      return;
    }
    _setMetronomeBpm(bpm);
  }

  void _tickMetronome(SoLoud engine) {
    final beat = _metronomeSequence.next();
    if (mounted) {
      setState(() {
        _metronomeBeat = beat.number;
        _metronomeIsCountIn = beat.isCountIn;
      });
    }
    unawaited(_playMetronomeClick(engine, beat));
  }

  bool _shouldPlayMetronomeClick() {
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return true;
    }
    final session = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    if (session == null) {
      return true;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null) {
      return true;
    }
    return jamShouldPlayClick(
      isConductor: permissions.canLead,
      mode: session.clickMode,
    );
  }

  Future<void> _playMetronomeClick(SoLoud engine, MetronomeBeat beat) async {
    if (!_shouldPlayMetronomeClick()) {
      return;
    }
    await _metronomeClicks.play(engine, beat, haptics: _metronomeHaptics);
  }

  void _persistMetronomeSettings() {
    unawaited(
      ref
          .read(metronomeSettingsProvider.notifier)
          .update(
            MetronomeSettings(
              bpm: _metronomeBpm,
              meter: _metronomeMeter,
              subdivision: _metronomeSubdivision,
              accents: _metronomeAccentPattern,
              countInBars: _metronomeCountInBars,
              haptics: _metronomeHaptics,
            ),
          ),
    );
  }

  void _stopMetronome({bool publish = true}) {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    if (SoLoud.instance.isInitialized) {
      unawaited(_metronomeClicks.stop(SoLoud.instance));
    }
    _jamSyncStartAt = null;
    _jamSyncLastStep = null;
    _pendingClockStartAt = null;
    if (mounted) {
      setState(() {
        _metronomeRunning = false;
        _metronomeIsCountIn = false;
        _metronomeBeat = 0;
      });
    }
    if (publish) {
      unawaited(ref.read(activeJamProvider.notifier).updatePlaying(false));
    }
  }

  Future<void> _disposeMetronome() async {
    await _metronomeClicks.dispose(SoLoud.instance);
  }

  Future<void> _showAudioAttachment() async {
    if (!_allowsEditing) return;
    await showEditSongSheet(context, song: widget.data.song);
    if (mounted) {
      ref.invalidate(scoreViewerDataProvider(widget.data.song.id));
    }
  }

  void _toggleAnnotationMode() {
    if (!_allowsEditing) return;
    _pointers.clear();
    _singleFingerStart = null;
    _twoFingerGestureActive = false;
    setState(() {
      _annotationMode = !_annotationMode;
      if (_annotationMode) {
        _measureEditing = false;
        _selectedMeasureId = null;
        _chromeVisible = true;
      }
      _draftAnnotationPage = null;
      _draftAnnotation = null;
    });
    _chromeHideTimer?.cancel();
    _chromeHideTimer = null;
    if (!_annotationMode) {
      _scheduleChromeHide();
    }
  }

  void _startAnnotation(int page, DragStartDetails details, Size size) {
    setState(() {
      _draftAnnotationPage = page;
      _draftAnnotation = AnnotationStroke(
        points: [_normalizedPoint(details.localPosition, size)],
        color: _annotationColor,
        width: _annotationPen.width,
        opacity: _annotationPen.opacity,
        eraser: _annotationPen.isEraser,
      );
    });
  }

  void _updateAnnotation(DragUpdateDetails details, Size size) {
    final draft = _draftAnnotation;
    if (draft == null) {
      return;
    }
    setState(() {
      _draftAnnotation = draft.copyWithPoints([
        ...draft.points,
        _normalizedPoint(details.localPosition, size),
      ]);
    });
  }

  void _loadAnnotations() {
    final songId = widget.data.song.id;
    ref.read(songFileStorageProvider).loadAnnotations(songId).then((json) {
      if (json == null || !mounted) return;
      try {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final strokes = <int, List<AnnotationStroke>>{};
        for (final entry in decoded.entries) {
          final page = int.tryParse(entry.key);
          if (page == null || entry.value is! List) continue;
          final pageStrokes = <AnnotationStroke>[];
          for (final strokeJson in entry.value as List) {
            final stroke = AnnotationStroke.tryParse(strokeJson);
            if (stroke != null) {
              pageStrokes.add(stroke);
            }
          }
          if (pageStrokes.isNotEmpty) {
            strokes[page] = pageStrokes;
          }
        }
        if (mounted && strokes.isNotEmpty) {
          setState(() {
            _annotationStrokes
              ..clear()
              ..addAll(strokes);
            _annotationHistory
              ..clear()
              ..addAll([
                for (final entry in strokes.entries)
                  for (final stroke in entry.value)
                    (page: entry.key, stroke: stroke),
              ]);
          });
        }
      } on Object {
        // Malformed annotation file; ignore.
      }
    });
  }

  void _saveAnnotations() {
    final songId = widget.data.song.id;
    final data = <String, dynamic>{};
    for (final entry in _annotationStrokes.entries) {
      data[entry.key.toString()] = entry.value
          .map((stroke) => stroke.toJson())
          .toList();
    }
    unawaited(
      ref
          .read(songFileStorageProvider)
          .saveAnnotations(songId, jsonEncode(data)),
    );
  }

  Future<void> _exportAnnotatedPdf() async {
    if (_exportingAnnotatedPdf || _annotationStrokes.isEmpty) {
      return;
    }
    setState(() => _exportingAnnotatedPdf = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.exportingAnnotatedPdf),
        duration: const Duration(days: 1),
      ),
    );

    try {
      final bytes = await ref
          .read(annotatedPdfExporterProvider)
          .export(
            sourcePath: widget.data.file.path,
            title: widget.data.song.title,
            annotations: {
              for (final entry in _annotationStrokes.entries)
                entry.key: List<AnnotationStroke>.unmodifiable(entry.value),
            },
          );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final savedPath = await FilePicker.saveFile(
        dialogTitle: l10n.exportAnnotatedPdf,
        fileName: annotatedPdfFileName(widget.data.song.title),
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      if (!mounted || savedPath == null) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.annotatedPdfExported)),
      );
    } on Object {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.annotatedPdfExportFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingAnnotatedPdf = false);
      }
    }
  }

  void _finishAnnotation() {
    final page = _draftAnnotationPage;
    final draft = _draftAnnotation;
    setState(() {
      _draftAnnotationPage = null;
      _draftAnnotation = null;
      if (page != null && draft != null && draft.points.length > 1) {
        _annotationStrokes.update(
          page,
          (strokes) => [...strokes, draft],
          ifAbsent: () => [draft],
        );
        _annotationHistory.add((page: page, stroke: draft));
      }
    });
    _saveAnnotations();
  }

  void _undoLastAnnotation() {
    if (_annotationHistory.isEmpty) {
      return;
    }
    final last = _annotationHistory.removeLast();
    setState(() {
      final strokes = _annotationStrokes[last.page];
      if (strokes == null || strokes.isEmpty) {
        return;
      }
      final index = strokes.lastIndexWhere(
        (stroke) => identical(stroke, last.stroke),
      );
      if (index >= 0) {
        strokes.removeAt(index);
      } else {
        strokes.removeLast();
      }
      if (strokes.isEmpty) {
        _annotationStrokes.remove(last.page);
      } else {
        _annotationStrokes[last.page] = List<AnnotationStroke>.from(strokes);
      }
    });
    _saveAnnotations();
  }

  void _clearAnnotations() {
    setState(() {
      _annotationStrokes.clear();
      _annotationHistory.clear();
      _draftAnnotation = null;
      _draftAnnotationPage = null;
    });
    _saveAnnotations();
  }

  void _startMeasure(int page, DragStartDetails details, Size size) {
    final point = _normalizedPoint(details.localPosition, size);
    setState(() {
      _selectedMeasureId = null;
      _editingMeasureRect = null;
      _draftMeasurePage = page;
      _draftMeasureStart = point;
      _draftMeasureRect = Rect.fromPoints(point, point);
    });
  }

  void _updateMeasure(DragUpdateDetails details, Size size) {
    final draft = _draftMeasureRect;
    final start = _draftMeasureStart;
    if (draft == null || start == null) {
      return;
    }
    setState(() {
      _draftMeasureRect = Rect.fromPoints(
        start,
        _normalizedPoint(details.localPosition, size),
      );
    });
  }

  Future<void> _finishMeasure() async {
    final page = _draftMeasurePage;
    final rect = _draftMeasureRect;
    setState(() {
      _draftMeasurePage = null;
      _draftMeasureStart = null;
      _draftMeasureRect = null;
    });
    if (page == null ||
        rect == null ||
        rect.width < 0.02 ||
        rect.height < 0.02) {
      return;
    }
    try {
      await ref
          .read(measureRepositoryProvider)
          .add(
            songId: widget.data.song.id,
            page: page,
            x: rect.left,
            y: rect.top,
            width: rect.width,
            height: rect.height,
          );
    } on Object catch (_) {
      _showMeasureError();
    }
  }

  void _selectMeasure(Measure measure) {
    setState(() {
      _selectedMeasureId = measure.id;
      _editingMeasureRect = _rectFor(measure);
    });
  }

  void _moveMeasure(Measure measure, DragUpdateDetails details, Size size) {
    final current = _editingMeasureRect ?? _rectFor(measure);
    setState(() {
      _editingMeasureRect = _clampRect(
        current.shift(
          Offset(details.delta.dx / size.width, details.delta.dy / size.height),
        ),
      );
    });
  }

  void _resizeMeasure(Measure measure, DragUpdateDetails details, Size size) {
    final current = _editingMeasureRect ?? _rectFor(measure);
    setState(() {
      _editingMeasureRect = _clampRect(
        Rect.fromLTWH(
          current.left,
          current.top,
          (current.width + details.delta.dx / size.width).clamp(
            0.02,
            1 - current.left,
          ),
          (current.height + details.delta.dy / size.height).clamp(
            0.02,
            1 - current.top,
          ),
        ),
      );
    });
  }

  Future<void> _saveMeasureRect(Measure measure) async {
    final rect = _editingMeasureRect;
    if (rect == null) {
      return;
    }
    try {
      await ref
          .read(measureRepositoryProvider)
          .updateRect(
            id: measure.id,
            x: rect.left,
            y: rect.top,
            width: rect.width,
            height: rect.height,
          );
      if (mounted) {
        setState(() => _editingMeasureRect = null);
      }
    } on Object catch (_) {
      _showMeasureError();
    }
  }

  // Not offered by any control of the viewer yet.
  // ignore: unused_element
  Future<void> _deleteMeasure(Measure? measure) async {
    if (measure == null) {
      return;
    }
    try {
      await ref.read(measureRepositoryProvider).delete(measure);
      if (mounted) {
        setState(() {
          _selectedMeasureId = null;
          _editingMeasureRect = null;
        });
      }
    } on Object catch (_) {
      _showMeasureError();
    }
  }

  // Not offered by any control of the viewer yet.
  // ignore: unused_element
  Future<void> _showSectionPicker(Measure measure) async {
    if (!_allowsEditing) return;
    final section = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      builder: (context) {
        return _stageSheet(
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.sectionLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final option in ['', ..._sectionOptions])
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context, option),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: option == measure.section
                                  ? AppColors.accent
                                  : AppColors.stageOutline,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            option.isEmpty
                                ? l10n.none
                                : _displaySectionLabel(option),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (section == null || !mounted) {
      return;
    }
    try {
      await ref
          .read(measureRepositoryProvider)
          .updateSection(
            id: measure.id,
            section: section.isEmpty ? null : section,
          );
    } on Object catch (_) {
      _showMeasureError();
    }
  }

  Future<void> _showProgressModePicker() async {
    final mode = await showModalBottomSheet<_ProgressMode>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      builder: (context) {
        return _stageSheet(
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.progressMode,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final option in _ProgressMode.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, option),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: option == _progressMode
                                ? AppColors.accent
                                : AppColors.stageOutline,
                            width: option == _progressMode ? 2 : 1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option == _ProgressMode.follow
                                  ? l10n.progressFollow
                                  : l10n.progressPage,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              option == _ProgressMode.follow
                                  ? l10n.progressFollowHint
                                  : l10n.progressPageHint,
                              style: const TextStyle(
                                color: AppColors.stageMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (mode == null || !mounted) {
      return;
    }
    setState(() => _progressMode = mode);
  }

  void _markManualOverride() {
    final pauseAudio = _audioPlaying && !_autoPaused;
    final pauseJam =
        !_applyingJamRemote &&
        _jamFollowConductor &&
        _isJamMemberOnCurrentSong();
    if (!pauseAudio && !pauseJam) {
      return;
    }
    setState(() {
      if (pauseAudio) {
        _autoPaused = true;
      }
      if (pauseJam) {
        _jamFollowConductor = false;
      }
    });
  }

  Future<void> _resumeLive(List<Measure> measures) async {
    setState(() => _autoPaused = false);
    final currentMeasure = measures
        .where((measure) => measure.number == _currentMeasureNumber)
        .firstOrNull;
    if (currentMeasure != null &&
        _controller.isReady &&
        currentMeasure.page != _pageNumber) {
      await _goToViewerPage(currentMeasure.page, duration: Duration.zero);
    }
  }

  bool _isJamMemberOnCurrentSong() {
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return false;
    }
    final session = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    if (session == null) {
      return false;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || !permissions.canFollow) {
      return false;
    }
    final shared = session.currentSong;
    return shared != null &&
        shared.title.trim().toLowerCase() ==
            widget.data.song.title.trim().toLowerCase();
  }

  void _toggleJamFollowConductor() {
    if (!_isJamMemberOnCurrentSong()) {
      return;
    }
    if (_jamFollowConductor) {
      setState(() => _jamFollowConductor = false);
      return;
    }
    unawaited(_returnToJamLive());
  }

  Future<void> _returnToJamLive() async {
    final active = ref.read(activeJamProvider);
    if (active == null || !mounted) {
      return;
    }
    final session = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    if (session == null) {
      return;
    }
    setState(() => _jamFollowConductor = true);
    _applyRemoteJamPosition(null, session);
    _applyRemoteJamMusic(null, session);
    _applyRemoteJamCountIn(null, session);
    _applyRemoteJamLoop(null, session);
    _applyRemoteJamPlaying(null, session);
  }

  Future<void> _toggleStatusBar() async {
    final visible = !_statusBarVisible;
    setState(() => _statusBarVisible = visible);
    unawaited(_persistViewerPrefs());
    await SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
    // 인셋이 바뀌면 맞춤 레이아웃을 다시 잡는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isReady) {
        _scheduleViewportRelayout();
      }
    });
  }

  void _afterSettingsClosed(VoidCallback action) {
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          action();
        }
      }),
    );
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (_onMapKey != null) {
      if (event is KeyDownEvent &&
          event.logicalKey != LogicalKeyboardKey.escape &&
          !PerformanceKeyMap.isModifier(event.logicalKey)) {
        _onMapKey!(event.logicalKey);
      }
      return true;
    }
    if (_hasTextInputFocus()) {
      return false;
    }
    final map =
        ref.read(performanceKeyMapProvider).asData?.value ??
        PerformanceKeyMap.defaults();
    final keyId = event.logicalKey.keyId;
    if (event is KeyDownEvent) {
      final direct = map.directActionFor(keyId);
      if (direct != null) {
        _performPerformanceAction(direct);
        return true;
      }
      final slot = map.slotFor(keyId);
      if (slot == null) {
        return false;
      }
      _onPedalDown(slot);
      return true;
    }
    if (event is KeyRepeatEvent) {
      final slot = map.slotFor(keyId);
      if (slot == null) {
        return map.directActionFor(keyId) != null;
      }
      _onPedalHeld(slot);
      return true;
    }
    if (event is KeyUpEvent) {
      final slot = map.slotFor(keyId);
      if (slot == null) {
        return map.directActionFor(keyId) != null;
      }
      _onPedalUp(slot);
      return true;
    }
    return false;
  }

  bool _hasTextInputFocus() {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _onPedalDown(PedalSlot slot) {
    _pedalLongTimers[slot]?.cancel();
    _pedalFlushTimers[slot]?.cancel();
    final action = _pedalInterpreter.onDown(slot, DateTime.now());
    _performPerformanceAction(action);
    if (action != null) {
      return;
    }
    _pedalLongTimers[slot] = Timer(_pedalInterpreter.longPress, () {
      _onPedalHeld(slot);
    });
  }

  void _onPedalHeld(PedalSlot slot) {
    _performPerformanceAction(_pedalInterpreter.onHeld(slot, DateTime.now()));
  }

  void _onPedalUp(PedalSlot slot) {
    _pedalLongTimers[slot]?.cancel();
    _performPerformanceAction(_pedalInterpreter.onUp(slot, DateTime.now()));
    _pedalFlushTimers[slot]?.cancel();
    _pedalFlushTimers[slot] = Timer(_pedalInterpreter.doublePress, () {
      _performPerformanceAction(
        _pedalInterpreter.flushPending(slot, DateTime.now()),
      );
    });
  }

  void _performPerformanceAction(PerformanceAction? action) {
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case PerformanceAction.previousPage:
        _turnPage(-1);
      case PerformanceAction.nextPage:
        _turnPage(1);
      case PerformanceAction.playPause:
        unawaited(_toggleAudio());
      case PerformanceAction.toggleLoop:
        _toggleLoopFromPedal();
    }
  }

  void _toggleLoopFromPedal() {
    if (_loopEnabled) {
      setState(() => _loopEnabled = false);
      unawaited(_publishJamLoop(enabled: false));
      return;
    }
    final anchors = ref
        .read(audioAnchorsProvider(widget.data.song.id))
        .asData
        ?.value;
    if (anchors == null || anchors.length < 2) {
      if (!widget.stageMode && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.needTwoAnchors)));
      }
      return;
    }
    final numbers = anchors.map((anchor) => anchor.measureNumber).toList()
      ..sort();
    final start = _loopStartMeasure ?? numbers.first;
    final end = _loopEndMeasure ?? numbers.last;
    if (start >= end) {
      return;
    }
    setState(() {
      _loopStartMeasure = start;
      _loopEndMeasure = end;
      _loopEnabled = true;
    });
    unawaited(
      _publishJamLoop(
        enabled: true,
        startMeasure: start,
        endMeasure: end,
        section: _loopSection,
      ),
    );
  }

  Future<void> _showPedalMapSheet() async {
    if (!stageAllowsMenu(widget.stageMode)) {
      return;
    }
    var map =
        ref.read(performanceKeyMapProvider).asData?.value ??
        PerformanceKeyMap.defaults();
    _PedalMapTarget? listening;
    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.stageElevated,
        showDragHandle: true,
        builder: (_) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              void listen(_PedalMapTarget target) {
                listening = target;
                setSheetState(() {});
                _onMapKey = (key) {
                  final next = switch (target) {
                    _PedalMapTarget.left => map.assign(
                      keyId: key.keyId,
                      slot: PedalSlot.left,
                    ),
                    _PedalMapTarget.right => map.assign(
                      keyId: key.keyId,
                      slot: PedalSlot.right,
                    ),
                    _PedalMapTarget.playPause => map.assign(
                      keyId: key.keyId,
                      action: PerformanceAction.playPause,
                    ),
                    _PedalMapTarget.loop => map.assign(
                      keyId: key.keyId,
                      action: PerformanceAction.toggleLoop,
                    ),
                  };
                  unawaited(
                    ref
                        .read(performanceKeyMapProvider.notifier)
                        .updateMap(next)
                        .then((_) {
                          if (!mounted) {
                            return;
                          }
                          map = next;
                          listening = null;
                          _onMapKey = null;
                          setSheetState(() {});
                        }),
                  );
                };
              }

              Widget row({
                required String title,
                required Set<int> keys,
                required _PedalMapTarget target,
              }) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    listening == target ? l10n.pressKey : map.labelFor(keys),
                    style: const TextStyle(color: AppColors.stageMuted),
                  ),
                  trailing: CompactIconButton(
                    icon: Icons.edit_rounded,
                    tooltip: l10n.change,
                    color: Colors.white,
                    onPressed: () => listen(target),
                  ),
                );
              }

              return _stageSheet(
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.pedal,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        row(
                          title: l10n.left,
                          keys: map.leftKeyIds,
                          target: _PedalMapTarget.left,
                        ),
                        row(
                          title: l10n.right,
                          keys: map.rightKeyIds,
                          target: _PedalMapTarget.right,
                        ),
                        row(
                          title: l10n.play,
                          keys: map.playPauseKeyIds,
                          target: _PedalMapTarget.playPause,
                        ),
                        row(
                          title: l10n.loop,
                          keys: map.loopKeyIds,
                          target: _PedalMapTarget.loop,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: CompactIconButton(
                            icon: Icons.restart_alt_rounded,
                            tooltip: l10n.defaults,
                            color: Colors.white,
                            onPressed: () {
                              unawaited(
                                ref
                                    .read(performanceKeyMapProvider.notifier)
                                    .updateMap(PerformanceKeyMap.defaults())
                                    .then((_) {
                                      if (!mounted) {
                                        return;
                                      }
                                      map = PerformanceKeyMap.defaults();
                                      listening = null;
                                      _onMapKey = null;
                                      setSheetState(() {});
                                    }),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _onMapKey = null;
    }
  }

  Future<void> _showMetronomeSheet({BuildContext? nestUnder}) async {
    if (!stageAllowsMenu(widget.stageMode)) return;
    _hydrateMetronomeSettings();
    unawaited(_preloadMetronomeClicks());
    final host = nestUnder ?? context;
    await showModalBottomSheet<void>(
      context: host,
      backgroundColor: AppColors.stageElevated,
      isScrollControlled: true,
      showDragHandle: nestUnder == null,
      builder: (sheetContext) {
        return Theme(
          data: AppTheme.stage,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: _buildMetronomePanel(
                    setSheetState: setSheetState,
                    sheetContext: sheetContext,
                    onBack: nestUnder == null
                        ? null
                        : () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMetronomePanel({
    required StateSetter setSheetState,
    required BuildContext sheetContext,
    VoidCallback? onBack,
  }) {
    final running = _metronomeRunning;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (onBack != null)
              IconButton(
                color: AppColors.canvas,
                tooltip: l10n.back,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            Expanded(
              child: Text(
                l10n.metronome,
                style: const TextStyle(
                  color: AppColors.canvas,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              color: AppColors.canvas,
              tooltip: l10n.bpmDown,
              onPressed: () {
                _setMetronomeBpm(_metronomeBpm - 1);
                setSheetState(() {});
              },
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 132,
              height: 48,
              child: TextField(
                controller: _metronomeBpmController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.canvas,
                  fontFamily: AppFonts.mono,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  suffixText: 'BPM',
                  suffixStyle: TextStyle(
                    color: AppColors.stageMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: false,
                  fillColor: Colors.transparent,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: _commitMetronomeBpm,
                onEditingComplete: () =>
                    _commitMetronomeBpm(_metronomeBpmController.text),
                onTapOutside: (_) =>
                    _commitMetronomeBpm(_metronomeBpmController.text),
              ),
            ),
            IconButton(
              color: AppColors.canvas,
              tooltip: l10n.bpmUp,
              onPressed: () {
                _setMetronomeBpm(_metronomeBpm + 1);
                setSheetState(() {});
              },
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        Slider(
          value: _metronomeBpm.toDouble(),
          min: 40,
          max: 240,
          divisions: 200,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.stageOutline,
          onChanged: (value) {
            _setMetronomeBpm(value.round(), publish: false);
            setSheetState(() {});
          },
          onChangeEnd: (value) {
            _setMetronomeBpm(value.round());
            setSheetState(() {});
          },
        ),
        CompactOptionTile(
          label: l10n.meter,
          value: _metronomeMeter.label,
          foregroundColor: AppColors.canvas,
          mutedColor: AppColors.stageMuted,
          onTap: () async {
            final selected = await showOptionPickerSheet<MetronomeMeter>(
              context: sheetContext,
              title: l10n.meter,
              options: metronomeMeters,
              labelOf: (meter) => meter.label,
              selected: _metronomeMeter,
              backgroundColor: AppColors.stageElevated,
              foregroundColor: Colors.white,
              mutedColor: AppColors.stageMuted,
            );
            if (selected != null) {
              _setMetronomeMeter(selected);
              setSheetState(() {});
            }
          },
        ),
        CompactOptionTile(
          label: l10n.countIn,
          value: metronomeCountInLabel(_metronomeCountInBars, l10n),
          enabled: !running,
          foregroundColor: Colors.white,
          mutedColor: AppColors.stageMuted,
          onTap: () async {
            final selected = await showOptionPickerSheet<int>(
              context: sheetContext,
              title: l10n.countIn,
              options: metronomeCountInBarOptions,
              labelOf: (bars) => metronomeCountInLabel(bars, l10n),
              selected: _metronomeCountInBars,
              backgroundColor: AppColors.stageElevated,
              foregroundColor: Colors.white,
              mutedColor: AppColors.stageMuted,
            );
            if (selected == null) {
              return;
            }
            setState(() => _metronomeCountInBars = selected);
            setSheetState(() {});
            _persistMetronomeSettings();
            unawaited(_publishJamCountInBars(selected));
          },
        ),
        const SizedBox(height: 8),
        Text(
          l10n.beatUnit,
          style: const TextStyle(
            color: AppColors.stageMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final subdivision in MetronomeSubdivision.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Tooltip(
                    message: subdivision.label,
                    child: Material(
                      color: _metronomeSubdivision == subdivision
                          ? AppColors.accent.withValues(alpha: 0.18)
                          : AppColors.stagePanel,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          _setMetronomeSubdivision(subdivision);
                          setSheetState(() {});
                        },
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _metronomeSubdivision == subdivision
                                  ? AppColors.accent
                                  : AppColors.stageOutline,
                              width: _metronomeSubdivision == subdivision
                                  ? 1.5
                                  : 1,
                            ),
                          ),
                          child: MetronomeSubdivisionIcon(
                            subdivision: subdivision,
                            color: _metronomeSubdivision == subdivision
                                ? AppColors.accent
                                : AppColors.stageMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.accent,
          style: const TextStyle(
            color: AppColors.stageMuted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var beat = 1; beat <= _metronomeBeatsPerBar; beat++)
              Tooltip(
                message: _metronomeAccentPattern[beat - 1].label(l10n),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _cycleMetronomeAccent(beat);
                    setSheetState(() {});
                  },
                  child: SizedBox(
                    width: 44,
                    height: 52,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.stagePanel,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.stageOutline,
                              width: 2,
                            ),
                          ),
                        ),
                        if (_metronomeAccentPattern[beat - 1] !=
                            MetronomeAccentLevel.mute)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              widthFactor: 1,
                              heightFactor:
                                  _metronomeAccentPattern[beat - 1] ==
                                      MetronomeAccentLevel.strong
                                  ? 1
                                  : .5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Text(
                            '$beat',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: Center(
            child: Text(
              running || _metronomeIsCountIn
                  ? _metronomeIsCountIn
                        ? '${l10n.countIn} $_metronomeBeat / $_metronomeBeatsPerBar'
                        : '$_metronomeBeat / $_metronomeBeatsPerBar'
                  : '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.stageMuted,
                fontFamily: AppFonts.mono,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: FilledButton(
            onPressed: _metronomeLoading
                ? null
                : () async {
                    final wasRunning = _metronomeRunning;
                    await _toggleMetronome();
                    if (!mounted || !sheetContext.mounted) {
                      return;
                    }
                    setSheetState(() {});
                    if (!wasRunning && _metronomeRunning && onBack == null) {
                      Navigator.pop(sheetContext);
                    }
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 64),
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.accent,
            ),
            child: Icon(
              running ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showViewerSettings(
    List<Measure> measures,
    List<AudioAnchor> anchors,
    List<Cue> cues,
    List<PracticeSession> sessions,
  ) async {
    if (!stageAllowsMenu(widget.stageMode)) return;
    final navKey = GlobalKey<NavigatorState>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.9;
        return Theme(
          data: AppTheme.stage,
          child: SizedBox(
            height: sheetHeight,
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) {
                  return;
                }
                final nav = navKey.currentState;
                if (nav != null && nav.canPop()) {
                  nav.pop();
                } else if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
              child: Navigator(
                key: navKey,
                onGenerateRoute: (_) {
                  return MaterialPageRoute<void>(
                    builder: (navContext) {
                      return StatefulBuilder(
                        builder: (context, setSheetState) {
                          void update(VoidCallback callback) {
                            setState(callback);
                            setSheetState(() {});
                          }

                          void pushSettingsPage(Widget page) {
                            Navigator.of(navContext).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    Theme(data: AppTheme.stage, child: page),
                              ),
                            );
                          }

                          final hasAudio = widget.data.audioFile != null;
                          final keyMap =
                              ref
                                  .read(performanceKeyMapProvider)
                                  .asData
                                  ?.value ??
                              PerformanceKeyMap.defaults();
                          final hardCount = measures
                              .where((measure) => measure.isDifficult)
                              .length;

                          return ColoredBox(
                            color: AppColors.stageElevated,
                            child: ViewerSettingsSheet(
                              snapshot: ViewerSettingsSnapshot(
                                hasAudio: hasAudio,
                                audioPlaying: _audioPlaying,
                                audioSpeedLabel:
                                    '${_audioSpeed.toStringAsFixed(1)}x',
                                metronomeRunning: _metronomeRunning,
                                metronomeSubtitle: _metronomeRunning
                                    ? '${_metronomeMeter.label} · $_metronomeBpm BPM · $_metronomeBeat'
                                    : l10n.meterConfigured(
                                        _metronomeMeter.label,
                                      ),
                                canLoop: anchors.length >= 2 && hasAudio,
                                loopLabel: _loopLabel,
                                viewModeLabel: _viewModeLabel,
                                hasMeasures: measures.isNotEmpty,
                                autoPaused: _autoPaused,
                                progressSubtitle: _autoPaused
                                    ? l10n.returnToCurrent
                                    : _progressMode == _ProgressMode.follow
                                    ? l10n.progressFollow
                                    : l10n.progressPage,
                                showJamFollow: _isJamMemberOnCurrentSong(),
                                jamFollowing: _jamFollowConductor,
                                jamFollowSubtitle: _jamFollowConductor
                                    ? l10n.followOn
                                    : l10n.returnToLive,
                                currentMeasureLabel:
                                    _currentMeasureNumber?.toString() ??
                                    l10n.notSelected,
                                nextSongId: widget.setlistProgress?.nextSongId,
                                canSyncAnchor: measures.isNotEmpty && hasAudio,
                                anchorsLabel: anchors.isEmpty
                                    ? l10n.none
                                    : l10n.anchorsCount(anchors.length),
                                pedalLabel:
                                    '${keyMap.labelFor(keyMap.leftKeyIds)} · ${keyMap.labelFor(keyMap.rightKeyIds)}',
                                practiceLabel: _practiceSettingsLabel(
                                  sessions.length,
                                ),
                                cuesLabel: cues.isEmpty
                                    ? l10n.none
                                    : l10n.anchorsCount(cues.length),
                                hardMeasuresLabel: l10n.anchorsCount(hardCount),
                                annotationsVisible: _annotationsVisible,
                                hasAnnotationStrokes:
                                    _annotationStrokes.isNotEmpty,
                                exportingAnnotations: _exportingAnnotatedPdf,
                                statusBarVisible: _statusBarVisible,
                                annotationMode: _annotationMode,
                                canAnnotate: _allowsEditing,
                              ),
                              actions: ViewerSettingsActions(
                                onMusic: () {
                                  if (hasAudio) {
                                    unawaited(_toggleAudio());
                                    setSheetState(() {});
                                  } else {
                                    Navigator.pop(sheetContext);
                                    _afterSettingsClosed(
                                      () => unawaited(_showAudioAttachment()),
                                    );
                                  }
                                },
                                onMetronome: () {
                                  _hydrateMetronomeSettings();
                                  unawaited(_preloadMetronomeClicks());
                                  pushSettingsPage(
                                    SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          8,
                                          20,
                                          24,
                                        ),
                                        child: StatefulBuilder(
                                          builder: (metroContext, setMetro) {
                                            return _buildMetronomePanel(
                                              setSheetState: (fn) {
                                                setMetro(fn);
                                                setSheetState(fn);
                                              },
                                              sheetContext: metroContext,
                                              onBack: () => Navigator.of(
                                                metroContext,
                                              ).pop(),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                onViewMode: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(_showViewModePicker()),
                                  );
                                },
                                onAnnotations: () {
                                  Navigator.pop(sheetContext);
                                  _toggleAnnotationMode();
                                },
                                onPlaybackSpeed: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(_showPlaybackSpeedSheet()),
                                  );
                                },
                                onLoop: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(
                                      _showLoopSheet(measures, anchors),
                                    ),
                                  );
                                },
                                onAutoAdvance: () {
                                  Navigator.pop(sheetContext);
                                  if (_autoPaused) {
                                    unawaited(_resumeLive(measures));
                                  } else {
                                    _afterSettingsClosed(
                                      () =>
                                          unawaited(_showProgressModePicker()),
                                    );
                                  }
                                },
                                onJamFollow: () {
                                  Navigator.pop(sheetContext);
                                  _toggleJamFollowConductor();
                                },
                                onCurrentMeasure: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(
                                      _showCurrentMeasurePicker(measures),
                                    ),
                                  );
                                },
                                onNextSong: (songId) {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => _openSetlistSong(songId),
                                  );
                                },
                                onSyncAnchor: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(
                                      _showSyncAnchorSheet(measures, anchors),
                                    ),
                                  );
                                },
                                onPedal: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(_showPedalMapSheet()),
                                  );
                                },
                                onPracticeLog: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () =>
                                        unawaited(_showPracticeSheet(sessions)),
                                  );
                                },
                                onCues: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(
                                      _showCueSheet(measures, cues),
                                    ),
                                  );
                                },
                                onHardMeasures: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(
                                      _showDifficultMeasureSheet(measures),
                                    ),
                                  );
                                },
                                onAnnotationsVisible: (value) {
                                  update(() => _annotationsVisible = value);
                                  unawaited(_persistViewerPrefs());
                                },
                                onExportAnnotations: () {
                                  Navigator.pop(sheetContext);
                                  _afterSettingsClosed(
                                    () => unawaited(_exportAnnotatedPdf()),
                                  );
                                },
                                onClearAnnotations: () {
                                  _clearAnnotations();
                                  setSheetState(() {});
                                },
                                onStatusBar: () {
                                  unawaited(_toggleStatusBar());
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showViewModePicker() async {
    if (!stageAllowsMenu(widget.stageMode)) return;
    final mode = await showModalBottomSheet<_PdfViewMode>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      builder: (context) {
        return _stageSheet(
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.pageLayout,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final option in _PdfViewMode.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, option),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: option == _viewMode
                                ? AppColors.accent
                                : AppColors.stageOutline,
                            width: option == _viewMode ? 2 : 1,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(switch (option) {
                          _PdfViewMode.auto => l10n.layoutAuto,
                          _PdfViewMode.fit => l10n.layoutFit,
                          _PdfViewMode.twoPage => l10n.layoutTwoUp,
                          _PdfViewMode.scroll => l10n.layoutScroll,
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (mode == null || mode == _viewMode || !mounted) {
      return;
    }
    setState(() {
      _viewMode = mode;
    });
    unawaited(_persistViewerPrefs());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.isReady) {
        return;
      }
      _controller.invalidate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isReady) {
          _fitCurrentPage();
        }
      });
    });
  }

  /// 두 장 보기: 스프레드(좌·우) 사이를 크게 띄워 위·아래 장이 보이지 않게 한다.
  PdfPageLayout _layoutTwoPages(List<PdfPage> pages, PdfViewerParams params) {
    final margin = params.margin;
    var maxSpreadWidth = 0.0;
    var maxRowHeight = 0.0;
    for (var index = 0; index < pages.length; index += 2) {
      final first = pages[index];
      final second = index + 1 < pages.length ? pages[index + 1] : null;
      final rowWidth = first.width + margin + (second?.width ?? 0);
      final rowHeight = math.max(first.height, second?.height ?? 0);
      maxSpreadWidth = math.max(maxSpreadWidth, rowWidth);
      maxRowHeight = math.max(maxRowHeight, rowHeight);
    }

    final viewH = _viewerViewportSize.height;
    final viewW = _viewerViewportSize.width;
    // After fit-zoom to a spread, neighbors must stay outside the viewport.
    final viewportGap = viewH > 0 && viewW > 0 && maxSpreadWidth > 0
        ? (viewH * maxSpreadWidth / viewW)
        : maxRowHeight;
    final gap = math.max(maxRowHeight, viewportGap) + margin;
    final documentWidth = maxSpreadWidth + margin * 2;

    final pageLayouts = <Rect>[];
    // Top letterbox so the first spread is vertically centered like later ones.
    var y = gap;
    for (var index = 0; index < pages.length; index += 2) {
      final first = pages[index];
      final second = index + 1 < pages.length ? pages[index + 1] : null;
      final rowHeight = math.max(first.height, second?.height ?? 0);
      final rowWidth = first.width + margin + (second?.width ?? 0);
      final startX = (documentWidth - rowWidth) / 2;
      pageLayouts.add(
        Rect.fromLTWH(
          startX,
          y + (rowHeight - first.height) / 2,
          first.width,
          first.height,
        ),
      );
      if (second != null) {
        pageLayouts.add(
          Rect.fromLTWH(
            startX + first.width + margin,
            y + (rowHeight - second.height) / 2,
            second.width,
            second.height,
          ),
        );
      }
      y += rowHeight + gap;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(documentWidth, y),
    );
  }

  /// 맞춤 모드: 페이지 사이를 크게 띄워 letterbox에 다음 장이 보이지 않게 한다.
  PdfPageLayout _layoutFitPages(List<PdfPage> pages, PdfViewerParams params) {
    final margin = params.margin;
    final maxPageHeight = pages.fold<double>(
      0,
      (max, page) => math.max(max, page.height),
    );
    final maxPageWidth = pages.fold<double>(
      0,
      (max, page) => math.max(max, page.width),
    );
    final viewH = _viewerViewportSize.height;
    final viewW = _viewerViewportSize.width;
    // Document-space gap large enough that after fit-zoom, neighbors stay off-screen.
    final viewportGap = viewH > 0 && viewW > 0 && maxPageWidth > 0
        ? (viewH * maxPageWidth / viewW)
        : maxPageHeight;
    final gap = math.max(maxPageHeight, viewportGap) + margin;
    final width = maxPageWidth + margin * 2;
    final pageLayouts = <Rect>[];
    // 첫 장도 가운데 맞추려면, 2장부터와 같은 크기의 위쪽 여백이 필요하다.
    // 여백이 없으면 뷰어가 문서 맨 위에 붙어서 1페이지만 상단 정렬된다.
    var y = gap;
    for (final page in pages) {
      pageLayouts.add(
        Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height),
      );
      y += page.height + gap;
    }
    return PdfPageLayout(
      pageLayouts: pageLayouts,
      documentSize: Size(width, y),
    );
  }

  PdfPageLayoutFunction? get _layoutPagesForMode {
    return switch (_effectiveViewMode) {
      _PdfViewMode.twoPage => _layoutTwoPages,
      _PdfViewMode.fit => _layoutFitPages,
      _PdfViewMode.scroll || _PdfViewMode.auto => null,
    };
  }

  Rect _viewAreaForPage(int pageNumber) {
    final viewMode = _effectiveViewMode;
    final firstPage = viewMode == _PdfViewMode.twoPage
        ? ((pageNumber - 1) ~/ 2) * 2 + 1
        : pageNumber;
    final first = _controller.layout.pageLayouts[firstPage - 1];
    if (viewMode != _PdfViewMode.twoPage || firstPage >= _pageCount) {
      return first;
    }
    final second = _controller.layout.pageLayouts[firstPage];
    return Rect.fromLTRB(
      math.min(first.left, second.left),
      math.min(first.top, second.top),
      math.max(first.right, second.right),
      math.max(first.bottom, second.bottom),
    );
  }

  Matrix4 _matrixForPage(int pageNumber) {
    if (_effectiveViewMode != _PdfViewMode.scroll) {
      return _controller.calcMatrixForArea(
        rect: _viewAreaForPage(pageNumber),
        anchor: PdfPageAnchor.all,
      );
    }

    final page = _controller.layout.pageLayouts[pageNumber - 1];
    final zoom = math
        .min(
          _controller.params.maxScale,
          (_controller.viewSize.width - _controller.params.margin * 2) /
              page.width,
        )
        .clamp(_controller.minScale, _controller.params.maxScale)
        .toDouble();
    final topPosition =
        page.top +
        (_controller.viewSize.height / 2 - _controller.params.margin) / zoom;
    return _controller.calcMatrixFor(
      Offset(page.center.dx, topPosition),
      zoom: zoom,
    );
  }

  /// 맞춤/2쪽에서는 현재 페이지(스프레드) 밖으로 이동하지 않는다.
  /// 스크롤 모드만 문서 전체를 연속으로 이동할 수 있다.
  Matrix4 _normalizeViewerMatrix(
    Matrix4 matrix,
    Size viewSize,
    PdfPageLayout layout,
    PdfViewerController? controller,
  ) {
    if (_effectiveViewMode == _PdfViewMode.scroll ||
        controller == null ||
        layout.pageLayouts.isEmpty) {
      return matrix;
    }

    final page = _normalizationTargetPage ?? _pageNumber;
    final pageIndex = (page - 1).clamp(0, layout.pageLayouts.length - 1);
    final firstIndex = _effectiveViewMode == _PdfViewMode.twoPage
        ? (pageIndex ~/ 2) * 2
        : pageIndex;
    var area = layout.pageLayouts[firstIndex];
    if (_effectiveViewMode == _PdfViewMode.twoPage &&
        firstIndex + 1 < layout.pageLayouts.length) {
      final second = layout.pageLayouts[firstIndex + 1];
      area = Rect.fromLTRB(
        math.min(area.left, second.left),
        math.min(area.top, second.top),
        math.max(area.right, second.right),
        math.max(area.bottom, second.bottom),
      );
    }

    final zoom = matrix.getMaxScaleOnAxis();
    if (zoom <= 0) {
      return matrix;
    }
    final halfWidth = viewSize.width / (2 * zoom);
    final halfHeight = viewSize.height / (2 * zoom);
    final center = matrix.calcPosition(viewSize);
    final minX = area.left + halfWidth;
    final maxX = area.right - halfWidth;
    final minY = area.top + halfHeight;
    final maxY = area.bottom - halfHeight;
    final clampedCenter = Offset(
      minX > maxX ? area.center.dx : center.dx.clamp(minX, maxX),
      minY > maxY ? area.center.dy : center.dy.clamp(minY, maxY),
    );
    return controller.calcMatrixFor(
      clampedCenter,
      zoom: zoom,
      viewSize: viewSize,
    );
  }

  Future<void> _goToViewerPage(
    int pageNumber, {
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    if (!_controller.isReady) {
      return;
    }
    final pageCount = _pageCount > 0 ? _pageCount : _controller.pageCount;
    if (pageCount == 0) {
      return;
    }
    final target = _normalizePageNumber(pageNumber.clamp(1, pageCount));
    _normalizationTargetPage = target;
    try {
      await _controller.goTo(_matrixForPage(target), duration: duration);
    } finally {
      if (_normalizationTargetPage == target) {
        _normalizationTargetPage = null;
      }
    }
    _controller.setCurrentPageNumber(target);
  }

  Future<void> _showCurrentMeasurePicker(List<Measure> measures) async {
    if (!stageAllowsMenu(widget.stageMode)) return;
    final measureNumber = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      builder: (context) {
        return _stageSheet(
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.currentMeasure,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final measure in measures)
                        OutlinedButton(
                          onPressed: () =>
                              Navigator.pop(context, measure.number),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: measure.number == _currentMeasureNumber
                                  ? AppColors.accent
                                  : AppColors.stageOutline,
                              width: measure.number == _currentMeasureNumber
                                  ? 2
                                  : 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            '${measure.number}',
                            style: const TextStyle(color: AppColors.canvas),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (measureNumber == null || !mounted) {
      return;
    }
    final measure = measures
        .where((item) => item.number == measureNumber)
        .firstOrNull;
    if (measure == null) {
      return;
    }
    _markManualOverride();
    setState(() {
      _currentMeasureNumber = measure.number;
    });
    _scheduleJamPositionPublish();
    if (_controller.isReady && measure.page != _pageNumber) {
      await _goToViewerPage(measure.page, duration: Duration.zero);
    }
  }

  // Not offered by any control of the viewer yet.
  // ignore: unused_element
  Future<void> _showTempoMapEditor(Measure measure, TempoMap? existing) async {
    if (!_allowsEditing) return;
    final startController = TextEditingController(
      text: (existing?.startMeasure ?? measure.number).toString(),
    );
    final endController = TextEditingController(
      text: (existing?.endMeasure ?? measure.number).toString(),
    );
    final startBpmController = TextEditingController(
      text: (existing?.startBpm ?? widget.data.song.defaultTempo ?? 120)
          .toString(),
    );
    final endBpmController = TextEditingController(
      text: (existing?.endBpm ?? widget.data.song.defaultTempo ?? 120)
          .toString(),
    );
    var mode = existing?.mode ?? 'step';
    String? error;

    final result =
        await showModalBottomSheet<
          ({
            String mode,
            int startMeasure,
            int endMeasure,
            int startBpm,
            int? endBpm,
            bool delete,
          })
        >(
          context: context,
          backgroundColor: AppColors.stageElevated,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                Widget numberField(
                  TextEditingController controller,
                  String label,
                ) {
                  return Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: label,
                        labelStyle: const TextStyle(
                          color: AppColors.stageMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.stagePanel,
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.stageOutline),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                  );
                }

                return _stageSheet(
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        MediaQuery.viewInsetsOf(context).bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.tempoMap,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final option in ['step', 'gradual'])
                                ChoiceChip(
                                  label: Text(
                                    option == 'step'
                                        ? l10n.tempoStep
                                        : l10n.tempoGradual,
                                  ),
                                  selected: mode == option,
                                  onSelected: (_) =>
                                      setModalState(() => mode = option),
                                  selectedColor: AppColors.accent,
                                  labelStyle: TextStyle(
                                    color: mode == option
                                        ? Colors.white
                                        : AppColors.stageMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              numberField(startController, l10n.startMeasure),
                              const SizedBox(width: 12),
                              numberField(endController, l10n.endMeasure),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              numberField(startBpmController, l10n.startBpm),
                              if (mode == 'gradual') ...[
                                const SizedBox(width: 12),
                                numberField(endBpmController, l10n.endBpm),
                              ],
                            ],
                          ),
                          if (error case final message?) ...[
                            const SizedBox(height: 12),
                            Text(
                              message,
                              style: const TextStyle(color: Color(0xFFFF8A65)),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (existing != null)
                                TextButton(
                                  onPressed: () => Navigator.pop(context, (
                                    mode: existing.mode,
                                    startMeasure: existing.startMeasure,
                                    endMeasure: existing.endMeasure,
                                    startBpm: existing.startBpm,
                                    endBpm: existing.endBpm,
                                    delete: true,
                                  )),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF8A65),
                                  ),
                                  child: Text(l10n.delete),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () {
                                  final startMeasure = int.tryParse(
                                    startController.text,
                                  );
                                  final endMeasure = int.tryParse(
                                    endController.text,
                                  );
                                  final startBpm = int.tryParse(
                                    startBpmController.text,
                                  );
                                  final endBpm = mode == 'gradual'
                                      ? int.tryParse(endBpmController.text)
                                      : null;
                                  if (startMeasure == null ||
                                      endMeasure == null ||
                                      startBpm == null ||
                                      (mode == 'gradual' && endBpm == null)) {
                                    setModalState(
                                      () => error = l10n.checkInput,
                                    );
                                    return;
                                  }
                                  Navigator.pop(context, (
                                    mode: mode,
                                    startMeasure: startMeasure,
                                    endMeasure: endMeasure,
                                    startBpm: startBpm,
                                    endBpm: endBpm,
                                    delete: false,
                                  ));
                                },
                                child: Text(l10n.save),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
    startController.dispose();
    endController.dispose();
    startBpmController.dispose();
    endBpmController.dispose();

    if (result == null || !mounted) {
      return;
    }
    try {
      final repository = ref.read(tempoMapRepositoryProvider);
      if (result.delete) {
        if (existing != null) {
          await repository.delete(existing);
        }
      } else {
        await repository.save(
          id: existing?.id,
          songId: widget.data.song.id,
          startMeasure: result.startMeasure,
          endMeasure: result.endMeasure,
          mode: result.mode,
          startBpm: result.startBpm,
          endBpm: result.endBpm,
        );
      }
    } on Object catch (_) {
      _showMeasureError();
    }
  }

  // Not offered by any control of the viewer yet.
  // ignore: unused_element
  Future<void> _showTimeSignatureEditor(
    Measure measure,
    TimeSignatureMap? existing,
  ) async {
    if (!_allowsEditing) return;
    final startController = TextEditingController(
      text: (existing?.startMeasure ?? measure.number).toString(),
    );
    final endController = TextEditingController(
      text: (existing?.endMeasure ?? measure.number).toString(),
    );
    final numeratorController = TextEditingController(
      text: (existing?.numerator ?? 4).toString(),
    );
    final denominatorController = TextEditingController(
      text: (existing?.denominator ?? 4).toString(),
    );
    String? error;

    final result =
        await showModalBottomSheet<
          ({
            int startMeasure,
            int endMeasure,
            int numerator,
            int denominator,
            bool delete,
          })
        >(
          context: context,
          backgroundColor: AppColors.stageElevated,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                Widget numberField(
                  TextEditingController controller,
                  String label,
                ) {
                  return Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: label,
                        labelStyle: const TextStyle(
                          color: AppColors.stageMuted,
                        ),
                        filled: true,
                        fillColor: AppColors.stagePanel,
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.stageOutline),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                  );
                }

                return _stageSheet(
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        MediaQuery.viewInsetsOf(context).bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.timeSignature,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              numberField(startController, l10n.startMeasure),
                              const SizedBox(width: 12),
                              numberField(endController, l10n.endMeasure),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              numberField(numeratorController, l10n.numerator),
                              const SizedBox(width: 12),
                              numberField(
                                denominatorController,
                                l10n.denominator,
                              ),
                            ],
                          ),
                          if (error case final message?) ...[
                            const SizedBox(height: 12),
                            Text(
                              message,
                              style: const TextStyle(color: Color(0xFFFF8A65)),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              if (existing != null)
                                TextButton(
                                  onPressed: () => Navigator.pop(context, (
                                    startMeasure: existing.startMeasure,
                                    endMeasure: existing.endMeasure,
                                    numerator: existing.numerator,
                                    denominator: existing.denominator,
                                    delete: true,
                                  )),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF8A65),
                                  ),
                                  child: Text(l10n.delete),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () {
                                  final startMeasure = int.tryParse(
                                    startController.text,
                                  );
                                  final endMeasure = int.tryParse(
                                    endController.text,
                                  );
                                  final numerator = int.tryParse(
                                    numeratorController.text,
                                  );
                                  final denominator = int.tryParse(
                                    denominatorController.text,
                                  );
                                  if (startMeasure == null ||
                                      endMeasure == null ||
                                      numerator == null ||
                                      denominator == null) {
                                    setModalState(
                                      () => error = l10n.checkInput,
                                    );
                                    return;
                                  }
                                  Navigator.pop(context, (
                                    startMeasure: startMeasure,
                                    endMeasure: endMeasure,
                                    numerator: numerator,
                                    denominator: denominator,
                                    delete: false,
                                  ));
                                },
                                child: Text(l10n.save),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
    startController.dispose();
    endController.dispose();
    numeratorController.dispose();
    denominatorController.dispose();

    if (result == null || !mounted) {
      return;
    }
    try {
      final repository = ref.read(timeSignatureMapRepositoryProvider);
      if (result.delete) {
        if (existing != null) {
          await repository.delete(existing);
        }
      } else {
        await repository.save(
          id: existing?.id,
          songId: widget.data.song.id,
          startMeasure: result.startMeasure,
          endMeasure: result.endMeasure,
          numerator: result.numerator,
          denominator: result.denominator,
        );
      }
    } on Object catch (_) {
      _showMeasureError();
    }
  }

  Offset _normalizedPoint(Offset point, Size size) {
    return Offset(
      (point.dx / size.width).clamp(0, 1),
      (point.dy / size.height).clamp(0, 1),
    );
  }

  Rect _rectFor(Measure measure) =>
      Rect.fromLTWH(measure.x, measure.y, measure.width, measure.height);

  Rect _clampRect(Rect rect) {
    final width = rect.width.clamp(0.02, 1.0);
    final height = rect.height.clamp(0.02, 1.0);
    return Rect.fromLTWH(
      rect.left.clamp(0.0, 1.0 - width),
      rect.top.clamp(0.0, 1.0 - height),
      width,
      height,
    );
  }

  TempoMap? _tempoMapFor(List<TempoMap> maps, int measureNumber) {
    return maps.where((map) => map.startMeasure == measureNumber).firstOrNull;
  }

  String _tempoLabel(TempoMap map) {
    return map.mode == 'gradual'
        ? '${map.startBpm}→${map.endBpm}'
        : '${map.startBpm} BPM';
  }

  String _timeSignatureLabel(TimeSignatureMap map) {
    return '${map.numerator}/${map.denominator}';
  }

  void _showMeasureError() {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.saveFailed)));
    }
  }

  List<Widget> _buildMeasureOverlays(
    int page,
    Size size,
    List<Measure> measures,
    List<TempoMap> tempoMaps,
    List<TimeSignatureMap> timeSignatureMaps, {
    required List<Cue> cues,
    required bool interactive,
    required int? currentMeasureNumber,
  }) {
    final pageMeasures = measures.where((measure) => measure.page == page);
    final strokes = _annotationStrokes[page] ?? const <AnnotationStroke>[];
    final activeStroke = _draftAnnotationPage == page ? _draftAnnotation : null;
    return [
      if (_annotationsVisible && (strokes.isNotEmpty || activeStroke != null))
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _AnnotationPainter(
                strokes: strokes,
                activeStroke: activeStroke,
              ),
            ),
          ),
        ),
      if (interactive)
        Positioned.fill(
          child: GestureDetector(
            key: ValueKey('measure-editor-$page'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) => _startMeasure(page, details, size),
            onPanUpdate: (details) => _updateMeasure(details, size),
            onPanEnd: (_) => _finishMeasure(),
          ),
        ),
      for (final measure in pageMeasures)
        _measureBox(
          measure,
          size,
          _tempoMapFor(tempoMaps, measure.number),
          _timeSignatureMapFor(timeSignatureMaps, measure.number),
          cue: cues
              .where((cue) => cue.measureNumber == measure.number)
              .firstOrNull,
          interactive: interactive,
          highlighted: measure.number == currentMeasureNumber,
        ),
      if (interactive && _draftMeasurePage == page)
        if (_draftMeasureRect case final rect?) _measureFrame(rect, size),
      if (_annotationMode)
        Positioned.fill(
          child: GestureDetector(
            key: ValueKey('annotation-editor-$page'),
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            onPanStart: (details) => _startAnnotation(page, details, size),
            onPanUpdate: (details) => _updateAnnotation(details, size),
            onPanEnd: (_) => _finishAnnotation(),
          ),
        ),
    ];
  }

  TimeSignatureMap? _timeSignatureMapFor(
    List<TimeSignatureMap> maps,
    int measureNumber,
  ) {
    return maps.where((map) => map.startMeasure == measureNumber).firstOrNull;
  }

  Widget _measureBox(
    Measure measure,
    Size size,
    TempoMap? tempoMap,
    TimeSignatureMap? timeSignatureMap, {
    Cue? cue,
    required bool interactive,
    required bool highlighted,
  }) {
    final selected = interactive && measure.id == _selectedMeasureId;
    final rect = selected && _editingMeasureRect != null
        ? _editingMeasureRect!
        : _rectFor(measure);
    final scaled = Rect.fromLTWH(
      rect.left * size.width,
      rect.top * size.height,
      rect.width * size.width,
      rect.height * size.height,
    );
    if (!interactive && !highlighted) {
      return Positioned.fromRect(
        rect: scaled,
        child: !measure.isDifficult && cue == null
            ? const SizedBox.shrink()
            : Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (measure.isDifficult) const ViewerHardBadge(),
                    if (cue != null) ViewerCueBadge(label: cue.label),
                  ],
                ),
              ),
      );
    }
    return Positioned.fromRect(
      rect: scaled,
      child: IgnorePointer(
        ignoring: !interactive,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectMeasure(measure),
          onPanStart: (_) => _selectMeasure(measure),
          onPanUpdate: (details) => _moveMeasure(measure, details, size),
          onPanEnd: (_) => _saveMeasureRect(measure),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.accent.withValues(alpha: 0.22)
                  : AppColors.accent.withValues(alpha: 0.10),
              border: Border.all(
                color: AppColors.accent,
                width: selected
                    ? 3
                    : highlighted
                    ? 4
                    : 2,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 4,
                  top: 4,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: AppColors.stage),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        '${measure.number}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (measure.isDifficult)
                  Positioned(right: 4, top: 4, child: const ViewerHardBadge()),
                if (measure.section case final section?)
                  Positioned(
                    left: 4,
                    top: 34,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        section,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (tempoMap != null)
                  Positioned(
                    left: 4,
                    top: measure.section == null ? 34 : 50,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        _tempoLabel(tempoMap),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFC68A3C),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (timeSignatureMap != null)
                  Positioned(
                    left: 4,
                    top:
                        34 +
                        (measure.section == null ? 0 : 16) +
                        (tempoMap == null ? 0 : 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        _timeSignatureLabel(timeSignatureMap),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7EC8FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (cue != null)
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: ViewerCueBadge(label: cue.label),
                  ),
                if (selected)
                  Positioned(
                    right: -12,
                    bottom: -12,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) =>
                          _resizeMeasure(measure, details, size),
                      onPanEnd: (_) => _saveMeasureRect(measure),
                      child: const SizedBox.square(
                        dimension: 32,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _measureFrame(Rect rect, Size size) {
    return Positioned.fromRect(
      rect: Rect.fromLTWH(
        rect.left * size.width,
        rect.top * size.height,
        rect.width * size.width,
        rect.height * size.height,
      ),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0x1AFF4800),
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.accent, width: 2),
          ),
        ),
      ),
    );
  }

  void _onViewerReady() {
    if (!mounted) {
      return;
    }
    _scheduleChromeHide();
    setState(() {
      _pageNumber = _normalizePageNumber(_controller.pageNumber ?? 1);
      _pageCount = _controller.pageCount;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isReady) {
        _fitCurrentPage();
      }
    });
    if (widget.startJam && !_startJamRequested) {
      _startJamRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startJamAfterViewerReady());
      });
    }
  }

  Future<void> _startJamAfterViewerReady() async {
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    JamSession? session;
    try {
      session = await ref.read(jamSessionProvider(active.sessionId).future);
    } on Object {
      return;
    }
    if (!mounted || session == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null) {
      return;
    }
    await _toggleMetronome(
      publish: permissions.canLead && !session.playing,
      jamStartAt: session.playing ? session.startAt : null,
    );
  }

  void _scheduleJamPositionPublish() {
    if (_applyingJamRemote) {
      return;
    }
    _jamPositionPublishTimer?.cancel();
    _jamPositionPublishTimer = Timer(const Duration(milliseconds: 120), () {
      unawaited(_publishJamPosition());
      unawaited(_publishJamMusic());
    });
  }

  void _scheduleJamMusicPublish() {
    if (_applyingJamRemote) {
      return;
    }
    _jamMusicPublishTimer?.cancel();
    _jamMusicPublishTimer = Timer(const Duration(milliseconds: 120), () {
      unawaited(_publishJamMusic());
    });
  }

  String? _currentJamSection(List<Measure> measures) {
    return calculateStageSectionPreview(
      measures.map(
        (measure) => StageSectionMarker(
          number: measure.number,
          section: measure.section,
        ),
      ),
      currentMeasure: _currentMeasureNumber,
    )?.currentSection;
  }

  Future<void> _publishJamPosition() async {
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final session = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    if (session == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || !permissions.canLead) {
      return;
    }
    final shared = session.currentSong;
    if (shared == null ||
        shared.title.trim().toLowerCase() !=
            widget.data.song.title.trim().toLowerCase()) {
      return;
    }
    await ref
        .read(activeJamProvider.notifier)
        .updatePosition(page: _pageNumber, measure: _currentMeasureNumber);
  }

  Future<void> _publishJamMusic() async {
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final session = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    if (session == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || !permissions.canLead) {
      return;
    }
    final shared = session.currentSong;
    if (shared == null ||
        shared.title.trim().toLowerCase() !=
            widget.data.song.title.trim().toLowerCase()) {
      return;
    }
    final measures =
        ref.read(measuresProvider(widget.data.song.id)).asData?.value ??
        const <Measure>[];
    final music = JamMusicState(
      bpm: _metronomeBpm,
      section: _currentJamSection(measures),
      meterNumerator: _metronomeMeter.numerator,
      meterDenominator: _metronomeMeter.denominator,
      subdivision: _metronomeSubdivision.name,
      accents: [for (final accent in _metronomeAccentPattern) accent.index],
    );
    await ref
        .read(activeJamProvider.notifier)
        .updateMusic(
          bpm: music.bpm,
          section: music.section,
          meterNumerator: music.meterNumerator,
          meterDenominator: music.meterDenominator,
          subdivision: music.subdivision,
          accents: music.accents,
        );
    final entryId = session.currentEntryId;
    if (entryId != null) {
      try {
        await ref
            .read(setlistRepositoryProvider)
            .updateMetronome(entryId: entryId, music: jamMusicProfile(music));
      } on Object {
        // A session can outlive a local setlist entry; Jam sync still wins.
      }
    }
  }

  void _applyRemoteJamPosition(JamSession? previous, JamSession? session) {
    if (session == null || !mounted || !_jamFollowConductor) {
      return;
    }
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || permissions.canLead) {
      return;
    }
    final shared = session.currentSong;
    if (shared == null ||
        shared.title.trim().toLowerCase() !=
            widget.data.song.title.trim().toLowerCase()) {
      return;
    }
    final position = session.position;
    if (position == null || position == previous?.position) {
      return;
    }

    _applyingJamRemote = true;
    if (position.measure != null) {
      setState(() => _currentMeasureNumber = position.measure);
    }
    final measures =
        ref.read(measuresProvider(widget.data.song.id)).asData?.value ??
        const <Measure>[];
    final measurePage = position.measure == null
        ? null
        : measures
              .where((item) => item.number == position.measure)
              .firstOrNull
              ?.page;
    // Jam shares a logical PDF page. A two-page viewer represents pages 1/2,
    // 3/4, … as one local spread, so normalize before comparing or navigating.
    final remotePage = measurePage ?? position.page;
    final targetPage = remotePage == null
        ? null
        : _normalizePageNumber(remotePage);
    if (targetPage != null &&
        targetPage != _pageNumber &&
        _controller.isReady) {
      unawaited(_goToViewerPage(targetPage, duration: Duration.zero));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyingJamRemote = false;
    });
  }

  void _applyRemoteJamMusic(JamSession? previous, JamSession? session) {
    if (session == null || !mounted || !_jamFollowConductor) {
      return;
    }
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || permissions.canLead) {
      return;
    }
    final shared = session.currentSong;
    if (shared == null ||
        shared.title.trim().toLowerCase() !=
            widget.data.song.title.trim().toLowerCase()) {
      return;
    }
    final music = session.music;
    if (music == null || music == previous?.music) {
      return;
    }

    _applyingJamRemote = true;
    if (music.bpm != null && music.bpm != _metronomeBpm) {
      _setMetronomeBpm(
        music.bpm!,
        publish: false,
        persist: false,
        restart: false,
      );
    }
    _applyRemoteJamMetronomeSettings(music);
    final section = music.section;
    if (section != null && section != previous?.music?.section) {
      final measures =
          ref.read(measuresProvider(widget.data.song.id)).asData?.value ??
          const <Measure>[];
      final target = measures
          .where((item) => normalizeJamSection(item.section) == section)
          .firstOrNull;
      if (target != null) {
        setState(() => _currentMeasureNumber = target.number);
        if (_controller.isReady && target.page != _pageNumber) {
          unawaited(_goToViewerPage(target.page, duration: Duration.zero));
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyingJamRemote = false;
    });
  }

  void _applyRemoteJamMetronomeSettings(JamMusicState music) {
    MetronomeMeter? remoteMeter;
    if (music.meterNumerator != null && music.meterDenominator != null) {
      remoteMeter = metronomeMeters
          .where(
            (meter) =>
                meter.numerator == music.meterNumerator &&
                meter.denominator == music.meterDenominator,
          )
          .firstOrNull;
    }
    final remoteSubdivision = music.subdivision == null
        ? null
        : MetronomeSubdivision.values
              .where((value) => value.name == music.subdivision)
              .firstOrNull;
    final meter = remoteMeter ?? _metronomeMeter;
    final subdivision = remoteSubdivision ?? _metronomeSubdivision;
    final remoteAccents = music.accents;
    final accentValues =
        remoteAccents ??
        [for (final accent in _metronomeAccentPattern) accent.index];
    final accents = List.generate(
      meter.numerator,
      (index) => index < accentValues.length
          ? MetronomeAccentLevel.values[accentValues[index]
                .clamp(0, MetronomeAccentLevel.values.length - 1)
                .toInt()]
          : MetronomeAccentLevel.normal,
    );
    final changed =
        meter != _metronomeMeter ||
        subdivision != _metronomeSubdivision ||
        !_sameAccentPattern(accents, _metronomeAccentPattern);
    if (!changed) {
      return;
    }
    setState(() {
      _metronomeMeter = meter;
      _metronomeSubdivision = subdivision;
      _metronomeAccentPattern = accents;
      _metronomeSequence.configure(
        beatsPerBar: meter.numerator,
        stepsPerBeat: subdivision.stepsPerBeat,
        accentPattern: accents,
      );
    });
    if (_metronomeRunning && SoLoud.instance.isInitialized) {
      _restartMetronomeClock(SoLoud.instance);
    }
  }

  bool _sameAccentPattern(
    List<MetronomeAccentLevel> first,
    List<MetronomeAccentLevel> second,
  ) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }

  void _applyRemoteJamPlaying(JamSession? previous, JamSession? session) {
    if (session == null || !mounted || !_jamFollowConductor) {
      return;
    }
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null) {
      return;
    }
    if (permissions.canLead) {
      if (!session.playing && _metronomeRunning) {
        _stopMetronome(publish: false);
      }
      return;
    }
    final shared = session.currentSong;
    if (shared == null ||
        shared.title.trim().toLowerCase() !=
            widget.data.song.title.trim().toLowerCase()) {
      return;
    }
    if (previous != null && previous.playing == session.playing) {
      return;
    }
    if (session.playing && !_metronomeRunning) {
      if (_metronomeCountInBars != session.countInBars) {
        _metronomeCountInBars = session.countInBars;
      }
      unawaited(_startMetronomeFromJam(session));
    } else if (!session.playing && _metronomeRunning) {
      _stopMetronome(publish: false);
    }
  }

  Future<void> _startMetronomeFromJam(JamSession session) async {
    if (!mounted || !_jamFollowConductor || _metronomeRunning) {
      return;
    }
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final current = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    if (current == null || !current.playing) {
      return;
    }
    await _toggleMetronome(publish: false, jamStartAt: session.startAt);
  }

  void _applyRemoteJamCountIn(JamSession? previous, JamSession? session) {
    if (session == null || !mounted || !_jamFollowConductor) {
      return;
    }
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || permissions.canLead) {
      return;
    }
    if (previous != null && previous.countInBars == session.countInBars) {
      return;
    }
    if (_metronomeCountInBars == session.countInBars) {
      return;
    }
    setState(() => _metronomeCountInBars = session.countInBars);
  }

  Future<void> _publishJamCountInBars(int bars) async {
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final session = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    if (session == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || !permissions.canLead) {
      return;
    }
    await ref.read(activeJamProvider.notifier).updateCountInBars(bars);
  }

  void _applyRemoteJamLoop(JamSession? previous, JamSession? session) {
    if (session == null || !mounted || !_jamFollowConductor) {
      return;
    }
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || permissions.canLead) {
      return;
    }
    final shared = session.currentSong;
    if (shared == null ||
        shared.title.trim().toLowerCase() !=
            widget.data.song.title.trim().toLowerCase()) {
      return;
    }
    final loop = session.loop;
    if (loop == previous?.loop) {
      return;
    }
    if (loop == null || !loop.enabled) {
      setState(() {
        _loopEnabled = false;
        _loopStartMeasure = null;
        _loopEndMeasure = null;
        _loopSection = null;
      });
      return;
    }
    if (!loop.isActive) {
      return;
    }
    setState(() {
      _loopEnabled = true;
      _loopStartMeasure = loop.startMeasure;
      _loopEndMeasure = loop.endMeasure;
      _loopSection = loop.section;
    });
  }

  Future<void> _publishJamLoop({
    required bool enabled,
    int? startMeasure,
    int? endMeasure,
    String? section,
  }) async {
    final active = ref.read(activeJamProvider);
    if (active == null) {
      return;
    }
    final session = ref
        .read(jamSessionProvider(active.sessionId))
        .asData
        ?.value;
    if (session == null) {
      return;
    }
    final permissions = session.permissionsFor(active.participantId);
    if (permissions == null || !permissions.canLead) {
      return;
    }
    final loop = normalizeJamLoop(
      enabled: enabled,
      startMeasure: startMeasure,
      endMeasure: endMeasure,
      section: section,
    );
    if (loop == null) {
      return;
    }
    await ref.read(activeJamProvider.notifier).updateLoop(loop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (size == Size.zero) {
      return;
    }
    // 뷰어가 준비되기 전에는 MediaQuery로 대략적인 크기를 쓴다.
    // 준비 후에는 onViewSizeChanged의 실제 크기를 유지하고, 폴드/회전만 감지한다.
    if (!_controller.isReady) {
      _viewerViewportSize = size;
      _lastMediaSize = size;
      return;
    }
    if (_lastMediaSize == size) {
      return;
    }
    _lastMediaSize = size;
    _scheduleViewportRelayout();
  }

  /// 폴드/회전처럼 뷰포트가 연속으로 바뀌는 동안 한 번만 다시 맞춘다.
  void _scheduleViewportRelayout() {
    final mode = _effectiveViewMode;
    if (mode == _PdfViewMode.scroll) {
      return;
    }
    _viewportRelayoutTimer?.cancel();
    // pdfrx가 크기 변경 직후 이전 줌/위치를 복원하므로, 그보다 늦게 맞춤을 덮어쓴다.
    _viewportRelayoutTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted || !_controller.isReady) {
        return;
      }
      _controller.invalidate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.isReady) {
          return;
        }
        _fitCurrentPage();
      });
    });
  }

  void _onViewerViewSizeChanged(
    Size viewSize,
    Size? oldViewSize,
    PdfViewerController controller,
  ) {
    if (viewSize == Size.zero) {
      return;
    }
    final previous = _viewerViewportSize;
    _viewerViewportSize = viewSize;
    if (oldViewSize == null || previous == Size.zero) {
      return;
    }
    if ((viewSize.width - previous.width).abs() < 1 &&
        (viewSize.height - previous.height).abs() < 1) {
      return;
    }
    _scheduleViewportRelayout();
  }

  bool _handleTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    final suppressUntil = _suppressTapUntil;
    if (suppressUntil != null && DateTime.now().isBefore(suppressUntil)) {
      return true;
    }
    if (_annotationMode || _measureEditing) {
      return true;
    }
    if (details.type == PdfViewerGeneralTapType.doubleTap) {
      return true;
    }
    if (details.type != PdfViewerGeneralTapType.tap) {
      return false;
    }
    if (!_chromeVisible) {
      _markManualOverride();
      _turnPage(1);
      return true;
    }

    final width = MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;
    if (x > width * 0.25 && x < width * 0.75) {
      _toggleChrome();
      return true;
    }
    _markManualOverride();
    _turnPage(x <= width * 0.25 ? -1 : 1);
    return true;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_annotationMode || _measureEditing) {
      return;
    }
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 1) {
      _singleFingerStart = event.localPosition;
    }
    if (_pointers.length != 2 || !_controller.isReady) {
      return;
    }

    _singleFingerStart = null;
    final positions = _pointers.values.take(2).toList();
    final focalPoint = _focalPoint(positions);
    _gestureDocumentFocalPoint = _controller.localToDocument(focalPoint);
    _gestureInitialLocalFocalPoint = focalPoint;
    _gestureInitialDistance = (positions.first - positions.last).distance;
    _gestureInitialZoom = _controller.currentZoom;
    _twoFingerGestureActive = true;
    _twoFingerGestureMoved = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_annotationMode || _measureEditing) {
      return;
    }
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }
    _pointers[event.pointer] = event.localPosition;

    if (_pointers.length < 2 ||
        !stageAllowsTwoFingerZoom(widget.stageMode) ||
        !_controller.isReady ||
        _gestureDocumentFocalPoint == null ||
        _gestureInitialDistance == null ||
        _gestureInitialZoom == null) {
      return;
    }

    final positions = _pointers.values.take(2).toList();
    final focalPoint = _focalPoint(positions);
    final distance = (positions.first - positions.last).distance;
    final scale = _gestureInitialDistance! == 0
        ? 1.0
        : distance / _gestureInitialDistance!;
    final zoom = (_gestureInitialZoom! * scale).clamp(
      _controller.minScale,
      _controller.params.maxScale,
    );

    if ((scale - 1).abs() > 0.015 ||
        (focalPoint - _gestureInitialLocalFocalPoint!).distance > 6) {
      _twoFingerGestureMoved = true;
    }

    final matrix = _controller.calcMatrixFor(
      _gestureDocumentFocalPoint!,
      zoom: zoom,
      viewSize: Size(focalPoint.dx * 2, focalPoint.dy * 2),
    );
    _controller.value = _controller.makeMatrixInSafeRange(matrix);
  }

  void _onPointerEnd(PointerEvent event) {
    if (_annotationMode || _measureEditing) {
      _pointers.remove(event.pointer);
      _singleFingerStart = null;
      _twoFingerGestureActive = false;
      return;
    }
    final isSingleFinger =
        _pointers.length == 1 &&
        _pointers.containsKey(event.pointer) &&
        _singleFingerStart != null &&
        !_twoFingerGestureActive;
    final singleFingerDelta = isSingleFinger
        ? event.localPosition - _singleFingerStart!
        : Offset.zero;
    _pointers.remove(event.pointer);

    if (isSingleFinger) {
      _singleFingerStart = null;
      if (!_measureEditing &&
          singleFingerDelta.dx.abs() >= 48 &&
          singleFingerDelta.dx.abs() > singleFingerDelta.dy.abs() * 1.2) {
        _suppressTapUntil = DateTime.now().add(
          const Duration(milliseconds: 350),
        );
        _markManualOverride();
        _turnPage(singleFingerDelta.dx < 0 ? 1 : -1);
      }
      return;
    }

    if (!_twoFingerGestureActive || _pointers.isNotEmpty) {
      return;
    }

    _twoFingerGestureActive = false;
    final now = DateTime.now();
    _suppressTapUntil = now.add(const Duration(milliseconds: 350));
    if (!_twoFingerGestureMoved) {
      final previousTap = _lastTwoFingerTap;
      if (previousTap != null &&
          now.difference(previousTap) <= const Duration(milliseconds: 350)) {
        _lastTwoFingerTap = null;
        _fitCurrentPage();
      } else {
        _lastTwoFingerTap = now;
      }
    }

    _gestureDocumentFocalPoint = null;
    _gestureInitialLocalFocalPoint = null;
    _gestureInitialDistance = null;
    _gestureInitialZoom = null;
  }

  Offset _focalPoint(List<Offset> positions) {
    return Offset(
      (positions.first.dx + positions.last.dx) / 2,
      (positions.first.dy + positions.last.dy) / 2,
    );
  }

  String get _pageLabel {
    if (_pageCount == 0) {
      return l10n.loading;
    }
    if (_effectiveViewMode == _PdfViewMode.twoPage) {
      final first = _spreadFirstPage(_pageNumber);
      final second = math.min(first + 1, _pageCount);
      if (second > first) {
        return '$first–$second / $_pageCount';
      }
      return '$first / $_pageCount';
    }
    return '$_pageNumber / $_pageCount';
  }

  void _turnPage(int delta) {
    if (!_controller.isReady) {
      return;
    }
    HapticFeedback.selectionClick();

    final viewMode = _effectiveViewMode;
    if (viewMode == _PdfViewMode.scroll) {
      final target = (_pageNumber + delta).clamp(1, _controller.pageCount);
      if (target == _pageNumber) {
        unawaited(_turnSetlistSong(delta));
        return;
      }
      unawaited(_goToViewerPage(target, duration: Duration.zero));
      return;
    }

    if (viewMode == _PdfViewMode.twoPage) {
      final firstPage = ((_pageNumber - 1) ~/ 2) * 2 + 1;
      final target = (firstPage + (delta > 0 ? 2 : -2)).clamp(
        1,
        _controller.pageCount,
      );
      if (target == firstPage) {
        unawaited(_turnSetlistSong(delta));
        return;
      }
      unawaited(_goToViewerPage(target, duration: Duration.zero));
      return;
    }

    final target = (_pageNumber + delta).clamp(1, _controller.pageCount);
    if (target == _pageNumber) {
      unawaited(_turnSetlistSong(delta));
      return;
    }

    unawaited(_goToViewerPage(target, duration: Duration.zero));
  }

  Future<void> _turnSetlistSong(int delta) async {
    var progress = widget.setlistProgress;
    var songId = progress == null
        ? null
        : (delta > 0 ? progress.nextSongId : progress.previousSongId);

    // The live setlist stream can still be loading when the last page is
    // reached. Read a local snapshot once so a valid next song is not lost.
    final setlistId = widget.setlistId;
    if (songId == null && setlistId != null) {
      try {
        final items = await ref
            .read(setlistRepositoryProvider)
            .getItems(setlistId);
        progress = calculateStageSetlistProgress(
          items.map(
            (item) => StageSetlistItem(
              songId: item.song.id,
              title: item.song.title,
              offlineAvailable: item.song.offlineAvailable,
              bpm: item.tempo,
            ),
          ),
          currentSongId: widget.data.song.id,
        );
        songId = progress == null
            ? null
            : (delta > 0 ? progress.nextSongId : progress.previousSongId);
      } on Object {
        return;
      }
    }

    if (!mounted || songId == null || songId == widget.data.song.id) {
      return;
    }
    _openSetlistSong(songId);
  }

  void _fitCurrentPage() {
    if (!_controller.isReady) {
      return;
    }
    unawaited(
      _controller.goTo(
        _matrixForPage(_pageNumber),
        duration: const Duration(milliseconds: 100),
      ),
    );
  }

  Future<void> _showPagePicker() async {
    if (!stageAllowsMenu(widget.stageMode)) return;
    if (_pageCount == 0) {
      return;
    }

    final selectedPage = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      builder: (context) {
        return _stageSheet(
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.pageNav,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 128,
                            childAspectRatio: 0.72,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemCount: _pageCount,
                      itemBuilder: (context, index) {
                        final page = index + 1;
                        final spreadFirst = _spreadFirstPage(_pageNumber);
                        final selected =
                            _effectiveViewMode == _PdfViewMode.twoPage
                            ? page == spreadFirst ||
                                  (page == spreadFirst + 1 &&
                                      page <= _pageCount)
                            : page == _pageNumber;
                        return Material(
                          color: AppColors.stagePanel,
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, page),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: PdfPageView(
                                    document: _controller.document,
                                    pageNumber: page,
                                    maximumDpi: 96,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.accent,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                Positioned(
                                  right: 6,
                                  bottom: 6,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.75,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        '$page',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
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
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selectedPage == null || !mounted) {
      return;
    }
    _markManualOverride();
    await _goToViewerPage(selectedPage, duration: Duration.zero);
  }

  PreferredSizeWidget _buildChromeAppBar(Song song) {
    final progress = widget.setlistProgress;
    final subtitle = progress?.nextTitle == null
        ? (progress == null ? null : '${progress.position}/${progress.total}')
        : l10n.stageNextSong(progress!.nextTitle!);
    return ViewerTopBar(
      title: progress?.title ?? song.title,
      subtitle: subtitle,
      bpm: progress?.bpm ?? song.defaultTempo,
      onBack: context.pop,
      onTitleTap: _toggleChrome,
      autoPaused: _autoPaused,
      followOff: !_jamFollowConductor && _isJamMemberOnCurrentSong(),
      followActive:
          _progressMode == _ProgressMode.follow &&
          !_autoPaused &&
          !_isJamMemberOnCurrentSong(),
      showJamFollow: _isJamMemberOnCurrentSong(),
      jamFollowing: _jamFollowConductor,
      onJamFollowToggle: _toggleJamFollowConductor,
    );
  }

  Widget _buildMetronomeStatus() {
    return ViewerMetronomePill(
      bpm: _metronomeBpm,
      meterLabel: _metronomeMeter.label,
      beat: _metronomeBeat,
      isCountIn: _metronomeIsCountIn,
      loading: _metronomeLoading,
      onTap: () => unawaited(_toggleMetronome()),
    );
  }

  Widget _buildAnnotationToolbar() {
    final canUndo = _annotationHistory.isNotEmpty;
    return AnnotationDock(
      color: _annotationColor,
      pen: _annotationPen,
      canUndo: canUndo,
      canClear: _annotationStrokes.isNotEmpty,
      onColor: (color) => setState(() => _annotationColor = color),
      onPen: (pen) => setState(() => _annotationPen = pen),
      onUndo: _undoLastAnnotation,
      onClear: _clearAnnotations,
      onDone: _toggleAnnotationMode,
    );
  }

  Widget _buildBottomChrome(
    List<Measure> measures,
    List<AudioAnchor> anchors,
    List<Cue> cues,
    List<PracticeSession> sessions,
  ) {
    return ViewerBottomBar(
      pageLabel: _pageLabel,
      pageNumber: _pageNumber,
      pageCount: _pageCount,
      onPrevPage: _pageCount == 0 ? null : () => _turnPage(-1),
      onNextPage: _pageCount == 0 ? null : () => _turnPage(1),
      onPagePicker: _pageCount == 0 ? null : _showPagePicker,
      onPageScrub: _jumpToPage,
      nextSongId: widget.setlistProgress?.nextSongId,
      onNextSong: widget.setlistProgress?.nextSongId == null
          ? null
          : () => _openSetlistSong(widget.setlistProgress!.nextSongId!),
      hasAudio: widget.data.audioFile != null,
      audioPlaying: _audioPlaying,
      audioLoading: _audioLoading,
      onToggleAudio: _toggleAudio,
      metronomeRunning: _metronomeRunning,
      metronomeLoading: _metronomeLoading,
      onMetronome: () => unawaited(_showMetronomeSheet()),
      showJamFollow: _isJamMemberOnCurrentSong(),
      jamFollowing: _jamFollowConductor,
      onJamFollowToggle: _toggleJamFollowConductor,
      annotationMode: _annotationMode,
      showAnnotations: _allowsEditing,
      onAnnotations: _toggleAnnotationMode,
      onSettings: () => _showViewerSettings(measures, anchors, cues, sessions),
    );
  }

  Widget _buildCollapsedPagePill() {
    return ViewerCollapsedPagePill(
      pageLabel: _pageLabel,
      onPrevPage: _pageCount == 0 ? null : () => _turnPage(-1),
      onNextPage: _pageCount == 0 ? null : () => _turnPage(1),
      onPagePicker: _showPagePicker,
    );
  }

  void _jumpToPage(double value) {
    if (!_controller.isReady || _pageCount == 0) {
      return;
    }
    var target = value.round().clamp(1, _pageCount);
    if (_effectiveViewMode == _PdfViewMode.twoPage) {
      target = ((target - 1) ~/ 2) * 2 + 1;
    }
    if (target == _pageNumber) {
      return;
    }
    _markManualOverride();
    unawaited(_goToViewerPage(target, duration: Duration.zero));
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.data.song;
    final activeJam = ref.watch(activeJamProvider);
    if (activeJam != null) {
      _subscribeClockOffset();
      ref.watch(jamSessionProvider(activeJam.sessionId));
      ref.listen(jamSessionProvider(activeJam.sessionId), (previous, next) {
        _applyRemoteJamPosition(previous?.asData?.value, next.asData?.value);
        _applyRemoteJamMusic(previous?.asData?.value, next.asData?.value);
        _applyRemoteJamCountIn(previous?.asData?.value, next.asData?.value);
        _applyRemoteJamLoop(previous?.asData?.value, next.asData?.value);
        _applyRemoteJamPlaying(previous?.asData?.value, next.asData?.value);
      });
      if (!_jamInitialSnapshotScheduled) {
        _jamInitialSnapshotScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          final session = ref
              .read(jamSessionProvider(activeJam.sessionId))
              .asData
              ?.value;
          _applyRemoteJamPosition(null, session);
          _applyRemoteJamMusic(null, session);
          _applyRemoteJamCountIn(null, session);
          _applyRemoteJamLoop(null, session);
          _applyRemoteJamPlaying(null, session);
        });
      }
    }
    final measures =
        ref.watch(measuresProvider(song.id)).asData?.value ?? const <Measure>[];
    final tempoMaps =
        ref.watch(tempoMapsProvider(song.id)).asData?.value ??
        const <TempoMap>[];
    final timeSignatureMaps =
        ref.watch(timeSignatureMapsProvider(song.id)).asData?.value ??
        const <TimeSignatureMap>[];
    final anchors =
        ref.watch(audioAnchorsProvider(song.id)).asData?.value ??
        const <AudioAnchor>[];
    final cues =
        ref.watch(cuesProvider(song.id)).asData?.value ?? const <Cue>[];
    final sessions =
        ref.watch(practiceSessionsProvider(song.id)).asData?.value ??
        const <PracticeSession>[];
    ref.watch(performanceKeyMapProvider);
    final viewMode = _effectiveViewMode;
    return Scaffold(
      backgroundColor: AppColors.stage,
      appBar: null,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
              child: SafeArea(
                // 상태 표시줄 ON: 상단 상태바·하단 시스템 제스처/버튼을 가리지 않음
                // OFF(immersive): 전체 화면으로 그림
                top: _statusBarVisible,
                bottom: _statusBarVisible,
                left: _statusBarVisible,
                right: _statusBarVisible,
                child: PdfViewer.file(
                  widget.data.file.path,
                  controller: _controller,
                  params: PdfViewerParams(
                    margin: 8,
                    backgroundColor: AppColors.stage,
                    pageDropShadow: const BoxShadow(color: Colors.transparent),
                    layoutPages: _layoutPagesForMode,
                    normalizeMatrix: _normalizeViewerMatrix,
                    panAxis: viewMode == _PdfViewMode.scroll
                        ? PanAxis.vertical
                        : PanAxis.free,
                    panEnabled:
                        !_annotationMode && viewMode == _PdfViewMode.scroll,
                    scaleEnabled:
                        !_annotationMode && viewMode == _PdfViewMode.scroll,
                    scrollPhysics:
                        !_annotationMode && viewMode == _PdfViewMode.scroll
                        ? PdfViewerParams.getScrollPhysics(context)
                        : null,
                    scrollByMouseWheel: viewMode == _PdfViewMode.scroll
                        ? 0.2
                        : null,
                    onViewerReady: (document, controller) => _onViewerReady(),
                    onViewSizeChanged: _onViewerViewSizeChanged,
                    onPageChanged: (pageNumber) {
                      if (pageNumber != null && mounted) {
                        final page = _normalizePageNumber(pageNumber);
                        setState(() => _pageNumber = page);
                        _scheduleJamPositionPublish();
                      }
                    },
                    onGeneralTap: (_measureEditing || _annotationMode)
                        ? (context, controller, details) => true
                        : _handleTap,
                    pageOverlaysBuilder:
                        (_annotationMode ||
                            (_annotationsVisible &&
                                (measures.isNotEmpty ||
                                    _annotationStrokes.isNotEmpty)))
                        ? (context, pageRect, page) => _buildMeasureOverlays(
                            page.pageNumber,
                            pageRect.size,
                            measures,
                            tempoMaps,
                            timeSignatureMaps,
                            cues: cues,
                            interactive: _measureEditing,
                            currentMeasureNumber: _currentMeasureNumber,
                          )
                        : null,
                    errorBannerBuilder:
                        (context, error, stackTrace, documentRef) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              l10n.reimportPdf,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ),
            if (_annotationMode)
              Positioned(
                left: 12,
                right: 12,
                bottom: 16,
                child: SafeArea(top: false, child: _buildAnnotationToolbar()),
              ),
            if (_metronomeRunning && !_annotationMode)
              Positioned(
                right: 16,
                // Full chrome ≈ 118; collapsed page pill ≈ 56 + bottom inset.
                bottom: _chromeVisible
                    ? 118 + MediaQuery.paddingOf(context).bottom
                    : 72 + MediaQuery.paddingOf(context).bottom,
                child: _buildMetronomeStatus(),
              ),
            if (_autoPaused && !_annotationMode)
              Positioned(
                left: 16,
                right: 16,
                bottom: _chromeVisible
                    ? 138 + MediaQuery.paddingOf(context).bottom
                    : 96 + MediaQuery.paddingOf(context).bottom,
                child: Center(
                  child: ViewerFloatingHint(
                    icon: Icons.play_circle_outline_rounded,
                    message: l10n.autoPausedHint,
                    onTap: () => unawaited(_resumeLive(measures)),
                  ),
                ),
              ),
            if (!_annotationMode && _controller.isReady)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _chromeVisible
                      ? KeyedSubtree(
                          key: const ValueKey('viewer-bottom-chrome'),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: _buildBottomChrome(
                              measures,
                              anchors,
                              cues,
                              sessions,
                            ),
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('viewer-bottom-pill'),
                          child: _buildCollapsedPagePill(),
                        ),
                ),
              ),
            ViewerTopChromeLayer(
              chromeVisible: _chromeVisible,
              topBar: _buildChromeAppBar(song),
              onReveal: _toggleChrome,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  const _AnnotationPainter({required this.strokes, this.activeStroke});

  final List<AnnotationStroke> strokes;
  final AnnotationStroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    for (final stroke in [
      ...strokes,
      if (activeStroke case final stroke?) stroke,
    ]) {
      if (stroke.points.length < 2) {
        continue;
      }
      final paint = Paint()
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.eraser ? BlendMode.clear : BlendMode.srcOver
        ..color = stroke.eraser
            ? Colors.transparent
            : stroke.color.withValues(alpha: stroke.opacity);
      final path = Path()
        ..moveTo(
          stroke.points.first.dx * size.width,
          stroke.points.first.dy * size.height,
        );
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke;
  }
}
