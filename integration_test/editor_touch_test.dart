// Runs on a device or emulator, with the real engraving and real pointers:
//
//   flutter test integration_test/editor_touch_test.dart --flavor piano -d <device>
//
// Where a finger comes down on the staff, with the note tool, is where the
// note is written: on every line and space, on ledger lines, on each of two
// staves, under another clef, after the page was enlarged, reduced or moved
// with two fingers, and with larger notes. The score is read back from the
// editor, not from the picture.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_editor_service.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_service.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/omr_review.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_proofread_screen.dart';
import 'package:page_a_diddle/features/digital_score/presentation/verovio_score_view.dart';

String _score({
  required String clefs,
  required int staves,
  required String bar,
  int fifths = -1,
  int bars = 8,
}) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0"><part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
<part id="P1">
<measure number="1"><attributes><divisions>1</divisions><key><fifths>$fifths</fifths></key>
<time><beats>4</beats><beat-type>4</beat-type></time>${staves > 1 ? '<staves>$staves</staves>' : ''}$clefs</attributes>
$bar</measure>
${[for (var n = 2; n <= bars; n++) '<measure number="$n">$bar</measure>'].join('\n')}
</part></score-partwise>''';

String _rests(int staff, String voice) => [
  for (var i = 0; i < 4; i++)
    '<note><rest/><duration>1</duration><voice>$voice</voice><type>quarter</type><staff>$staff</staff></note>',
].join();

/// One staff, treble clef, one flat: four quarter rests in every bar.
final _treble = _score(
  clefs: '<clef><sign>G</sign><line>2</line></clef>',
  staves: 1,
  bar: _rests(1, '1'),
);

/// One staff, bass clef.
final _bass = _score(
  clefs: '<clef><sign>F</sign><line>4</line></clef>',
  staves: 1,
  bar: _rests(1, '1'),
  fifths: 2,
);

/// Two staves, treble and bass.
final _piano = _score(
  clefs:
      '<clef number="1"><sign>G</sign><line>2</line></clef><clef number="2"><sign>F</sign><line>4</line></clef>',
  staves: 2,
  bar:
      '${_rests(1, '1')}<backup><duration>4</duration></backup>${_rests(2, '5')}',
  fifths: 0,
);

class _MemoryStorage extends SongFileStorage {
  String? manifest;
  final versions = <String, List<int>>{};
  List<int>? draft;
  final sequences = <String, String>{};

  @override
  Future<String?> loadScoreVersionManifest(String id) async => manifest;

  @override
  Future<void> saveScoreVersionManifest(String id, String json) async {
    manifest = json;
  }

  @override
  Future<void> saveScoreVersionBytes(
    String id,
    String versionId,
    List<int> bytes,
  ) async {
    if (versionId == scoreDraftId) {
      draft = bytes;
    } else {
      versions[versionId] = bytes;
    }
  }

  @override
  Future<List<int>?> loadScoreVersionBytes(String id, String versionId) async =>
      versionId == scoreDraftId ? draft : versions[versionId];

  @override
  Future<void> deleteScoreVersion(String id, String versionId) async {
    if (versionId == scoreDraftId) {
      draft = null;
    } else {
      versions.remove(versionId);
    }
  }

  @override
  Future<String?> loadPlaybackSequence(
    String songId, {
    String? versionId,
  }) async => sequences[versionId ?? ''];

  @override
  Future<void> savePlaybackSequence(
    String songId,
    String jsonContent, {
    String? versionId,
  }) async {
    sequences[versionId ?? ''] = jsonContent;
  }
}

class _Originals implements OmrConvertService {
  @override
  Future<List<List<OmrBarPlace?>>?> barPlaces(String songId) async => null;

  @override
  Future<Uint8List?> systemImage(String songId, String name) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _names = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

/// The note on the staff position [steps] half-gaps above the bottom line.
({PitchStep step, int octave}) _pitchAt(int steps, {required bool bass}) {
  // Bottom line: E4 under the treble clef, G2 under the bass clef.
  final diatonic = (bass ? 2 * 7 + 4 : 4 * 7 + 2) + steps;
  return (
    step: PitchStep.values.firstWhere(
      (s) => s.name.toUpperCase() == _names[diatonic % 7],
    ),
    octave: diatonic ~/ 7,
  );
}

String _name(MusicPitch? pitch) => pitch == null
    ? 'rest'
    : '${pitch.step.name.toUpperCase()}${pitch.alter > 0
          ? '#'
          : pitch.alter < 0
          ? 'b'
          : ''}${pitch.octave}';

final _view = find.byType(VerovioScoreView);

VerovioScoreViewState _state(WidgetTester tester) =>
    tester.state<VerovioScoreViewState>(_view);

Finder get _viewer =>
    find.descendant(of: _view, matching: find.byType(InteractiveViewer));

Offset _global(WidgetTester tester, Offset content) =>
    tester.getTopLeft(_viewer) +
    MatrixUtils.transformPoint(_state(tester).transformForTest, content);

double _scale(WidgetTester tester) =>
    _state(tester).transformForTest.getMaxScaleOnAxis();

/// Pumps until the page shown is the score as it is now.
Future<bool> _ready(WidgetTester tester, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    final state = _state(tester);
    final layout = state.layoutForTest;
    if (layout != null &&
        layout.measures.isNotEmpty &&
        !state.pagesStaleForTest) {
      // Two quiet frames more: an edit asks for a new page a frame later.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      final again = _state(tester);
      if (again.layoutForTest != null && !again.pagesStaleForTest) return true;
    }
  }
  return false;
}

Future<void> _open(WidgetTester tester, String xml) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        songFileStorageProvider.overrideWithValue(_MemoryStorage()),
        omrConvertServiceProvider.overrideWithValue(_Originals()),
      ],
      child: MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: appLocalizationDelegates,
        home: ScoreProofreadScreen(
          // Another score is another screen, not the old one kept.
          key: ValueKey(xml.hashCode),
          songId: 'touch-test',
          musicXml: xml,
          catalog: ScoreVersionCatalog.empty,
        ),
      ),
    ),
  );
  expect(await _ready(tester), isTrue, reason: 'the score was engraved');
}

/// The notes and rests of [staff] in [bar], in order.
List<MusicNote> _events(WidgetTester tester, int bar, int staff) => [
  for (final event
      in tester
          .widget<VerovioScoreView>(_view)
          .score
          .parts
          .first
          .measures[bar]
          .events)
    if (event is MusicNote &&
        !event.isChord &&
        !event.isGrace &&
        event.staff.clamp(1, 2) == staff)
      event,
];

/// Where the [index]th note or rest of [staff] in [bar] stands on the page,
/// and the staff's bottom line and line gap there.
({double x, double bottom, double gap}) _spot(
  WidgetTester tester,
  int bar,
  int staff,
  int index,
) {
  final layout = _state(tester).layoutForTest!;
  final box = layout.measures.firstWhere((m) => m.measureIndex == bar);
  final drawn = [
    for (final note in layout.notes)
      if (note.measureIndex == bar && note.staff == staff) note,
  ]..sort((a, b) => a.center.dx.compareTo(b.center.dx));
  // Notes struck together stand at one x.
  final columns = <double>[];
  for (final note in drawn) {
    if (columns.isEmpty || note.center.dx - columns.last > 1) {
      columns.add(note.center.dx);
    }
  }
  return (
    x: columns[index],
    bottom: box.bottomLineFor(staff),
    gap: box.lineGapFor(staff),
  );
}

final _log = <String>[];
void _say(String line) {
  _log.add(line);
  // ignore: avoid_print
  print('TOUCHQA $line');
}

Future<void> _undo(WidgetTester tester) async {
  await tester.tap(find.byTooltip('실행 취소'));
  await _ready(tester);
}

/// Taps every staff position from [low] to [high] at the [index]th rest of
/// [staff] in [bar], each [off] of a half-gap away from the exact place, and
/// returns how many were written and how many of those were the pitch of the
/// position tapped.
Future<({int taps, int written, int right, List<String> wrong})> _sweep(
  WidgetTester tester, {
  required String label,
  required int bar,
  required int staff,
  required bool bass,
  int index = 0,
  int low = -6,
  int high = 14,
  double off = 0,
  double toward = 0,
}) async {
  var written = 0, right = 0, taps = 0;
  final wrong = <String>[];
  final waits = <int>[];
  // Between two notes the nearer one is meant.
  final expectAt = toward > 0.5 ? index + 1 : index;
  // The place to be tapped is brought into view first, as a player would.
  final middle = _spot(tester, bar, staff, index);
  await _bringIn(tester, Offset(middle.x, middle.bottom - middle.gap * 2));
  final area = tester.getRect(_viewer).deflate(6);
  for (var steps = low; steps <= high; steps++) {
    final spot = _spot(tester, bar, staff, index);
    final next = toward == 0 ? spot : _spot(tester, bar, staff, index + 1);
    final content = Offset(
      spot.x + (next.x - spot.x) * toward,
      spot.bottom - (steps + off) * spot.gap / 2,
    );
    final at = _global(tester, content);
    if (!area.contains(at)) continue;
    taps++;
    final clock = Stopwatch()..start();
    await tester.tapAt(at);
    await _ready(tester);
    waits.add(clock.elapsedMilliseconds);
    final now = _events(tester, bar, staff);
    final target = now[expectAt];
    final want = _pitchAt(steps, bass: bass);
    if (target.pitch == null) {
      wrong.add(
        'step $steps (${_names[want.step.index]}${want.octave}): nothing written',
      );
      continue;
    }
    written++;
    final others = [
      for (final (i, event) in now.indexed)
        if (i != expectAt && event.pitch != null) i,
    ];
    if (target.pitch!.step == want.step &&
        target.pitch!.octave == want.octave &&
        others.isEmpty) {
      right++;
    } else {
      wrong.add(
        'step $steps: wanted ${_names[want.step.index]}${want.octave} at event $index, '
        'got ${_name(target.pitch)}${others.isEmpty ? '' : ' and notes at $others'}',
      );
    }
    await _undo(tester);
  }
  _say(
    '$label | scale ${_scale(tester).toStringAsFixed(2)} | gap on screen '
    '${(_spot(tester, bar, staff, index).gap * _scale(tester) * tester.view.devicePixelRatio).toStringAsFixed(1)}px | '
    'off ${off.toStringAsFixed(2)} | taps $taps written $written right $right'
    '${waits.isEmpty ? '' : ' | page ready after ${(waits.reduce((a, b) => a + b) / waits.length).round()}ms (longest ${waits.reduce((a, b) => a > b ? a : b)}ms)'}'
    '${wrong.isEmpty ? '' : ' | WRONG: ${wrong.join('; ')}'}',
  );
  return (taps: taps, written: written, right: right, wrong: wrong);
}

/// Two fingers about [focus], their distance going from [from] to [to]. Both
/// stay on the score: where one would leave it, the pair is moved along.
Future<void> _pinch(
  WidgetTester tester,
  Offset focus,
  double from,
  double to,
) async {
  final area = tester.getRect(_viewer).deflate(12);
  final reach = (from > to ? from : to) / 2;
  final centre = Offset(
    focus.dx.clamp(area.left + reach, area.right - reach),
    focus.dy.clamp(area.top + 8, area.bottom - 8),
  );
  final a = await tester.startGesture(
    centre - Offset(from / 2, 0),
    pointer: 31,
  );
  final b = await tester.startGesture(
    centre + Offset(from / 2, 0),
    pointer: 32,
  );
  await tester.pump(const Duration(milliseconds: 30));
  for (var i = 1; i <= 12; i++) {
    final d = from + (to - from) * i / 12;
    await a.moveTo(centre - Offset(d / 2, 0));
    await b.moveTo(centre + Offset(d / 2, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await a.up();
  await b.up();
  await tester.pump(const Duration(milliseconds: 300));
  await _ready(tester);
}

/// Moves the page with one finger until [content] is well inside the view.
Future<bool> _bringIn(WidgetTester tester, Offset content) async {
  for (var i = 0; i < 12; i++) {
    final area = tester.getRect(_viewer).deflate(40);
    final at = _global(tester, content);
    if (area.contains(at)) return true;
    final want = Offset(
      at.dx.clamp(area.left + 20, area.right - 20),
      at.dy.clamp(area.top + 60, area.bottom - 60),
    );
    final delta = want - at;
    final step = Offset(delta.dx.clamp(-120, 120), delta.dy.clamp(-120, 120));
    await tester.timedDragFrom(
      tester.getRect(_viewer).center,
      step,
      const Duration(milliseconds: 220),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await _ready(tester);
  }
  return false;
}

Future<void> _noteTool(WidgetTester tester) async {
  await tester.tap(find.byTooltip('음표 넣기'));
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.widget<VerovioScoreView>(_view).inputMode, 'place');
}

/// Two taps one after the other, [apart] milliseconds between them: on the
/// first and on the second beat of [bar]. Says how many were written.
Future<int> _twoTaps(WidgetTester tester, int bar, int apart) async {
  final first = _spot(tester, bar, 1, 0);
  final second = _spot(tester, bar, 1, 1);
  await tester.tapAt(
    _global(tester, Offset(first.x, first.bottom - 3 * first.gap / 2)),
  );
  await tester.pump(Duration(milliseconds: apart));
  await tester.tapAt(
    _global(tester, Offset(second.x, second.bottom - 5 * second.gap / 2)),
  );
  await _ready(tester);
  await tester.pump(const Duration(milliseconds: 400));
  await _ready(tester);
  final now = _events(tester, bar, 1);
  final written = [now[0], now[1]].where((e) => e.pitch != null).length;
  _say(
    'two taps ${apart}ms apart | written $written of 2 '
    '(${_name(now[0].pitch)}, ${_name(now[1].pitch)})',
  );
  for (var i = 0; i < written; i++) {
    await _undo(tester);
  }
  return written;
}

/// A finger held on [from] of the [index]th rest and carried to [to] before
/// it is lifted: the note is the one of the place it is lifted from.
Future<String?> _carry(
  WidgetTester tester, {
  required int bar,
  required int index,
  required int from,
  required int to,
}) async {
  final spot = _spot(tester, bar, 1, index);
  Offset at(num steps) =>
      _global(tester, Offset(spot.x, spot.bottom - steps * spot.gap / 2));
  final finger = await tester.startGesture(at(from), pointer: 41);
  await tester.pump(const Duration(milliseconds: 650));
  for (var i = 1; i <= 8; i++) {
    await finger.moveTo(at(from + (to - from) * i / 8));
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pump(const Duration(milliseconds: 150));
  await finger.up();
  await _ready(tester);
  final got = _events(tester, bar, 1)[index].pitch;
  final want = _pitchAt(to, bass: false);
  final right =
      got != null && got.step == want.step && got.octave == want.octave;
  _say(
    'held on step $from and carried to step $to | scale ${_scale(tester).toStringAsFixed(2)} | '
    'wanted ${_names[want.step.index]}${want.octave}, got ${_name(got)}${right ? '' : ' | WRONG'}',
  );
  if (got != null) await _undo(tester);
  return right ? null : 'carried $from->$to: got ${_name(got)}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a tap on the staff writes the note of that line or space', (
    tester,
  ) async {
    await _open(tester, _treble);
    await _noteTool(tester);
    final failures = <String>[];
    void check(
      ({int taps, int written, int right, List<String> wrong}) r,
      String what,
    ) {
      if (r.right != r.written || r.wrong.isNotEmpty) {
        failures.add('$what: ${r.wrong.join('; ')}');
      }
    }

    // As opened.
    check(
      await _sweep(
        tester,
        label: 'treble as opened',
        bar: 0,
        staff: 1,
        bass: false,
      ),
      'as opened',
    );
    // A finger a quarter of the way to the next line or space still means this one.
    check(
      await _sweep(
        tester,
        label: 'treble, a little high',
        bar: 0,
        staff: 1,
        bass: false,
        off: 0.4,
        low: -2,
        high: 10,
      ),
      'a little high',
    );
    check(
      await _sweep(
        tester,
        label: 'treble, a little low',
        bar: 0,
        staff: 1,
        bass: false,
        off: -0.4,
        low: -2,
        high: 10,
      ),
      'a little low',
    );
    // Each beat of the bar is its own place.
    for (var index = 1; index < 4; index++) {
      check(
        await _sweep(
          tester,
          label: 'treble beat ${index + 1}',
          bar: 0,
          staff: 1,
          bass: false,
          index: index,
          low: 0,
          high: 8,
        ),
        'beat ${index + 1}',
      );
    }
    // Between two notes, the nearer one is meant.
    check(
      await _sweep(
        tester,
        label: 'treble, a third of the way to the next beat',
        bar: 0,
        staff: 1,
        bass: false,
        index: 1,
        toward: 0.3,
        low: 0,
        high: 8,
      ),
      'toward 0.3',
    );
    check(
      await _sweep(
        tester,
        label: 'treble, two thirds of the way to the next beat',
        bar: 0,
        staff: 1,
        bass: false,
        index: 1,
        toward: 0.7,
        low: 0,
        high: 8,
      ),
      'toward 0.7',
    );
    // Another line of the score.
    final lastBar = _state(tester).layoutForTest!.measures.last.measureIndex;
    check(
      await _sweep(
        tester,
        label: 'treble last bar ($lastBar)',
        bar: lastBar,
        staff: 1,
        bass: false,
        index: 2,
        low: 0,
        high: 8,
      ),
      'last bar',
    );

    // Enlarged and reduced with two fingers, about the place to be tapped.
    for (final (from, to) in [
      (120.0, 200.0),
      (120.0, 220.0),
      (100.0, 260.0),
      // Reduced again, down to the smallest the page goes.
      (300.0, 150.0),
      (300.0, 150.0),
      (300.0, 170.0),
      (300.0, 190.0),
      (300.0, 150.0),
    ]) {
      var spot = _spot(tester, 0, 1, 1);
      await _pinch(
        tester,
        _global(tester, Offset(spot.x, spot.bottom - spot.gap * 2)),
        from,
        to,
      );
      spot = _spot(tester, 0, 1, 1);
      await _bringIn(tester, Offset(spot.x, spot.bottom - spot.gap * 2));
      check(
        await _sweep(
          tester,
          label: 'treble after pinch $from->$to',
          bar: 0,
          staff: 1,
          bass: false,
          index: 1,
        ),
        'pinch $from->$to',
      );
      check(
        await _sweep(
          tester,
          label: 'treble after pinch $from->$to, off',
          bar: 0,
          staff: 1,
          bass: false,
          index: 2,
          off: 0.4,
          low: 0,
          high: 8,
        ),
        'pinch $from->$to off',
      );
    }
    // One tap soon after another.
    for (final apart in [60, 150, 300, 500, 800]) {
      await _twoTaps(tester, 0, apart);
    }
    // A finger held down and carried up or down the staff.
    for (final (from, to) in [(2, 6), (6, 1), (4, 11), (0, -3)]) {
      final wrong = await _carry(tester, bar: 0, index: 1, from: from, to: to);
      if (wrong != null) failures.add(wrong);
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  testWidgets('under the bass clef and on two staves', (tester) async {
    final failures = <String>[];
    void check(
      ({int taps, int written, int right, List<String> wrong}) r,
      String what,
    ) {
      if (r.right != r.written || r.wrong.isNotEmpty) {
        failures.add('$what: ${r.wrong.join('; ')}');
      }
    }

    await _open(tester, _bass);
    await _noteTool(tester);
    check(
      await _sweep(tester, label: 'bass clef', bar: 0, staff: 1, bass: true),
      'bass clef',
    );
    var spot = _spot(tester, 0, 1, 1);
    await _pinch(
      tester,
      _global(tester, Offset(spot.x, spot.bottom - spot.gap * 2)),
      100,
      240,
    );
    check(
      await _sweep(
        tester,
        label: 'bass clef enlarged',
        bar: 0,
        staff: 1,
        bass: true,
        index: 1,
      ),
      'bass clef enlarged',
    );

    await _open(tester, _piano);
    await _noteTool(tester);
    check(
      await _sweep(
        tester,
        label: 'piano upper staff',
        bar: 0,
        staff: 1,
        bass: false,
        low: -3,
        high: 12,
      ),
      'piano upper',
    );
    check(
      await _sweep(
        tester,
        label: 'piano lower staff',
        bar: 0,
        staff: 2,
        bass: true,
        low: -4,
        high: 11,
      ),
      'piano lower',
    );
    spot = _spot(tester, 0, 2, 1);
    await _pinch(
      tester,
      _global(tester, Offset(spot.x, spot.bottom - spot.gap * 2)),
      100,
      230,
    );
    check(
      await _sweep(
        tester,
        label: 'piano upper staff enlarged',
        bar: 0,
        staff: 1,
        bass: false,
        index: 1,
        low: -3,
        high: 12,
      ),
      'piano upper enlarged',
    );
    check(
      await _sweep(
        tester,
        label: 'piano lower staff enlarged',
        bar: 0,
        staff: 2,
        bass: true,
        index: 1,
        low: -4,
        high: 11,
      ),
      'piano lower enlarged',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  testWidgets('with larger notes, and after the page was moved', (
    tester,
  ) async {
    final failures = <String>[];
    void check(
      ({int taps, int written, int right, List<String> wrong}) r,
      String what,
    ) {
      if (r.right != r.written || r.wrong.isNotEmpty) {
        failures.add('$what: ${r.wrong.join('; ')}');
      }
    }

    await _open(tester, _treble);
    for (final size in ['크게', '아주 크게', '작게', '보통']) {
      await tester.tap(find.byTooltip('팔레트'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('보기').last);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('음표 크기'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(size).last);
      await _ready(tester);
      await _noteTool(tester);
      check(
        await _sweep(
          tester,
          label: 'note size $size',
          bar: 0,
          staff: 1,
          bass: false,
          index: 1,
        ),
        'size $size',
      );
      // Moved with one finger, then tapped: a bar of the last line.
      final area = tester.getRect(_viewer);
      await tester.timedDragFrom(
        area.center,
        const Offset(0, -45),
        const Duration(milliseconds: 250),
      );
      await _ready(tester);
      final far = _state(tester).layoutForTest!.measures.last.measureIndex;
      final there = _spot(tester, far, 1, 2);
      await _bringIn(tester, Offset(there.x, there.bottom - there.gap * 2));
      check(
        await _sweep(
          tester,
          label: 'note size $size, page moved (bar $far)',
          bar: far,
          staff: 1,
          bass: false,
          index: 2,
          low: 0,
          high: 8,
        ),
        'size $size moved',
      );
      await tester.tap(find.byTooltip('선택'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    // One long line that moves across the screen.
    await tester.tap(find.byTooltip('팔레트'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('보기').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('보기 방식'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('이어 보기').last);
    await tester.pump(const Duration(milliseconds: 600));
    await _ready(tester);
    await _noteTool(tester);
    for (final bar in [0, 5]) {
      check(
        await _sweep(
          tester,
          label: 'one long line, bar $bar',
          bar: bar,
          staff: 1,
          bass: false,
          index: 1,
        ),
        'long line bar $bar',
      );
    }
    final spot = _spot(tester, 5, 1, 1);
    await _pinch(
      tester,
      _global(tester, Offset(spot.x, spot.bottom - spot.gap * 2)),
      120,
      230,
    );
    check(
      await _sweep(
        tester,
        label: 'one long line enlarged, bar 5',
        bar: 5,
        staff: 1,
        bass: false,
        index: 2,
      ),
      'long line enlarged',
    );
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
