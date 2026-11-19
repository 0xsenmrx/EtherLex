class FolderNode {
  const FolderNode({required this.id, required this.name, required this.parentId});
  final int id;
  final String name;
  final int? parentId;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'parent': parentId};

  static FolderNode? fromJson(Object? j) {
    if (j is! Map || j['id'] is! num || j['name'] is! String) return null;
    return FolderNode(id: (j['id'] as num).toInt(), name: j['name'] as String, parentId: (j['parent'] as num?)?.toInt());
  }
}

class FileEntry {
  const FileEntry({
    required this.id,
    required this.folderId,
    required this.name,
    required this.size,
    required this.mime,
    required this.updatedAt,
    required this.url,
    required this.courseId,
  });

  final int id;
  final int folderId;
  final String name;
  final int size;
  final String mime;
  final DateTime? updatedAt;
  final String? url;
  final int courseId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'folder': folderId,
        'name': name,
        'size': size,
        'mime': mime,
        'updated': updatedAt?.toUtc().toIso8601String(),
        'url': url,
        'course': courseId,
      };

  static FileEntry? fromJson(Object? j) {
    if (j is! Map || j['id'] is! num || j['name'] is! String) return null;
    final updated = j['updated'];
    return FileEntry(
      id: (j['id'] as num).toInt(),
      folderId: (j['folder'] as num?)?.toInt() ?? 0,
      name: j['name'] as String,
      size: (j['size'] as num?)?.toInt() ?? 0,
      mime: (j['mime'] as String?) ?? '',
      updatedAt: updated is String ? DateTime.tryParse(updated)?.toLocal() : null,
      url: j['url'] as String?,
      courseId: (j['course'] as num?)?.toInt() ?? 0,
    );
  }
}

class CourseFiles {
  const CourseFiles({required this.folders, required this.files, this.fromCache = false});
  final List<FolderNode> folders;
  final List<FileEntry> files;

  /// This is the last copy saved on this computer: Canvas could not be reached.
  final bool fromCache;

  CourseFiles asCached() => CourseFiles(folders: folders, files: files, fromCache: true);

  Map<String, dynamic> toJson() => {
        'folders': [for (final f in folders) f.toJson()],
        'files': [for (final f in files) f.toJson()],
      };

  static CourseFiles? fromJson(Object? j) {
    if (j is! Map) return null;
    final fo = j['folders'];
    final fi = j['files'];
    if (fo is! List || fi is! List) return null;
    return CourseFiles(
      folders: [for (final x in fo) ?FolderNode.fromJson(x)],
      files: [for (final x in fi) ?FileEntry.fromJson(x)],
    );
  }
}

/// Every file inside [folderId] and below (null = the whole course), leaving
/// out folders in [skip] and everything under them.
List<FileEntry> filesUnder(CourseFiles d, int? folderId, {Set<int> skip = const {}}) {
  final children = <int?, List<FolderNode>>{};
  for (final f in d.folders) {
    (children[f.parentId] ??= []).add(f);
  }
  final allowed = <int>{};
  void walk(FolderNode f) {
    if (skip.contains(f.id) || !allowed.add(f.id)) return;
    for (final c in children[f.id] ?? const <FolderNode>[]) {
      walk(c);
    }
  }

  if (folderId == null) {
    for (final r in children[null] ?? const <FolderNode>[]) {
      walk(r);
    }
    if (d.folders.isEmpty) return List.of(d.files);
  } else {
    for (final f in d.folders) {
      if (f.id == folderId) walk(f);
    }
    if (!allowed.contains(folderId) && d.folders.every((f) => f.id != folderId)) return const [];
  }
  return [for (final f in d.files) if (allowed.contains(f.folderId)) f];
}
