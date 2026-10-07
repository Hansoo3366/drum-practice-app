import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/widgets/sheet_insets.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One button of the score screen, as the guide explains it.
typedef ScoreGuideEntry = ({IconData icon, String title, String body});

/// What the buttons above a score do, in the order they stand. [converted]
/// scores also have the review of what the conversion was unsure of.
List<ScoreGuideEntry> scoreGuideEntries(
  AppLocalizations l10n, {
  required bool converted,
}) => [
  (
    icon: Icons.layers_outlined,
    title: l10n.scoreGuideVersionTitle,
    body: l10n.scoreGuideVersionBody,
  ),
  (
    icon: Icons.playlist_play_rounded,
    title: l10n.playbackSequence,
    body: l10n.scoreGuideOrderBody,
  ),
  if (converted)
    (
      icon: Icons.fact_check_outlined,
      title: l10n.omrReview,
      body: l10n.scoreGuideReviewBody,
    ),
  (
    icon: Icons.edit_outlined,
    title: l10n.proofread,
    body: l10n.scoreGuideProofreadBody,
  ),
  (
    icon: Icons.play_circle_outline_rounded,
    title: l10n.play,
    body: l10n.scoreGuidePlayBody,
  ),
  (
    icon: Icons.more_vert_rounded,
    title: l10n.scoreTools,
    body: l10n.scoreGuideToolsBody,
  ),
];

/// Shows the guide to the score screen's buttons.
Future<void> showScoreGuideSheet(
  BuildContext context, {
  required bool converted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ScoreGuideSheet(converted: converted),
  );
}

class ScoreGuideSheet extends StatelessWidget {
  const ScoreGuideSheet({required this.converted, super.key});

  final bool converted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ConstrainedBox(
      // Never the whole screen: the score stays visible behind it.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: sheetContentPadding(context, top: 0, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.scoreGuideTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l10n.scoreGuideIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in scoreGuideEntries(l10n, converted: converted))
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(entry.icon),
                title: Text(entry.title),
                subtitle: Text(entry.body),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.scoreGuideDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether the guide has been shown on this device.
abstract interface class ScoreGuideStore {
  Future<bool> seen();
  Future<void> markSeen();
}

class _PrefsScoreGuideStore implements ScoreGuideStore {
  const _PrefsScoreGuideStore();

  static const _key = 'score_guide_seen';

  @override
  Future<bool> seen() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(_key, true);
}

final scoreGuideStoreProvider = Provider<ScoreGuideStore>(
  (_) => const _PrefsScoreGuideStore(),
);

/// Whether the score of a song came from converting a picture; known once the
/// score has loaded.
final scoreConvertedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, songId) async =>
      (await ref.watch(digitalScoreDataProvider(songId).future)).omrJobId !=
      null,
);

/// Shows the guide once, the first time a score is on the screen: someone
/// who has just added their first score meets the buttons with their names.
/// Later it is under the tools menu.
class ScoreGuideGate extends ConsumerStatefulWidget {
  const ScoreGuideGate({required this.songId, required this.child, super.key});

  final String songId;
  final Widget child;

  @override
  ConsumerState<ScoreGuideGate> createState() => _ScoreGuideGateState();
}

class _ScoreGuideGateState extends ConsumerState<ScoreGuideGate> {
  var _asked = false;

  Future<void> _offer(bool converted) async {
    if (_asked) return;
    _asked = true;
    final store = ref.read(scoreGuideStoreProvider);
    try {
      if (await store.seen()) return;
      // Marked before it shows: a guide that could not be closed properly
      // must not come back on every score.
      await store.markSeen();
    } on Object {
      // Without storage the guide would return every time: better not at all.
      return;
    }
    if (!mounted) return;
    // After the frame that put the score on the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showScoreGuideSheet(context, converted: converted);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    // Loaded now, or when it loads: the guide waits for the score.
    final converted = ref.watch(scoreConvertedProvider(widget.songId));
    if (converted.hasValue && !_asked) {
      final value = converted.requireValue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _offer(value);
      });
    }
    return widget.child;
  }
}
