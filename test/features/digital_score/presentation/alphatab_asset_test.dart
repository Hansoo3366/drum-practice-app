import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const assetRoot = 'assets/alphatab';

  test(
    'piano renderer is fully local and configured for responsive notation',
    () {
      final html = File('$assetRoot/index.html').readAsStringSync();

      expect(html, contains('src="./vendor/alphaTab.min.js"'));
      expect(html, contains('useWorkers: false'));
      expect(html, contains("layoutMode: 'page'"));
      expect(html, contains("staveProfile: 'score'"));
      expect(html, contains('barsPerRow: -1'));
      expect(html, contains('var A4_WIDTH = 794'));
      expect(html, contains('var A4_HEIGHT = 1123'));
      expect(html, contains('height: 1123px'));
      expect(html, contains('scorePaperHeight'));
      expect(html, contains('var PAGE_GAP = 24'));
      expect(html, contains('paginateScore'));
      expect(html, contains('sourceToPageY'));
      expect(html, contains('pageToSourceY'));
      expect(html, contains('enableLazyLoading: false'));
      expect(html, contains("frame.style.height = scorePaperHeight() + 'px'"));
      expect(html, contains('padding: 0'));
      expect(html, contains('background: transparent'));
      expect(html, contains('var PAGE_GUTTER_X = 12'));
      expect(html, contains('Math.min(1, availableW / A4_WIDTH)'));
      expect(html, contains('applyPageFit'));
      expect(html, contains('userZoom'));
      expect(html, contains('alphaTab-viewport'));
      expect(html, contains('background: #ffffff'));
      expect(html, contains('handleViewPointer'));
      expect(html, contains('bridgePointer'));
      expect(html, contains('bridgeSetInputMode'));
      expect(html, contains('bridgeStartMeasureDrag'));
      expect(html, contains('pad-note-ghost'));
      expect(html, contains('pad-measure-ghost'));
      expect(html, contains("postToFlutter('measureMoved'"));
      expect(html, contains('commitNoteGhost'));
      expect(html, isNot(contains("addEventListener('touchstart'")));
      expect(html, contains('bridgeSetView'));
      expect(html, contains('bridgeZoomBy'));
      expect(html, contains('zoomViewBy'));
      expect(html, contains("postToFlutter('scoreSystems'"));
      expect(html, contains('bridgeSetViewportWidth'));
      expect(html, contains('bridgeSetViewport'));
      expect(html, contains('api.noteMouseDown.on'));
      expect(html, contains("postNoteHit('noteTapped'"));
      expect(html, contains("postToFlutter('staffTapped'"));
      expect(html, contains('lookup.getBeatAtPos(point.x, point.y)'));
      expect(html, contains('lookup.getNoteAtPos(beat, point.x, point.y)'));
      expect(html, contains('unlockAudio'));
      expect(html, contains('enablePlayer: true'));
      expect(html, contains('enableCursor: true'));
      expect(html, contains('WebAudioScriptProcessor'));
      expect(
        html,
        contains("soundFont: './vendor/soundfont/ydp-grand-piano.sf2'"),
      );
      expect(html, contains('bridgePlayPause'));
      expect(html, contains("postToFlutter('playerIssue'"));
      expect(html, contains('class="playback-off"'));
      expect(html, contains('bridgeSetPlaybackVisible'));
      expect(html, contains('bridgeHighlightMeasure'));
      expect(html, contains('bridgeSetMeasureKeys'));
      expect(html, contains('bridgeSetMeasureSections'));
      expect(html, contains('pad-measure-highlight'));
      expect(html, contains('measureUnion'));
      expect(html, contains('findMasterBarByIndex'));
      expect(html, contains('systemBox'));
      expect(html, contains('bridgeTapAt'));
      expect(html, contains('highlightMeasure(measure)'));
      expect(html, contains('box-shadow: 0 8px 20px rgba(255, 72, 0, 0.28)'));
      expect(html, contains('pad-measure-key'));
      expect(html, contains('pad-measure-section'));
      expect(html, contains('drawMeasureKeys'));
      expect(html, contains('drawMeasureSections'));
      expect(html, contains('sectionMarkX'));
      expect(html, contains('hideNativeRehearsals'));
      expect(html, contains('getMasterBarBounds'));
      expect(html, contains("postToFlutter('scoreTapped'"));
      expect(html, contains("setAttribute('data-measure'"));
      expect(html, contains('postPlaybackTimeline'));
      expect(html, contains('bridgeRefreshPlayback'));
      expect(html, contains('installInlineSynthWorker'));
      expect(html, contains('api.player.output.activate'));
      expect(html, contains('createAlphaSynthWebWorker'));
      expect(html, contains('playbackDurationMs'));
      expect(html, contains('midiLoaded'));
      expect(html, contains('bridgeSeekPlayback'));
      expect(html, contains("postToFlutter('playedBeatChanged'"));
      expect(html, contains('followPlaybackMeasure'));
      expect(html, contains('playbackPlaying'));
      expect(html, contains("frame.classList.add('playback-follow')"));
      expect(html, contains('transition: transform 220ms ease-out'));
      expect(html, isNot(contains('cdn.jsdelivr.net')));
      expect(html, isNot(contains('@latest')));
      expect(html, isNot(contains('filterDrumTracks')));
      expect(RegExp(r'https?://').hasMatch(html), isFalse);
    },
  );

  test('alphaTab 1.8.4 and Bravura assets are bundled with licenses', () {
    final renderer = File('$assetRoot/vendor/alphaTab.min.js');
    final rendererLicense = File('$assetRoot/vendor/alphaTab-MPL-2.0.txt');
    final fontRoot = Directory('$assetRoot/vendor/font');

    expect(renderer.existsSync(), isTrue);
    expect(renderer.lengthSync(), greaterThan(1_000_000));
    expect(renderer.readAsStringSync(), contains('static version="1.8.4"'));
    expect(rendererLicense.existsSync(), isTrue);
    expect(File('${fontRoot.path}/Bravura.woff2').existsSync(), isTrue);
    expect(File('${fontRoot.path}/Bravura.woff').existsSync(), isTrue);
    expect(File('${fontRoot.path}/Bravura.otf').existsSync(), isTrue);
    expect(File('${fontRoot.path}/Bravura-OFL.txt').existsSync(), isTrue);
    expect(File('$assetRoot/THIRD_PARTY_NOTICES.md').existsSync(), isTrue);
  });

  test(
    'sampled grand piano SoundFont is bundled for offline MIDI playback',
    () {
      final soundFont = File('$assetRoot/vendor/soundfont/ydp-grand-piano.sf2');
      final notice = File(
        '$assetRoot/vendor/soundfont/YDP-GrandPiano-NOTICE.txt',
      );
      final license = File('$assetRoot/vendor/soundfont/CC-BY-3.0.txt');
      final notices = File(
        '$assetRoot/THIRD_PARTY_NOTICES.md',
      ).readAsStringSync();

      expect(soundFont.existsSync(), isTrue);
      expect(soundFont.lengthSync(), greaterThan(50_000_000));
      final handle = soundFont.openSync();
      final header = handle.readSync(12);
      handle.closeSync();
      expect(header.sublist(0, 4), [0x52, 0x49, 0x46, 0x46]);
      expect(header.sublist(8, 12), [0x73, 0x66, 0x62, 0x6b]);
      expect(notice.existsSync(), isTrue);
      expect(
        notice.readAsStringSync(),
        contains('Creative Commons Attribution 3.0'),
      );
      expect(license.existsSync(), isTrue);
      expect(license.readAsStringSync(), contains('Attribution 3.0 Unported'));
      expect(notices, contains('vendor/soundfont/ydp-grand-piano.sf2'));
      expect(notices, isNot(contains('sonivox.sf2')));
    },
  );
}
