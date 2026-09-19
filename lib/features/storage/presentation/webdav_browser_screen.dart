import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/library/data/song_repository.dart';
import 'package:page_a_diddle/features/storage/data/remote_score_service.dart';
import 'package:page_a_diddle/features/storage/data/webdav_connection.dart';
import 'package:page_a_diddle/features/storage/domain/sync_status.dart';

class WebDavBrowserScreen extends ConsumerStatefulWidget {
  const WebDavBrowserScreen({this.selectOnly = false, super.key});

  /// In Jam, return the selected Library song instead of staying in the
  /// browser so the caller can bind it to a shared setlist entry.
  final bool selectOnly;

  @override
  ConsumerState<WebDavBrowserScreen> createState() =>
      _WebDavBrowserScreenState();
}

class _WebDavBrowserScreenState extends ConsumerState<WebDavBrowserScreen> {
  WebDavCredentials? _credentials;
  Uri? _root;
  Uri? _directory;
  List<WebDavEntry> _entries = const [];
  Map<String, Song> _songsByUri = const {};
  bool _isLoading = true;
  String? _error;
  String? _registeringUri;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final credentials = await ref.read(webDavSettingsStoreProvider).read();
      if (credentials == null) {
        if (mounted) {
          setState(() {
            _error = context.l10n.webdavNeeded;
            _isLoading = false;
          });
        }
        return;
      }
      final parsedRoot = Uri.parse(credentials.url);
      final root = parsedRoot.path.endsWith('/')
          ? parsedRoot
          : parsedRoot.replace(path: '${parsedRoot.path}/');
      _credentials = credentials;
      _root = root;
      await _open(root);
    } on Object {
      if (mounted) {
        setState(() {
          _error = context.l10n.cantReadSettings;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _open(Uri directory) async {
    setState(() {
      _directory = directory;
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await ref
          .read(webDavConnectionProvider)
          .list(_credentials!, directory);
      final repository = ref.read(songRepositoryProvider);
      await repository.reconcileWebDavDirectory(
        directory: directory,
        entries: entries,
      );
      final songsByUri = await repository.getSongsByRemoteUris(
        entries.where((entry) => !entry.isDirectory).map((entry) => entry.uri),
      );
      if (mounted && _directory == directory) {
        setState(() {
          _entries = entries;
          _songsByUri = songsByUri;
          _isLoading = false;
        });
      }
    } on WebDavConnectionException catch (error) {
      if (mounted && _directory == directory) {
        setState(() {
          _error = error.message;
          _isLoading = false;
        });
      }
    } on Object {
      if (mounted && _directory == directory) {
        setState(() {
          _error = context.l10n.cantSaveSync;
          _isLoading = false;
        });
      }
    }
  }

  bool get _canGoUp =>
      _root != null &&
      _directory != null &&
      _normalizedPath(_root!) != _normalizedPath(_directory!);

  String _normalizedPath(Uri uri) {
    return uri.path.endsWith('/') && uri.path.length > 1
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
  }

  void _goUp() {
    if (!_canGoUp) return;
    final segments = [..._directory!.pathSegments]
      ..removeWhere((part) => part.isEmpty)
      ..removeLast();
    final rootSegments = _root!.pathSegments.where((part) => part.isNotEmpty);
    if (segments.length < rootSegments.length) return;
    _open(_directory!.replace(pathSegments: segments));
  }

  Future<void> _register(WebDavEntry entry) async {
    if (_registeringUri != null) return;
    setState(() => _registeringUri = entry.uri.toString());
    try {
      final remoteService = ref.read(remoteScoreServiceProvider);
      final songId = await remoteService.register(entry);
      if (widget.selectOnly && mounted) {
        final song = await ref.read(songRepositoryProvider).getSong(songId);
        if (song != null && !song.offlineAvailable) {
          await remoteService.download(song);
        }
        if (!mounted) return;
        Navigator.of(context).pop(songId);
        return;
      }
      final songsByUri = await ref
          .read(songRepositoryProvider)
          .getSongsByRemoteUris(
            _entries.where((item) => !item.isDirectory).map((item) => item.uri),
          );
      if (mounted) {
        setState(() {
          _songsByUri = songsByUri;
          _registeringUri = null;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _registeringUri = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.addFailed)));
      }
    }
  }

  Future<void> _selectRegisteredSong(Song song) async {
    if (_registeringUri != null) return;
    if (!widget.selectOnly) return;
    setState(() => _registeringUri = song.remoteUri);
    try {
      if (!song.offlineAvailable) {
        await ref.read(remoteScoreServiceProvider).download(song);
      }
      if (mounted) Navigator.of(context).pop(song.id);
    } on Object {
      if (mounted) {
        setState(() => _registeringUri = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.addFailed)));
      }
    }
  }

  List<String> _breadcrumb(AppLocalizations l10n) {
    if (_directory == null || _root == null) return const [];
    final rootParts = _root!.pathSegments.where((p) => p.isNotEmpty).toList();
    final dirParts = _directory!.pathSegments
        .where((p) => p.isNotEmpty)
        .toList();
    if (dirParts.length <= rootParts.length) return [l10n.root];
    return [l10n.root, ...dirParts.sublist(rootParts.length)];
  }

  String _directoryName(AppLocalizations l10n) {
    final directory = _directory;
    if (directory == null || directory == _root) return l10n.webdavFiles;
    return directory.pathSegments.where((part) => part.isNotEmpty).lastOrNull ??
        l10n.webdavFiles;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final breadcrumb = _breadcrumb(l10n);
    return Theme(
      data: AppTheme.stage,
      child: PopScope(
        canPop: !_canGoUp,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goUp();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_directoryName(l10n)),
            leading: _canGoUp
                ? IconButton(
                    onPressed: _goUp,
                    tooltip: l10n.parentFolder,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (breadcrumb.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < breadcrumb.length; i++) ...[
                          Text(
                            breadcrumb[i],
                            style: TextStyle(
                              color: i == breadcrumb.length - 1
                                  ? AppColors.canvas
                                  : AppColors.stageMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (i < breadcrumb.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: AppColors.stageMuted,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _ErrorPane(
                        message: _error!,
                        onRetry: () => _open(_directory!),
                      )
                    : _entries.isEmpty
                    ? const _EmptyPane()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final song = _songsByUri[entry.uri.toString()];
                          final status = entry.isDirectory
                              ? null
                              : resolveSyncStatus(
                                  hasLocalRecord: song != null,
                                  offlineAvailable:
                                      song?.offlineAvailable ?? false,
                                  remotePresent: true,
                                  syncedModifiedAt: song?.remoteModifiedAt,
                                  syncedSize: song?.remoteSize,
                                  remoteModifiedAt: entry.modifiedAt,
                                  remoteSize: entry.size,
                                );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _EntryCard(
                              entry: entry,
                              status: status,
                              registered: song != null,
                              loading: _registeringUri == entry.uri.toString(),
                              onTap: entry.isDirectory
                                  ? () => _open(entry.uri)
                                  : song == null
                                  ? () => _register(entry)
                                  : widget.selectOnly
                                  ? () => _selectRegisteredSong(song)
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.registered,
    required this.loading,
    required this.onTap,
    this.status,
  });

  final WebDavEntry entry;
  final SyncStatus? status;
  final bool registered;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: AppColors.stageElevated,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entry.isDirectory
                      ? AppColors.stagePanel
                      : AppColors.stagePanel,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.stageOutline),
                ),
                child: Icon(
                  entry.isDirectory
                      ? Icons.folder_rounded
                      : Icons.picture_as_pdf_outlined,
                  size: 20,
                  color: entry.isDirectory
                      ? AppColors.stageMuted
                      : AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.canvas,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 4),
                      _SyncBadge(label: status!.label(l10n)),
                    ],
                  ],
                ),
              ),
              if (loading)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (entry.isDirectory)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.stageMuted,
                )
              else
                Icon(
                  registered
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: registered ? AppColors.accent : AppColors.stageMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.stageMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.canvas),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.canvas,
              ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_open_rounded,
            size: 48,
            color: AppColors.stageOutline,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.emptyFolder,
            style: const TextStyle(color: AppColors.stageMuted),
          ),
        ],
      ),
    );
  }
}
