import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_guide.dart';

class _Store implements ScoreGuideStore {
  _Store({this.wasSeen = false, this.broken = false});

  bool wasSeen;
  final bool broken;
  var marks = 0;

  @override
  Future<bool> seen() async {
    if (broken) throw StateError('no storage');
    return wasSeen;
  }

  @override
  Future<void> markSeen() async {
    marks++;
    wasSeen = true;
  }
}

Widget _app(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: appLocalizationDelegates,
        home: home,
      ),
    );

void main() {
  testWidgets('the guide names every button, and the review only for a '
      'converted score', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    final l10n = context.l10n;

    final converted = scoreGuideEntries(l10n, converted: true);
    final imported = scoreGuideEntries(l10n, converted: false);
    expect(converted.map((e) => e.title), [
      '버전 (제목 옆 이름)',
      '연주 순서',
      '변환 검토',
      '교정',
      '재생',
      '도구',
    ]);
    expect(imported.map((e) => e.title), isNot(contains('변환 검토')));
    expect(imported, hasLength(converted.length - 1));
    for (final entry in converted) {
      expect(entry.body, isNotEmpty);
    }
  });

  testWidgets('the sheet lists them and closes on its button', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showScoreGuideSheet(context, converted: true),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('화면 안내'), findsOneWidget);
    expect(find.text('변환 검토'), findsOneWidget);
    expect(find.textContaining('악기별 악보 만들기'), findsOneWidget);
    await tester.ensureVisible(find.text('알겠어요'));
    await tester.tap(find.text('알겠어요'));
    await tester.pumpAndSettle();
    expect(find.text('화면 안내'), findsNothing);
  });

  testWidgets('the sheet scrolls instead of overflowing with large text on '
      'a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showScoreGuideSheet(context, converted: true),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.dragUntilVisible(
      find.text('알겠어요'),
      find.byType(SingleChildScrollView),
      const Offset(0, -120),
    );
    expect(find.text('알겠어요'), findsOneWidget);
  });

  group('first time a score is opened', () {
    Future<_Store> open(
      WidgetTester tester, {
      required _Store store,
      bool converted = true,
    }) async {
      await tester.pumpWidget(
        _app(
          const ScoreGuideGate(
            songId: 's',
            child: Scaffold(body: Text('악보')),
          ),
          overrides: [
            scoreGuideStoreProvider.overrideWithValue(store),
            scoreConvertedProvider('s').overrideWith((ref) async => converted),
          ],
        ),
      );
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('the guide comes up by itself, once', (tester) async {
      final store = await open(tester, store: _Store());

      expect(find.text('화면 안내'), findsOneWidget);
      expect(find.text('변환 검토'), findsOneWidget);
      expect(store.marks, 1);

      await tester.tap(find.text('알겠어요'));
      await tester.pumpAndSettle();
      // The next score opens without it.
      await tester.pumpWidget(const SizedBox());
      await open(tester, store: store);
      expect(find.text('화면 안내'), findsNothing);
      expect(store.marks, 1);
    });

    testWidgets('an imported score gets the guide without the review', (
      tester,
    ) async {
      await open(tester, store: _Store(), converted: false);

      expect(find.text('화면 안내'), findsOneWidget);
      expect(find.text('변환 검토'), findsNothing);
    });

    testWidgets('someone who has seen it is not shown it again', (
      tester,
    ) async {
      final store = await open(tester, store: _Store(wasSeen: true));

      expect(find.text('화면 안내'), findsNothing);
      expect(find.text('악보'), findsOneWidget);
      expect(store.marks, 0);
    });

    testWidgets('without storage the score simply opens', (tester) async {
      await open(tester, store: _Store(broken: true));

      expect(find.text('화면 안내'), findsNothing);
      expect(find.text('악보'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
