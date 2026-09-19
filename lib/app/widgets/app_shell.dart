import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/icons/app_icons.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_brand_mark.dart';
import 'package:page_a_diddle/app/widgets/app_layout.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  List<NavigationDestination> _destinations(AppLocalizations l10n) => [
    NavigationDestination(
      icon: const Icon(AppIcons.home),
      selectedIcon: const Icon(AppIcons.homeSelected),
      label: l10n.tabHome,
    ),
    NavigationDestination(
      icon: const Icon(AppIcons.library),
      selectedIcon: const Icon(AppIcons.librarySelected),
      label: l10n.tabLibrary,
    ),
    NavigationDestination(
      icon: const Icon(AppIcons.setlists),
      selectedIcon: const Icon(AppIcons.setlistsSelected),
      label: l10n.tabSetlists,
    ),
    NavigationDestination(
      icon: const Icon(AppIcons.tools),
      selectedIcon: const Icon(AppIcons.toolsSelected),
      label: l10n.tabTools,
    ),
    NavigationDestination(
      icon: const Icon(AppIcons.jam),
      selectedIcon: const Icon(AppIcons.jamSelected),
      label: l10n.tabJam,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = _destinations(l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= appWideLayoutBreakpoint;
        final colors = Theme.of(context).colorScheme;

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
                    overlayColor: WidgetStatePropertyAll(
                      AppColors.accent.withValues(alpha: 0.08),
                    ),
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
                    child: AppBrandMark(),
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
