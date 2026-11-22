import '../../files/domain/files_models.dart';
import 'proposed_files.dart';

/// Most lines of a course's file tree sent to the assistant.
const int kMaxTreeLines = 400;

/// The course's folders and files as an indented tree, each folder with its
/// full path (the form the assistant writes back: "Lectures/Week 1"), what is
/// hidden marked, and files with their size. Long listings are cut and say so.
String fileTreeText(CourseFiles data, Set<int> hiddenFolders, {int maxLines = kMaxTreeLines}) {
  if (data.folders.isEmpty && data.files.isEmpty) return 'No files.';
  final lines = <String>[];
  final root = data.folders.where((f) => f.parentId == null).firstOrNull;
  int byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  void filesIn(int? folderId, String indent) {
    final files = data.files.where((f) => f.folderId == (folderId ?? 0)).toList()..sort((a, b) => byName(a.name, b.name));
    for (final f in files) {
      lines.add('$indent- ${f.name} (${sizeText(f.size)})');
    }
  }

  void walk(FolderNode folder, String path, String indent) {
    final subs = data.folders.where((f) => f.parentId == folder.id).toList()..sort((a, b) => byName(a.name, b.name));
    for (final sub in subs) {
      final p = path.isEmpty ? sub.name : '$path/${sub.name}';
      final count = data.files.where((f) => folderTree(data, sub.id).contains(f.folderId)).length;
      lines.add('$indent[folder] $p${hiddenFolders.contains(sub.id) ? ' (hidden)' : ''} · $count ${count == 1 ? 'file' : 'files'}');
      filesIn(sub.id, '$indent  ');
      walk(sub, p, '$indent  ');
    }
  }

  if (root == null) {
    filesIn(null, '');
  } else {
    filesIn(root.id, '');
    walk(root, '', '');
  }
  if (lines.length <= maxLines) return lines.join('\n');
  return '${lines.take(maxLines).join('\n')}\n[${lines.length - maxLines} more lines left out: ask about one folder to see more]';
}
