import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/router/app_transitions.dart';
import 'package:page_a_diddle/app/widgets/piano_app_shell.dart';
import 'package:page_a_diddle/features/digital_score/presentation/score_entry_screen.dart';
import 'package:page_a_diddle/features/library/presentation/library_screen.dart';
import 'package:page_a_diddle/features/settings/presentation/legal_document_screen.dart';
import 'package:page_a_diddle/features/settings/presentation/settings_screen.dart';
import 'package:page_a_diddle/features/storage/presentation/webdav_browser_screen.dart';
import 'package:page_a_diddle/features/storage/presentation/webdav_screen.dart';

final _pianoRootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'piano-root',
);

/// Router for the piano application flavor.
///
/// This is intentionally a separate router rather than a product flag inside
/// the drum router. That keeps the piano app from accidentally inheriting
/// tap-tempo, tempo-trainer, setlist, or Jam destinations.
final pianoRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _pianoRootNavigatorKey,
    initialLocation: '/library',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/library'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PianoAppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) =>
                    fadePage(key: state.pageKey, child: const LibraryScreen()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/score/:songId',
        parentNavigatorKey: _pianoRootNavigatorKey,
        pageBuilder: (context, state) => fadePage(
          key: ValueKey<String>(state.uri.toString()),
          duration: const Duration(milliseconds: 340),
          child: ScoreEntryScreen(songId: state.pathParameters['songId']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _pianoRootNavigatorKey,
        pageBuilder: (context, state) =>
            sharedAxisPage(key: state.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/legal/privacy',
        parentNavigatorKey: _pianoRootNavigatorKey,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: LegalDocumentScreen(
            title: context.l10n.privacyPolicy,
            body: context.l10n.privacyBodyPiano,
          ),
        ),
      ),
      GoRoute(
        path: '/legal/terms',
        parentNavigatorKey: _pianoRootNavigatorKey,
        pageBuilder: (context, state) => sharedAxisPage(
          key: state.pageKey,
          child: LegalDocumentScreen(
            title: context.l10n.termsOfUse,
            body: context.l10n.termsBodyPiano,
          ),
        ),
      ),
      GoRoute(
        path: '/tools/webdav',
        parentNavigatorKey: _pianoRootNavigatorKey,
        pageBuilder: (context, state) =>
            sharedAxisPage(key: state.pageKey, child: const WebDavScreen()),
        routes: [
          GoRoute(
            path: 'files',
            parentNavigatorKey: _pianoRootNavigatorKey,
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
  );
});
