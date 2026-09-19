import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:page_a_diddle/app/icons/brand_marks.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/app/widgets/compact_controls.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/core/session/jam_session.dart';
import 'package:page_a_diddle/core/session/jam_session_store.dart';
import 'package:page_a_diddle/core/storage/song_file_storage.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/jam/domain/jam_local_song_match.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_controller.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_instrument_ui.dart';
import 'package:page_a_diddle/features/jam/presentation/jam_session_error_l10n.dart';
import 'package:page_a_diddle/features/library/data/pdf_picker.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/library/presentation/import_score_sheet.dart';
import 'package:page_a_diddle/features/setlists/data/setlist_repository.dart';
import 'package:page_a_diddle/features/setlists/presentation/setlist_controller.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';
import 'package:page_a_diddle/features/storage/cloud/presentation/cloud_browser_screen.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';
import 'package:page_a_diddle/features/storage/presentation/webdav_browser_screen.dart';
import 'package:page_a_diddle/features/tools/data/metronome_settings.dart';
import 'package:page_a_diddle/features/tools/domain/metronome_sequence.dart';
import 'package:page_a_diddle/features/tools/presentation/metronome_settings_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

enum _JamScoreSource { library, device, googleDrive, dropbox, webDav }

class JamSessionScreen extends ConsumerStatefulWidget {
  const JamSessionScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<JamSessionScreen> createState() => _JamSessionScreenState();
}

class _JamSessionScreenState extends ConsumerState<JamSessionScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  String? _openedEntryId;
  String? _openingEntryId;
  final Map<String, String> _localSongIdsByEntry = {};
  final Map<String, String> _hostFallbackSongIdsByEntry = {};
  late final Future<void> _bindingsReady;
  bool _hasSeenSession = false;
  bool _setlistBusy = false;
  final Set<String> _savingSharedSetlists = {};
  final Set<String> _savedSharedSetlists = {};

  @override
  void initState() {
    super.initState();
    _bindingsReady = _loadLocalBindings();
    unawaited(ref.read(songRepositoryProvider).clearJamHostSongs());
  }

  Future<void> _loadLocalBindings() async {
    final bindings = await JamLocalSongBindingStore.load();
    if (mounted) {
      setState(() => _localSongIdsByEntry.addAll(bindings));
    }
  }

  @override
  void dispose() {
    ref.read(jamSessionStoreProvider).setHostScoreProvider(null);
    final ids = _hostFallbackSongIdsByEntry.values.toList(growable: false);
    if (ids.isNotEmpty) {
      unawaited(ref.read(songRepositoryProvider).deleteSongs(ids));
    }
    super.dispose();
  }

  Future<JamHostScore?> _provideHostScore(
    JamSession session,
    String entryId,
  ) async {
    final setlistId = session.sharedSetlist?.id ?? session.setlistId;
    if (setlistId == null) return null;
    final item = (await ref.read(setlistRepositoryProvider).getItems(setlistId))
        .where((item) => item.entry.id == entryId)
        .firstOrNull;
    final song = item?.song;
    if (song == null) return null;
    final file = await ref
        .read(songFileStorageProvider)
        .resolve(song.sourcePath);
    if (!await file.exists()) return null;
    final length = await file.length();
    if (length == 0 || length > JamHostScore.maxBytes) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length < 5 ||
        !String.fromCharCodes(bytes.take(1024)).contains('%PDF-')) {
      return null;
    }
    return JamHostScore(
      entryId: entryId,
      title: song.title,
      artist: song.artist,
      bpm: item?.tempo,
      bytes: bytes,
    );
  }

  void _registerHostScoreProvider(JamSession session) {
    final active = ref.read(activeJamProvider);
    final canLead =
        active != null &&
        session.permissionsFor(active.participantId)?.canLead == true;
    ref
        .read(jamSessionStoreProvider)
        .setHostScoreProvider(
          canLead ? (entryId) => _provideHostScore(session, entryId) : null,
        );
  }

  Future<Song?> _cacheHostScore(
    JamSession session,
    JamSharedSong shared,
    JamHostScore score,
  ) async {
    if (score.entryId != shared.entryId) return null;
    final key = _bindingKey(session, shared);
    final existingId = _hostFallbackSongIdsByEntry[key];
    if (existingId != null) {
      final existing = await ref
          .read(songRepositoryProvider)
          .getSong(existingId);
      if (existing != null) return existing;
    }
    final songId = 'jam-host-${const Uuid().v4()}';
    final storage = ref.read(songFileStorageProvider);
    final relativePath = await storage.storeJamPdf(
      bytes: score.bytes,
      songId: songId,
    );
    final now = DateTime.now();
    try {
      await ref
          .read(songRepositoryProvider)
          .saveSong(
            SongsCompanion.insert(
              id: songId,
              title: score.title.trim().isEmpty ? shared.title : score.title,
              artist: Value(score.artist),
              defaultTempo: Value(score.bpm ?? shared.bpm),
              sourcePath: relativePath,
              sourceProvider: const Value(jamHostSourceProvider),
              offlineAvailable: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } on Object {
      await storage.delete(relativePath);
      rethrow;
    }
    _hostFallbackSongIdsByEntry[key] = songId;
    return ref.read(songRepositoryProvider).getSong(songId);
  }

  Future<void> _leave() async {
    await ref.read(activeJamProvider.notifier).leave();
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/jam');
    }
  }

  Future<void> _pickSetlist() async {
    if (_setlistBusy) {
      return;
    }
    setState(() => _setlistBusy = true);
    try {
      final setlists = await ref
          .read(setlistRepositoryProvider)
          .getSetlists()
          .timeout(const Duration(seconds: 4));
      if (!mounted) {
        return;
      }
      if (setlists.isEmpty) {
        await _openSetlistsAndShareLatest();
        return;
      }
      final selected = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.stageElevated,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return Theme(
            data: AppTheme.stage,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      l10n.setlist,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.canvas,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.select,
                      style: const TextStyle(color: AppColors.stageMuted),
                    ),
                    const SizedBox(height: 16),
                    for (final setlist in setlists)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.stagePanel,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minVerticalPadding: 8,
                            leading: const Icon(
                              Icons.queue_music_rounded,
                              color: AppColors.accent,
                              size: 28,
                            ),
                            title: Text(
                              setlist.title,
                              style: const TextStyle(
                                color: AppColors.canvas,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.stageMuted,
                            ),
                            onTap: () =>
                                Navigator.pop(sheetContext, setlist.id),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _openSetlistsAndShareLatest();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.newSetlist),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (selected == null || !mounted) {
        return;
      }
      await ref.read(activeJamProvider.notifier).shareSetlist(selected);
    } on JamSessionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jamSessionErrorMessage(l10n, error))),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.loadFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _setlistBusy = false);
      }
    }
  }

  Future<void> _openSetlistsAndShareLatest() async {
    await context.push('/setlists');
    if (!mounted) {
      return;
    }
    ref.invalidate(setlistsProvider);
    final updated = await ref
        .read(setlistRepositoryProvider)
        .getSetlists()
        .timeout(const Duration(seconds: 4));
    if (updated.isNotEmpty) {
      await ref.read(activeJamProvider.notifier).shareSetlist(updated.first.id);
    }
  }

  Future<void> _openSetlistEditor(String setlistId) async {
    await context.push('/setlists/$setlistId');
    if (mounted) {
      ref.invalidate(setlistsProvider);
      try {
        await ref.read(activeJamProvider.notifier).shareSetlist(setlistId);
      } on JamSessionException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(jamSessionErrorMessage(l10n, error))),
          );
        }
      }
    }
  }

  Future<void> _selectSong(String entryId) async {
    try {
      await ref.read(activeJamProvider.notifier).selectSong(entryId);
    } on JamSessionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jamSessionErrorMessage(l10n, error))),
        );
      }
    }
  }

  Future<Song?> _pickLocalSong(
    JamSharedSong shared,
    Iterable<Song> songs,
  ) async {
    final matching = localSongCandidatesForJam(songs, shared);
    final candidates = matching.isEmpty
        ? songs.toList(growable: false)
        : matching;
    if (candidates.isEmpty || !mounted) {
      return null;
    }
    return showModalBottomSheet<Song>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Theme(
          data: AppTheme.stage,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    l10n.openScore,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.canvas,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    shared.title,
                    style: const TextStyle(color: AppColors.stageMuted),
                  ),
                  const SizedBox(height: 16),
                  for (final song in candidates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: AppColors.stagePanel,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minVerticalPadding: 8,
                          title: Text(
                            song.title,
                            style: const TextStyle(
                              color: AppColors.canvas,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: song.artist == null
                              ? null
                              : Text(
                                  song.artist!,
                                  style: const TextStyle(
                                    color: AppColors.stageMuted,
                                  ),
                                ),
                          trailing: song.offlineAvailable
                              ? const Icon(
                                  Icons.download_done_rounded,
                                  color: AppColors.accent,
                                )
                              : null,
                          onTap: () => Navigator.pop(sheetContext, song),
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

  Future<_JamScoreSource?> _pickJamScoreSource() {
    return showModalBottomSheet<_JamScoreSource>(
      context: context,
      backgroundColor: AppColors.stageElevated,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return Theme(
          data: AppTheme.stage,
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    l10n.openScore,
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(
                          color: AppColors.canvas,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _JamSourceTile(
                  icon: const Icon(Icons.library_music_outlined),
                  label: l10n.library,
                  onTap: () =>
                      Navigator.pop(sheetContext, _JamScoreSource.library),
                ),
                _JamSourceTile(
                  icon: BrandMarks.device(),
                  label: l10n.importFromDevice,
                  onTap: () =>
                      Navigator.pop(sheetContext, _JamScoreSource.device),
                ),
                _JamSourceTile(
                  icon: BrandMarks.googleDrive(),
                  label: l10n.importFromGoogleDrive,
                  onTap: () =>
                      Navigator.pop(sheetContext, _JamScoreSource.googleDrive),
                ),
                _JamSourceTile(
                  icon: BrandMarks.dropbox(),
                  label: l10n.importFromDropbox,
                  onTap: () =>
                      Navigator.pop(sheetContext, _JamScoreSource.dropbox),
                ),
                _JamSourceTile(
                  icon: BrandMarks.webDav(),
                  label: l10n.importFromWebDav,
                  onTap: () =>
                      Navigator.pop(sheetContext, _JamScoreSource.webDav),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Song?> _importDeviceScore() async {
    final file = await ref.read(pdfPickerProvider).pick();
    if (file == null || !mounted) return null;
    final songId = await showImportScoreSheet(
      context,
      file: file,
      sourceProvider: StorageProvider.osFileProvider,
    );
    if (songId == null || !mounted) return null;
    return ref.read(songRepositoryProvider).getSong(songId);
  }

  Future<Song?> _importCloudScore(CloudKind kind) async {
    final result = await openCloudBrowser(context, ref, kind: kind);
    if (result == null || !mounted) return null;
    return ref.read(songRepositoryProvider).getSong(result.songId);
  }

  Future<Song?> _importWebDavScore() async {
    final credentials = await ref.read(webDavSettingsStoreProvider).read();
    if (!mounted) return null;
    if (credentials == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.webdavNeeded)));
      await context.push('/tools/webdav');
      return null;
    }
    final songId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const WebDavBrowserScreen(selectOnly: true),
      ),
    );
    if (songId == null || !mounted) return null;
    return ref.read(songRepositoryProvider).getSong(songId);
  }

  Future<Song?> _pickSongForJam(JamSharedSong shared) async {
    final source = await _pickJamScoreSource();
    if (source == null || !mounted) return null;
    return switch (source) {
      _JamScoreSource.library => _pickLocalSong(
        shared,
        await ref.read(songRepositoryProvider).watchSongs().first,
      ),
      _JamScoreSource.device => _importDeviceScore(),
      _JamScoreSource.googleDrive => _importCloudScore(CloudKind.googleDrive),
      _JamScoreSource.dropbox => _importCloudScore(CloudKind.dropbox),
      _JamScoreSource.webDav => _importWebDavScore(),
    };
  }

  String _bindingKey(JamSession session, JamSharedSong shared) {
    return jamLocalSongBindingKey(
      setlistId: session.sharedSetlist?.id ?? session.setlistId ?? session.id,
      entryId: shared.entryId,
    );
  }

  Future<void> _openCurrentSong(
    JamSession session, {
    bool startJam = false,
    bool chooseLocal = false,
  }) async {
    final shared = session.currentSong;
    if (shared == null) {
      return;
    }
    await _openSharedSong(
      session,
      shared,
      startJam: startJam,
      chooseLocal: chooseLocal,
    );
  }

  Future<void> _openSharedSong(
    JamSession session,
    JamSharedSong shared, {
    bool startJam = false,
    bool chooseLocal = false,
  }) async {
    if (_openingEntryId == shared.entryId) {
      return;
    }
    _openingEntryId = shared.entryId;
    try {
      await _bindingsReady;
      final songs = await ref.read(songRepositoryProvider).watchSongs().first;
      if (!mounted) {
        return;
      }
      final bindingKey = _bindingKey(session, shared);
      final mappedId = chooseLocal ? null : _localSongIdsByEntry[bindingKey];
      var local = mappedId == null
          ? null
          : songs.where((song) => song.id == mappedId).firstOrNull;
      if (local != null && !local.offlineAvailable) {
        local = null;
      }
      if (local == null && !chooseLocal) {
        final cachedId = _hostFallbackSongIdsByEntry[bindingKey];
        if (cachedId != null) {
          local = await ref.read(songRepositoryProvider).getSong(cachedId);
        }
      }
      if (local == null && !chooseLocal) {
        final match = matchLocalSongForJam(songs, shared);
        local = match?.offlineAvailable == true ? match : null;
        if (local != null) {
          _localSongIdsByEntry[bindingKey] = local.id;
          await JamLocalSongBindingStore.save(_localSongIdsByEntry);
        }
      }
      if (local == null && !chooseLocal) {
        final active = ref.read(activeJamProvider);
        if (active != null &&
            session.permissionsFor(active.participantId)?.canFollow == true) {
          final hostScore = await ref
              .read(jamSessionStoreProvider)
              .requestHostScore(
                sessionId: active.sessionId,
                participantId: active.participantId,
                entryId: shared.entryId,
              );
          if (hostScore != null) {
            local = await _cacheHostScore(session, shared, hostScore);
          }
        }
      }
      if (local == null) {
        local = await _pickSongForJam(shared);
        if (local == null || !mounted) {
          return;
        }
        _localSongIdsByEntry[bindingKey] = local.id;
        await JamLocalSongBindingStore.save(_localSongIdsByEntry);
        await ref
            .read(setlistRepositoryProvider)
            .replaceEntrySong(entryId: shared.entryId, songId: local.id);
        setState(() {});
      }
      if (!mounted) return;
      _openedEntryId = shared.entryId;
      final setlistId = session.sharedSetlist?.id ?? session.setlistId;
      final query = <String, String>{
        if (setlistId != null) 'setlistId': setlistId,
        if (startJam) 'startJam': 'true',
      };
      final path = Uri(
        path: '/score/${local.id}',
        queryParameters: query,
      ).toString();
      final route = context.push(path);
      unawaited(
        route.whenComplete(() {
          if (mounted && _openedEntryId == shared.entryId) {
            _openedEntryId = null;
          }
        }),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importFailed)));
      }
    } finally {
      _openingEntryId = null;
    }
  }

  Future<void> _toggleSession(JamSession session) async {
    if (session.playing) {
      await ref.read(activeJamProvider.notifier).updatePlaying(false);
      return;
    }
    if (session.currentSong == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.emptyJamSongs)));
      return;
    }
    if (!session.allMembersReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.jamNotReady)));
      return;
    }
    try {
      await _openCurrentSong(session, startJam: true);
    } on JamSessionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jamSessionErrorMessage(l10n, error))),
        );
      }
    }
  }

  Future<void> _toggleReady(JamParticipant participant) async {
    unawaited(HapticFeedback.selectionClick());
    await ref.read(activeJamProvider.notifier).updateReady(!participant.ready);
  }

  MetronomeSettings _metronomeSettingsForJam(JamSession session) {
    final defaults = ref.read(metronomeSettingsProvider);
    final music = session.music;
    final meter =
        music?.meterNumerator == null || music?.meterDenominator == null
        ? defaults.meter
        : metronomeMeters
                  .where(
                    (candidate) =>
                        candidate.numerator == music!.meterNumerator &&
                        candidate.denominator == music.meterDenominator,
                  )
                  .firstOrNull ??
              defaults.meter;
    final subdivision = music?.subdivision == null
        ? defaults.subdivision
        : MetronomeSubdivision.values
                  .where((value) => value.name == music!.subdivision)
                  .firstOrNull ??
              defaults.subdivision;
    final remoteAccents = music?.accents;
    final accents = List.generate(meter.numerator, (index) {
      final raw = remoteAccents != null && index < remoteAccents.length
          ? remoteAccents[index]
          : null;
      if (raw != null) {
        return MetronomeAccentLevel.values[raw
            .clamp(0, MetronomeAccentLevel.values.length - 1)
            .toInt()];
      }
      return index < defaults.accents.length
          ? defaults.accents[index]
          : index == 0
          ? MetronomeAccentLevel.strong
          : MetronomeAccentLevel.normal;
    });
    return MetronomeSettings(
      bpm: music?.bpm ?? session.currentSong?.bpm ?? defaults.bpm,
      meter: meter,
      subdivision: subdivision,
      accents: accents,
      countInBars: session.countInBars,
      haptics: defaults.haptics,
    );
  }

  Future<void> _updateJamMetronome(
    JamSession session,
    MetronomeSettings settings,
  ) async {
    try {
      await ref.read(metronomeSettingsProvider.notifier).update(settings);
      await ref
          .read(activeJamProvider.notifier)
          .updateMusic(
            bpm: settings.bpm,
            meterNumerator: settings.meter.numerator,
            meterDenominator: settings.meter.denominator,
            subdivision: settings.subdivision.name,
            accents: [for (final accent in settings.accents) accent.index],
          );
      await ref
          .read(activeJamProvider.notifier)
          .updateCountInBars(settings.countInBars);
      final active = ref.read(activeJamProvider);
      final entryId = session.currentEntryId;
      final setlistId = session.sharedSetlist?.id ?? session.setlistId;
      if (active != null &&
          entryId != null &&
          setlistId != null &&
          session.permissionsFor(active.participantId)?.canLead == true) {
        await ref
            .read(setlistRepositoryProvider)
            .updateMetronome(
              entryId: entryId,
              music: JamMusicState(
                bpm: settings.bpm,
                meterNumerator: settings.meter.numerator,
                meterDenominator: settings.meter.denominator,
                subdivision: settings.subdivision.name,
                accents: [for (final accent in settings.accents) accent.index],
              ),
            );
      }
    } on JamSessionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jamSessionErrorMessage(l10n, error))),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.changeFailed)));
      }
    }
  }

  Future<void> _showJamMetronomeSheet(JamSession session) async {
    await showMetronomeSettingsSheet(
      context: context,
      initial: _metronomeSettingsForJam(session),
      enabled: !session.playing,
      title: l10n.metronome,
      subtitle: l10n.metronomeSubtitleFull,
      onChanged: (settings) =>
          unawaited(_updateJamMetronome(session, settings)),
    );
  }

  void _queueSharedSetlistImport(JamSession session) {
    final shared = session.sharedSetlist;
    if (shared == null ||
        _savedSharedSetlists.contains(shared.id) ||
        !_savingSharedSetlists.add(shared.id)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _savingSharedSetlists.remove(shared.id);
        return;
      }
      unawaited(_saveSharedSetlist(session, shared));
    });
  }

  Future<void> _saveSharedSetlist(
    JamSession session,
    JamSharedSetlist shared,
  ) async {
    try {
      await _bindingsReady;
      final songs = await ref
          .read(songRepositoryProvider)
          .watchSongs()
          .first
          .timeout(const Duration(seconds: 4));
      final localSongIdsByEntry = <String, String>{};
      for (final sharedSong in shared.songs) {
        final local = matchLocalSongForJam(songs, sharedSong);
        if (local != null) {
          localSongIdsByEntry[sharedSong.entryId] = local.id;
        }
      }
      final result = await ref
          .read(setlistRepositoryProvider)
          .importSharedSetlist(
            id: shared.id,
            title: shared.title,
            entries: [
              for (final song in shared.songs)
                SetlistImportEntry(
                  entryId: song.entryId,
                  title: song.title,
                  artist: song.artist,
                  bpm: song.bpm,
                  music: song.music,
                ),
            ],
            localSongIdsByEntry: localSongIdsByEntry,
          );
      _localSongIdsByEntry.removeWhere(
        (key, _) => key.startsWith('${shared.id}/'),
      );
      for (final entry in result.localSongIdsByEntry.entries) {
        _localSongIdsByEntry[jamLocalSongBindingKey(
              setlistId: shared.id,
              entryId: entry.key,
            )] =
            entry.value;
      }
      await JamLocalSongBindingStore.save(_localSongIdsByEntry);
      _savedSharedSetlists.add(shared.id);
      if (mounted) setState(() {});
    } on Object {
      // A transient database/stream failure should not break the Jam lobby.
    } finally {
      _savingSharedSetlists.remove(shared.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(jamSessionProvider(widget.sessionId), (previous, next) {
      final previousSession = previous?.asData?.value;
      final session = next.asData?.value;
      if (session == null) {
        ref.read(jamSessionStoreProvider).setHostScoreProvider(null);
        return;
      }
      final self = ref.read(activeJamProvider)?.participantId;
      final canLead = self == null
          ? true
          : session.permissionsFor(self)?.canLead ?? true;
      if (!canLead &&
          session.playing &&
          previousSession?.playing != true &&
          session.currentSong != null &&
          _openedEntryId != session.currentEntryId) {
        unawaited(_openCurrentSong(session, startJam: true));
      }
    });

    final session = ref.watch(jamSessionProvider(widget.sessionId));
    final selfId = ref.watch(activeJamProvider)?.participantId;

    return session.when(
      data: (value) {
        if (value != null) {
          _hasSeenSession = true;
          _registerHostScoreProvider(value);
        } else {
          ref.read(jamSessionStoreProvider).setHostScoreProvider(null);
        }
        if (value == null) {
          return Theme(
            data: AppTheme.stage,
            child: Scaffold(
              appBar: AppBar(title: Text(l10n.jam)),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 40,
                        color: AppColors.stageMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _hasSeenSession
                            ? l10n.jamHostDisconnected
                            : l10n.jamSessionNotFound,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          ref.read(activeJamProvider.notifier).clear();
                          context.go('/jam');
                        },
                        child: Text(l10n.jamBackToHub),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        final permissions = selfId == null
            ? null
            : value.permissionsFor(selfId);
        final selfParticipant = selfId == null
            ? null
            : value.participantById(selfId);
        final presence = jamPresence(value.participants);
        final shared = value.sharedSetlist;
        final canLead = permissions?.canLead ?? false;
        final currentSong = value.currentSong;
        if (permissions != null && !canLead) {
          _queueSharedSetlistImport(value);
        }
        final previousEntryId = shared == null
            ? null
            : jamAdjacentEntryId(
                shared,
                currentEntryId: value.currentEntryId,
                delta: -1,
              );
        final nextEntryId = shared == null
            ? null
            : jamAdjacentEntryId(
                shared,
                currentEntryId: value.currentEntryId,
                delta: 1,
              );
        return Theme(
          data: AppTheme.stage,
          child: Builder(
            builder: (context) {
              final textTheme = Theme.of(context).textTheme;
              final colors = Theme.of(context).colorScheme;
              return Scaffold(
                appBar: AppBar(
                  title: Text(value.title),
                  actions: [
                    CompactIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: permissions?.leaveLabel ?? l10n.leave,
                      onPressed: _leave,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                body: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 136),
                          children: [
                            if (permissions != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.stageElevated,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withValues(
                                              alpha: 0.16,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.groups_rounded,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.jamLobby,
                                                style: textTheme.labelMedium
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                value.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: textTheme.titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          value.code,
                                          style: textTheme.titleLarge?.copyWith(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      selfParticipant == null
                                          ? permissions.roleLabel
                                          : jamInstrumentLabel(
                                              l10n,
                                              selfParticipant.instrument,
                                              custom: selfParticipant
                                                  .customInstrument,
                                            ),
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${jamPresenceLabel(presence)} · ${permissions.roleLabel}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (permissions?.canInvite ?? false) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  22,
                                  20,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.stageElevated,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.accent.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      l10n.inviteCode,
                                      style: textTheme.labelMedium?.copyWith(
                                        color: colors.onSurfaceVariant,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      value.code,
                                      style: textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 8,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CompactIconButton(
                                          icon: Icons.copy_rounded,
                                          tooltip: l10n.copy,
                                          color: Colors.white,
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(text: value.code),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(l10n.codeCopied),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    Theme(
                                      data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent,
                                      ),
                                      child: ExpansionTile(
                                        initiallyExpanded: false,
                                        tilePadding: EdgeInsets.zero,
                                        title: Text(
                                          l10n.showQr,
                                          textAlign: TextAlign.center,
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: Center(
                                              child: ColoredBox(
                                                color: Colors.white,
                                                child: QrImageView(
                                                  data: jamInvitePayload(
                                                    value.code,
                                                  ),
                                                  size: 168,
                                                  backgroundColor: Colors.white,
                                                  semanticsLabel: l10n.jamCode,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (canLead && value.members.isNotEmpty) ...[
                              Text(
                                l10n.jamReadyCount(
                                  value.readyMemberCount,
                                  value.connectedMembers.length,
                                ),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: value.allMembersReady
                                      ? AppColors.accent
                                      : colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.setlist,
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (canLead)
                                  OutlinedButton.icon(
                                    onPressed: _setlistBusy
                                        ? null
                                        : () {
                                            HapticFeedback.selectionClick();
                                            unawaited(_pickSetlist());
                                          },
                                    icon: Icon(
                                      _setlistBusy
                                          ? Icons.hourglass_top_rounded
                                          : shared == null
                                          ? Icons.playlist_add_rounded
                                          : Icons.playlist_play_rounded,
                                    ),
                                    label: Text(
                                      shared == null
                                          ? l10n.select
                                          : l10n.change,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (shared == null)
                              Text(l10n.none, style: textTheme.bodyMedium)
                            else ...[
                              Text(
                                shared.title,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.songCount(shared.songs.length),
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              if (canLead) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: () => unawaited(
                                      _openSetlistEditor(shared.id),
                                    ),
                                    icon: const Icon(Icons.add_rounded),
                                    label: Text(l10n.addSongs),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              if (shared.songs.isEmpty)
                                Text(l10n.emptyJamSongs)
                              else
                                for (var i = 0; i < shared.songs.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _JamSongRow(
                                      index: i + 1,
                                      song: shared.songs[i],
                                      isCurrent:
                                          shared.songs[i].entryId ==
                                          value.currentEntryId,
                                      canSelect: canLead,
                                      isBound: _localSongIdsByEntry.containsKey(
                                        _bindingKey(value, shared.songs[i]),
                                      ),
                                      onSelect: () => unawaited(
                                        _selectSong(shared.songs[i].entryId),
                                      ),
                                      onBind: canLead
                                          ? null
                                          : () => unawaited(
                                              _openSharedSong(
                                                value,
                                                shared.songs[i],
                                                chooseLocal: true,
                                              ),
                                            ),
                                    ),
                                  ),
                            ],
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.stageElevated,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: canLead
                                  ? CompactOptionTile(
                                      label: l10n.metronome,
                                      value:
                                          jamMusicLabel(value.music) ??
                                          l10n.none,
                                      foregroundColor: AppColors.canvas,
                                      mutedColor: AppColors.stageMuted,
                                      enabled: !value.playing,
                                      onTap: () => unawaited(
                                        _showJamMetronomeSheet(value),
                                      ),
                                    )
                                  : ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        l10n.metronome,
                                        style: textTheme.bodySmall,
                                      ),
                                      trailing: Text(
                                        jamMusicLabel(value.music) ?? l10n.none,
                                        style: textTheme.titleSmall,
                                      ),
                                    ),
                            ),
                            const Divider(height: 28),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.stageElevated,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.participants,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        '${presence.connectedCount}/${presence.total}',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _JamParticipantRow(
                                    participant: value.conductor,
                                    isSelf: value.conductor.id == selfId,
                                  ),
                                  if (value.members.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    for (final member in value.members) ...[
                                      _JamParticipantRow(
                                        participant: member,
                                        isSelf: member.id == selfId,
                                      ),
                                      if (member != value.members.last)
                                        const SizedBox(height: 8),
                                    ],
                                  ],
                                  if (value.members.isEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.emptyJamMembers,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (currentSong != null ||
                            selfParticipant?.role == JamRole.member)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 12,
                            child: SafeArea(
                              top: false,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  10,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.stagePanel,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: value.playing
                                        ? AppColors.accent.withValues(
                                            alpha: 0.7,
                                          )
                                        : AppColors.stageOutline,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          onTap: currentSong == null
                                              ? null
                                              : () => unawaited(
                                                  _openCurrentSong(value),
                                                ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accent
                                                        .withValues(
                                                          alpha: 0.16,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.music_note_rounded,
                                                    color: AppColors.accent,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        l10n.nowLabel,
                                                        style: textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color: AppColors
                                                                  .accent,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 1),
                                                      Text(
                                                        currentSong?.title ??
                                                            l10n.none,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                            ),
                                                      ),
                                                      Text(
                                                        jamMusicLabel(
                                                              value.music,
                                                            ) ??
                                                            (currentSong?.bpm ==
                                                                    null
                                                                ? value.playing
                                                                      ? l10n.playing
                                                                      : l10n.tapToStart
                                                                : '${currentSong?.bpm} BPM'),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color:
                                                                  value.playing
                                                                  ? AppColors
                                                                        .accent
                                                                  : colors
                                                                        .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (canLead) ...[
                                      CompactIconButton(
                                        icon: Icons.skip_previous_rounded,
                                        tooltip: l10n.previous,
                                        color: Colors.white,
                                        onPressed: previousEntryId == null
                                            ? null
                                            : () => unawaited(
                                                _selectSong(previousEntryId),
                                              ),
                                      ),
                                      CompactIconButton(
                                        icon: Icons.skip_next_rounded,
                                        tooltip: l10n.next,
                                        color: Colors.white,
                                        onPressed: nextEntryId == null
                                            ? null
                                            : () => unawaited(
                                                _selectSong(nextEntryId),
                                              ),
                                      ),
                                      const SizedBox(width: 4),
                                      FilledButton.icon(
                                        onPressed:
                                            value.playing ||
                                                value.allMembersReady
                                            ? () => unawaited(
                                                _toggleSession(value),
                                              )
                                            : null,
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 44),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          backgroundColor: value.playing
                                              ? AppColors.stageOutline
                                              : AppColors.accent,
                                          foregroundColor: AppColors.canvas,
                                        ),
                                        icon: Icon(
                                          value.playing
                                              ? Icons.stop_rounded
                                              : Icons.play_arrow_rounded,
                                        ),
                                        label: Text(
                                          value.playing
                                              ? l10n.stop
                                              : value.allMembersReady
                                              ? l10n.start
                                              : l10n.waitingForReady,
                                        ),
                                      ),
                                    ] else if (selfParticipant != null)
                                      FilledButton.icon(
                                        onPressed: () => unawaited(
                                          _toggleReady(selfParticipant),
                                        ),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 44),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          backgroundColor: selfParticipant.ready
                                              ? AppColors.accent
                                              : AppColors.stageOutline,
                                          foregroundColor: AppColors.canvas,
                                        ),
                                        icon: Icon(
                                          selfParticipant.ready
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                    .radio_button_unchecked_rounded,
                                        ),
                                        label: Text(
                                          selfParticipant.ready
                                              ? l10n.readyDone
                                              : l10n.ready,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => Theme(
        data: AppTheme.stage,
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) => Theme(
        data: AppTheme.stage,
        child: Builder(
          builder: (context) {
            final l10n = context.l10n;
            return Scaffold(
              appBar: AppBar(title: Text(l10n.jam)),
              body: Center(child: Text(l10n.loadFailed)),
            );
          },
        ),
      ),
    );
  }
}

class _JamSourceTile extends StatelessWidget {
  const _JamSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon,
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.canvas,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.stageMuted,
      ),
      onTap: onTap,
    );
  }
}

class _JamSongRow extends StatelessWidget {
  const _JamSongRow({
    required this.index,
    required this.song,
    required this.isCurrent,
    required this.canSelect,
    required this.isBound,
    required this.onSelect,
    required this.onBind,
  });

  final int index;
  final JamSharedSong song;
  final bool isCurrent;
  final bool canSelect;
  final bool isBound;
  final VoidCallback onSelect;
  final VoidCallback? onBind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.accent.withValues(alpha: 0.16)
            : AppColors.stageElevated,
        borderRadius: BorderRadius.circular(10),
        border: isCurrent
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              style: TextStyle(
                color: isCurrent ? AppColors.accent : colors.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? Colors.white : null,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (song.artist case final artist?)
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.white.withValues(alpha: 0.72)
                          : colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (song.bpm case final bpm?)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '$bpm BPM',
                style: TextStyle(
                  color: isCurrent ? AppColors.accent : colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if (!canSelect)
            IconButton(
              tooltip: isBound ? context.l10n.change : context.l10n.openScore,
              onPressed: onBind,
              color: isCurrent ? AppColors.accent : Colors.white,
              icon: Icon(
                isBound ? Icons.menu_book_rounded : Icons.add_link_rounded,
              ),
            ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            const Icon(Icons.play_arrow_rounded, color: AppColors.accent),
          ],
        ],
      ),
    );
    if (!canSelect) {
      return child;
    }
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }
}

class _JamParticipantRow extends StatelessWidget {
  const _JamParticipantRow({required this.participant, required this.isSelf});

  final JamParticipant participant;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final roleLabel = participant.role == JamRole.conductor
        ? l10n.roleConductor
        : l10n.roleMembers;
    final instrumentLabel = jamInstrumentLabel(
      l10n,
      participant.instrument,
      custom: participant.customInstrument,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.stagePanel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Semantics(
            label: participant.connected ? l10n.connected : l10n.disconnected,
            child: Icon(
              jamInstrumentIcon(participant.instrument),
              size: 22,
              color: participant.connected ? AppColors.accent : colors.outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$instrumentLabel · $roleLabel · ${participant.connected ? l10n.connected : l10n.disconnected}',
                  style: TextStyle(
                    color: participant.connected
                        ? colors.onSurfaceVariant
                        : colors.outline,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (participant.role == JamRole.member)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: participant.ready
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : AppColors.stageOutline,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                participant.ready ? l10n.readyDone : l10n.ready,
                style: TextStyle(
                  color: participant.ready
                      ? AppColors.accent
                      : colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(width: 8),
          if (isSelf)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.me,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
