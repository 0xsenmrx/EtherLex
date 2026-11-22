import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../courses/domain/course.dart';
import '../../files/domain/files_models.dart';
import '../../files/presentation/file_actions.dart';
import '../../files/presentation/files_providers.dart';
import '../../grades/domain/plan_proposal.dart';
import '../domain/proposed_files.dart';
import 'choice_pick.dart';

/// What was applied from a files card, and how to put the folder changes back.
/// Saved and downloaded files stay: Undo only covers hiding and showing folders.
class AppliedFiles {
  const AppliedFiles({required this.lines, required this.hideUndo, this.courseUndo = const {}});

  final List<FileLine> lines;

  /// Folder id -> hidden before.
  final Map<int, bool> hideUndo;

  /// Course id -> hidden in Files before.
  final Map<int, bool> courseUndo;
}

class AppliedFilesNotifier extends Notifier<Map<String, AppliedFiles>> {
  @override
  Map<String, AppliedFiles> build() {
    ref.watch(settingsStoreProvider); // starts over with the account
    return const {};
  }

  void mark(String key, AppliedFiles a) => state = {...state, key: a};

  void clear(String key) => state = {...state}..remove(key);
}

final appliedFilesProvider = NotifierProvider<AppliedFilesNotifier, Map<String, AppliedFiles>>(AppliedFilesNotifier.new);

/// Folders to hide or show, files to save for offline use or download, as a
/// card: each with what would happen and an Apply button. Nothing is done
/// until it is pressed, and saving or downloading says how much first.
class FilesCard extends ConsumerStatefulWidget {
  const FilesCard({super.key, required this.proposal, required this.source});

  final FilesProposal proposal;
  final String source;

  @override
  ConsumerState<FilesCard> createState() => _FilesCardState();
}

class _FilesCardState extends ConsumerState<FilesCard> {
  bool _busy = false;

  /// What the student picked on skipped lines: place in the list -> id.
  final Map<int, int> _courseChoices = {};
  final Map<int, int> _folderChoices = {};
  final Map<int, int> _fileChoices = {};

  Future<void> _choose(int index, FileLine l) async {
    final kind = l.pick!;
    final title = switch (kind) {
      PickKind.course => 'Which course?',
      PickKind.folder => 'Which folder?',
      PickKind.file => 'Which file?',
    };
    final id = await pickChoice(context, title, l.options);
    if (id == null || !mounted) return;
    setState(() {
      switch (kind) {
        case PickKind.course:
          _courseChoices[index] = id;
        case PickKind.folder:
          _folderChoices[index] = id;
        case PickKind.file:
          _fileChoices[index] = id;
      }
    });
  }

  List<FileLine> _lines(List<Course> courses) {
    final repo = ref.read(filesRepositoryProvider);
    final data = <int, CourseFiles?>{};
    final actions = widget.proposal.actions;
    for (var i = 0; i < actions.length; i++) {
      final picked = _courseChoices[i] == null ? null : courses.where((c) => c.id == _courseChoices[i]).firstOrNull;
      final course = picked ?? matchCourse(actions[i].course, courses);
      if (course != null && !data.containsKey(course.id)) data[course.id] = ref.watch(courseFilesProvider(course.id)).value;
    }
    return previewFileActions(
      widget.proposal,
      courses,
      dataFor: (id) => data[id],
      hiddenFolders: ref.watch(hiddenFoldersProvider),
      hiddenCourses: ref.watch(hiddenFileCoursesProvider),
      saved: (f) => repo.cachedPath(f) != null,
      courseChoices: _courseChoices,
      folderChoices: _folderChoices,
      fileChoices: _fileChoices,
    );
  }

  Future<void> _apply(List<FileLine> lines) async {
    if (_busy) return;
    final todo = [for (final l in lines) if (l.effect == FileEffect.change) l];
    final fetch = [for (final l in todo) if (l.action.kind != FileActionKind.hideFolder) ...l.files];
    if (fetch.isNotEmpty) {
      final bytes = fetch.fold<int>(0, (s, f) => s + f.size);
      final ok = await confirmAction(
        context,
        title: 'Get ${fetch.length} ${fetch.length == 1 ? 'file' : 'files'} (${sizeText(bytes)})?',
        message: 'Saving for offline use keeps them on this computer (up to 3 GB, the oldest are removed first). '
            'Downloads go to your Downloads folder. This only reads from Canvas.',
        confirmLabel: 'Get files',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final hiddenNow = ref.read(hiddenFoldersProvider);
    final folders = ref.read(hiddenFoldersProvider.notifier);
    final undo = <int, bool>{};
    final courseUndo = <int, bool>{};
    final hiddenCoursesNow = ref.read(hiddenFileCoursesProvider);
    final fileCourses = ref.read(hiddenFileCoursesProvider.notifier);
    try {
      for (final l in todo) {
        switch (l.action.kind) {
          case FileActionKind.hideFolder:
            undo.putIfAbsent(l.folderId!, () => hiddenNow.contains(l.folderId));
            l.action.value ? folders.hide(l.folderId!) : folders.show(l.folderId!);
          case FileActionKind.hideCourse:
            courseUndo.putIfAbsent(l.courseId!, () => hiddenCoursesNow.contains(l.courseId));
            l.action.value ? fileCourses.hide(l.courseId!) : fileCourses.show(l.courseId!);
          case FileActionKind.offline:
            await saveOffline(ref, l.files);
          case FileActionKind.download:
            for (final f in l.files) {
              await downloadWithToast(ref, f);
            }
        }
        if (!mounted) break;
      }
      ref.read(appliedFilesProvider.notifier).mark(widget.source, AppliedFiles(lines: lines, hideUndo: undo, courseUndo: courseUndo));
    } catch (_) {
      // Whatever was done stays; the button can be pressed again for the rest.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _undo(AppliedFiles a) {
    final folders = ref.read(hiddenFoldersProvider.notifier);
    for (final e in a.hideUndo.entries) {
      e.value ? folders.hide(e.key) : folders.show(e.key);
    }
    final fileCourses = ref.read(hiddenFileCoursesProvider.notifier);
    for (final e in a.courseUndo.entries) {
      e.value ? fileCourses.hide(e.key) : fileCourses.show(e.key);
    }
    ref.read(appliedFilesProvider.notifier).clear(widget.source);
  }

  static String _note(FileLine l) => switch (l.effect) {
        FileEffect.change => l.note,
        FileEffect.same => l.note,
        FileEffect.unknown => l.pick != null ? l.note : '${l.note}, skipped',
        FileEffect.loading => l.note,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final applied = ref.watch(appliedFilesProvider)[widget.source];
    final lines = applied?.lines ?? _lines(courses);
    final changes = lines.where((l) => l.effect == FileEffect.change).length;
    final skipped = lines.where((l) => l.effect == FileEffect.unknown || l.effect == FileEffect.same).length;
    final loading = lines.any((l) => l.effect == FileEffect.loading);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.sunken, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(EIcons.sparkles, size: 16, color: c.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(applied == null ? 'Proposed file changes' : 'File changes', style: t.label)),
            ],
          ),
          const SizedBox(height: 8),
          for (final (index, l) in lines.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      l.label,
                      style: t.label.copyWith(color: l.effect == FileEffect.change ? c.textPrimary : c.textTertiary),
                    ),
                  ),
                  Expanded(
                    child: Text(l.detail, style: l.effect == FileEffect.change ? t.body : t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (_note(l).isNotEmpty) ...[const SizedBox(width: 8), Text(_note(l), style: t.metaMuted)],
                  if (applied == null && l.pick != null && l.options.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    EButton(label: 'Choose', kind: EButtonKind.ghost, onTap: () => _choose(index, l)),
                  ],
                ],
              ),
            ),
          if (widget.proposal.note != null) ...[
            const SizedBox(height: 6),
            Text(widget.proposal.note!, style: t.metaMuted),
          ],
          const SizedBox(height: 10),
          Container(height: 1, color: c.line),
          const SizedBox(height: 10),
          if (applied == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    loading
                        ? 'Loading the course files...'
                        : changes == 0
                            ? 'Nothing here would change anything.'
                            : skipped == 0
                                ? 'Nothing happens until you press Apply.'
                                : 'Nothing happens until you press Apply. $skipped will be skipped.',
                    style: t.metaMuted,
                  ),
                ),
                const SizedBox(width: 12),
                EButton(
                  label: changes == 1 ? 'Apply 1 change' : 'Apply $changes changes',
                  icon: EIcons.check,
                  kind: EButtonKind.primary,
                  loading: _busy,
                  onTap: changes == 0 || loading ? null : () => _apply(lines),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(EIcons.check, size: 15, color: c.success),
                const SizedBox(width: 6),
                Expanded(child: Text('Applied $changes ${changes == 1 ? 'change' : 'changes'}', style: t.label)),
                if (applied.hideUndo.isNotEmpty || applied.courseUndo.isNotEmpty) EButton(label: 'Undo hiding', kind: EButtonKind.ghost, onTap: () => _undo(applied)),
              ],
            ),
        ],
      ),
    );
  }
}
