import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_offline_service.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';
import 'package:page_a_diddle/features/setlists/domain/setlist_song.dart';
import 'package:page_a_diddle/features/setlists/presentation/add_setlist_songs_sheet.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_controller.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_name_dialog.dart';
import 'package:page_a_diddle/features/stage/domain/stage_setlist_progress.dart';
import 'package:page_a_diddle/features/storage/domain/sync_status.dart';

class SetlistDetailScreen extends ConsumerWidget {
  const SetlistDetailScreen({required this.setlistId, super.key});

  final String setlistId;

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final name = await showSetlistNameDialog(
      context,
      title: context.l10n.rename,
      initialName: current,
    );
    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await ref
          .read(setlistRepositoryProvider)
          .renameSetlist(id: setlistId, title: name);
    } on Object catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.changeFailed)));
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.confirmDelete),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(setlistRepositoryProvider).deleteSetlist(setlistId);
    if (context.mounted) {
      context.pop();
    }
  }

  Future<void> _downloadOffline(BuildContext context, WidgetRef ref) async {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      final result = await ref
          .read(setlistOfflineServiceProvider)
          .download(setlistId);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final failed = result.failedTitles.length;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed == 0
                ? l10n.savedSongs(result.downloaded)
                : l10n.savedSongsPartial(result.downloaded, failed),
          ),
        ),
      );
    } on Object {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.downloadFailed)));
    }
  }

  void _startStage(
    BuildContext context,
    List<SetlistSong> songs, {
    String? fromSongId,
  }) {
    final startId = firstStageSongId(
      songs.map(
        (item) => StageSetlistItem(
          songId: item.song.id,
          title: item.song.title,
          offlineAvailable: item.song.offlineAvailable,
          bpm: item.tempo,
        ),
      ),
      fromSongId: fromSongId,
    );
    if (startId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.downloadRequired)));
      return;
    }
    context.push('/score/$startId?setlistId=$setlistId&stage=true');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlist = ref.watch(setlistProvider(setlistId));
    final items = ref.watch(setlistItemsProvider(setlistId));
    final title = setlist.asData?.value?.title ?? context.l10n.setlist;
    final songs = items.asData?.value;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          CompactIconButton(
            icon: Icons.groups_outlined,
            tooltip: context.l10n.jam,
            onPressed: () => context.push('/jam?setlistId=$setlistId'),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.more,
            onSelected: (value) {
              switch (value) {
                case 'rename':
                  if (setlist.asData?.value case final current?) {
                    _rename(context, ref, current.title);
                  }
                case 'download':
                  _downloadOffline(context, ref);
                case 'delete':
                  _delete(context, ref);
              }
            },
            itemBuilder: (menuContext) {
              final l10n = menuContext.l10n;
              return [
                PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                PopupMenuItem(value: 'download', child: Text(l10n.saveOffline)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ];
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            showAddSetlistSongsSheet(context, setlistId: setlistId),
        tooltip: context.l10n.addSongs,
        child: const Icon(Icons.add_rounded),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              if (songs != null && songs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _startStage(context, songs),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.canvas,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            color: AppColors.accent,
                          ),
                          label: Text(context.l10n.startStage),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.songCount(songs.length),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: items.when(
                  data: (songItems) => songItems.isEmpty
                      ? _EmptySetlistSongs(
                          onAdd: () => showAddSetlistSongsSheet(
                            context,
                            setlistId: setlistId,
                          ),
                        )
                      : _SetlistSongList(
                          setlistId: setlistId,
                          items: songItems,
                          onStartStage: (songId) => _startStage(
                            context,
                            songItems,
                            fromSongId: songId,
                          ),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      Center(child: Text(context.l10n.fetchFailed)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetlistSongList extends ConsumerWidget {
  const _SetlistSongList({
    required this.setlistId,
    required this.items,
    required this.onStartStage,
  });

  final String setlistId;
  final List<SetlistSong> items;
  final ValueChanged<String> onStartStage;

  String _subtitle(SetlistSong item, AppLocalizations l10n) {
    return [
      if (item.song.artist case final artist?) artist,
      if (item.tempo case final tempo?) '$tempo BPM',
      if (!item.song.offlineAvailable) l10n.offlineMissing,
      if (SyncStatus.fromKey(item.song.syncStatus) case final status?)
        status.label(l10n),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: items.length,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 6,
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        final ordered = [...items];
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final moved = ordered.removeAt(oldIndex);
        ordered.insert(newIndex, moved);
        unawaited(
          ref
              .read(setlistRepositoryProvider)
              .reorderSongs(
                setlistId: setlistId,
                entryIds: ordered.map((item) => item.entry.id).toList(),
              ),
        );
      },
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          key: ValueKey(item.entry.id),
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              if (!item.song.offlineAvailable) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(context.l10n.downloadRequired)));
                return;
              }
              context.push('/score/${item.song.id}?setlistId=$setlistId');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (_subtitle(item, context.l10n) case final sub
                            when sub.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  CompactIconButton(
                    icon: Icons.fullscreen_rounded,
                    tooltip: context.l10n.stage,
                    onPressed: () => onStartStage(item.song.id),
                  ),
                  CompactIconButton(
                    icon: Icons.remove_circle_outline_rounded,
                    tooltip: context.l10n.remove,
                    onPressed: () => unawaited(
                      ref
                          .read(setlistRepositoryProvider)
                          .removeSong(item.entry.id),
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptySetlistSongs extends StatelessWidget {
  const _EmptySetlistSongs({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.playlist_add_rounded,
                size: 32,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Text(context.l10n.noSongs, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              context.l10n.setlistPromptBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.addSongs),
            ),
          ],
        ),
      ),
    );
  }
}
