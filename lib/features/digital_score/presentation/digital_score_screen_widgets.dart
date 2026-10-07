part of 'digital_score_screen.dart';

// Dialogs, the bar tools bar and the OMR review sheet of the score screen.

class _ScoreVersionDialog extends StatefulWidget {
  const _ScoreVersionDialog({required this.initialName});

  final String initialName;

  @override
  State<_ScoreVersionDialog> createState() => _ScoreVersionDialogState();
}

class _ScoreVersionDialogState extends State<_ScoreVersionDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.scoreVersionName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.scoreVersionName),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(context.l10n.save)),
      ],
    );
  }
}

class _MeasureToolsBar extends StatelessWidget {
  const _MeasureToolsBar({
    required this.canDelete,
    required this.onAdd,
    required this.onRemove,
    required this.onDuplicate,
    required this.onDrag,
  });

  final bool canDelete;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onDrag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: AppColors.canvas,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.insertMeasureAfter,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                ),
                IconButton(
                  tooltip: l10n.deleteMeasure,
                  onPressed: canDelete ? onRemove : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                IconButton(
                  tooltip: l10n.duplicateMeasure,
                  onPressed: onDuplicate,
                  icon: const Icon(Icons.copy_all_rounded),
                ),
                IconButton(
                  tooltip: l10n.dragMeasure,
                  onPressed: onDrag,
                  icon: const Icon(Icons.drag_indicator_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OmrQualitySheet extends ConsumerStatefulWidget {
  const _OmrQualitySheet({
    required this.data,
    required this.report,
    required this.onJump,
    required this.onReviewed,
    required this.onCorrect,
    required this.onReview,
  });

  final DigitalScoreData data;
  final OmrQualityReport report;
  final void Function(int index) onJump;
  final Future<void> Function(OmrQualityReport updated) onReviewed;
  final VoidCallback onCorrect;

  /// Opens the suspect measures of the server conversion, one at a time.
  final VoidCallback onReview;

  @override
  ConsumerState<_OmrQualitySheet> createState() => _OmrQualitySheetState();
}

class _OmrQualitySheetState extends ConsumerState<_OmrQualitySheet> {
  late OmrQualityReport _report = widget.report;
  final _keyController = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _runAi() async {
    final xml = widget.data.sourceXml;
    if (xml == null) {
      setState(() => _error = '원본 MusicXML이 없습니다.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(omrAiReviewerProvider)
          .review(
            songId: widget.data.song.id,
            score: widget.data.score,
            musicXml: xml,
            report: _report,
          );
      await widget.onReviewed(updated);
      if (mounted) setState(() => _report = updated);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final match = _report.sourceMatch;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            l10n.omrHealthScore(_report.score),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (match != null) ...[
            const SizedBox(height: 8),
            Text(
              match.hasReference
                  ? [
                      if (match.chordRecall != null)
                        '코드 ${match.chordHitCount}/${match.chordRefCount} (${match.chordRecall}%)',
                      if (match.lyricRecall != null)
                        '가사 ${match.lyricHitCount}/${match.lyricRefCount} (${match.lyricRecall}%)',
                      if (match.combined != null) '원본 대조 ${match.combined}%',
                    ].join(' · ')
                  : '원본 PDF에 대조할 텍스트가 없습니다.',
            ),
          ],
          const SizedBox(height: 12),
          if (widget.data.omrJobId != null) ...[
            FilledButton.icon(
              onPressed: _busy ? null : widget.onReview,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('의심 마디 검토'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : widget.onCorrect,
            icon: const Icon(Icons.compare_outlined),
            label: const Text('원본 마디 대조·수정'),
          ),
          // Reviewing with a key of one's own is a developer's tool: the
          // server reviews every conversion, and a user has no such key.
          if (kDebugMode) ...[
            TextField(
              controller: _keyController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'XAI_API_KEY',
                hintText: l10n.omrAiNeedKey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await ref
                              .read(omrAiReviewerProvider)
                              .saveKey(_keyController.text);
                        },
                  child: Text(l10n.omrAiSaveKey),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _runAi,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.omrAiRun),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          if (_report.issues.isEmpty)
            Text(l10n.omrReviewEmpty)
          else
            for (final entry in _report.groupedByRule.entries)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                leading: Icon(switch (entry.value.first.severity) {
                  OmrIssueSeverity.high => Icons.error_outline,
                  OmrIssueSeverity.medium => Icons.warning_amber_outlined,
                  OmrIssueSeverity.low => Icons.info_outline,
                }),
                title: Text(omrRuleHeadline(entry.key)),
                subtitle: Text('${entry.key} · ${entry.value.length}곳'),
                children: [
                  for (final issue in entry.value)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(issue.message),
                      subtitle: Text(
                        [
                          if (issue.measureNumber != null)
                            '마디 ${issue.measureNumber}',
                          if (issue.ai != null)
                            issue.ai!.corrections.isEmpty
                                ? 'AI: 수정 없음 (${issue.ai!.overallConfidence.toStringAsFixed(2)})'
                                : 'AI: ${issue.ai!.corrections.map((c) => '${c.property} ${c.currentValue}→${c.suggestedValue}').join(', ')}',
                        ].join(' · '),
                      ),
                      onTap: issue.measureNumber == null
                          ? null
                          : () {
                              final index = widget
                                  .data
                                  .score
                                  .parts
                                  .first
                                  .measures
                                  .indexWhere(
                                    (measure) =>
                                        measure.number == issue.measureNumber,
                                  );
                              if (index >= 0) widget.onJump(index);
                              Navigator.pop(context);
                            },
                    ),
                ],
              ),
        ],
      ),
    );
  }
}

enum _LeaveAction { discard, save }

enum _ScoreMenuAction {
  playbackOrder,
  review,
  fetchAi,
  deleteVersion,
  renameVersion,
  songInfo,
  transpose,
  threeStaff,
  exportMusicXml,
  exportMidi,
  exportPdf,
  exportProject,
  guide,
}

class _SectionNameDialog extends StatefulWidget {
  const _SectionNameDialog();

  @override
  State<_SectionNameDialog> createState() => _SectionNameDialogState();
}

class _SectionNameDialogState extends State<_SectionNameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sectionNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxSectionNameLength,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
