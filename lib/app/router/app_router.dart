import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/router/app_transitions.dart';
import 'package:page_a_diddle/app/widgets/app_shell.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_entry_screen.dart';
import 'package:page_a_diddle/features/home/presentation/home_screen.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_hub_screen.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_session_screen.dart';
import 'package:page_a_diddle/features/library/presentation/library_screen.dart';
import 'package:page_a_diddle/features/onboarding/data/onboarding_controller.dart';
import 'package:page_a_diddle/features/onboarding/presentation/boot_screen.dart';
import 'package:page_a_diddle/features/onboarding/presentation/onboarding_screen.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_detail_screen.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlists_screen.dart';
import 'package:page_a_diddle/features/settings/presentation/legal_document_screen.dart';
import 'package:page_a_diddle/features/settings/presentation/settings_screen.dart';
import 'package:page_a_diddle/features/storage/presentation/webdav_browser_screen.dart';
import 'package:page_a_diddle/features/storage/presentation/webdav_screen.dart';
import 'package:page_a_diddle/features/tools/presentation/metronome_screen.dart';
import 'package:page_a_diddle/features/tools/presentation/tap_tempo_screen.dart';
import 'package:page_a_diddle/features/tools/presentation/tempo_trainer_screen.dart';
import 'package:page_a_diddle/features/tools/presentation/tools_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = OnboardingRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/boot',
    refreshListenable: refresh,
    redirect: (context, state) {
      final done = ref.read(onboardingCompletedProvider);
      final loc = state.matchedLocation;
      if (done == null) {
        return loc == '/boot' ? null : '/boot';
      }
      if (!done) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      if (loc == '/boot' || loc == '/onboarding') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/boot',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => fadePage(
          key: state.pageKey,
          duration: const Duration(milliseconds: 200),
          child: const BootScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => fadePage(
          key: state.pageKey,
          duration: const Duration(milliseconds: 360),
          child: const OnboardingScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) =>
                    fadePage(key: state.pageKey, child: const HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) =>
                    fadePage(key: state.pageKey, child: const LibraryScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/setlists',
                pageBuilder: (context, state) =>
                    fadePage(key: state.pageKey, child: const SetlistsScreen()),
                routes: [
                  GoRoute(
                    path: ':setlistId',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => sharedAxisPage(
                      key: state.pageKey,
                      child: SetlistDetailScreen(
                        setlistId: state.pathParameters['setlistId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tools',
                pageBuilder: (context, state) =>
                    fadePage(key: state.pageKey, child: const ToolsScreen()),
                routes: [
                  GoRoute(
                    path: 'tap-tempo',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => sharedAxisPage(
                      key: state.pageKey,
                      child: const TapTempoScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'metronome',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final bpm = int.tryParse(
                        state.uri.queryParameters['bpm'] ?? '',
                      );
                      return sharedAxisPage(
                        key: state.pageKey,
                        child: MetronomeScreen(initialBpm: bpm),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'tempo-trainer',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final launch = state.extra;
                      return sharedAxisPage(
                        key: state.pageKey,
                        child: TempoTrainerScreen(
                          launch: launch is TempoTrainerLaunch ? launch : null,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'webdav',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => sharedAxisPage(
                      key: state.pageKey,
                      child: const WebDavScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'files',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final extra = state.extra;
                          final args = extra is WebDavBrowseArgs
                              ? extra
                              : const WebDavBrowseArgs();
                          return sharedAxisPage(
                            key: state.pageKey,
                            child: WebDavBrowserScreen(
                              selectOnly: args.selectOnly,
                              fileFilter: args.fileFilter,
                              importFolderId: args.importFolderId,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/jam',
                pageBuilder: (context, state) => fadePage(
                  key: state.pageKey,
                  child: JamHubScreen(
                    setlistId: state.uri.queryParameters['setlistId'],
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 's/:sessionId',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => fadePage(
                      key: state.pageKey,
                      child: JamSessionScreen(
                        sessionId: state.pathParameters['sessionId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) =>
            sharedAxisPage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/legal/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: LegalDocumentScreen(
            title: context.l10n.privacyPolicy,
            body: context.l10n.privacyBody,
          ),
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: LegalDocumentScreen(
            title: context.l10n.termsOfUse,
            body: context.l10n.termsBody,
          ),
        ),
      ),
      GoRoute(
        path: '/score/:songId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => fadePage(
          // `state.pageKey` is based on the route pattern (`/score/:songId`),
          // so every song would reuse the same PDF viewer State. Key the page
          // by its resolved location so setlist replacement reloads the score.
          key: ValueKey<String>(state.uri.toString()),
          duration: const Duration(milliseconds: 340),
          child: ScoreEntryScreen(
            songId: state.pathParameters['songId']!,
            setlistId: state.uri.queryParameters['setlistId'],
            startJam: state.uri.queryParameters['startJam'] == 'true',
            stageMode: state.uri.queryParameters['stage'] == 'true',
          ),
        ),
      ),
      GoRoute(
        path: '/jam/:sessionId',
        parentNavigatorKey: _rootNavigatorKey,
        redirect: (context, state) {
          final sessionId = state.pathParameters['sessionId'];
          if (sessionId == null) return '/jam';
          return '/jam/s/$sessionId';
        },
      ),
    ],
  );
});
