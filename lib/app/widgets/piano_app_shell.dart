import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_layout.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input_feature.dart';

/// Navigation shell for the piano product.
///
/// Piano deliberately has fewer destinations than the drum product: scores
/// and the MusicXML editor are the product surface. Practice-only drum tools
/// and group-performance flows stay out of this shell.
class PianoAppShell extends StatelessWidget {
  const PianoAppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  List<NavigationDestination> _destinations(BuildContext context) => [
    NavigationDestination(
      icon: const Icon(Icons.library_music_outlined),
      selectedIcon: const Icon(Icons.library_music),
      label: context.l10n.library,
    ),
    if (noteInputEnabled)
      NavigationDestination(
        icon: const Icon(Icons.edit_note_outlined),
        selectedIcon: const Icon(Icons.edit_note),
        label: context.l10n.editSong,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(context);
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= appWideLayoutBreakpoint;
        if (destinations.length <= 1) {
          return Scaffold(body: navigationShell);
        }
        if (!useRail) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: ColoredBox(
              color: colors.surface,
              child: SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.outline)),
                  ),
                  child: NavigationBar(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: _selectDestination,
                    destinations: destinations,
                    height: 68,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    indicatorColor: AppColors.accent.withValues(alpha: 0.16),
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _selectDestination,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.85,
                  leading: const Padding(
                    padding: EdgeInsets.only(bottom: 28, top: 8),
                    child: Icon(Icons.piano, size: 30),
                  ),
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: destination.icon,
                        selectedIcon: destination.selectedIcon,
                        label: Text(destination.label),
                      ),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: colors.outlineVariant),
              Expanded(child: navigationShell),
            ],
          ),
        );
      },
    );
  }
}
