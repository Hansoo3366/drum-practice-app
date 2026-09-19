import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/icons/app_icons.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/widgets/app_layout.dart';
import 'package:page_a_diddle/app/widgets/app_motion.dart';
import 'package:page_a_diddle/app/widgets/app_surfaces.dart';

/// Tool launcher with a featured metronome tile.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabTools)),
      body: AppScreen(
        maxWidth: 720,
        scrollable: false,
        child: FadeSlideIn(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth >= 600 ? 3 : 2;
              return GridView(
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.18,
                ),
                children: [
                  AppFeatureTile(
                    icon: AppIcons.metronome,
                    title: l10n.metronome,
                    subtitle: l10n.metronomeSubtitleFull,
                    featured: true,
                    onTap: () => context.push('/tools/metronome'),
                  ),
                  AppFeatureTile(
                    icon: AppIcons.tapTempo,
                    title: l10n.tapTempo,
                    subtitle: l10n.toolsTapForBpm,
                    onTap: () => context.push('/tools/tap-tempo'),
                  ),
                  AppFeatureTile(
                    icon: AppIcons.tempoTrainer,
                    title: l10n.tempoTrainer,
                    subtitle: l10n.toolsGraduallyFaster,
                    onTap: () => context.push('/tools/tempo-trainer'),
                  ),
                  AppFeatureTile(
                    icon: AppIcons.jam,
                    title: l10n.tabJam,
                    subtitle: l10n.toolsWifiSync,
                    onTap: () => context.go('/jam'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
