import '../domain/files_models.dart';

FolderNode? parseFolder(Map<String, dynamic> j) {
  final id = j['id'];
  final name = j['name'];
  if (id is! num || name is! String) return null;
  final parent = j['parent_folder_id'];
  return FolderNode(id: id.toInt(), name: name, parentId: parent is num ? parent.toInt() : null);
}

/// Files the user cannot open (locked) are skipped.
FileEntry? parseFile(Map<String, dynamic> j, {required int courseId}) {
  final id = j['id'];
  final folderId = j['folder_id'];
  if (id is! num || folderId is! num) return null;
  if (j['locked_for_user'] == true) return null;
  final name = (j['display_name'] ?? j['filename']);
  if (name is! String || name.isEmpty) return null;
  final updated = j['modified_at'] ?? j['updated_at'];
  final url = j['url'];
  return FileEntry(
    id: id.toInt(),
    folderId: folderId.toInt(),
    name: name,
    size: (j['size'] as num?)?.toInt() ?? 0,
    mime: (j['content-type'] ?? j['mime_class'] ?? '') as String,
    updatedAt: updated is String ? DateTime.tryParse(updated)?.toLocal() : null,
    url: url is String && url.isNotEmpty ? url : null,
    courseId: courseId,
  );
}
