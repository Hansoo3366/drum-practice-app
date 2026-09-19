import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/features/stage/domain/performance_key_map.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PerformanceKeyMapStore {
  PerformanceKeyMapStore({Directory? Function()? documents})
    : _documents = documents;

  final Directory? Function()? _documents;

  Future<File> _file() async {
    final directory =
        _documents?.call() ?? await getApplicationDocumentsDirectory();
    return File(p.join(directory.path, 'performance_keys.json'));
  }

  Future<PerformanceKeyMap> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) {
        return PerformanceKeyMap.defaults();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<Object?, Object?>) {
        return PerformanceKeyMap.defaults();
      }
      return PerformanceKeyMap.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return PerformanceKeyMap.defaults();
    }
  }

  Future<void> save(PerformanceKeyMap map) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(map.toJson()));
  }
}

class PerformanceKeyMapNotifier extends AsyncNotifier<PerformanceKeyMap> {
  @override
  Future<PerformanceKeyMap> build() {
    return ref.read(performanceKeyMapStoreProvider).load();
  }

  Future<void> updateMap(PerformanceKeyMap map) async {
    await ref.read(performanceKeyMapStoreProvider).save(map);
    state = AsyncData(map);
  }
}

final performanceKeyMapStoreProvider = Provider<PerformanceKeyMapStore>((ref) {
  return PerformanceKeyMapStore();
});

final performanceKeyMapProvider =
    AsyncNotifierProvider<PerformanceKeyMapNotifier, PerformanceKeyMap>(
      PerformanceKeyMapNotifier.new,
    );
