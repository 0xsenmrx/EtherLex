import '../../files/domain/files_models.dart';

/// Most files attached in one go (ticked files and folders together).
const int kMaxAttachFiles = 10;

/// How many folder levels below a ticked folder are searched.
const int kMaxFolderDepth = 6;

/// Most folders looked into for one attach, so a huge tree cannot freeze the app.
const int kMaxFoldersVisited = 200;

/// What ticking files and folders adds up to.
class CollectedFiles {
  const CollectedFiles({
    required this.files,
    this.skipped = const [],
    this.notes = const [],
  });

  /// The files to attach, at most the limit, each once.
  final List<FileEntry> files;

  /// Files found in folders that cannot be attached, with the reason.
  final List<({FileEntry file, String reason})> skipped;

  /// Words for the student when a limit stopped the search.
  final List<String> notes;
}

/// The files to attach for the ticked [fileIds] and [folderIds] of [data].
///
/// A folder gives the files directly in it, and with [includeSubfolders] the
/// files of its subfolders too, breadth first, so the nearest files come
/// first. The search is bounded three ways: [maxFiles] files, [maxDepth]
/// levels and [maxFolders] folders; every folder is visited once, so a folder
/// that lists itself as its own parent cannot loop. Folders in [skipFolders]
/// (hidden ones) are never entered. [problemOf] says why a file cannot be
/// attached (null when it can); those are reported in [CollectedFiles.skipped]
/// and do not use up the limit.
CollectedFiles collectFiles(
  CourseFiles data, {
  Set<int> fileIds = const {},
  Set<int> folderIds = const {},
  bool includeSubfolders = false,
  Set<int> skipFolders = const {},
  String? Function(FileEntry file)? problemOf,
  int maxFiles = kMaxAttachFiles,
  int maxDepth = kMaxFolderDepth,
  int maxFolders = kMaxFoldersVisited,
}) {
  final byId = {for (final f in data.files) f.id: f};
  final children = <int, List<FolderNode>>{};
  final known = <int>{for (final f in data.folders) f.id};
  for (final f in data.folders) {
    final p = f.parentId;
    if (p != null) (children[p] ??= []).add(f);
  }
  final filesIn = <int, List<FileEntry>>{};
  for (final f in data.files) {
    (filesIn[f.folderId] ??= []).add(f);
  }
  int byName(FileEntry a, FileEntry b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());

  final out = <FileEntry>[];
  final taken = <int>{};
  final skipped = <({FileEntry file, String reason})>[];
  var hitFiles = false, hitDepth = false, hitFolders = false;

  // Files ticked one by one come first, in the order of the course listing.
  for (final f in data.files) {
    if (!fileIds.contains(f.id) || !byId.containsKey(f.id)) continue;
    if (out.length >= maxFiles) {
      hitFiles = true;
      break;
    }
    if (taken.add(f.id)) out.add(f);
  }

  final visited = <int>{};
  final queue = <({int id, int depth})>[
    for (final id in folderIds)
      if (known.contains(id) && !skipFolders.contains(id)) (id: id, depth: 0),
  ];
  var head = 0;
  while (head < queue.length && !hitFiles) {
    final (:id, :depth) = queue[head++];
    if (!visited.add(id)) continue;
    if (visited.length > maxFolders) {
      hitFolders = true;
      break;
    }
    final here = [...?filesIn[id]]..sort(byName);
    for (final f in here) {
      if (taken.contains(f.id)) continue;
      final why = problemOf?.call(f);
      if (why != null) {
        skipped.add((file: f, reason: why));
        continue;
      }
      if (out.length >= maxFiles) {
        hitFiles = true;
        break;
      }
      taken.add(f.id);
      out.add(f);
    }
    if (hitFiles || !includeSubfolders) continue;
    final subs = [...?children[id]]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (subs.isNotEmpty && depth >= maxDepth) {
      hitDepth = true;
      continue;
    }
    for (final s in subs) {
      if (!skipFolders.contains(s.id) && !visited.contains(s.id)) queue.add((id: s.id, depth: depth + 1));
    }
  }

  return CollectedFiles(
    files: out,
    skipped: skipped,
    notes: [
      if (hitFiles) 'Stopped at $maxFiles files. Attach the rest in a second go.',
      if (hitDepth) 'Folders more than $maxDepth levels down were left out.',
      if (hitFolders) 'Stopped after $maxFolders folders; pick a smaller folder.',
    ],
  );
}
