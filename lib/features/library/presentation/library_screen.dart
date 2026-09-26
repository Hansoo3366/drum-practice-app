import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/product.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/app_empty_state.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/app/widgets/sheet_insets.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/format/relative_time.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_import_service.dart';
import 'package:page_a_diddle/features/digital_score/data/music_xml_picker.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_client.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_convert_jobs.dart';
import 'package:page_a_diddle/features/digital_score/data/omr_source_picker.dart';
import 'package:page_a_diddle/features/digital_score/domain/note_input_feature.dart';
import 'package:page_a_diddle/features/library/data/folder_repository.dart';
import 'package:page_a_diddle/features/library/data/label_repository.dart';
import 'package:page_a_diddle/features/library/data/pdf_picker.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/domain/folder_colors.dart';
import 'package:page_a_diddle/features/library/domain/library_filter.dart';
import 'package:page_a_diddle/features/library/domain/score_file_filter.dart';
import 'package:page_a_diddle/features/library/presentation/create_music_xml_sheet.dart';
import 'package:page_a_diddle/features/library/presentation/edit_song_sheet.dart';
import 'package:page_a_diddle/features/library/presentation/import_score_sheet.dart';
import 'package:page_a_diddle/features/library/presentation/import_source_sheet.dart';
import 'package:page_a_diddle/features/library/presentation/library_controller.dart';
import 'package:page_a_diddle/features/library/presentation/library_folder_bar.dart';
import 'package:page_a_diddle/features/library/presentation/score_thumbnail.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_storage.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';
import 'package:page_a_diddle/features/storage/cloud/presentation/cloud_browser_screen.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';
import 'package:page_a_diddle/features/storage/presentation/webdav_browser_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  String? _currentImportFolderId(WidgetRef ref) {
    final key = ref.read(libraryFolderFilterProvider);
    if (key == null || key == unfiledFolderFilterKey) {
      return null;
    }
    return key;
  }

  Future<void> _importScore(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_LibraryAddAction>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: sheetContentPadding(context, top: 16, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (noteInputEnabled)
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: Text(context.l10n.createScore),
                onTap: () => Navigator.pop(context, _LibraryAddAction.create),
              ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(context.l10n.importPdf),
              onTap: () => Navigator.pop(context, _LibraryAddAction.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.music_note_rounded),
              title: Text(context.l10n.importMusicXml),
              onTap: () =>
                  Navigator.pop(context, _LibraryAddAction.importMusicXml),
            ),
            if (isPianoProduct)
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: Text(context.l10n.convertToDigitalScore),
                onTap: () => Navigator.pop(context, _LibraryAddAction.convert),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _LibraryAddAction.create:
        await _createMusicXml(context, ref);
      case _LibraryAddAction.pdf:
        await _importFromSource(context, ref, ScoreImportKind.pdf);
      case _LibraryAddAction.importMusicXml:
        await _importFromSource(context, ref, ScoreImportKind.musicXml);
      case _LibraryAddAction.convert:
        await _convertToDigitalScore(context, ref);
    }
  }

  Future<void> _convertToDigitalScore(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final file = await ref.read(omrSourcePickerProvider).pick();
    if (file == null || !context.mounted) return;
    final profile = await showModalBottomSheet<OmrRecognitionProfile>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: sheetContentPadding(sheetContext, top: 16, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.piano_rounded),
              title: Text(sheetContext.l10n.omrProfileStandard),
              onTap: () =>
                  Navigator.pop(sheetContext, OmrRecognitionProfile.standard),
            ),
            ListTile(
              leading: const Icon(Icons.lyrics_rounded),
              title: Text(sheetContext.l10n.omrProfileChordsLyrics),
              onTap: () => Navigator.pop(
                sheetContext,
                OmrRecognitionProfile.chordsLyrics,
              ),
            ),
          ],
        ),
      ),
    );
    if (profile == null || !context.mounted) return;
    await ref
        .read(omrConvertJobsProvider.notifier)
        .enqueue(file, folderId: _currentImportFolderId(ref), profile: profile);
  }

  Future<void> _createMusicXml(BuildContext context, WidgetRef ref) async {
    final songId = await showCreateMusicXmlSheet(
      context,
      folderId: _currentImportFolderId(ref),
    );
    if (songId == null || !context.mounted) return;
    await context.push('/score/$songId');
  }

  Future<void> _importFromSource(
    BuildContext context,
    WidgetRef ref,
    ScoreImportKind kind,
  ) async {
    final l10n = context.l10n;
    final source = await showImportSourceSheet(context);
    if (source == null || !context.mounted) return;
    final fileFilter = switch (kind) {
      ScoreImportKind.pdf => ScoreFileFilter.pdf,
      ScoreImportKind.musicXml => ScoreFileFilter.musicXml,
    };

    if (source == ImportSource.webDav) {
      final credentials = await ref.read(webDavSettingsStoreProvider).read();
      if (!context.mounted) return;
      if (credentials == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.webdavNeeded)));
        await context.push('/tools/webdav');
        return;
      }
      await context.push(
        '/tools/webdav/files',
        extra: WebDavBrowseArgs(
          fileFilter: fileFilter,
          importFolderId: _currentImportFolderId(ref),
        ),
      );
      return;
    }

    var sourceProvider = source.storageProvider;
    if (source.usesCloudOAuth) {
      final cloudKind = switch (source) {
        ImportSource.googleDrive => CloudKind.googleDrive,
        ImportSource.dropbox => CloudKind.dropbox,
        ImportSource.device || ImportSource.webDav => CloudKind.googleDrive,
      };
      if (ref.read(cloudStorageProvider).canAttempt(cloudKind)) {
        await openCloudBrowser(
          context,
          ref,
          kind: cloudKind,
          importFolderId: _currentImportFolderId(ref),
          fileFilter: fileFilter,
        );
        return;
      }
      // OAuth is optional; let Android's DocumentsUI expose an installed
      // Drive/Dropbox provider instead of leaving the source action dead.
      sourceProvider = StorageProvider.osFileProvider;
    }

    try {
      if (kind == ScoreImportKind.musicXml) {
        final file = await ref.read(musicXmlPickerProvider).pick();
        if (file == null || !context.mounted) return;
        final score = await ref
            .read(musicXmlImportServiceProvider)
            .inspect(file);
        if (!context.mounted) return;
        final tempo = score.tempoBpm?.round();
        final imported = await showImportScoreSheet(
          context,
          file: file,
          sourceProvider: sourceProvider,
          folderId: _currentImportFolderId(ref),
          kind: ScoreImportKind.musicXml,
          initialTitle: score.title,
          initialArtist: score.composer,
          initialTempo: tempo != null && tempo >= 40 && tempo <= 240
              ? tempo
              : null,
        );
        if (imported != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.songAdded(file.name))));
        }
        return;
      }

      final file = await ref.read(pdfPickerProvider).pick();
      if (file == null || !context.mounted) {
        return;
      }

      final imported = await showImportScoreSheet(
        context,
        file: file,
        sourceProvider: sourceProvider,
        folderId: _currentImportFolderId(ref),
      );
      if (imported != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.songAdded(file.name))));
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kind == ScoreImportKind.musicXml
                  ? l10n.importFailed
                  : l10n.pickFailed,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final songs = ref.watch(librarySongsProvider);
    final convertJobs = ref.watch(omrConvertJobsProvider);
    final selectedFilter = ref.watch(libraryFilterProvider);
    final labelFilter = ref.watch(libraryLabelFilterProvider);
    final selection = ref.watch(librarySelectionProvider);
    final colors = Theme.of(context).colorScheme;

    ref.listen(libraryFolderFilterProvider, (_, _) {
      ref.read(librarySelectionProvider.notifier).clear();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selection.isEmpty
              ? l10n.library
              : l10n.selectedCount(selection.length),
        ),
        leading: selection.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () =>
                    ref.read(librarySelectionProvider.notifier).clear(),
              ),
        actions: [
          if (selection.isEmpty)
            CompactIconButton(
              icon: Icons.add_rounded,
              tooltip: l10n.import,
              onPressed: () => _importScore(context, ref),
            )
          else ...[
            if (selection.length == 1)
              CompactIconButton(
                icon: Icons.edit_rounded,
                tooltip: l10n.editSong,
                onPressed: () => _editSelected(context, ref, songs),
              ),
            CompactIconButton(
              icon: Icons.drive_file_move_outlined,
              tooltip: l10n.move,
              onPressed: () => _moveSelected(context, ref),
            ),
            CompactIconButton(
              icon: Icons.copy_outlined,
              tooltip: l10n.copy,
              onPressed: () => _copySelected(context, ref),
            ),
            CompactIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: l10n.delete,
              onPressed: () => _deleteSelected(context, ref),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          const _ConvertResume(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final mainColumn = Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: SearchBar(
                          hintText: l10n.searchHint,
                          leading: Icon(
                            Icons.search_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                          elevation: const WidgetStatePropertyAll(0),
                          backgroundColor: WidgetStatePropertyAll(
                            colors.surfaceContainer,
                          ),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onChanged: ref
                              .read(libraryQueryProvider.notifier)
                              .update,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!wide) ...[
                        const LibraryFolderSelector(),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: LibraryFilter.values.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final filter = LibraryFilter.values[index];
                            final selected = filter == selectedFilter;
                            return FilterChip(
                              label: Text(filter.label(l10n)),
                              selected: selected,
                              showCheckmark: false,
                              onSelected: (_) => ref
                                  .read(libraryFilterProvider.notifier)
                                  .update(filter),
                              selectedColor: AppColors.accent.withValues(
                                alpha: 0.16,
                              ),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selected
                                    ? AppColors.ink
                                    : colors.onSurfaceVariant,
                              ),
                              side: BorderSide(
                                color: selected
                                    ? AppColors.accent
                                    : colors.outline,
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          },
                        ),
                      ),
                      if (labelFilter != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InputChip(
                              label: Text('#$labelFilter'),
                              onDeleted: () => ref
                                  .read(libraryLabelFilterProvider.notifier)
                                  .update(null),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      songs.when(
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  4,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    l10n.libraryCountFilter(
                                      items.length,
                                      selectedFilter.label(l10n),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: songs.when(
                          data: (items) => items.isEmpty && convertJobs.isEmpty
                              ? _EmptyLibrary(
                                  onImport: () => _importScore(context, ref),
                                )
                              : _SongList(items: items),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) => const _LibraryError(),
                        ),
                      ),
                    ],
                  );

                  if (!wide) {
                    return mainColumn;
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 236, child: LibraryFolderSidebar()),
                      Expanded(child: mainColumn),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSelected(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Song>> songs,
  ) async {
    final id = ref.read(librarySelectionProvider).singleOrNull;
    if (id == null) return;
    final fromList = songs.asData?.value.where((song) => song.id == id);
    final resolved = fromList != null && fromList.isNotEmpty
        ? fromList.first
        : await ref.read(songRepositoryProvider).getSong(id);
    if (resolved == null || !context.mounted) return;
    await showEditSongSheet(context, song: resolved);
    ref.read(librarySelectionProvider.notifier).clear();
  }

  Future<void> _moveSelected(BuildContext context, WidgetRef ref) async {
    final ids = ref.read(librarySelectionProvider);
    if (ids.isEmpty) return;
    final pick = await showLibraryFolderPicker(
      context,
      title: context.l10n.moveToFolder,
    );
    if (pick == null) return;
    await ref
        .read(songRepositoryProvider)
        .setFolders(ids: ids, folderId: pick.folderId);
    ref.read(librarySelectionProvider.notifier).clear();
  }

  Future<void> _copySelected(BuildContext context, WidgetRef ref) async {
    final ids = ref.read(librarySelectionProvider);
    if (ids.isEmpty) return;
    final pick = await showLibraryFolderPicker(
      context,
      title: context.l10n.copyToFolder,
    );
    if (pick == null) return;
    await ref
        .read(songRepositoryProvider)
        .duplicateSongs(
          ids: ids,
          folderId: pick.folderId,
          clearFolder: pick.folderId == null,
        );
    ref.read(librarySelectionProvider.notifier).clear();
  }

  Future<void> _deleteSelected(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ids = ref.read(librarySelectionProvider);
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteSelectedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(songRepositoryProvider).deleteSongs(ids);
    ref.read(librarySelectionProvider.notifier).clear();
  }
}

class _SongList extends ConsumerWidget {
  const _SongList({required this.items});

  final List<Song> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(libraryFoldersProvider).asData?.value ?? const [];
    final folderById = {for (final folder in folders) folder.id: folder};
    final selection = ref.watch(librarySelectionProvider);
    final selecting = selection.isNotEmpty;

    final jobs = ref.watch(omrConvertJobsProvider);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
      itemCount: jobs.length + items.length,
      itemBuilder: (context, index) {
        if (index < jobs.length) {
          return _ConvertJobTile(job: jobs[index]);
        }
        final song = items[index - jobs.length];
        final colors = Theme.of(context).colorScheme;
        final folder = song.folderId == null ? null : folderById[song.folderId];
        final labelsAsync = ref.watch(songLabelsProvider(song.id));
        final checked = selection.contains(song.id);

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (selecting) {
              ref.read(librarySelectionProvider.notifier).toggle(song.id);
              return;
            }
            if (!song.offlineAvailable) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.downloadNeeded)));
              return;
            }
            context.push('/score/${song.id}');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: checked,
                  onChanged: (_) => ref
                      .read(librarySelectionProvider.notifier)
                      .toggle(song.id),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
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
                            color: FolderColors.toColor(folder.color),
                            borderRadius: const BorderRadius.horizontal(
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
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _songSubtitle(song, l10n, folder?.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
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
                                for (final label in labels.take(4))
                                  GestureDetector(
                                    onTap: selecting
                                        ? null
                                        : () => ref
                                              .read(
                                                libraryLabelFilterProvider
                                                    .notifier,
                                              )
                                              .update(label.name),
                                    child: Text(
                                      '#${label.name}',
                                      style: TextStyle(
                                        color: AppColors.accent.withValues(
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
                  icon: song.isFavorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  tooltip: song.isFavorite ? l10n.unfavorite : l10n.favorite,
                  selected: song.isFavorite,
                  onPressed: () =>
                      ref.read(songRepositoryProvider).toggleFavorite(song.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _songSubtitle(Song song, AppLocalizations l10n, String? folderName) {
    return [
      if (folderName != null) folderName,
      if (song.artist case final artist?) artist,
      if (song.defaultTempo case final tempo?) '$tempo BPM',
      if (song.targetBpm case final target?) l10n.targetBpmShort(target),
      if (song.lastOpenedAt case final opened?)
        formatRelativeTime(opened, l10n),
      if (!song.offlineAvailable) l10n.offlineMissing,
    ].join(' · ');
  }
}

class _ConvertResume extends ConsumerStatefulWidget {
  const _ConvertResume();

  @override
  ConsumerState<_ConvertResume> createState() => _ConvertResumeState();
}

class _ConvertResumeState extends ConsumerState<_ConvertResume>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(omrConvertJobsProvider.notifier).resume());
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ConvertJobTile extends ConsumerWidget {
  const _ConvertJobTile({required this.job});

  final OmrConvertJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Container(
            width: 52,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              job.isRunning
                  ? Icons.document_scanner_outlined
                  : Icons.error_outline_rounded,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  job.isRunning
                      ? (job.progress > 0
                            ? l10n.convertingScorePercent(job.progress)
                            : l10n.convertingScore)
                      : (job.error ?? l10n.convertFailed),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (job.isRunning) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: job.progress > 0 ? job.progress / 100 : null,
                  ),
                ],
              ],
            ),
          ),
          if (!job.isRunning)
            CompactIconButton(
              icon: Icons.close_rounded,
              tooltip: l10n.close,
              onPressed: () =>
                  ref.read(omrConvertJobsProvider.notifier).dismiss(job.id),
            ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: Icons.library_music_outlined,
      title: l10n.emptyLibraryTitle,
      body: l10n.emptyLibraryBody,
      actionLabel: l10n.import,
      onAction: onImport,
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: l10n.loadFailed,
      body: l10n.retryAction,
      compact: true,
    );
  }
}

enum _LibraryAddAction { create, pdf, importMusicXml, convert }
