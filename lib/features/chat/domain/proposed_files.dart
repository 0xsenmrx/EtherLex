import 'dart:convert';

import '../../courses/domain/course.dart';
import '../../files/domain/files_models.dart';
import '../../grades/domain/plan_proposal.dart';

/// The word after the opening fence of the block the assistant writes when it
/// proposes something about files: hiding a folder, saving for offline use,
/// downloading.
const String kFilesFence = 'etherlex-files';

enum FileActionKind {
  /// Hide a folder in the Files tab (or show it again).
  hideFolder,

  /// Save a folder, a whole course or one file on this computer so it opens without Canvas.
  offline,

  /// Save one file into the Downloads folder.
  download,

  /// Hide a whole course in the Files tab (or show it again). The course stays everywhere else.
  hideCourse,
}

class FileAction {
  const FileAction({required this.kind, required this.course, this.folder, this.file, this.value = true});

  final FileActionKind kind;

  /// The course as the assistant wrote it; matched against the real ones.
  final String course;

  /// Folder name or path ("Lectures" or "Lectures/Week 1"). Null for a whole course.
  final String? folder;

  /// A file name (download, or offline for one file).
  final String? file;

  /// hideFolder / hideCourse: true = hide, false = show again.
  final bool value;
}

class FilesProposal {
  const FilesProposal({required this.actions, this.note});

  final List<FileAction> actions;
  final String? note;
}

String? _text(Object? v, {int max = 160}) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty || t.length > max ? null : t;
}

/// Reads and checks the JSON inside the block; null if it is not usable (the
/// chat then shows plain code). Anything unknown makes the whole block invalid.
FilesProposal? parseFileActions(String source) {
  final Object? j;
  try {
    j = jsonDecode(source);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final raw = j['files'];
  if (raw is! List || raw.isEmpty || raw.length > 12) return null;
  final out = <FileAction>[];
  for (final r in raw) {
    if (r is! Map) return null;
    final course = _text(r['course']);
    if (course == null) return null;
    final folder = r['folder'] == null ? null : _text(r['folder']);
    final file = r['file'] == null ? null : _text(r['file']);
    if ((r['folder'] != null && folder == null) || (r['file'] != null && file == null)) return null;
    switch (r['type']) {
      case 'hide_folder':
        final value = r['value'] ?? true;
        if (folder == null || file != null || value is! bool) return null;
        out.add(FileAction(kind: FileActionKind.hideFolder, course: course, folder: folder, value: value));
      case 'hide_course':
        final value = r['value'] ?? true;
        if (folder != null || file != null || value is! bool) return null;
        out.add(FileAction(kind: FileActionKind.hideCourse, course: course, value: value));
      case 'offline':
        out.add(FileAction(kind: FileActionKind.offline, course: course, folder: folder, file: file));
      case 'download':
        if (file == null) return null;
        out.add(FileAction(kind: FileActionKind.download, course: course, folder: folder, file: file));
      default:
        return null;
    }
  }
  final note = j['note'];
  return FilesProposal(actions: out, note: note is String && note.trim().isNotEmpty ? note.trim() : null);
}

/// Every folder [path] could mean in [data]. "A/B" follows the tree from the
/// course's top; a plain name may sit anywhere.
List<FolderNode> folderMatches(CourseFiles data, String path) {
  final parts = [for (final p in path.split('/')) if (normalizeName(p).isNotEmpty) normalizeName(p)];
  if (parts.isEmpty) return const [];
  final byId = {for (final f in data.folders) f.id: f};
  final inner = data.folders.where((f) => f.parentId != null); // the top one is the course itself
  bool matches(FolderNode f) {
    FolderNode? node = f;
    for (var i = parts.length - 1; i >= 0; i--) {
      // The top folder is the course itself, never a match.
      if (node == null || node.parentId == null || normalizeName(node.name) != parts[i]) return false;
      node = byId[node.parentId];
    }
    return true;
  }

  return inner.where(matches).toList();
}

/// The one folder [path] means, or null when none or several fit.
FolderNode? resolveFolder(CourseFiles data, String path) {
  final found = folderMatches(data, path);
  return found.length == 1 ? found.single : null;
}

/// "Lectures/Week 1": the folder's place in the course, without the course's own top folder.
String folderPath(CourseFiles data, FolderNode folder) {
  final byId = {for (final f in data.folders) f.id: f};
  final names = <String>[];
  FolderNode? node = folder;
  final seen = <int>{};
  while (node != null && node.parentId != null && seen.add(node.id)) {
    names.add(node.name);
    node = byId[node.parentId];
  }
  return names.reversed.join('/');
}

/// Every folder id at or below [root], for "this folder and what is inside".
Set<int> folderTree(CourseFiles data, int root) {
  final ids = {root};
  var grew = true;
  while (grew) {
    grew = false;
    for (final f in data.folders) {
      if (f.parentId != null && ids.contains(f.parentId) && ids.add(f.id)) grew = true;
    }
  }
  return ids;
}

/// The files [name] could mean: those named exactly that (ignoring case and
/// punctuation), else those whose name contains it.
List<FileEntry> fileMatches(List<FileEntry> files, String name) {
  final n = normalizeName(name);
  if (n.isEmpty) return const [];
  final exact = files.where((f) => normalizeName(f.name) == n).toList();
  if (exact.isNotEmpty) return exact;
  return n.length >= 4 ? files.where((f) => normalizeName(f.name).contains(n)).toList() : const [];
}

/// The one file [name] means, or null when none or several fit.
FileEntry? resolveFile(List<FileEntry> files, String name) {
  final found = fileMatches(files, name);
  return found.length == 1 ? found.single : null;
}

enum FileEffect { change, same, unknown, loading }

enum PickKind { course, folder, file }

/// One thing to choose from on a skipped line.
class PickOption {
  const PickOption({required this.id, required this.label, this.sub = ''});

  final int id;
  final String label;
  final String sub;
}

class FileLine {
  const FileLine({
    required this.action,
    required this.label,
    required this.detail,
    required this.effect,
    this.note = '',
    this.courseId,
    this.folderId,
    this.files = const [],
    this.pick,
    this.options = const [],
  });

  final FileAction action;

  /// When this line is skipped because several things fit (or the course is
  /// unknown), what the student can choose between, and what is being chosen.
  final PickKind? pick;
  final List<PickOption> options;

  /// "Hide folder", "Save offline", "Download"...
  final String label;

  /// What it is about: "Physics II · Lectures".
  final String detail;
  final FileEffect effect;

  /// Why it is skipped, or what it will do ("12 files, 48 MB").
  final String note;
  final int? courseId;
  final int? folderId;

  /// offline / download: the files that would be fetched.
  final List<FileEntry> files;
}

String sizeText(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(bytes >= 10 << 20 ? 0 : 1)} MB';
  if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).round()} KB';
  return '$bytes B';
}

/// What applying [proposal] would do, line by line. [dataFor] gives a course's
/// listing (null while it is still loading or could not be loaded); [saved]
/// says whether a file is already on this computer. Nothing is guessed: a
/// course, folder or file that matches nothing is skipped, and one that several
/// things fit is skipped with the choices, which the student can pick from; a
/// pick (by the action's place in the list) is used in place of matching.
List<FileLine> previewFileActions(
  FilesProposal proposal,
  List<Course> courses, {
  required CourseFiles? Function(int courseId) dataFor,
  required Set<int> hiddenFolders,
  Set<int> hiddenCourses = const {},
  required bool Function(FileEntry) saved,
  Map<int, int> courseChoices = const {},
  Map<int, int> folderChoices = const {},
  Map<int, int> fileChoices = const {},
}) {
  final out = <FileLine>[];
  for (var index = 0; index < proposal.actions.length; index++) {
    final a = proposal.actions[index];
    final label = switch (a.kind) {
      FileActionKind.hideFolder => a.value ? 'Hide folder' : 'Show folder',
      FileActionKind.offline => 'Save offline',
      FileActionKind.download => 'Download',
      FileActionKind.hideCourse => a.value ? 'Hide in Files' : 'Show in Files',
    };
    final pickedCourse = courseChoices[index] == null ? null : courses.where((c) => c.id == courseChoices[index]).firstOrNull;
    final course = pickedCourse ?? matchCourse(a.course, courses);
    if (course == null) {
      final near = [for (final c in courses) if (normalizeName(c.name).contains(normalizeName(a.course)) || normalizeName(a.course).contains(normalizeName(c.name))) c];
      out.add(FileLine(
        action: a,
        label: label,
        detail: a.course,
        effect: FileEffect.unknown,
        note: 'no single course matches',
        pick: PickKind.course,
        options: [for (final c in (near.length > 1 ? near : courses)) PickOption(id: c.id, label: c.name, sub: c.code)],
      ));
      continue;
    }
    final where = course.shortLabel;
    if (a.kind == FileActionKind.hideCourse) {
      final hidden = hiddenCourses.contains(course.id);
      out.add(FileLine(
        action: a,
        label: label,
        detail: course.name,
        effect: hidden == a.value ? FileEffect.same : FileEffect.change,
        note: hidden == a.value ? 'already so' : '',
        courseId: course.id,
      ));
      continue;
    }
    final data = dataFor(course.id);
    if (data == null) {
      out.add(FileLine(action: a, label: label, detail: where, effect: FileEffect.loading, courseId: course.id, note: 'loading the files'));
      continue;
    }
    FolderNode? folder;
    if (a.folder != null) {
      final chosen = folderChoices[index] == null ? null : data.folders.where((f) => f.id == folderChoices[index]).firstOrNull;
      final found = folderMatches(data, a.folder!);
      folder = chosen ?? (found.length == 1 ? found.single : null);
      if (folder == null) {
        out.add(FileLine(
          action: a,
          label: label,
          detail: '$where · ${a.folder}',
          effect: FileEffect.unknown,
          courseId: course.id,
          note: found.isEmpty ? 'no folder matches' : '${found.length} folders match',
          pick: found.length > 1 ? PickKind.folder : null,
          options: [for (final f in found) PickOption(id: f.id, label: folderPath(data, f))],
        ));
        continue;
      }
    }
    final detail = [where, if (folder != null) folder.name, if (a.file != null) a.file!].join(' · ');
    switch (a.kind) {
      case FileActionKind.hideCourse:
        break; // handled above
      case FileActionKind.hideFolder:
        final hidden = hiddenFolders.contains(folder!.id);
        out.add(FileLine(
          action: a,
          label: label,
          detail: detail,
          effect: hidden == a.value ? FileEffect.same : FileEffect.change,
          note: hidden == a.value ? 'already so' : '',
          courseId: course.id,
          folderId: folder.id,
        ));
      case FileActionKind.offline:
      case FileActionKind.download:
        final pool = folder == null ? data.files : [for (final f in data.files) if (folderTree(data, folder.id).contains(f.folderId)) f];
        List<FileEntry> files;
        if (a.file != null) {
          final source = a.kind == FileActionKind.download && folder == null ? data.files : pool;
          final found = fileMatches(source, a.file!);
          final chosen = fileChoices[index] == null ? null : source.where((f) => f.id == fileChoices[index]).firstOrNull;
          if (chosen == null && found.length != 1) {
            final folderNames = {for (final f in data.folders) f.id: folderPath(data, f)};
            out.add(FileLine(
              action: a,
              label: label,
              detail: detail,
              effect: FileEffect.unknown,
              courseId: course.id,
              folderId: folder?.id,
              note: found.isEmpty ? 'no file matches' : '${found.length} files match',
              pick: found.length > 1 ? PickKind.file : null,
              options: [
                for (final f in found)
                  PickOption(id: f.id, label: f.name, sub: [if ((folderNames[f.folderId] ?? '').isNotEmpty) folderNames[f.folderId]!, sizeText(f.size)].join(' · ')),
              ],
            ));
            continue;
          }
          files = [chosen ?? found.single];
        } else {
          files = pool;
        }
        final todo = a.kind == FileActionKind.offline ? [for (final f in files) if (!saved(f)) f] : files;
        if (todo.isEmpty) {
          out.add(FileLine(
            action: a,
            label: label,
            detail: detail,
            effect: files.isEmpty ? FileEffect.unknown : FileEffect.same,
            note: files.isEmpty ? 'no files there' : 'already saved',
            courseId: course.id,
            folderId: folder?.id,
          ));
        } else {
          final bytes = todo.fold<int>(0, (s, f) => s + f.size);
          out.add(FileLine(
            action: a,
            label: label,
            detail: detail,
            effect: FileEffect.change,
            note: todo.length == 1 && a.file != null ? sizeText(bytes) : '${todo.length} files, ${sizeText(bytes)}',
            courseId: course.id,
            folderId: folder?.id,
            files: todo,
          ));
        }
    }
  }
  return out;
}
