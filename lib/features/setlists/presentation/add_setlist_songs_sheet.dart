import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/library/data/folder_repository.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/folder_colors.dart';
import 'package:page_a_diddle/features/library/presentation/library_folder_bar.dart';
import 'package:page_a_diddle/features/library/presentation/score_thumbnail.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_controller.dart';

Future<void> showAddSetlistSongsSheet(
  BuildContext context, {
  required String setlistId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _AddSetlistSongsSheet(setlistId: setlistId),
  );
}

class _AddSetlistSongsSheet extends ConsumerStatefulWidget {
  const _AddSetlistSongsSheet({required this.setlistId});

  final String setlistId;

  @override
  ConsumerState<_AddSetlistSongsSheet> createState() =>
      _AddSetlistSongsSheetState();
}

class _AddSetlistSongsSheetState extends ConsumerState<_AddSetlistSongsSheet> {
  var _query = '';
  String? _folderId;
  String? _labelName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final songsAsync = ref.watch(
      _pickerSongsProvider((
        query: _query,
        folderId: _folderId,
        labelName: _labelName,
      )),
    );
    final setlistItems =
        ref.watch(setlistItemsProvider(widget.setlistId)).asData?.value ??
        const [];
    final alreadyIds = {for (final item in setlistItems) item.song.id};
    final folders = ref.watch(libraryFoldersProvider).asData?.value ?? const [];
    final folderById = {for (final folder in folders) folder.id: folder};

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              l10n.addSongs,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchBar(
              hintText: l10n.searchHint,
              leading: Icon(
                Icons.search_rounded,
                color: colors.onSurfaceVariant,
              ),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 10),
          LibraryFolderSelector(
            selectedFolderId: _folderId,
            onFolderChanged: (id) => setState(() => _folderId = id),
          ),
          if (_labelName != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('#$_labelName'),
                  onDeleted: () => setState(() => _labelName = null),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: songsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(child: Text(l10n.noSongs));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final song = items[index];
                    final folder = song.folderId == null
                        ? null
                        : folderById[song.folderId];
                    final already = alreadyIds.contains(song.id);
                    final labelsAsync = ref.watch(songLabelsProvider(song.id));
                    final subtitle = [
                      if (folder?.name case final name?) name,
                      if (song.artist case final artist?) artist,
                      if (song.defaultTempo case final tempo?) '$tempo BPM',
                    ].join(' · ');

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: already
                          ? null
                          : () => _addSong(context, song),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                ScoreThumbnail(song: song),
                                if (folder != null)
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 3,
                                      decoration: BoxDecoration(
                                        color: FolderColors.toColor(
                                          folder.color,
                                        ),
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                          left: Radius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                  labelsAsync.when(
                                    data: (labels) {
                                      if (labels.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            for (final label
                                                in labels.take(4))
                                              GestureDetector(
                                                onTap: () => setState(
                                                  () =>
                                                      _labelName = label.name,
                                                ),
                                                child: Text(
                                                  '#${label.name}',
                                                  style: TextStyle(
                                                    color: AppColors.accent
                                                        .withValues(
                                                      alpha: 0.95,
                                                    ),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, _) => const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                            CompactIconButton(
                              icon: already
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              tooltip: already
                                  ? l10n.songAdded(song.title)
                                  : l10n.addSongs,
                              selected: already,
                              onPressed: already
                                  ? null
                                  : () => _addSong(context, song),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(l10n.fetchFailed)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSong(BuildContext context, Song song) async {
    final l10n = context.l10n;
    await ref.read(setlistRepositoryProvider).addSong(
      setlistId: widget.setlistId,
      songId: song.id,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.songAdded(song.title))),
    );
  }
}

typedef _PickerQuery = ({String query, String? folderId, String? labelName});

final _pickerSongsProvider =
    StreamProvider.family<List<Song>, _PickerQuery>((ref, params) {
      return ref.watch(songRepositoryProvider).watchSongs(
        query: params.query,
        folderId: params.folderId,
        labelName: params.labelName,
      );
    });
