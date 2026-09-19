import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/features/stage/data/performance_key_map_store.dart';
import 'package:page_a_diddle/features/stage/domain/performance_action.dart';
import 'package:page_a_diddle/features/stage/domain/performance_key_map.dart';

void main() {
  test('없는 파일은 기본 매핑을 돌려준다', () async {
    final directory = await Directory.systemTemp.createTemp('pedal-map-');
    addTearDown(() => directory.delete(recursive: true));
    final store = PerformanceKeyMapStore(documents: () => directory);

    final map = await store.load();

    expect(map.slotFor(LogicalKeyboardKey.arrowLeft.keyId), PedalSlot.left);
  });

  test('매핑을 저장하고 다시 읽는다', () async {
    final directory = await Directory.systemTemp.createTemp('pedal-map-');
    addTearDown(() => directory.delete(recursive: true));
    final store = PerformanceKeyMapStore(documents: () => directory);
    final saved = PerformanceKeyMap.defaults().assign(
      keyId: LogicalKeyboardKey.keyZ.keyId,
      action: PerformanceAction.toggleLoop,
    );

    await store.save(saved);
    final loaded = await store.load();

    expect(
      loaded.directActionFor(LogicalKeyboardKey.keyZ.keyId),
      PerformanceAction.toggleLoop,
    );
    expect(loaded.directActionFor(LogicalKeyboardKey.keyL.keyId), isNull);
  });
}
