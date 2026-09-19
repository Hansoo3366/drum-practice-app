import 'package:flutter/material.dart';
import 'package:page_a_diddle/app/icons/brand_marks.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/core/storage/storage_provider.dart';

enum ImportSource { device, googleDrive, dropbox, webDav }

extension ImportSourceX on ImportSource {
  StorageProvider get storageProvider => switch (this) {
    ImportSource.device => StorageProvider.osFileProvider,
    ImportSource.googleDrive => StorageProvider.googleDrive,
    ImportSource.dropbox => StorageProvider.dropbox,
    ImportSource.webDav => StorageProvider.webDav,
  };

  bool get usesCloudOAuth => switch (this) {
    ImportSource.googleDrive || ImportSource.dropbox => true,
    ImportSource.device || ImportSource.webDav => false,
  };
}

Future<ImportSource?> showImportSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImportSource>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => const _ImportSourceSheet(),
  );
}

class _ImportSourceSheet extends StatelessWidget {
  const _ImportSourceSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.import,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                children: [
                  _SourceTile(
                    mark: BrandMarks.device(),
                    label: l10n.importFromDevice,
                    onTap: () => Navigator.pop(context, ImportSource.device),
                  ),
                  _SourceTile(
                    mark: BrandMarks.googleDrive(),
                    label: l10n.importFromGoogleDrive,
                    onTap: () =>
                        Navigator.pop(context, ImportSource.googleDrive),
                  ),
                  _SourceTile(
                    mark: BrandMarks.dropbox(),
                    label: l10n.importFromDropbox,
                    onTap: () => Navigator.pop(context, ImportSource.dropbox),
                  ),
                  _SourceTile(
                    mark: BrandMarks.webDav(),
                    label: l10n.importFromWebDav,
                    subtitle: l10n.importWebDavViaApp,
                    onTap: () => Navigator.pop(context, ImportSource.webDav),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.mark,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final Widget mark;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: mark,
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
