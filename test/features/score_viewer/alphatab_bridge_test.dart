import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/score_engine/alphatab_bridge.dart';

void main() {
  group('AlphaTabCommand', () {
    test('LoadScoreCommand toJsCall', () {
      const cmd = LoadScoreCommand(xmlContent: '<score-partwise/>');
      expect(cmd.name, 'loadScore');
      expect(cmd.toJsCall(), contains('bridgeLoadScore'));
      expect(cmd.params['xmlContent'], '<score-partwise/>');
    });

    test('GoToMeasureCommand toJsCall', () {
      const cmd = GoToMeasureCommand(measureNumber: 5);
      expect(cmd.name, 'goToMeasure');
      expect(cmd.toJsCall(), 'bridgeGoToMeasure(5)');
      expect(cmd.params['measureNumber'], 5);
    });

    test('SetCursorCommand toJsCall', () {
      const cmd = SetCursorCommand(measureNumber: 3, beatIndex: 2);
      expect(cmd.name, 'setCursor');
      expect(cmd.toJsCall(), 'bridgeSetCursor(3, 2)');
    });

    test('SetZoomCommand toJsCall', () {
      const cmd = SetZoomCommand(scale: 1.5);
      expect(cmd.name, 'setZoom');
      expect(cmd.toJsCall(), 'bridgeSetZoom(1.5)');
    });

    test('SetLoopRangeCommand toJsCall', () {
      const cmd = SetLoopRangeCommand(startMeasure: 1, endMeasure: 8);
      expect(cmd.name, 'setLoopRange');
      expect(cmd.toJsCall(), 'bridgeSetLoopRange(1, 8)');
    });

    test('LoadScoreWithFilterCommand toJsCall', () {
      const cmd = LoadScoreWithFilterCommand(
        xmlContent: '<score-partwise/>',
        drumOnly: true,
      );
      expect(cmd.name, 'loadScoreWithFilter');
      expect(cmd.toJsCall(), contains('bridgeLoadScoreWithFilter'));
      expect(cmd.toJsCall(), contains('true'));
      expect(cmd.params['drumOnly'], true);
    });

    test('AutoScaleCommand toJsCall', () {
      const cmd = AutoScaleCommand(containerWidth: 360.0);
      expect(cmd.name, 'autoScale');
      expect(cmd.toJsCall(), 'bridgeAutoScale(360.0)');
      expect(cmd.params['containerWidth'], 360.0);
    });

    test('ClearCursorCommand toJsCall', () {
      const cmd = ClearCursorCommand();
      expect(cmd.name, 'clearCursor');
      expect(cmd.toJsCall(), 'bridgeClearCursor()');
      expect(cmd.params, isEmpty);
    });
  });

  group('AlphaTabEvent.fromJson', () {
    test('ready 이벤트 파싱', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'ready',
        'data': <String, dynamic>{},
      });
      expect(event, isA<AlphaTabReadyEvent>());
    });

    test('scoreLoaded 이벤트 파싱', () {
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
      expect(event, isA<ScoreLoadedEvent>());
      final loaded = event as ScoreLoadedEvent;
      expect(loaded.title, 'Test Score');
      expect(loaded.artist, 'Artist');
      expect(loaded.tempo, 120);
      expect(loaded.partCount, 2);
      expect(loaded.measureCount, 32);
    });

    test('currentBarChanged 이벤트 파싱', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'currentBarChanged',
        'data': {'measure': 5},
      });
      expect(event, isA<CurrentBarChangedEvent>());
      expect((event as CurrentBarChangedEvent).measureNumber, 5);
    });

    test('currentBeatChanged 이벤트 파싱', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'currentBeatChanged',
        'data': {'measure': 3, 'beatIndex': 2},
      });
      expect(event, isA<CurrentBeatChangedEvent>());
      final beat = event as CurrentBeatChangedEvent;
      expect(beat.measureNumber, 3);
      expect(beat.beatIndex, 2);
    });

    test('scoreTapped 이벤트 파싱', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'scoreTapped',
        'data': {'measure': 10},
      });
      expect(event, isA<ScoreTappedEvent>());
      expect((event as ScoreTappedEvent).measure, 10);
    });

    test('loopRangeSet 이벤트 파싱', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'loopRangeSet',
        'data': {'startMeasure': 1, 'endMeasure': 8},
      });
      expect(event, isA<LoopRangeSetEvent>());
      final loop = event as LoopRangeSetEvent;
      expect(loop.startMeasure, 1);
      expect(loop.endMeasure, 8);
    });

    test('error 이벤트 파싱', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'error',
        'data': {'message': 'Something went wrong'},
      });
      expect(event, isA<AlphaTabErrorEvent>());
      expect((event as AlphaTabErrorEvent).message, 'Something went wrong');
    });

    test('알 수 없는 타입은 UnknownAlphaTabEvent', () {
      final event = AlphaTabEvent.fromJson({
        'type': 'unknownType',
        'data': <String, dynamic>{},
      });
      expect(event, isA<UnknownAlphaTabEvent>());
      expect((event as UnknownAlphaTabEvent).type, 'unknownType');
    });

    test('data가 없어도 기본값 사용', () {
      final event = AlphaTabEvent.fromJson({'type': 'scoreLoaded'});
      expect(event, isA<ScoreLoadedEvent>());
      final loaded = event as ScoreLoadedEvent;
      expect(loaded.title, '');
      expect(loaded.tempo, 120);
    });
  });
}
