import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/icons/brand_marks.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';
import 'package:page_a_diddle/features/library/presentation/import_score_sheet.dart';
import 'package:page_a_diddle/features/storage/cloud/data/cloud_storage.dart';
import 'package:page_a_diddle/features/storage/cloud/domain/cloud_models.dart';

class CloudBrowserScreen extends ConsumerStatefulWidget {
  const CloudBrowserScreen({
    required this.kind,
    this.importFolderId,
    super.key,
  });

  final CloudKind kind;
  final String? importFolderId;

  @override
  ConsumerState<CloudBrowserScreen> createState() => _CloudBrowserScreenState();
}

class CloudImportResult {
  const CloudImportResult({required this.songId, required this.title});

  final String songId;
  final String title;
}

class _CloudBrowserScreenState extends ConsumerState<CloudBrowserScreen> {
  final _stack = <_NavFrame>[const _NavFrame.root()];
  List<CloudEntry> _entries = const [];
  var _loading = true;
  String? _error;
  String? _importingId;

  CloudKind get _kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cloud = ref.read(cloudStorageProvider);
      final frame = _stack.last;
      final entries = await cloud.list(
        _kind,
        folderId: frame.folderId,
        folderPath: frame.folderPath,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on CloudNotConfiguredException {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.cloudOAuthNotConfigured;
        _loading = false;
      });
    } on CloudAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.fetchFailed;
        _loading = false;
      });
    }
  }

  bool get _canGoUp => _stack.length > 1;

  void _goUp() {
    if (!_canGoUp) return;
    setState(() => _stack.removeLast());
    _load();
  }

  Future<void> _openFolder(CloudEntry entry) async {
    setState(() {
      _stack.add(
        _NavFrame(
          folderId: entry.id,
          folderPath: entry.path,
          title: entry.name,
        ),
      );
    });
    await _load();
  }

  Future<void> _importFile(CloudEntry entry) async {
    if (_importingId != null) return;
    setState(() => _importingId = entry.id);
    try {
      final file = await ref.read(cloudStorageProvider).download(_kind, entry);
      if (!mounted) return;
      final provider = switch (_kind) {
        CloudKind.googleDrive => StorageProvider.googleDrive,
        CloudKind.dropbox => StorageProvider.dropbox,
      };
      final imported = await showImportScoreSheet(
        context,
        file: file,
        sourceProvider: provider,
        folderId: widget.importFolderId,
      );
      if (imported != null && mounted) {
        // Close the whole browser (all folder levels) back to Library.
        Navigator.of(
          context,
        ).pop(CloudImportResult(songId: imported, title: entry.name));
        return;
      }
    } on CloudAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.importFailed}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _importingId = null);
    }
  }

  void _closeBrowser() {
    Navigator.of(context).pop();
  }

  Future<void> _disconnect() async {
    await ref.read(cloudStorageProvider).disconnect(_kind);
    if (mounted) Navigator.of(context).pop();
  }

  String _title(AppLocalizations l10n) {
    if (_stack.last.title case final title?) return title;
    return switch (_kind) {
      CloudKind.googleDrive => l10n.importFromGoogleDrive,
      CloudKind.dropbox => l10n.importFromDropbox,
    };
  }

  Widget _brandMark() => switch (_kind) {
    CloudKind.googleDrive => BrandMarks.googleDrive(),
    CloudKind.dropbox => BrandMarks.dropbox(),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_canGoUp,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _canGoUp) _goUp();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              _brandMark(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _title(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: Icon(
              _canGoUp ? Icons.arrow_back_rounded : Icons.close_rounded,
            ),
            tooltip: _canGoUp ? l10n.parentFolder : l10n.close,
            onPressed: _canGoUp ? _goUp : _closeBrowser,
          ),
          actions: [
            if (_canGoUp)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: l10n.close,
                onPressed: _closeBrowser,
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'disconnect') _disconnect();
                if (value == 'refresh') _load();
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'refresh', child: Text(l10n.retryAction)),
                PopupMenuItem(
                  value: 'disconnect',
                  child: Text(l10n.cloudDisconnect),
                ),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: Text(l10n.retryAction),
                      ),
                    ],
                  ),
                ),
              )
            : _entries.isEmpty
            ? Center(child: Text(l10n.emptyFolder))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final importing = _importingId == entry.id;
                  return ListTile(
                    leading: Icon(
                      entry.isFolder
                          ? Icons.folder_rounded
                          : Icons.picture_as_pdf_outlined,
                      color: entry.isFolder
                          ? AppColors.accent
                          : colors.onSurfaceVariant,
                    ),
                    title: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: importing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : entry.isFolder
                        ? const Icon(Icons.chevron_right_rounded)
                        : const Icon(Icons.add_rounded),
                    onTap: importing
                        ? null
                        : () {
                            if (entry.isFolder) {
                              _openFolder(entry);
                            } else {
                              _importFile(entry);
                            }
                          },
                  );
                },
              ),
      ),
    );
  }
}

class _NavFrame {
  const _NavFrame({this.folderId, this.folderPath, this.title});

  const _NavFrame.root() : folderId = null, folderPath = '', title = null;

  final String? folderId;
  final String? folderPath;
  final String? title;
}

/// Ensures OAuth session then opens [CloudBrowserScreen].
Future<CloudImportResult?> openCloudBrowser(
  BuildContext context,
  WidgetRef ref, {
  required CloudKind kind,
  String? importFolderId,
}) async {
  final l10n = context.l10n;
  final cloud = ref.read(cloudStorageProvider);

  if (!cloud.canAttempt(kind)) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.cloudOAuthSetupTitle),
          content: Text(l10n.cloudOAuthNotConfigured),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
    }
    return null;
  }

  try {
    final connected = await cloud.isConnected(kind);
    if (!connected) {
      if (!context.mounted) return null;
      await cloud.connect(kind);
    }
    if (!context.mounted) return null;
    final added = await Navigator.of(context).push<CloudImportResult>(
      MaterialPageRoute<CloudImportResult>(
        builder: (_) =>
            CloudBrowserScreen(kind: kind, importFolderId: importFolderId),
      ),
    );
    if (added != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.songAdded(added.title))));
    }
    return added;
  } on CloudNotConfiguredException {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.cloudOAuthNotConfigured)));
    }
    return null;
  } on CloudAuthException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
    return null;
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pickFailed)));
    }
    return null;
  }
}
