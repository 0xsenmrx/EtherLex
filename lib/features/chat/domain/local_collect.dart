import 'file_collect.dart';

/// What a path on the computer is, for attaching.
enum LocalKind { file, folder, skip }

/// The computer's disk, as little as [collectLocal] needs (a fake in tests).
abstract interface class LocalDisk {
  /// A file, a folder, or [LocalKind.skip] for anything else: shortcuts and
  /// links (they could point anywhere or loop), devices, missing paths.
  Future<LocalKind> kindOf(String path);

  Future<int> sizeOf(String file);

  /// Full paths of the files and of the folders directly inside [folder].
  /// Links, hidden items and system folders are left out by the implementation.
  Future<({List<String> files, List<String> folders})> list(String folder);
}

/// The last part of a path (Windows or other separators).
String fileNameOf(String path) {
  final parts = path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty);
  return parts.isEmpty ? path : parts.last;
}

class CollectedLocal {
  const CollectedLocal({required this.files, this.skipped = const [], this.notes = const []});

  final List<String> files;
  final List<({String path, String reason})> skipped;
  final List<String> notes;
}

/// The files to attach for [roots] (dropped or picked files and folders).
///
/// A folder gives its files and, breadth first, those of its subfolders, so
/// the nearest come first. Bounded like [collectFiles]: [maxFiles] files,
/// [maxDepth] levels, [maxFolders] folders, each folder once. [problemOf]
/// says why a file cannot be attached (null when it can); those are reported
/// in [CollectedLocal.skipped] and do not use up the limit.
Future<CollectedLocal> collectLocal(
  LocalDisk disk,
  List<String> roots, {
  String? Function(String name, int size)? problemOf,
  int maxFiles = kMaxAttachFiles,
  int maxDepth = kMaxFolderDepth,
  int maxFolders = kMaxFoldersVisited,
}) async {
  final out = <String>[];
  final taken = <String>{};
  final skipped = <({String path, String reason})>[];
  var hitFiles = false, hitDepth = false, hitFolders = false;

  Future<void> offer(String path) async {
    if (taken.contains(path)) return;
    final name = fileNameOf(path);
    final why = problemOf?.call(name, await disk.sizeOf(path));
    if (why != null) {
      skipped.add((path: path, reason: why));
      return;
    }
    if (out.length >= maxFiles) {
      hitFiles = true;
      return;
    }
    taken.add(path);
    out.add(path);
  }

  final queue = <({String path, int depth})>[];
  for (final r in roots) {
    switch (await disk.kindOf(r)) {
      case LocalKind.file:
        await offer(r);
      case LocalKind.folder:
        queue.add((path: r, depth: 0));
      case LocalKind.skip:
        skipped.add((path: r, reason: 'a shortcut, link or something else that cannot be attached'));
    }
  }

  final visited = <String>{};
  var head = 0;
  while (head < queue.length && !hitFiles) {
    final (:path, :depth) = queue[head++];
    if (!visited.add(path)) continue;
    if (visited.length > maxFolders) {
      hitFolders = true;
      break;
    }
    final here = await disk.list(path);
    final files = [...here.files]..sort((a, b) => fileNameOf(a).toLowerCase().compareTo(fileNameOf(b).toLowerCase()));
    for (final f in files) {
      await offer(f);
      if (hitFiles) break;
    }
    if (hitFiles) break;
    final subs = [...here.folders]..sort((a, b) => fileNameOf(a).toLowerCase().compareTo(fileNameOf(b).toLowerCase()));
    if (subs.isNotEmpty && depth >= maxDepth) {
      hitDepth = true;
      continue;
    }
    for (final s in subs) {
      if (!visited.contains(s)) queue.add((path: s, depth: depth + 1));
    }
  }

  return CollectedLocal(
    files: out,
    skipped: skipped,
    notes: [
      if (hitFiles) 'Stopped at $maxFiles files. Attach the rest in a second go.',
      if (hitDepth) 'Folders more than $maxDepth levels down were left out.',
      if (hitFolders) 'Stopped after $maxFolders folders; pick a smaller folder.',
    ],
  );
}
