import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';

void main() {
  group('AlphaTabCommand', () {
    test('LoadScoreCommand toJsCall', () {
      const command = LoadScoreCommand(xmlContent: '<score-partwise/>');
      expect(command.name, 'loadScore');
      expect(command.toJsCall(), contains('bridgeLoadScore'));
      expect(command.params['xmlContent'], '<score-partwise/>');
    });

    test('GoToMeasureCommand toJsCall', () {
      const command = GoToMeasureCommand(measureNumber: 5);
      expect(command.name, 'goToMeasure');
      expect(command.toJsCall(), 'bridgeGoToMeasure(5)');
      expect(command.params['measureNumber'], 5);
    });

    test('SetCursorCommand toJsCall', () {
      const command = SetCursorCommand(measureNumber: 3, beatIndex: 2);
      expect(command.name, 'setCursor');
      expect(command.toJsCall(), 'bridgeSetCursor(3, 2)');
    });

    test('SetZoomCommand toJsCall', () {
      const command = SetZoomCommand(scale: 1.5);
      expect(command.name, 'setZoom');
      expect(command.toJsCall(), 'bridgeSetZoom(1.5)');
    });

    test('SetLoopRangeCommand toJsCall', () {
      const command = SetLoopRangeCommand(startMeasure: 1, endMeasure: 8);
      expect(command.name, 'setLoopRange');
      expect(command.toJsCall(), 'bridgeSetLoopRange(1, 8)');
    });

    test('LoadScoreWithFilterCommand toJsCall', () {
      const command = LoadScoreWithFilterCommand(
        xmlContent: '<score-partwise/>',
      );
      expect(command.name, 'loadScoreWithFilter');
      expect(command.toJsCall(), contains('bridgeLoadScoreWithFilter'));
      expect(command.toJsCall(), contains('true'));
      expect(command.params['drumOnly'], isTrue);
    });

    test('AutoScaleCommand toJsCall', () {
      const command = AutoScaleCommand(containerWidth: 360);
      expect(command.name, 'autoScale');
      expect(command.toJsCall(), 'bridgeAutoScale(360.0)');
      expect(command.params['containerWidth'], 360);
    });

    test('SetViewportWidthCommand toJsCall', () {
      const command = SetViewportWidthCommand(width: 840);
      expect(command.name, 'setViewportWidth');
      expect(command.toJsCall(), 'bridgeSetViewportWidth(840.0)');
      expect(command.params['width'], 840);
    });

    test('SetViewportWidthCommand includes height when provided', () {
      const command = SetViewportWidthCommand(width: 360, height: 640);
      expect(command.toJsCall(), 'bridgeSetViewport(360.0, 640.0)');
      expect(command.params['height'], 640);
    });

    test('ClearCursorCommand toJsCall', () {
      const command = ClearCursorCommand();
      expect(command.name, 'clearCursor');
      expect(command.toJsCall(), 'bridgeClearCursor()');
      expect(command.params, isEmpty);
    });

    test('playback commands call the alphaTab player API', () {
      expect(const PlayPauseScoreCommand().toJsCall(), 'bridgePlayPause()');
      expect(
        const PauseScorePlaybackCommand().toJsCall(),
        'bridgePausePlayback()',
      );
      expect(
        const StopScorePlaybackCommand().toJsCall(),
        'bridgeStopPlayback()',
      );
      expect(
        const SeekScorePlaybackCommand(positionMs: 1250).toJsCall(),
        'bridgeSeekPlayback(1250.0)',
      );
      expect(
        const SetScorePlaybackSpeedCommand(speed: 0.75).toJsCall(),
        'bridgeSetPlaybackSpeed(0.75)',
      );
      expect(
        const SetPlaybackVisibleCommand(visible: false).toJsCall(),
        'bridgeSetPlaybackVisible(false)',
      );
      expect(
        const RefreshPlaybackCommand().toJsCall(),
        'bridgeRefreshPlayback()',
      );
      expect(
        const HighlightMeasureCommand(measureIndex: 2).toJsCall(),
        'bridgeHighlightMeasure(2)',
      );
      expect(
        const HighlightMeasureCommand().toJsCall(),
        'bridgeHighlightMeasure(-1)',
      );
      expect(
        const SetMeasureKeysCommand(fifths: [0, 2, -1]).toJsCall(),
        'bridgeSetMeasureKeys([0,2,-1])',
      );
      expect(
        const SetMeasureSectionsCommand(labels: ['벌스', '', '코러스']).toJsCall(),
        'bridgeSetMeasureSections(["벌스","","코러스"])',
      );
    });
  });

  group('AlphaTabEvent.fromJson', () {
    test('parses ready event and renderer version', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'ready',
        'data': <String, dynamic>{'version': '1.8.4'},
      });
      expect(event, isA<AlphaTabReadyEvent>());
      expect((event as AlphaTabReadyEvent).version, '1.8.4');
    });

    test('parses scoreLoaded event', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'scoreLoaded',
        'data': {
          'title': 'Test Score',
          'artist': 'Artist',
          'tempo': 120,
          'partCount': 2,
          'measureCount': 32,
        },
      });
      final loaded = event as ScoreLoadedEvent;
      expect(loaded.title, 'Test Score');
      expect(loaded.artist, 'Artist');
      expect(loaded.tempo, 120);
      expect(loaded.partCount, 2);
      expect(loaded.measureCount, 32);
    });

    test('accepts JavaScript numeric values', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'scoreLoaded',
        'data': {'tempo': 119.6, 'partCount': 2.0, 'measureCount': '32'},
      });
      final loaded = event as ScoreLoadedEvent;
      expect(loaded.tempo, 120);
      expect(loaded.partCount, 2);
      expect(loaded.measureCount, 32);
    });

    test('parses render lifecycle events', () {
      final started = AlphaTabEvent.fromJson({
        'type': 'renderStarted',
        'data': <String, dynamic>{},
      });
      final finished = AlphaTabEvent.fromJson({
        'type': 'renderFinished',
        'data': {'contentHeight': 1280, 'scale': 0.86},
      });

      expect(started, isA<AlphaTabRenderStartedEvent>());
      expect(finished, isA<AlphaTabRenderedEvent>());
      expect((finished as AlphaTabRenderedEvent).contentHeight, 1280);
      expect(finished.scale, 0.86);
    });

    test('parses current bar and beat events', () {
      final bar = AlphaTabEvent.fromJson({
        'type': 'currentBarChanged',
        'data': {'measure': 5},
      });
      final beat = AlphaTabEvent.fromJson({
        'type': 'currentBeatChanged',
        'data': {'measure': 3, 'beatIndex': 2},
      });

      expect((bar as CurrentBarChangedEvent).measureNumber, 5);
      expect((beat as CurrentBeatChangedEvent).measureNumber, 3);
      expect(beat.beatIndex, 2);
    });

    test('parses score tap and loop events', () {
      final tap = AlphaTabEvent.fromJson({
        'type': 'scoreTapped',
        'data': {'measure': 10},
      });
      final loop = AlphaTabEvent.fromJson({
        'type': 'loopRangeSet',
        'data': {'startMeasure': 1, 'endMeasure': 8},
      });

      expect((tap as ScoreTappedEvent).measure, 10);
      expect((loop as LoopRangeSetEvent).startMeasure, 1);
      expect(loop.endMeasure, 8);

      final systems = AlphaTabEvent.fromJson({
        'type': 'scoreSystems',
        'data': {
          'systems': [
            {'start': 0, 'end': 2},
            {'start': 3, 'end': 6},
          ],
        },
      });
      expect((systems as ScoreSystemsEvent).systems, [
        (start: 0, end: 2),
        (start: 3, end: 6),
      ]);
    });

    test('parses a staff tap and note drag', () {
      final tap = AlphaTabEvent.fromJson({
        'type': 'staffTapped',
        'data': {
          'partIndex': 0,
          'measureIndex': 2,
          'staff': 1,
          'onsetTicks': 960,
          'midi': 64,
        },
      });
      final drag = AlphaTabEvent.fromJson({
        'type': 'noteDragged',
        'data': {
          'partIndex': 0,
          'measureIndex': 2,
          'staff': 1,
          'onsetTicks': 960,
          'originalMidi': 64,
          'midi': 67,
        },
      });

      expect((tap as AlphaTabStaffTappedEvent).midi, 64);
      expect(tap.measureIndex, 2);
      expect((drag as AlphaTabNoteDraggedEvent).originalMidi, 64);
      expect(drag.midi, 67);
    });

    test('parses a rendered note hit', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'noteTapped',
        'data': {
          'partIndex': 1,
          'measureIndex': 4,
          'staff': 2,
          'voiceIndex': 0,
          'onsetTicks': 960,
          'midi': 60,
          'noteIndex': 2,
        },
      });

      final note = event as AlphaTabNoteTappedEvent;
      expect(note.partIndex, 1);
      expect(note.measureIndex, 4);
      expect(note.staff, 2);
      expect(note.onsetTicks, 960);
      expect(note.midi, 60);
      expect(note.noteIndex, 2);
    });

    test('parses error and unknown events', () {
      final error = AlphaTabEvent.fromJson({
        'type': 'error',
        'data': {'message': 'Something went wrong'},
      });
      final unknown = AlphaTabEvent.fromJson({
        'type': 'unknownType',
        'data': <String, dynamic>{},
      });

      expect((error as AlphaTabErrorEvent).message, 'Something went wrong');
      expect((unknown as UnknownAlphaTabEvent).type, 'unknownType');
    });

    test('parses alphaTab player timeline events', () {
      final ready = AlphaTabEvent.fromJson({
        'type': 'playerReady',
        'data': {
          'durationMs': 12345.6,
          'endTick': 3840,
          'readyForPlayback': true,
        },
      });
      final state = AlphaTabEvent.fromJson({
        'type': 'playerStateChanged',
        'data': {'playing': true, 'stopped': 0},
      });
      final position = AlphaTabEvent.fromJson({
        'type': 'playerPositionChanged',
        'data': {
          'currentTimeMs': 1500,
          'durationMs': 8000,
          'currentTick': 480,
          'endTick': 3840,
        },
      });
      final beat = AlphaTabEvent.fromJson({
        'type': 'playedBeatChanged',
        'data': {'partIndex': 0, 'measureIndex': 2, 'beatIndex': 1},
      });
      final finished = AlphaTabEvent.fromJson({
        'type': 'playerFinished',
        'data': <String, dynamic>{},
      });
      final issue = AlphaTabEvent.fromJson({
        'type': 'playerIssue',
        'data': {'message': 'soundfont'},
      });

      expect((ready as AlphaTabPlayerReadyEvent).durationMs, 12345.6);
      expect(ready.endTick, 3840);
      expect(ready.readyForPlayback, isTrue);
      expect((state as AlphaTabPlayerStateEvent).playing, isTrue);
      expect(state.stopped, isFalse);
      expect((position as AlphaTabPlayerPositionEvent).currentTimeMs, 1500);
      expect(position.durationMs, 8000);
      expect((beat as AlphaTabPlayedBeatEvent).measureIndex, 2);
      expect(beat.beatIndex, 1);
      expect(finished, isA<AlphaTabPlayerFinishedEvent>());
      expect((issue as AlphaTabPlayerIssueEvent).message, 'soundfont');
    });

    test('uses defaults when event data is omitted', () {
      final event = AlphaTabEvent.fromJson({'type': 'scoreLoaded'});
      final loaded = event as ScoreLoadedEvent;
      expect(loaded.title, '');
      expect(loaded.tempo, 120);
    });
  });
}
