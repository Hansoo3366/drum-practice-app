import 'package:flutter/foundation.dart';
import 'package:page_a_diddle/features/digital_score/domain/playback_sequence.dart';

/// Sections and playback order of the score version on screen, with the line
/// pick of the structure panel.
///
/// Every change made in the panel is saved at once, one save after the
/// other; bar edits move the sections with their bars and are saved with the
/// edited score instead (see [followMeasureEdits] and [markSaved]).
class ScoreStructureController extends ChangeNotifier {
  ScoreStructureController({
    required String Function() versionId,
    required Future<void> Function(String versionId, PlaybackSequence sequence)
    save,
    required VoidCallback onSaveFailed,
  }) : _versionId = versionId,
       _save = save,
       _onSaveFailed = onSaveFailed;

  final String Function() _versionId;
  final Future<void> Function(String versionId, PlaybackSequence sequence)
  _save;
  final VoidCallback _onSaveFailed;

  PlaybackSequence _sequence = PlaybackSequence.empty;
  PlaybackSequence _saved = PlaybackSequence.empty;
  final List<PlaybackSequence> _history = [];
  Future<void> _saving = Future.value();

  int? _pickStart;
  int? _pickEnd;
  bool _pickingEnd = false;

  /// The order before the first bar insert/delete/move, and what it became
  /// for the bars last seen; see [followMeasureEdits].
  ({
    PlaybackSequence sequence,
    List<int> ids,
    PlaybackSequence remapped,
    List<int> remappedIds,
  })?
  _base;

  bool _disposed = false;

  PlaybackSequence get sequence => _sequence;

  /// True when the order on screen is the one saved for the version.
  bool get isSaved => _sequence == _saved;
  bool get canUndo => _history.isNotEmpty;

  /// Completes when every save started so far has finished.
  Future<void> get saving => _saving;

  /// First bar of the picked lines, or null.
  int? get pickStart => _pickStart;

  /// Last bar of the picked lines when they span more than one bar.
  int? get pickEnd => _pickEnd;

  /// True after a pick, until a name is chosen: a later line extends it.
  bool get pickingEnd => _pickingEnd;

  /// Shows [sequence] as saved for the version now on screen.
  void load(PlaybackSequence sequence) {
    _sequence = sequence;
    _saved = sequence;
    _history.clear();
    _base = null;
    _clearPick();
    _notify();
  }

  /// Records that [sequence] was saved with the score.
  void markSaved() {
    _saved = _sequence;
    _notify();
  }

  /// Changes the order and saves it.
  void update(PlaybackSequence next) {
    if (_sequence == next) return;
    _history.add(_sequence);
    if (_history.length > 100) _history.removeAt(0);
    _sequence = next;
    _notify();
    _autosave();
  }

  void undo() {
    if (_history.isEmpty) return;
    _sequence = _history.removeLast();
    _notify();
    _autosave();
  }

  void clearPick() {
    _clearPick();
    _notify();
  }

  /// Picks the staff line of bars [lineStart]..[lineEnd]; while a pick is
  /// open, a later line extends it to that line's end.
  void pickLine(int lineStart, int lineEnd) {
    final start = _pickStart;
    if (_pickingEnd && start != null && lineStart > start) {
      _pickEnd = lineEnd;
    } else {
      _pickStart = lineStart;
      _pickEnd = lineEnd > lineStart ? lineEnd : null;
      _pickingEnd = true;
    }
    _notify();
  }

  /// After naming, the next tap starts a new pick.
  void endPick() {
    _pickEnd = null;
    _pickingEnd = false;
    _notify();
  }

  /// Keeps section boundaries on their bars when bars are inserted, deleted
  /// or moved. Boundaries are always recomputed from the order as it was
  /// before the first such edit, so undoing an edit restores them exactly.
  ///
  /// [writtenMarks] are the rehearsal-mark boundaries of the score before the
  /// edit, which stand in for boundaries while the user has set none.
  void followMeasureEdits(
    List<int> before,
    List<int> after, {
    List<SectionMark> writtenMarks = const [],
  }) {
    if (identical(before, after) || listEquals(before, after)) return;
    final base = _base;
    if (base == null ||
        _sequence != base.remapped ||
        !listEquals(before, base.remappedIds)) {
      final sequence = _sequence.marks.isEmpty && writtenMarks.isNotEmpty
          ? _sequence.copyWith(marks: writtenMarks)
          : _sequence;
      _base = (
        sequence: sequence,
        ids: before,
        remapped: _sequence,
        remappedIds: before,
      );
    }
    final origin = _base!;
    _sequence = remapSectionMarks(origin.sequence, origin.ids, after);
    // Earlier orders refer to bars that moved; undo belongs to the bar edit.
    _history.clear();
    _base = (
      sequence: origin.sequence,
      ids: origin.ids,
      remapped: _sequence,
      remappedIds: after,
    );
    _notify();
  }

  void _clearPick() {
    _pickStart = null;
    _pickEnd = null;
    _pickingEnd = false;
  }

  void _autosave() {
    final sequence = _sequence;
    final versionId = _versionId();
    _saving = _saving.then((_) async {
      try {
        await _save(versionId, sequence);
        if (_versionId() == versionId) {
          _saved = sequence;
          _notify();
        }
      } on Object {
        if (!_disposed) _onSaveFailed();
      }
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
