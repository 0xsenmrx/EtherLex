import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show Tooltip;

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart' show ECheck;
import '../../../design_system/ether/menu.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../activity/domain/activity_item.dart';
import '../../activity/presentation/activity_providers.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../../courses/domain/course.dart';
import '../../files/domain/files_models.dart';
import '../../files/domain/folder_view.dart';
import '../../../design_system/components/compact_field.dart';
import '../../files/presentation/files_providers.dart';
import '../../submission/domain/submission.dart';
import '../../submission/presentation/submission_providers.dart';
import '../../grades/presentation/grades_providers.dart';
import '../../viewer/data/file_text.dart';
import '../../viewer/domain/preview_kind.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/format.dart';
import '../domain/ai_settings.dart';
import '../domain/attach_rules.dart';
import '../domain/context_builders.dart';
import '../domain/context_item.dart';
import '../data/local_disk.dart';
import '../domain/file_collect.dart';
import '../domain/local_collect.dart';
import 'ai_consent.dart';
import 'ai_providers.dart';

/// Makes the item when the student picks it (some need a moment to load).
/// What a pick produced: the things to attach, and words for the student about
/// what could not be attached or was left out.
class AttachResult {
  const AttachResult(this.items, [this.notes = const []]);

  final List<ContextItem> items;
  final List<String> notes;
}

typedef ContextBuilder = Future<AttachResult> Function();

/// A builder for one item (or none).
ContextBuilder single(Future<ContextItem?> Function() make) => () async {
      final item = await make();
      return AttachResult([?item]);
    };

/// Asks, once per AI service and account, whether Canvas data may be sent to
/// it. True when it is allowed (now or before). Sample mode has no real
/// service, so it never asks.
Future<bool> ensureConsent(BuildContext context, WidgetRef ref) async {
  final session = ref.read(authProvider).value;
  if (session == null || session.isSample) return true;
  final settings = ref.read(aiSettingsProvider);
  final consent = ref.read(aiConsentProvider.notifier);
  if (consent.allows(settings)) {
    // Bind an old server-less yes to this server now.
    if (!ref.read(aiConsentProvider).contains(consentKeyFor(settings))) consent.grant(settings);
    return true;
  }
  final name = aiServiceName(settings);
  final ok = await confirmAction(
    context,
    title: 'Send Canvas data to $name?',
    message: 'What you attach (assignments, grades, announcements, files or pictures) is sent to '
        '$name together with your question, using your own API key. '
        'The names of your courses go along with every question, so it can find the one you mean. '
        'EtherLex sends nothing else. '
        'You can take this permission back in Settings.',
    confirmLabel: 'Allow',
  );
  if (ok) consent.grant(settings);
  return ok;
}

/// The "Attach from Canvas" list. Returns what to build, or null. [ref] is the
/// page's: what is built runs after the dialog has closed, so it must not use
/// the dialog's own.
Future<ContextBuilder?> pickContext(BuildContext context, WidgetRef ref) =>
    showEtherDialog<ContextBuilder>(context, (_) => _AttachDialog(ref), maxWidth: 520);

class _AttachDialog extends StatelessWidget {
  const _AttachDialog(this.ref);

  final WidgetRef ref;

  Widget _row(BuildContext context, {required IconData icon, required String title, String? subtitle, ContextBuilder? build, VoidCallback? onPick}) {
    final c = context.colors;
    final t = context.text;
    return ETap(
      onTap: onPick ?? () => Navigator.of(context).pop(build),
      builder: (context, s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: s.hovered ? c.hover : const Color(0x00000000), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) Text(subtitle, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Courses the student hid (for example one they teach) stay out, as everywhere else in the app.
    final disabled = ref.read(disabledCoursesProvider);
    List<Course> visibleCourses() => [
          for (final c in ref.read(coursesProvider).value ?? const <Course>[])
            if (!disabled.contains(c.id)) c,
        ];
    final courses = [...visibleCourses()]..sort((a, b) => a.shortLabel.toLowerCase().compareTo(b.shortLabel.toLowerCase()));

    Future<Course?> chooseCourse(String title) => showEtherDialog<Course>(context, (_) => _CourseChooser(title, courses), maxWidth: 480);

    return EDialog(
      title: 'Attach from Canvas',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EMenuCaption('At a glance'),
          _row(
            context,
            icon: EIcons.assignments,
            title: 'Open assignments',
            subtitle: 'Everything not done yet, with due dates',
            build: single(() async => openAssignmentsContext(
                  [
                    for (final a in ref.read(assignmentsProvider).value ?? const <Assignment>[])
                      if (!disabled.contains(a.courseId)) a,
                  ],
                  ref.read(coursesByIdProvider),
                )),
          ),
          _row(
            context,
            icon: EIcons.announcement,
            title: 'Recent announcements',
            subtitle: 'The latest ten',
            build: single(() async => recentAnnouncementsContext(
                  [
                    for (final a in ref.read(activityProvider).value ?? const <ActivityItem>[])
                      if (a.courseId == null || !disabled.contains(a.courseId)) a,
                  ],
                  ref.read(coursesByIdProvider),
                )),
          ),
          _row(
            context,
            icon: EIcons.grades,
            title: 'Grades overview',
            subtitle: 'Your current grade in each course',
            build: single(() async {
              // Grades are only fetched when the Grades page is opened; fetch them now if they were not.
              if (ref.read(courseGradesProvider).isEmpty) await ref.read(gradesSyncProvider.notifier).refresh();
              return gradesOverviewContext(visibleCourses(), ref.read(courseGradesProvider));
            }),
          ),
          if (courses.isNotEmpty)
            _row(
              context,
              icon: EIcons.grades,
              title: 'Grades of one course',
              subtitle: 'Every graded item and the weights',
              onPick: () async {
                final course = await chooseCourse('Grades of which course?');
                if (course == null || !context.mounted) return;
                Navigator.of(context).pop(single(() async {
                  final work = await ref.read(courseWorkProvider(course.id).future);
                  return courseGradesContext(course, ref.read(courseGradesProvider)[course.id], work.items, groups: work.groups);
                }));
              },
            ),
          const EMenuDivider(),
          const EMenuCaption('Files and pictures'),
          _row(
            context,
            icon: EIcons.fileImage,
            title: 'From this computer',
            subtitle: 'PDF, Word, PowerPoint, text, pictures. Pick several at once',
            build: () => _attachFromComputer(ref),
          ),
          _row(
            context,
            icon: EIcons.folderClosed,
            title: 'A folder from this computer',
            subtitle: 'Its files and those of its subfolders, up to $kMaxAttachFiles',
            build: () => _attachFolderFromComputer(ref),
          ),
          _row(
            context,
            icon: EIcons.assignments,
            title: 'Of an assignment',
            subtitle: 'Handouts linked in it, and its instructions',
            onPick: () async {
              final build = await showEtherDialog<ContextBuilder>(context, (_) => _AssignmentFilesDialog(ref), maxWidth: 520);
              if (build != null && context.mounted) Navigator.of(context).pop(build);
            },
          ),
          if (courses.isNotEmpty)
            _row(
              context,
              icon: EIcons.files,
              title: 'Of a course',
              subtitle: 'Syllabus, slides, notes. Tick files or whole folders',
              onPick: () async {
                final course = await chooseCourse('Files of which course?');
                if (course == null || !context.mounted) return;
                final build = await showEtherDialog<ContextBuilder>(context, (_) => _FilesDialog(ref, course), maxWidth: 520);
                if (build != null && context.mounted) Navigator.of(context).pop(build);
              },
            ),
        ],
      ),
      actions: [EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
    );
  }
}

/// Choose one of the courses.
class _CourseChooser extends StatelessWidget {
  const _CourseChooser(this.title, this.courses);

  final String title;
  final List<Course> courses;

  @override
  Widget build(BuildContext context) => EDialog(
        title: title,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in courses)
              _pickRow(
                context,
                icon: EIcons.files,
                title: c.shortLabel,
                subtitle: c.name == c.shortLabel ? null : c.name,
                onTap: () => Navigator.of(context).pop<Course>(c),
              ),
          ],
        ),
        actions: [EButton(label: 'Back', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
      );
}

/// Pictures and documents picked in the system file dialog, several at once.
Future<AttachResult> _attachFromComputer(WidgetRef ref) async {
  final picked = await openFiles(
    acceptedTypeGroups: [
      const XTypeGroup(label: 'Documents and pictures', extensions: [
        'pdf', 'docx', 'pptx', 'md', 'markdown', 'txt', 'csv', 'tex', 'png', 'jpg', 'jpeg', 'gif', 'webp',
      ]),
    ],
  );
  return attachLocalPaths(ref, [for (final x in picked) x.path]);
}

/// A folder picked in the system dialog: its files and those of its subfolders, within the limits.
Future<AttachResult> _attachFolderFromComputer(WidgetRef ref) async {
  final dir = await getDirectoryPath();
  if (dir == null) return const AttachResult([]);
  return attachLocalPaths(ref, [dir]);
}

/// Reads files and folders on this computer (picked, or dropped on the chat)
/// into things to attach. A folder gives its files and, nearest first, those of
/// its subfolders, bounded by [collectLocal]; links and hidden folders are not
/// entered. A file that cannot be read is reported and does not stop the others.
Future<AttachResult> attachLocalPaths(WidgetRef ref, List<String> paths, {LocalDisk disk = const IoLocalDisk()}) async {
  if (paths.isEmpty) return const AttachResult([]);
  final readsImages = ref.read(aiSettingsProvider).provider.readsImages;
  final found = await collectLocal(
    disk,
    paths,
    problemOf: (name, size) => attachProblemFor(name, size, readsImages: readsImages),
  );
  final items = <ContextItem>[];
  final problems = [
    ...found.notes,
    for (final s in found.skipped.take(5)) '${fileNameOf(s.path)}: ${s.reason}.',
    if (found.skipped.length > 5) '${found.skipped.length - 5} more could not be attached.',
  ];
  for (final path in found.files) {
    try {
      items.add(await contextForPath(path, fileNameOf(path)));
    } on AttachException catch (e) {
      problems.add(e.message);
    } catch (_) {
      problems.add('${fileNameOf(path)}: could not be read.');
    }
  }
  if (items.isEmpty) throw AttachException(problems.isEmpty ? 'There was nothing to attach.' : problems.join(' '));
  return AttachResult(items, problems);
}

/// Reads [file] (downloading it if needed) into something to attach.
Future<ContextItem> contextForFile(WidgetRef ref, FileEntry file) async {
  final String path;
  try {
    path = await ref.read(filesRepositoryProvider).localPath(file);
  } catch (_) {
    throw const AttachException('Could not download that file from Canvas. Check your connection and try again.', retryable: true);
  }
  return contextForPath(path, file.name, fileId: file.id);
}

/// Reads several Canvas files. One that cannot be read is reported in the
/// result's notes and does not stop the others; if none can be read it throws.
Future<AttachResult> contextForFiles(
  WidgetRef ref,
  List<FileEntry> files, {
  List<ContextItem> first = const [],
  List<String> notes = const [],
}) async {
  final items = [...first];
  final problems = [...notes];
  var retryable = false;
  for (final f in files) {
    try {
      items.add(await contextForFile(ref, f));
    } on AttachException catch (e) {
      problems.add('${f.name}: ${e.message}');
      retryable = retryable || e.retryable;
    } catch (_) {
      problems.add('${f.name}: could not be read.');
    }
  }
  if (items.isEmpty) {
    throw AttachException(problems.isEmpty ? 'There was nothing to attach.' : problems.join(' '), retryable: retryable);
  }
  return AttachResult(items, problems);
}

/// Reads the file at [path] (named [name]) into something to attach.
Future<ContextItem> contextForPath(String path, String name, {int? fileId}) async {
  final mime = imageMimeFor(name);
  if (mime != null) {
    final bytes = await File(path).readAsBytes();
    if (bytes.length > kMaxImageBytes) {
      throw AttachException('$name is ${formatBytes(bytes.length)}; pictures over ${formatBytes(kMaxImageBytes)} are not sent.');
    }
    return ImageContext(name: name, mimeType: mime, bytes: bytes);
  }
  final text = await readFileText(path, name);
  if (text == null) {
    throw AttachException('Could not find any text in $name. If it is a scan or its text is inside pictures, attach a text version instead.');
  }
  return FileContext(name: name, content: text, fileId: fileId);
}

/// One row of a picker: icon, title, a line under it, something at the right.
Widget _pickRow(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? subtitle,
  String? trailing,
  bool disabled = false,
  Widget? leading,
  VoidCallback? onTap,
}) {
  final c = context.colors;
  final t = context.text;
  return ETap(
    onTap: disabled ? null : onTap,
    builder: (context, s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: s.hovered && !disabled ? c.hover : const Color(0x00000000), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          ?leading,
          Icon(icon, size: 16, color: disabled ? c.textTertiary : c.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: disabled ? t.label.copyWith(color: c.textTertiary) : t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Text(subtitle, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), Text(trailing, style: t.meta)],
        ],
      ),
    ),
  );
}

/// A row that can be ticked; the whole row toggles it. A row that cannot be
/// attached has no tick and says why.
Widget _tickRow(
  BuildContext context, {
  required bool checked,
  required VoidCallback onToggle,
  required IconData icon,
  required String title,
  String? subtitle,
  String? trailing,
  bool disabled = false,
}) =>
    _pickRow(
      context,
      leading: disabled ? const SizedBox(width: 32, height: 32) : ECheck(checked: checked, onTap: onToggle),
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      disabled: disabled,
      onTap: onToggle,
    );

/// "Include subfolders" tick for the footer of a picker.
Widget _subfoldersToggle(BuildContext context, bool on, VoidCallback onTap) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ECheck(checked: on, onTap: onTap),
        ETap(onTap: onTap, builder: (context, _) => Text('Include subfolders', style: context.text.label)),
      ],
    );

class _FilesDialog extends StatefulWidget {
  const _FilesDialog(this.ref, this.course);

  final WidgetRef ref;
  final Course course;

  @override
  State<_FilesDialog> createState() => _FilesDialogState();
}

class _FilesDialogState extends State<_FilesDialog> {
  late final Future<CourseFiles> _future = widget.ref.read(courseFilesProvider(widget.course.id).future);
  CourseFiles? _data;
  List<int> _path = const [];
  String _query = '';
  final FocusNode _search = FocusNode();

  // What is ticked; kept while moving between folders and searching.
  final Set<int> _files = {};
  final Set<int> _folders = {};
  bool _sub = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _future.then<void>((d) {
      _data = d;
    }, onError: (Object _) {});
    // Typing starts in the search box at once (the dialog itself would otherwise hold the focus).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search.requestFocus();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _readsImages => widget.ref.read(aiSettingsProvider).provider.readsImages;

  void _toggleFile(FileEntry f) => setState(() {
        _note = null;
        if (_files.remove(f.id)) return;
        if (_files.length >= kMaxAttachFiles) {
          _note = 'Up to $kMaxAttachFiles files at once.';
        } else {
          _files.add(f.id);
        }
      });

  void _toggleFolder(int id) => setState(() {
        _note = null;
        if (!_folders.remove(id)) _folders.add(id);
      });

  void _attach() {
    final data = _data;
    if (data == null) return;
    final found = collectFiles(
      data,
      fileIds: _files,
      folderIds: _folders,
      includeSubfolders: _sub,
      skipFolders: widget.ref.read(hiddenFoldersProvider),
      problemOf: (f) => attachProblemFor(f.name, f.size, readsImages: _readsImages),
    );
    final notes = [
      ...found.notes,
      for (final s in found.skipped.take(5)) '${s.file.name}: ${s.reason}.',
      if (found.skipped.length > 5) '${found.skipped.length - 5} more files could not be attached.',
      if (found.files.isEmpty && found.skipped.isEmpty && _folders.isNotEmpty) 'No files were found in the folders you ticked.',
    ];
    Navigator.of(context).pop<ContextBuilder>(() => contextForFiles(widget.ref, found.files, notes: notes));
  }

  Widget _fileRow(BuildContext context, FileEntry f, {String? where}) {
    final problem = attachProblemFor(f.name, f.size, readsImages: _readsImages);
    return _tickRow(
      context,
      checked: _files.contains(f.id),
      onToggle: () => _toggleFile(f),
      icon: previewKindFor(f.name) == PreviewKind.image ? EIcons.fileImage : EIcons.fileText,
      title: f.name,
      subtitle: problem ?? where,
      trailing: formatBytes(f.size),
      disabled: problem != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final picked = _files.length + _folders.length;
    return EDialog(
      title: widget.course.shortLabel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CompactField(
            width: double.infinity,
            initial: '',
            hint: 'Search this course by name',
            numeric: false,
            focusNode: _search,
            onChanged: (v) => setState(() => _query = v),
          ),
          if (_note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_note!, style: t.meta)),
          const SizedBox(height: 8),
          FutureBuilder<CourseFiles>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Padding(padding: const EdgeInsets.all(16), child: Text('Loading files…', style: t.meta));
              }
              if (snap.hasError) {
                return Padding(padding: const EdgeInsets.all(16), child: Text('Could not load the files of this course.', style: t.meta));
              }
              final data = snap.data!;
              final hidden = widget.ref.read(hiddenFoldersProvider);
              final names = {for (final f in data.folders) f.id: f.name};
              final searching = _query.trim().isNotEmpty;
              final view = viewFolder(data, _path.isEmpty ? null : _path.last);
              final List<Widget> rows;
              if (searching) {
                final found = [
                  for (final f in filesUnder(data, null, skip: hidden))
                    if (nameMatches(f.name, _query)) f,
                ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                rows = [
                  for (final f in found.take(60)) _fileRow(context, f, where: names[f.folderId]),
                  if (found.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('No file with that name.', style: t.meta)),
                  if (found.length > 60) Padding(padding: const EdgeInsets.all(10), child: Text('${found.length - 60} more: type more of the name.', style: t.meta)),
                ];
              } else {
                rows = [
                  if (_path.isNotEmpty)
                    _pickRow(
                      context,
                      icon: EIcons.chevronLeft,
                      title: 'Back',
                      subtitle: view.breadcrumb.map((f) => f.name).join(' / '),
                      onTap: () => setState(() => _path = _path.sublist(0, _path.length - 1)),
                    ),
                  for (final f in view.folders)
                    if (!hidden.contains(f.id))
                      _pickRow(
                        context,
                        leading: ECheck(checked: _folders.contains(f.id), onTap: () => _toggleFolder(f.id)),
                        icon: EIcons.folderClosed,
                        title: f.name,
                        subtitle: 'Tick to attach the files in it, or click to open',
                        onTap: () => setState(() => _path = [..._path, f.id]),
                      ),
                  for (final f in view.files) _fileRow(context, f),
                  if (view.folders.isEmpty && view.files.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Nothing in this folder.', style: t.meta)),
                ];
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)),
              );
            },
          ),
        ],
      ),
      leading: [if (_folders.isNotEmpty) _subfoldersToggle(context, _sub, () => setState(() => _sub = !_sub))],
      actions: [
        EButton(label: 'Back', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop()),
        EButton(label: picked == 0 ? 'Attach' : 'Attach $picked', kind: EButtonKind.primary, onTap: picked == 0 ? null : _attach),
      ],
    );
  }
}

/// Choose an assignment, then tick its instructions and the files linked in it.
class _AssignmentFilesDialog extends StatefulWidget {
  const _AssignmentFilesDialog(this.ref);

  final WidgetRef ref;

  @override
  State<_AssignmentFilesDialog> createState() => _AssignmentFilesDialogState();
}

typedef _AssignmentFiles = ({SubmissionInfo info, List<FileEntry> files});

class _AssignmentFilesDialogState extends State<_AssignmentFilesDialog> {
  Assignment? _picked;
  Future<_AssignmentFiles>? _load;
  _AssignmentFiles? _loaded;
  String _query = '';
  final FocusNode _search = FocusNode();

  bool _text = false;
  final Set<int> _files = {};
  String? _note;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search.requestFocus();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _readsImages => widget.ref.read(aiSettingsProvider).provider.readsImages;

  Future<_AssignmentFiles> _fetch(AssignmentRef key) async {
    final info = await widget.ref.read(submissionInfoProvider(key).future);
    final files = await widget.ref.read(attachmentsProvider(key).future);
    return _loaded = (info: info, files: files);
  }

  void _open(Assignment a) => setState(() {
        _picked = a;
        _loaded = null;
        _text = false;
        _note = null;
        _files.clear();
        _load = _fetch((courseId: a.courseId, assignmentId: a.id));
      });

  void _toggleFile(FileEntry f) => setState(() {
        _note = null;
        if (_files.remove(f.id)) return;
        if (_files.length >= kMaxAttachFiles) {
          _note = 'Up to $kMaxAttachFiles files at once.';
        } else {
          _files.add(f.id);
        }
      });

  void _attach(Assignment picked) {
    final data = _loaded;
    if (data == null) return;
    final text = data.info.description.trim();
    final files = [for (final f in data.files) if (_files.contains(f.id)) f];
    Navigator.of(context).pop<ContextBuilder>(
      () => contextForFiles(
        widget.ref,
        files,
        first: [if (_text && text.isNotEmpty) FileContext(name: '${picked.title} (instructions)', content: text)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final picked = _picked;
    if (picked == null) return _list(context, t);
    final course = widget.ref.read(coursesByIdProvider)[picked.courseId];
    final count = _files.length + (_text ? 1 : 0);
    return EDialog(
      eyebrow: course?.shortLabel,
      title: picked.title,
      body: FutureBuilder<_AssignmentFiles>(
        future: _load,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Padding(padding: const EdgeInsets.all(16), child: Text('Loading…', style: t.meta));
          }
          if (snap.hasError || snap.data == null) {
            return Padding(padding: const EdgeInsets.all(16), child: Text('Could not load this assignment. Check your connection and try again.', style: t.meta));
          }
          final data = snap.data!;
          final text = data.info.description.trim();
          final missing = data.info.attachments.length - data.files.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (text.isNotEmpty)
                _tickRow(
                  context,
                  checked: _text,
                  onToggle: () => setState(() => _text = !_text),
                  icon: EIcons.fileText,
                  title: 'The instructions',
                  subtitle: 'The text of the assignment',
                  trailing: '${formatBytes(text.length)} of text',
                ),
              for (final f in data.files) _fileRow(context, f),
              if (text.isEmpty && data.files.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text('Nothing is attached to this assignment.', style: t.meta)),
              if (missing > 0)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    missing == 1 ? 'One linked file could not be found in Canvas.' : '$missing linked files could not be found in Canvas.',
                    style: t.meta,
                  ),
                ),
              if (_note != null) Padding(padding: const EdgeInsets.all(10), child: Text(_note!, style: t.meta)),
            ],
          );
        },
      ),
      actions: [
        EButton(label: 'Back', kind: EButtonKind.ghost, onTap: () => setState(() => _picked = null)),
        EButton(label: count == 0 ? 'Attach' : 'Attach $count', kind: EButtonKind.primary, onTap: count == 0 ? null : () => _attach(picked)),
      ],
    );
  }

  Widget _fileRow(BuildContext context, FileEntry f) {
    final problem = attachProblemFor(f.name, f.size, readsImages: _readsImages);
    return _tickRow(
      context,
      checked: _files.contains(f.id),
      onToggle: () => _toggleFile(f),
      icon: previewKindFor(f.name) == PreviewKind.image ? EIcons.fileImage : EIcons.fileText,
      title: f.name,
      subtitle: problem,
      trailing: formatBytes(f.size),
      disabled: problem != null,
    );
  }

  Widget _list(BuildContext context, EtherText t) {
    final courses = widget.ref.read(coursesByIdProvider);
    final found = assignmentsWithFiles(
      widget.ref.read(assignmentsProvider).value ?? const <Assignment>[],
      courses,
      disabled: widget.ref.read(disabledCoursesProvider),
      query: _query,
    );
    final now = DateTime.now();
    return EDialog(
      title: 'Which assignment?',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CompactField(
            width: double.infinity,
            initial: '',
            hint: 'Search by title or course',
            numeric: false,
            focusNode: _search,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in found.take(60))
                    _pickRow(
                      context,
                      icon: EIcons.assignments,
                      title: a.title,
                      subtitle: courses[a.courseId]?.shortLabel,
                      trailing: a.done ? 'Done' : formatDue(a.dueAt, now),
                      onTap: () => _open(a),
                    ),
                  if (found.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('No assignment found.', style: t.meta)),
                  if (found.length > 60) Padding(padding: const EdgeInsets.all(10), child: Text('${found.length - 60} more: type more of the name.', style: t.meta)),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [EButton(label: 'Back', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
    );
  }
}

/// What will be sent with the next message, each with an x to take it off.
class AttachChips extends StatelessWidget {
  const AttachChips({super.key, required this.items, required this.onRemove, this.onSendWhole});

  final List<ContextItem> items;
  final void Function(ContextItem item) onRemove;

  /// Switches a long file from its first part to the whole file.
  final void Function(FileContext item)? onSendWhole;

  static IconData _icon(ContextKind k) => switch (k) {
        ContextKind.assignments => EIcons.assignments,
        ContextKind.grades => EIcons.grades,
        ContextKind.announcements => EIcons.announcement,
        ContextKind.file => EIcons.fileText,
        ContextKind.image => EIcons.fileImage,
        ContextKind.courses => EIcons.files,
        ContextKind.fileList => EIcons.files,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final i in items)
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
            decoration: BoxDecoration(
              color: c.sunken,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon(i.kind), size: 13, color: c.textSecondary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(i.label, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (i case final FileContext f when f.isLong && onSendWhole != null) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Sends all ${f.content.length ~/ 1000}k characters (about ${f.content.length ~/ 4000}k tokens), '
                        'and again with every follow-up question in this chat.',
                    child: ETap(
                      onTap: () => onSendWhole!(f),
                      builder: (context, s) => Text('Send whole file', style: t.meta.copyWith(color: c.accent, decoration: s.hovered ? TextDecoration.underline : null)),
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                EIconButton(
                  icon: EIcons.close,
                  tooltip: 'Remove',
                  size: 20,
                  iconSize: 12,
                  bordered: false,
                  onTap: () => onRemove(i),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
