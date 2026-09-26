import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/widgets/app_empty_state.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/digital_score/data/digital_score_data.dart';
import 'package:page_a_diddle/features/digital_score/presentation/digital_score_screen.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/score_type.dart';
import 'package:page_a_diddle/features/piano/presentation/lomse_piano_editor_screen.dart';
import 'package:page_a_diddle/features/score_viewer/presentation/score_viewer_screen.dart';

class ScoreEntryScreen extends ConsumerWidget {
  const ScoreEntryScreen({
    required this.songId,
    this.setlistId,
    this.startJam = false,
    this.stageMode = false,
    this.useLomse = false,
    super.key,
  });

  final String songId;
  final String? setlistId;
  final bool startJam;
  final bool stageMode;
  final bool useLomse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(_scoreEntrySongProvider(songId));
    return song.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => _ScoreEntryError(
        onRetry: () => ref.invalidate(_scoreEntrySongProvider(songId)),
      ),
      data: (value) {
        if (value == null) {
          return _ScoreEntryError(
            onRetry: () => ref.invalidate(_scoreEntrySongProvider(songId)),
          );
        }
        if (ScoreType.fromKey(value.scoreType) == ScoreType.musicXml) {
          if (useLomse) {
            final data = ref.watch(digitalScoreDataProvider(songId));
            return data.when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => _ScoreEntryError(
                onRetry: () => ref.invalidate(digitalScoreDataProvider(songId)),
              ),
              data: (scoreData) => LomsePianoEditorScreen(
                songId: songId,
                initialData: scoreData,
              ),
            );
          }
          return DigitalScoreScreen(songId: songId);
        }
        return ScoreViewerScreen(
          songId: songId,
          setlistId: setlistId,
          startJam: startJam,
          stageMode: stageMode,
        );
      },
    );
  }
}

class _ScoreEntryError extends StatelessWidget {
  const _ScoreEntryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: context.l10n.loadFailed,
        body: context.l10n.retryAction,
        actionLabel: context.l10n.retryAction,
        onAction: onRetry,
      ),
    );
  }
}

final _scoreEntrySongProvider = FutureProvider.autoDispose
    .family<Song?, String>((ref, songId) {
      return ref.watch(songRepositoryProvider).getSong(songId);
    });
