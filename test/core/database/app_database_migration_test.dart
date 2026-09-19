import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:page_a_diddle/core/database/app_database.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('page_a_diddle_migration_');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('schema version가 뒤처져도 이미 추가된 컬럼을 다시 만들지 않는다', () async {
    final file = File('${root.path}/page_a_diddle.sqlite');
    final database = AppDatabase(NativeDatabase(file));
    await database.customSelect('SELECT 1').get();
    await database.close();

    final staleVersionDatabase = AppDatabase(NativeDatabase(file));
    await staleVersionDatabase.customStatement('PRAGMA user_version = 13');
    await staleVersionDatabase.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);

    await expectLater(reopened.select(reopened.songs).get(), completes);
    final version = await reopened
        .customSelect('PRAGMA user_version')
        .getSingle();
    final columns = await reopened
        .customSelect('PRAGMA table_info("setlist_entries")')
        .get();

    expect(version.read<int>('user_version'), 16);
    expect(
      columns.any((row) => row.read<String>('name') == 'metronome_json'),
      isTrue,
    );
  });
}
