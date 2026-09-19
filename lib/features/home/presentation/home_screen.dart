import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/branding/app_branding.dart';
import 'package:page_a_diddle/app/icons/app_icons.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_brand_mark.dart';
import 'package:page_a_diddle/app/widgets/app_layout.dart';
import 'package:page_a_diddle/app/widgets/app_motion.dart';
import 'package:page_a_diddle/app/widgets/app_surfaces.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/format/relative_time.dart';
import 'package:page_a_diddle/features/library/presentation/library_controller.dart';
import 'package:page_a_diddle/features/library/presentation/score_thumbnail.dart';

/// Editorial practice hub — continue card, deck grid, recent strip.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final recent = ref.watch(recentSongsProvider);
    final showHeaderBrandMark =
        MediaQuery.sizeOf(context).width < appWideLayoutBreakpoint;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                FadeSlideIn(
                  child: Row(
                    children: [
                      if (showHeaderBrandMark) ...[
                        const AppBrandMark(size: 44),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppBranding.appName,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                height: 1.05,
                              ),
                            ),
                            Text(
                              l10n.tagline,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CompactIconButton(
                        icon: AppIcons.settings,
                        tooltip: l10n.settings,
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FadeSlideIn(
                  child: recent.when(
                    data: (songs) {
                      if (songs.isEmpty) {
                        return _OpenLibraryCard(
                          onTap: () => context.go('/library'),
                        );
                      }
                      final song = songs.first;
                      final subtitle = [
                        if (song.artist case final artist?) artist,
                        if (song.defaultTempo case final tempo?) '$tempo BPM',
                      ].join(' · ');
                      return AppContinueCard(
                        title: song.title,
                        subtitle: subtitle.isEmpty ? l10n.openScore : subtitle,
                        footnote: song.lastOpenedAt == null
                            ? null
                            : formatRelativeTime(song.lastOpenedAt!, l10n),
                        bpm: song.defaultTempo,
                        onTap: () => context.push('/score/${song.id}'),
                      );
                    },
                    // Prefer empty CTA over a long shimmer while DB warms.
                    loading: () =>
                        _OpenLibraryCard(onTap: () => context.go('/library')),
                    error: (_, _) =>
                        _OpenLibraryCard(onTap: () => context.go('/library')),
                  ),
                ),
                const SizedBox(height: 26),
                FadeSlideIn(child: AppSectionLabel(l10n.practiceDeck)),
                const SizedBox(height: 12),
                FadeSlideIn(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossCount = constraints.maxWidth >= 520 ? 3 : 2;
                      final tiles = [
                        _DeckItem(
                          icon: AppIcons.metronome,
                          title: l10n.metronome,
                          subtitle: l10n.metronomeSubtitle,
                          featured: true,
                          onTap: () => context.push('/tools/metronome'),
                        ),
                        _DeckItem(
                          icon: AppIcons.tapTempo,
                          title: l10n.tapTempo,
                          onTap: () => context.push('/tools/tap-tempo'),
                        ),
                        _DeckItem(
                          icon: AppIcons.tempoTrainer,
                          title: l10n.tempoTrainer,
                          onTap: () => context.push('/tools/tempo-trainer'),
                        ),
                        _DeckItem(
                          icon: AppIcons.setlists,
                          title: l10n.tabSetlists,
                          onTap: () => context.go('/setlists'),
                        ),
                        _DeckItem(
                          icon: AppIcons.jam,
                          title: l10n.tabJam,
                          onTap: () => context.go('/jam'),
                        ),
                        _DeckItem(
                          icon: AppIcons.library,
                          title: l10n.tabLibrary,
                          onTap: () => context.go('/library'),
                        ),
                      ];
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.22,
                        ),
                        itemCount: tiles.length,
                        itemBuilder: (context, index) => tiles[index],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                FadeSlideIn(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.recentScores,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/library'),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(l10n.seeAll),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  child: recent.when(
                    data: (songs) => songs.isEmpty
                        ? const _EmptyRecentScores()
                        : _RecentStrip(songs: songs.skip(1).take(8).toList()),
                    loading: () => const _EmptyRecentScores(),
                    error: (_, _) => const _EmptyRecentScores(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckItem extends StatelessWidget {
  const _DeckItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.featured = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return AppFeatureTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      featured: featured,
      onTap: onTap,
    );
  }
}

class _OpenLibraryCard extends StatelessWidget {
  const _OpenLibraryCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return PressableScale(
      onTap: onTap,
      enabled: onTap != null,
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const AppRhythmBackdrop(),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.openScore,
                    style: textTheme.displaySmall?.copyWith(
                      color: AppColors.canvas,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.importHintHome,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.canvas.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.tabLibrary,
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.canvas,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const _EmptyRecentScores();
    }
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final song = songs[index];
          return _RecentTile(
            song: song,
            onTap: () => context.push('/score/${song.id}'),
          );
        },
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 152,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScoreThumbnail(song: song, width: 36, height: 44),
                const Spacer(),
                Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (song.defaultTempo case final tempo?)
                  Text(
                    '$tempo BPM',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                if (song.lastOpenedAt case final opened?)
                  Text(
                    formatRelativeTime(opened, l10n),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecentScores extends StatelessWidget {
  const _EmptyRecentScores();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: colors.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Text(
            l10n.emptyRecentTitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
