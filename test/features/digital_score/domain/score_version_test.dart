import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_version.dart';

void main() {
  test('parses a version catalog and keeps original out of stored list', () {
    final catalog = ScoreVersionCatalog.fromJson({
      'activeId': 'v1',
      'versions': [
        {'id': 'original', 'name': 'Original'},
        {'id': 'v1', 'name': 'Version 1'},
        {'id': 'v2', 'name': 'Version 2'},
      ],
    });

    expect(catalog.activeId, 'v1');
    expect(catalog.versions.map((v) => v.id), ['v1', 'v2']);
    expect(catalog.selectable.map((v) => v.id), [
      scoreVersionOriginalId,
      'v1',
      'v2',
    ]);
  });

  test('falls back to original when active version is missing', () {
    final catalog = ScoreVersionCatalog.fromJson({
      'activeId': 'missing',
      'versions': [
        {'id': 'v1', 'name': 'Version 1'},
      ],
    });
    expect(catalog.activeId, scoreVersionOriginalId);
  });

  test('picks the next free version number', () {
    expect(ScoreVersionCatalog.nextVersionNumber(const []), 1);
    expect(
      ScoreVersionCatalog.nextVersionNumber(const [
        ScoreVersionRef(id: 'a', name: 'Version 1'),
        ScoreVersionRef(id: 'b', name: '버전 2'),
      ]),
      3,
    );
  });
}
