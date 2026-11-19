import 'files_models.dart';

class FolderView {
  const FolderView({
    required this.current,
    required this.breadcrumb,
    required this.folders,
    required this.files,
  });

  /// The folder being shown (null if the course has no folder structure).
  final FolderNode? current;

  /// Path from just below the root down to [current].
  final List<FolderNode> breadcrumb;
  final List<FolderNode> folders;
  final List<FileEntry> files;
}

int _byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// What to show when the user is inside [folderId] (null = course root).
FolderView viewFolder(CourseFiles data, int? folderId) {
  final byId = {for (final f in data.folders) f.id: f};
  final root = data.folders.where((f) => f.parentId == null).firstOrNull;
  final current = (folderId == null ? null : byId[folderId]) ?? root;

  if (current == null) {
    final files = [...data.files]..sort((a, b) => _byName(a.name, b.name));
    return FolderView(current: null, breadcrumb: const [], folders: const [], files: files);
  }

  final crumbs = <FolderNode>[];
  final seen = <int>{};
  FolderNode? node = current;
  while (node != null && node.parentId != null && seen.add(node.id)) {
    crumbs.add(node);
    node = byId[node.parentId];
  }

  final folders = data.folders.where((f) => f.parentId == current.id).toList()
    ..sort((a, b) => _byName(a.name, b.name));
  final files = data.files.where((f) => f.folderId == current.id).toList()
    ..sort((a, b) => _byName(a.name, b.name));

  return FolderView(
    current: current,
    breadcrumb: crumbs.reversed.toList(),
    folders: folders,
    files: files,
  );
}
