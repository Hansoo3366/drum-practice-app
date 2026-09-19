import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/sheet_insets.dart';
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
}) {
  return showModalBottomSheet<ScoreTransposeRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ScoreTransposeSheet(
      currentFifths: currentFifths,
      originalFifths: originalFifths ?? currentFifths,
    ),
  );
}

class _ScoreTransposeSheet extends StatefulWidget {
  const _ScoreTransposeSheet({
    required this.currentFifths,
    required this.originalFifths,
  });

  final int currentFifths;
  final int originalFifths;

  @override
  State<_ScoreTransposeSheet> createState() => _ScoreTransposeSheetState();
}

class _ScoreTransposeSheetState extends State<_ScoreTransposeSheet> {
  late int _semitones;
  late int _targetFifths;

  @override
  void initState() {
    super.initState();
    _semitones = 0;
    _targetFifths = widget.currentFifths;
  }

  bool get _canApply =>
      _semitones != 0 || _targetFifths != widget.currentFifths;

  void _setSemitones(int value) {
    final semitones = value.clamp(minTransposeSemitones, maxTransposeSemitones);
    setState(() {
      _semitones = semitones;
      _targetFifths = wrapKeyFifths(
        widget.currentFifths +
            fifthsDeltaForSemitones(
              semitones,
              referenceFifths: widget.currentFifths,
            ),
      );
    });
  }

  void _setTargetFifths(int fifths) {
    setState(() {
      _targetFifths = fifths;
      _semitones = semitonesForKeyChange(widget.currentFifths, fifths);
    });
  }

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
                onPressed: _semitones <= minTransposeSemitones
                    ? null
                    : () => _setSemitones(_semitones - 1),
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
                onPressed: _semitones >= maxTransposeSemitones
                    ? null
                    : () => _setSemitones(_semitones + 1),
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
