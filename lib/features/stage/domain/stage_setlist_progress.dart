class StageSetlistItem {
  const StageSetlistItem({
    required this.songId,
    required this.title,
    required this.offlineAvailable,
    this.bpm,
  });

  final String songId;
  final String title;
  final bool offlineAvailable;
  final int? bpm;
}

class StageSetlistProgress {
  const StageSetlistProgress({
    required this.position,
    required this.total,
    required this.title,
    this.bpm,
    this.previousSongId,
    this.nextSongId,
    this.nextTitle,
  });

  final int position;
  final int total;
  final String title;
  final int? bpm;
  final String? previousSongId;
  final String? nextSongId;
  final String? nextTitle;
}

String? firstStageSongId(
  Iterable<StageSetlistItem> items, {
  String? fromSongId,
}) {
  final list = items.toList();
  var start = 0;
  if (fromSongId != null) {
    final index = list.indexWhere((item) => item.songId == fromSongId);
    if (index != -1) {
      start = index;
    }
  }
  for (var i = start; i < list.length; i++) {
    if (list[i].offlineAvailable) {
      return list[i].songId;
    }
  }
  return null;
}

StageSetlistProgress? calculateStageSetlistProgress(
  Iterable<StageSetlistItem> items, {
  required String currentSongId,
}) {
  final playable = items.where((item) => item.offlineAvailable).toList();
  final index = playable.indexWhere((item) => item.songId == currentSongId);
  if (index == -1) {
    return null;
  }
  final current = playable[index];
  final next = index + 1 < playable.length ? playable[index + 1] : null;
  return StageSetlistProgress(
    position: index + 1,
    total: playable.length,
    title: current.title,
    bpm: current.bpm,
    previousSongId: index > 0 ? playable[index - 1].songId : null,
    nextSongId: next?.songId,
    nextTitle: next?.title,
  );
}
