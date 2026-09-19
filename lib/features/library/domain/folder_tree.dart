import 'package:page_a_diddle/core/database/app_database.dart';

/// Root folders are depth 0. Depth 2 is the deepest allowed subfolder.
const maxFolderDepth = 2;

class FolderNode {
  const FolderNode({required this.folder, this.children = const []});

  final Folder folder;
  final List<FolderNode> children;

  bool get hasChildren => children.isNotEmpty;
}

/// Builds a Finder-style forest from a flat folder list.
List<FolderNode> buildFolderForest(List<Folder> folders) {
  final byParent = <String?, List<Folder>>{};
  for (final folder in folders) {
    byParent.putIfAbsent(folder.parentId, () => []).add(folder);
  }
  for (final list in byParent.values) {
    list.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  FolderNode build(Folder folder) {
    final kids = byParent[folder.id] ?? const <Folder>[];
    return FolderNode(
      folder: folder,
      children: [for (final child in kids) build(child)],
    );
  }

  final roots = byParent[null] ?? const <Folder>[];
  return [for (final root in roots) build(root)];
}

/// Depth-first flat rows for dropdowns / pickers.
List<(Folder folder, int depth)> flattenFolderForest(List<FolderNode> forest) {
  final rows = <(Folder, int)>[];
  void walk(FolderNode node, int depth) {
    rows.add((node.folder, depth));
    for (final child in node.children) {
      walk(child, depth + 1);
    }
  }

  for (final root in forest) {
    walk(root, 0);
  }
  return rows;
}

int? folderDepthInForest(List<FolderNode> forest, String folderId) {
  for (final (folder, depth) in flattenFolderForest(forest)) {
    if (folder.id == folderId) return depth;
  }
  return null;
}

bool canCreateSubfolderAtDepth(int parentDepth) {
  return parentDepth + 1 <= maxFolderDepth;
}

String indentedFolderLabel(String name, int depth) {
  if (depth <= 0) return name;
  return '${'  ' * depth}$name';
}
