import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_empty_state.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';
import 'package:page_a_diddle/features/digital_score/data/alphatab_asset_server.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_codec.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_playback.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';
import 'package:page_a_diddle/features/digital_score/presentation/playback_sequence_panel.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
    this.onSystemsChanged,
    this.onNoteDragged,
    this.onPlayerIssue,
    this.highlightedMeasureIndex,
    this.absorbMeasureTaps = false,
    this.oneFingerPan = true,
    super.key,
  });

  final MusicScore score;
  final String semanticsLabel;
  final PianoScorePlaybackController playback;
  final bool playbackVisible;
  final ValueChanged<AlphaTabNoteTappedEvent>? onNoteTapped;
  final ValueChanged<AlphaTabStaffTappedEvent>? onStaffTapped;
  final ValueChanged<int>? onMeasureTapped;
  final ValueChanged<List<ScoreSystemSpan>>? onSystemsChanged;
  final ValueChanged<AlphaTabNoteDraggedEvent>? onNoteDragged;
  final VoidCallback? onPlayerIssue;
  final int? highlightedMeasureIndex;
  final bool absorbMeasureTaps;
  final bool oneFingerPan;

  @override
  State<PianoScoreView> createState() => _PianoScoreViewState();
}

class _PianoScoreViewState extends State<PianoScoreView> {
  static const _assetPath = 'assets/alphatab/index.html';

  late final WebViewController _controller;
  final _assetServer = AlphaTabAssetServer();
  bool _bridgeReady = false;
  bool _rendered = false;
  String? _errorMessage;
  double? _viewportWidth;
  double? _viewportHeight;
  int _overlayPointers = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.canvas)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'file' || uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }
            if (uri.host == '127.0.0.1' || uri.host == 'localhost') {
              return NavigationDecision.navigate;
            }
            if (uri.scheme == 'https' &&
                uri.host == 'appassets.androidplatform.net') {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _handleBridgeMessage,
      );
    _allowOfflineMediaPlayback();
    widget.playback.attach(
      playPause: _playPause,
      stop: _stopPlayback,
      seek: _seekPlayback,
    );
    _seedEstimatedDuration();
    _loadRendererAsset();
  }

  @override
  void didUpdateWidget(covariant PianoScoreView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playback != widget.playback) {
      oldWidget.playback.detach();
      widget.playback.attach(
        playPause: _playPause,
        stop: _stopPlayback,
        seek: _seekPlayback,
      );
    }
    if (oldWidget.playbackVisible != widget.playbackVisible) {
      _sendPlaybackVisible();
      if (!widget.playbackVisible) {
        widget.playback.replaceState(
          widget.playback.state.copyWith(playing: false),
        );
      } else {
        _seedEstimatedDuration();
        _refreshPlaybackTimeline();
      }
    }
    if (!identical(oldWidget.score, widget.score) && _bridgeReady) {
      _rendered = false;
      _errorMessage = null;
      _resetPlaybackForScore();
      _loadScore();
    } else if (oldWidget.highlightedMeasureIndex !=
        widget.highlightedMeasureIndex) {
      _sendHighlightedMeasure();
    }
    if (oldWidget.oneFingerPan != widget.oneFingerPan) {
      _sendOneFingerPan();
    }
  }

  @override
  void dispose() {
    unawaited(widget.playback.stop());
    widget.playback.detach();
    unawaited(_assetServer.close());
    super.dispose();
  }

  void _allowOfflineMediaPlayback() {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
      platform.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }
  }

  Future<void> _loadRendererAsset() async {
    try {
      final uri = await _assetServer.ensureStarted();
      await _controller.loadRequest(uri);
    } on Object {
      try {
        await _controller.loadFlutterAsset(_assetPath);
      } on Object catch (error) {
        if (!mounted) return;
        setState(() => _errorMessage = error.toString());
      }
    }
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map) return;
      final event = AlphaTabEvent.fromJson(Map<String, dynamic>.from(decoded));
      switch (event) {
        case AlphaTabReadyEvent():
          _bridgeReady = true;
          _sendViewportWidth();
          _sendOneFingerPan();
          _sendPlaybackVisible();
          _loadScore();
        case AlphaTabRenderedEvent():
          if (!mounted) return;
          widget.playback.replaceState(
            widget.playback.state.copyWith(loaded: true),
          );
          _seedEstimatedDuration();
          setState(() {
            _rendered = true;
            _errorMessage = null;
          });
          _refreshPlaybackTimeline();
          _sendHighlightedMeasure();
          _sendMeasureKeys();
          _sendMeasureSections();
        case AlphaTabErrorEvent(:final message):
          if (!mounted) return;
          setState(() => _errorMessage = message);
        case AlphaTabNoteTappedEvent():
          widget.onNoteTapped?.call(event);
        case AlphaTabStaffTappedEvent():
          widget.onStaffTapped?.call(event);
        case ScoreTappedEvent(:final measure):
          if (measure > 0) widget.onMeasureTapped?.call(measure - 1);
        case ScoreSystemsEvent(:final systems):
          widget.onSystemsChanged?.call([
            for (final system in systems)
              ScoreSystemSpan(
                startMeasureIndex: system.start,
                endMeasureIndex: system.end,
              ),
          ]);
        case AlphaTabNoteDraggedEvent():
          widget.onNoteDragged?.call(event);
        case AlphaTabPlayerReadyEvent(
          :final durationMs,
          :final readyForPlayback,
        ):
          widget.playback.replaceState(
            widget.playback.state.copyWith(
              ready: readyForPlayback || widget.playback.state.ready,
              durationMs: durationMs > 0 ? durationMs : null,
            ),
          );
        case AlphaTabPlayerStateEvent(:final playing, :final stopped):
          widget.playback.replaceState(
            stopped
                ? widget.playback.state.copyWith(
                    playing: false,
                    currentTimeMs: 0,
                    measureNumber: 1,
                    beatIndex: 0,
                  )
                : widget.playback.state.copyWith(playing: playing),
          );
        case AlphaTabPlayerPositionEvent(
          :final currentTimeMs,
          :final durationMs,
        ):
          widget.playback.replaceState(
            widget.playback.state.copyWith(
              currentTimeMs: currentTimeMs,
              durationMs: durationMs > 0 ? durationMs : null,
            ),
          );
        case AlphaTabPlayedBeatEvent(:final measureIndex, :final beatIndex):
          widget.playback.replaceState(
            widget.playback.state.copyWith(
              measureNumber: measureIndex + 1,
              beatIndex: beatIndex,
            ),
          );
        case AlphaTabPlayerFinishedEvent():
          widget.playback.replaceState(
            widget.playback.state.copyWith(
              playing: false,
              currentTimeMs: widget.playback.state.durationMs,
            ),
          );
        case AlphaTabPlayerIssueEvent():
          widget.onPlayerIssue?.call();
        default:
          break;
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  void _resetPlaybackForScore() {
    widget.playback.replaceState(
      ScorePlaybackState(durationMs: estimateScoreDurationMs(widget.score)),
    );
  }

  void _seedEstimatedDuration() {
    final estimated = estimateScoreDurationMs(widget.score);
    if (estimated <= 0) return;
    final current = widget.playback.state;
    if (current.durationMs > 0) return;
    widget.playback.replaceState(current.copyWith(durationMs: estimated));
  }

  Future<void> _loadScore() async {
    if (!_bridgeReady) return;
    try {
      final bytes = const MusicXmlCodec().encodeMusicXml(widget.score);
      final command = LoadScoreCommand(xmlContent: utf8.decode(bytes));
      await _controller.runJavaScript(command.toJsCall());
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  Future<bool> _runPlayback(String javascript) async {
    if (!_bridgeReady) return false;
    try {
      final result = await _controller.runJavaScriptReturningResult(javascript);
      return result == true || result == 'true';
    } on Object {
      return false;
    }
  }

  Future<bool> _playPause() async {
    final started = await _runPlayback(
      const PlayPauseScoreCommand().toJsCall(),
    );
    if (started && !widget.playback.state.playing) {
      widget.playback.replaceState(
        widget.playback.state.copyWith(playing: true),
      );
    }
    return started;
  }

  Future<bool> _stopPlayback() async {
    final stopped = await _runPlayback(
      const StopScorePlaybackCommand().toJsCall(),
    );
    if (stopped) {
      widget.playback.replaceState(
        widget.playback.state.copyWith(playing: false, currentTimeMs: 0),
      );
    }
    return stopped;
  }

  Future<bool> _seekPlayback(double positionMs) async {
    final seeked = await _runPlayback(
      SeekScorePlaybackCommand(positionMs: positionMs).toJsCall(),
    );
    if (seeked) {
      widget.playback.replaceState(
        widget.playback.state.copyWith(currentTimeMs: positionMs),
      );
    }
    return seeked;
  }

  void _updateViewportSize(double width, double height) {
    final nextWidth = width.isFinite && width > 0 ? width : _viewportWidth;
    final nextHeight = height.isFinite && height > 0 ? height : _viewportHeight;
    if (nextWidth == _viewportWidth && nextHeight == _viewportHeight) return;
    _viewportWidth = nextWidth;
    _viewportHeight = nextHeight;
    _sendViewportWidth();
  }

  Future<void> _refreshPlaybackTimeline() async {
    if (!_bridgeReady) return;
    try {
      await _controller.runJavaScript(
        const RefreshPlaybackCommand().toJsCall(),
      );
    } on Object {
      // A later render or player event will publish the duration.
    }
  }

  Future<void> _sendHighlightedMeasure() async {
    if (!_bridgeReady) return;
    try {
      await _controller.runJavaScript(
        HighlightMeasureCommand(
          measureIndex: widget.highlightedMeasureIndex,
        ).toJsCall(),
      );
    } on Object {
      // A later render will reapply the highlight.
    }
  }

  Future<void> _sendMeasureKeys() async {
    if (!_bridgeReady) return;
    try {
      await _controller.runJavaScript(
        SetMeasureKeysCommand(
          fifths: measureKeyFifths(widget.score),
        ).toJsCall(),
      );
    } on Object {
      // A later render will reapply the key labels.
    }
  }

  Future<void> _sendMeasureSections() async {
    if (!_bridgeReady || !mounted) return;
    final l10n = context.l10n;
    try {
      await _controller.runJavaScript(
        SetMeasureSectionsCommand(
          labels: [
            for (final code in measureSectionMarks(widget.score))
              code == null ? '' : playbackSectionLabel(l10n, code),
          ],
        ).toJsCall(),
      );
    } on Object {
      // A later render will reapply the section labels.
    }
  }

  Future<void> _sendPlaybackVisible() async {
    if (!_bridgeReady) return;
    try {
      await _controller.runJavaScript(
        SetPlaybackVisibleCommand(visible: widget.playbackVisible).toJsCall(),
      );
    } on Object {
      // A later ready event will resend the flag.
    }
  }

  Future<void> _sendViewportWidth() async {
    final width = _viewportWidth;
    if (!_bridgeReady || width == null) return;
    try {
      final command = SetViewportWidthCommand(
        width: width,
        height: _viewportHeight,
      );
      await _controller.runJavaScript(command.toJsCall());
    } on Object {
      // A later layout pass or renderer reload will resend the width.
    }
  }

  Future<void> _sendOneFingerPan() async {
    if (!_bridgeReady) return;
    try {
      await _controller.runJavaScript(
        'bridgeSetOneFingerPan(${widget.oneFingerPan})',
      );
    } on Object {
      // A later ready event will resend the flag.
    }
  }

  Offset? _localPoint(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return null;
    return box.globalToLocal(global);
  }

  void _forwardViewPointer(String phase, PointerEvent event) {
    final local = _localPoint(event.position);
    if (local == null) return;
    unawaited(
      _controller.runJavaScript(
        "bridgePointer('$phase', ${event.pointer}, "
        '${local.dx.toStringAsFixed(2)}, ${local.dy.toStringAsFixed(2)})',
      ),
    );
  }

  void _onAbsorbedTap(PointerDownEvent event) {
    final local = _localPoint(event.position);
    if (local == null) return;
    unawaited(
      _controller.runJavaScript(
        'bridgeTapAt(${local.dx.toStringAsFixed(2)}, ${local.dy.toStringAsFixed(2)})',
      ),
    );
  }

  void _onOverlayPointerDown(PointerDownEvent event) {
    _overlayPointers += 1;
    _forwardViewPointer('down', event);
    if (_overlayPointers == 1) _onAbsorbedTap(event);
  }

  void _onOverlayPointerEnd(PointerEvent event) {
    _forwardViewPointer('up', event);
    _overlayPointers = (_overlayPointers - 1).clamp(0, 32);
  }

  Future<void> _retry() async {
    widget.playback.replaceState(const ScorePlaybackState());
    setState(() {
      _bridgeReady = false;
      _rendered = false;
      _errorMessage = null;
    });
    await _loadRendererAsset();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _updateViewportSize(
              constraints.maxWidth,
              constraints.maxHeight,
            );
          }
        });
        return Semantics(
          container: true,
          label: widget.semanticsLabel,
          child: ColoredBox(
            color: AppColors.canvas,
            child: Stack(
              fit: StackFit.expand,
              children: [
                WebViewWidget(controller: _controller),
                if (widget.absorbMeasureTaps && _errorMessage == null)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onOverlayPointerDown,
                      onPointerMove: (event) =>
                          _forwardViewPointer('move', event),
                      onPointerUp: _onOverlayPointerEnd,
                      onPointerCancel: _onOverlayPointerEnd,
                    ),
                  ),
                if (_errorMessage != null)
                  ColoredBox(
                    color: AppColors.canvas,
                    child: AppEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: context.l10n.loadFailed,
                      body: context.l10n.retryAction,
                      actionLabel: context.l10n.retryAction,
                      onAction: _retry,
                      compact: true,
                    ),
                  )
                else if (!_rendered)
                  const ColoredBox(
                    color: AppColors.canvas,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
