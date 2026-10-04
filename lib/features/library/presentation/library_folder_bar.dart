import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_a_diddle/app/l10n/l10n.dart';
import 'package:page_a_diddle/app/theme/app_theme.dart';
import 'package:page_a_diddle/core/database/app_database.dart';
import 'package:page_a_diddle/features/library/data/folder_repository.dart';
import 'package:page_a_diddle/features/library/domain/folder_colors.dart';
import 'package:page_a_diddle/features/library/presentation/library_controller.dart';

/// Phone portrait: one row showing the current folder; opens a sheet to switch.
///
/// Pass [onFolderChanged] to bind a local folder filter (e.g. setlist picker)
/// instead of the global library folder filter.
class LibraryFolderSelector extends ConsumerWidget {
  const LibraryFolderSelector({
    super.key,
    this.selectedFolderId,
    this.onFolderChanged,
  });

  final String? selectedFolderId;
  final ValueChanged<String?>? onFolderChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(libraryFoldersProvider).asData?.value ?? const [];
    final colors = Theme.of(context).colorScheme;
    final selected = onFolderChanged != null
        ? selectedFolderId
        : ref.watch(libraryFolderFilterProvider);
    final showingAll = selected == null || selected == unfiledFolderFilterKey;

    Folder? current;
    if (!showingAll) {
      for (final folder in folders) {
        if (folder.id == selected) {
          current = folder;
          break;
        }
      }
    }

    final label = current?.name ?? l10n.allScores;
    final color = current == null
        ? colors.onSurfaceVariant
        : FolderColors.toColor(current.color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => showLibraryFolderBrowserSheet(
            context,
            selectedFolderId: selected,
            onSelected: onFolderChanged,
          ),
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(
                    current == null
                        ? Icons.library_music_outlined
                        : Icons.folder_rounded,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showLibraryFolderBrowserSheet(
  BuildContext context, {
  String? selectedFolderId,
  ValueChanged<String?>? onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _FolderBrowserSheet(
      selectedFolderId: selectedFolderId,
      onSelected: onSelected,
    ),
  );
}

class _FolderBrowserSheet extends ConsumerWidget {
  const _FolderBrowserSheet({this.selectedFolderId, this.onSelected});

  final String? selectedFolderId;
  final ValueChanged<String?>? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(libraryFoldersProvider).asData?.value ?? const [];
    final selected = onSelected != null
        ? selectedFolderId
        : ref.watch(libraryFolderFilterProvider);
    final showingAll = selected == null || selected == unfiledFolderFilterKey;

    void pick(String? folderId) {
      if (onSelected != null) {
        onSelected!(folderId);
      } else {
        ref.read(libraryFolderFilterProvider.notifier).update(folderId);
      }
      Navigator.pop(context);
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.folders,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showFolderEditorSheet(context),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: Text(l10n.newFolder),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: [
                _SidebarRow(
                  icon: Icons.library_music_outlined,
                  label: l10n.allScores,
                  selected: showingAll,
                  onTap: () => pick(null),
                ),
                for (final folder in folders)
                  _SidebarRow(
                    icon: Icons.folder_rounded,
                    iconColor: FolderColors.toColor(folder.color),
                    label: folder.name,
                    selected: selected == folder.id,
                    onTap: () => pick(folder.id),
                    onLongPress: () =>
                        showFolderEditorSheet(context, folder: folder),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical folder sidebar for wide / landscape layouts.
class LibraryFolderSidebar extends ConsumerWidget {
  const LibraryFolderSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(libraryFoldersProvider).asData?.value ?? const [];
    final selected = ref.watch(libraryFolderFilterProvider);
    final colors = Theme.of(context).colorScheme;
    final showingAll = selected == null || selected == unfiledFolderFilterKey;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.folders,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.newFolder,
                  onPressed: () => showFolderEditorSheet(context),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: [
                _SidebarRow(
                  icon: Icons.library_music_outlined,
                  label: l10n.allScores,
                  selected: showingAll,
                  onTap: () => ref
                      .read(libraryFolderFilterProvider.notifier)
                      .update(null),
                ),
                for (final folder in folders)
                  _SidebarRow(
                    icon: Icons.folder_rounded,
                    iconColor: FolderColors.toColor(folder.color),
                    label: folder.name,
                    selected: selected == folder.id,
                    onTap: () => ref
                        .read(libraryFolderFilterProvider.notifier)
                        .update(folder.id),
                    onLongPress: () =>
                        showFolderEditorSheet(context, folder: folder),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconColor,
    this.onLongPress,
  });

  final IconData icon;
  final Color? iconColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(
                  icon,
                  size: 18,
                  color:
                      iconColor ??
                      (selected ? AppColors.ink : colors.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                      color: selected ? AppColors.ink : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Result of [showLibraryFolderPicker]. [folderId] is null for no folder.
class LibraryFolderPick {
  const LibraryFolderPick(this.folderId);

  final String? folderId;
}

Future<LibraryFolderPick?> showLibraryFolderPicker(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<LibraryFolderPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _FolderPickerSheet(title: title),
  );
}

class _FolderPickerSheet extends ConsumerWidget {
  const _FolderPickerSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final folders = ref.watch(libraryFoldersProvider).asData?.value ?? const [];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
              children: [
                _SidebarRow(
                  icon: Icons.folder_off_outlined,
                  label: l10n.noFolder,
                  selected: false,
                  onTap: () =>
                      Navigator.pop(context, const LibraryFolderPick(null)),
                ),
                for (final folder in folders)
                  _SidebarRow(
                    icon: Icons.folder_rounded,
                    iconColor: FolderColors.toColor(folder.color),
                    label: folder.name,
                    selected: false,
                    onTap: () =>
                        Navigator.pop(context, LibraryFolderPick(folder.id)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showFolderEditorSheet(BuildContext context, {Folder? folder}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _FolderEditorSheet(folder: folder),
  );
}

class _FolderEditorSheet extends ConsumerStatefulWidget {
  const _FolderEditorSheet({this.folder});

  final Folder? folder;

  @override
  ConsumerState<_FolderEditorSheet> createState() => _FolderEditorSheetState();
}

class _FolderEditorSheetState extends ConsumerState<_FolderEditorSheet> {
  late final TextEditingController _nameController;
  late int _color;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder?.name ?? '');
    _color = FolderColors.normalize(widget.folder?.color);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) {
      if (name.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.folderNameRequired)),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(folderRepositoryProvider);
      if (widget.folder == null) {
        await repo.createFolder(name: name, color: _color);
      } else {
        await repo.updateFolder(
          id: widget.folder!.id,
          name: name,
          color: _color,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Object catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.saveFailed)));
      }
    }
  }

  Future<void> _delete() async {
    final folder = widget.folder;
    if (folder == null) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteFolder),
        content: Text(l10n.deleteFolderBody),
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
    await ref.read(folderRepositoryProvider).deleteFolder(folder.id);
    final selected = ref.read(libraryFolderFilterProvider);
    if (selected == folder.id) {
      ref.read(libraryFolderFilterProvider.notifier).update(null);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editing = widget.folder != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing ? l10n.editFolder : l10n.newFolder,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.folderName,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.folderColor,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in FolderColors.palette)
                InkWell(
                  onTap: () => setState(() => _color = color),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: FolderColors.toColor(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == color
                            ? AppColors.ink
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.saving : l10n.save),
          ),
          if (editing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: Text(l10n.deleteFolder),
            ),
          ],
        ],
      ),
    );
  }
}
