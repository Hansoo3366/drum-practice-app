import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/sheet_insets.dart';
import 'package:page_a_diddle/features/digital_score/domain/music_score.dart';
import 'package:page_a_diddle/features/digital_score/domain/score_transpose.dart';

class ScoreTransposeRequest {
  const ScoreTransposeRequest({
    required this.semitones,
    required this.fifthsDelta,
  });

  final int semitones;
  final int fifthsDelta;
}

Future<ScoreTransposeRequest?> showScoreTransposeSheet(
  BuildContext context, {
  required int currentFifths,
  int? originalFifths,
  MusicScore? score,
}) {
  return showModalBottomSheet<ScoreTransposeRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ScoreTransposeSheet(
      currentFifths: currentFifths,
      originalFifths: originalFifths ?? currentFifths,
      score: score,
    ),
  );
}

class _ScoreTransposeSheet extends StatefulWidget {
  const _ScoreTransposeSheet({
    required this.currentFifths,
    required this.originalFifths,
    required this.score,
  });

  final int currentFifths;
  final int originalFifths;
  final MusicScore? score;

  @override
  State<_ScoreTransposeSheet> createState() => _ScoreTransposeSheetState();
}

class _ScoreTransposeSheetState extends State<_ScoreTransposeSheet> {
  late int _semitones;
  late int _targetFifths;
  late final List<int> _validSemitones;

  @override
  void initState() {
    super.initState();
    _semitones = 0;
    _targetFifths = widget.currentFifths;
    _validSemitones = widget.score == null
        ? [
            for (
              var value = minTransposeSemitones;
              value <= maxTransposeSemitones;
              value++
            )
              value,
          ]
        : validTransposeSemitones(widget.score!);
  }

  bool get _canApply =>
      (_semitones != 0 || _targetFifths != widget.currentFifths) &&
      _selectionIsValid;

  bool get _selectionIsValid {
    final score = widget.score;
    if (score == null) return _validSemitones.contains(_semitones);
    return canTransposeScore(
      score,
      semitones: _semitones,
      fifthsDelta: _targetFifths - widget.currentFifths,
    );
  }

  int? get _previousSemitone {
    for (var index = _validSemitones.length - 1; index >= 0; index--) {
      if (_validSemitones[index] < _semitones) return _validSemitones[index];
    }
    return null;
  }

  int? get _nextSemitone {
    for (final value in _validSemitones) {
      if (value > _semitones) return value;
    }
    return null;
  }

  void _setSemitones(int value) {
    if (!_validSemitones.contains(value)) return;
    setState(() {
      _semitones = value;
      _targetFifths = wrapKeyFifths(
        widget.currentFifths +
            fifthsDeltaForSemitones(
              value,
              referenceFifths: widget.currentFifths,
            ),
      );
    });
  }

  void _setTargetFifths(int fifths) {
    final pitchClass = semitonesForKeyChange(widget.currentFifths, fifths);
    final candidates =
        _validSemitones
            .where(
              (value) =>
                  (value % 12 + 12) % 12 == pitchClass &&
                  _canUseTarget(value, fifths),
            )
            .toList()
          ..sort((a, b) {
            final byDistance = a.abs().compareTo(b.abs());
            return byDistance != 0 ? byDistance : b.compareTo(a);
          });
    if (candidates.isEmpty) return;
    setState(() {
      _targetFifths = fifths;
      _semitones = candidates.first;
    });
  }

  bool _canUseTarget(int semitones, int fifths) {
    final score = widget.score;
    return score == null ||
        canTransposeScore(
          score,
          semitones: semitones,
          fifthsDelta: fifths - widget.currentFifths,
        );
  }

  bool _targetIsAvailable(int fifths) {
    final pitchClass = semitonesForKeyChange(widget.currentFifths, fifths);
    return _validSemitones.any(
      (value) =>
          (value % 12 + 12) % 12 == pitchClass && _canUseTarget(value, fifths),
    );
  }

  String _signed(int value) => value > 0 ? '+$value' : '$value';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: sheetContentPadding(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.scoreTranspose,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: l10n.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${l10n.semitone}: ${_signed(_validSemitones.first)} ~ '
              '${_signed(_validSemitones.last)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                l10n.sourceKey,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(width: 12),
              Text(
                keySignatureLabel(widget.originalFifths),
                style: const TextStyle(
                  fontFamily: AppFonts.mono,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.semitone,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.semitoneDown,
                onPressed: _previousSemitone == null
                    ? null
                    : () => _setSemitones(_previousSemitone!),
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$_semitones',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.mono,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.semitoneUp,
                onPressed: _nextSemitone == null
                    ? null
                    : () => _setSemitones(_nextSemitone!),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.keySignature,
              border: const OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _targetFifths,
                isExpanded: true,
                items: [
                  for (var fifths = -7; fifths <= 7; fifths++)
                    DropdownMenuItem(
                      value: fifths,
                      enabled: _targetIsAvailable(fifths),
                      child: Text(keySignatureLabel(fifths)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _setTargetFifths(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canApply
                  ? () => Navigator.pop(
                      context,
                      ScoreTransposeRequest(
                        semitones: _semitones,
                        fifthsDelta: _targetFifths - widget.currentFifths,
                      ),
                    )
                  : null,
              child: Text(l10n.done),
            ),
          ),
        ],
      ),
    );
  }
}
