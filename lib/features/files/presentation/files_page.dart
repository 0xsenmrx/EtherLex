import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/smooth_scroll.dart';
import '../../../core/network/canvas_exception.dart';
import '../../../core/notify/toast.dart';
import '../../../core/ui/hover_prefetch.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/fixed_colors.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/course_palette.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../settings/presentation/view_prefs_provider.dart';
import '../../courses/domain/course.dart';
import '../data/file_cache.dart';
import '../domain/files_models.dart';
import '../domain/folder_view.dart';
import 'file_actions.dart';
import 'file_row.dart';
import 'files_providers.dart';

const Color _folderColor = FixedColors.folder;

/// One row of a list: how to draw it, what Enter does, what D does.
typedef _RowSpec = ({
  Widget Function(bool selected) build,
  VoidCallback open,
  VoidCallback? download,
});

class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  Course? _course;
  List<int> _path = const [];
  bool _showHidden = false;
  final FocusNode _focus = FocusNode();

  // A file to select once its folder is on screen (from a link in a message).
  // The tick makes the list start over even when the folder is already open.
  int? _revealId;
  int _revealTick = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual<FileEntry?>(fileFocusProvider, (_, file) {
      if (file == null) return;
      // Providers must not change while the tree is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(fileFocusProvider.notifier).clear();
        _showFile(file);
      });
    }, fireImmediately: true);
    ref.listenManual<int?>(filesCourseRequestProvider, (_, id) {
      if (id == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ref.read(filesCourseRequestProvider.notifier).clear();
        final course = await _courseById(id);
        if (mounted && course != null) _goTo(course, const []);
      });
    }, fireImmediately: true);
    _restore();
  }

  /// Opens the course and folder this account had open last time, unless a
  /// file link or a click already chose something.
  Future<void> _restore() async {
    await ref.read(viewPrefsProvider.notifier).ready;
    if (!mounted) return;
    // The current choice, not the one first read from disk: leaving Files and
    // coming back in the same session must show where the student left it.
    final prefs = ref.read(viewPrefsProvider);
    final id = prefs.filesCourseId;
    if (!mounted || _course != null || _touched || id == null) return;
    final course = await _courseById(id);
    if (!mounted || _course != null || _touched || course == null) return;
    setState(() {
      _course = course;
      _path = prefs.filesFolderPath;
    });
  }

  /// The student (or a link) moved since the page opened: no restoring then.
  bool _touched = false;

  /// Goes to [course] and [path] and remembers it for next time.
  void _goTo(Course? course, List<int> path) {
    _touched = true;
    setState(() {
      _course = course;
      _path = path;
    });
    ref.read(viewPrefsProvider.notifier).update(
          (p) => p.copyWith(filesCourseId: () => course?.id, filesFolderPath: course == null ? const [] : path),
        );
  }

  Future<Course?> _courseById(int id) async {
    try {
      final all = ref.read(coursesProvider).value ?? await ref.read(coursesProvider.future);
      return all?.where((c) => c.id == id).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  /// Opens the course and folder of [file] and selects it.
  Future<void> _showFile(FileEntry file) async {
    final course = await _courseById(file.courseId);
    if (!mounted) return;
    if (course == null) {
      ref.read(toastProvider.notifier).show("That file's course is not in your list.");
      return;
    }
    var entry = file;
    var path = const <int>[];
    try {
      final data = await ref.read(courseFilesProvider(course.id).future);
      // The listing knows the real folder; the single-file answer may not.
      entry = data.files.where((f) => f.id == file.id).firstOrNull ?? file;
      path = [for (final c in viewFolder(data, entry.folderId).breadcrumb) c.id];
    } catch (_) {
      // The course page shows the error with its retry button.
    }
    if (!mounted) return;
    _goTo(course, path);
    setState(() {
      _revealId = entry.id;
      _revealTick++;
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Ctrl+R / F5: the open course's listing again, or the course list.
  void _refresh() {
    final course = _course;
    if (course != null) {
      ref.invalidate(courseFilesProvider(course.id));
    } else {
      ref.read(syncProvider.notifier).refresh();
    }
  }

  void _up() {
    if (_path.isNotEmpty) {
      _goTo(_course, _path.sublist(0, _path.length - 1));
    } else {
      _goTo(null, const []);
    }
  }

  String _errorText(Object e) {
    if (e is CanvasException) {
      return e.kind == CanvasErrorKind.unauthorized
          ? 'Files are not available for this course.'
          : e.message;
    }
    return 'Could not load files.';
  }

  @override
  Widget build(BuildContext context) {
    final course = _course;
    final filesAsync = course == null ? null : ref.watch(courseFilesProvider(course.id));
    final data = filesAsync?.value;
    final view = data == null ? null : viewFolder(data, _path.isEmpty ? null : _path.last);

    final Widget body;
    if (course == null) {
      body = _CourseList(
        key: const ValueKey('courses'),
        onOpen: (c) => _goTo(c, const []),
      );
    } else {
      body = filesAsync!.when(
        loading: () => const ESkeletonList(key: ValueKey('loading'), rowHeight: kFileRowExtent),
        error: (e, _) => EErrorState(
          key: const ValueKey('error'),
          message: _errorText(e),
          onRetry: () => ref.invalidate(courseFilesProvider(course.id)),
        ),
        data: (d) {
          final v = viewFolder(d, _path.isEmpty ? null : _path.last);
          final hiddenIds = ref.watch(hiddenFoldersProvider);
          final hiddenNotifier = ref.read(hiddenFoldersProvider.notifier);
          return _FileList(
            key: ValueKey('list-${course.id}-${_path.lastOrNull}-$_revealTick'),
            revealFileId: _revealId,
            onRevealed: () => _revealId = null,
            files: v.files,
            folders: [for (final f in v.folders) if (!hiddenIds.contains(f.id)) f],
            hiddenFolders: [for (final f in v.folders) if (hiddenIds.contains(f.id)) f],
            showHidden: _showHidden,
            onToggleShowHidden: () => setState(() => _showHidden = !_showHidden),
            onOpenFolder: (f) => _goTo(course, [..._path, f.id]),
            isOffline: (f) => ref.read(filesRepositoryProvider).cachedPath(f) != null,
            onOpen: (f) => openFile(context, ref, f),
            onDownload: (f) => downloadWithToast(ref, f),
            onHide: (f) {
              hiddenNotifier.hide(f.id);
              ref.read(toastProvider.notifier).show(
                    '${f.name} hidden',
                    actionLabel: 'Undo',
                    onAction: () => hiddenNotifier.show(f.id),
                  );
            },
            onRestore: (f) => hiddenNotifier.show(f.id),
          );
        },
      );
    }

    final String? subtitle;
    if (course == null) {
      subtitle = 'Choose a course';
    } else if (data?.fromCache ?? false) {
      subtitle = 'Offline copy · connect to see changes';
    } else {
      subtitle = null;
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.backspace): () {
          if (_course != null) _up();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_course != null) _up();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          if (_course != null) _up();
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
      },
      child: Focus(
        autofocus: true,
        focusNode: _focus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EPageHeader(
              title: 'Files',
              subtitle: subtitle,
              actions: [
                if (course != null && data != null)
                  EButton(
                    label: 'Save offline',
                    icon: EIcons.download,
                    onTap: () => saveOffline(
                      ref,
                      filesUnder(
                        data,
                        _path.isEmpty ? null : _path.last,
                        skip: ref.read(hiddenFoldersProvider),
                      ),
                    ),
                  ),
                if (course != null)
                  ESyncButton(
                    state: SyncState(loading: filesAsync?.isLoading ?? false),
                    onRefresh: () => ref.invalidate(courseFilesProvider(course.id)),
                  ),
              ],
            ),
            if (course != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 20, 10),
                child: _Breadcrumb(
                  course: course,
                  crumbs: view?.breadcrumb ?? const [],
                  onRoot: () => _goTo(null, const []),
                  onCourse: () => _goTo(course, const []),
                  onCrumb: (i) => _goTo(course, [for (final c in view!.breadcrumb.take(i + 1)) c.id]),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.course,
    required this.crumbs,
    required this.onRoot,
    required this.onCourse,
    required this.onCrumb,
  });

  final Course course;
  final List<FolderNode> crumbs;
  final VoidCallback onRoot;
  final VoidCallback onCourse;
  final ValueChanged<int> onCrumb;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parts = <Widget>[
      _Crumb(label: 'Courses', onTap: onRoot),
      _Crumb(label: course.name, swatch: CoursePalette.colorFor(course.id), onTap: crumbs.isEmpty ? null : onCourse),
      for (var i = 0; i < crumbs.length; i++)
        _Crumb(label: crumbs[i].name, onTap: i == crumbs.length - 1 ? null : () => onCrumb(i)),
    ];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(EIcons.chevronRight, size: 14, color: c.textTertiary),
            ),
          parts[i],
        ],
      ],
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.onTap, this.swatch});
  final String label;
  final VoidCallback? onTap;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final current = onTap == null;
    final sw = swatch;
    return ETap(
      onTap: onTap,
      pressedScale: 0.96,
      builder: (context, s) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: s.hovered ? c.hover : const Color(0x00000000),
          borderRadius: BorderRadius.circular(8),
          boxShadow: focusRing(c, s.focused),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sw != null) ...[ESwatch(sw, width: 7, height: 10), const SizedBox(width: 7)],
            Text(
              label,
              style: t.label.copyWith(
                color: current || s.hovered ? c.textPrimary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keyboard cursor over fixed-height rows: J/K or arrows move, Enter opens,
/// D downloads the selected file.
mixin _RowCursor<T extends StatefulWidget> on State<T> {
  final FocusNode focus = FocusNode();
  final SmoothScrollController scroll = SmoothScrollController();
  int cursor = -1;
  List<_RowSpec> rows = const [];
  bool _focusAsked = false;

  @override
  void dispose() {
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  void move(int delta) {
    if (rows.isEmpty) return;
    setState(() {
      cursor = cursor < 0 ? (delta > 0 ? 0 : rows.length - 1) : (cursor + delta).clamp(0, rows.length - 1);
    });
    scrollToCursor();
  }

  /// Scrolls just enough to show the cursor row, or puts it in the middle.
  void scrollToCursor({bool center = false}) {
    if (!scroll.hasClients || cursor < 0) return;
    final top = cursor * kFileRowExtent;
    final view = scroll.position.viewportDimension;
    double? target;
    if (center) {
      target = top - (view - kFileRowExtent) / 2;
    } else if (top < scroll.offset) {
      target = top;
    } else if (top + kFileRowExtent > scroll.offset + view) {
      target = top + kFileRowExtent - view;
    }
    if (target != null) {
      scroll.animateTo(
        target.clamp(0.0, scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget withKeys(Widget child) {
    // Take the keyboard once the rows exist (the page holds it until then).
    if (!_focusAsked) {
      _focusAsked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focus.requestFocus();
      });
    }
    return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => move(1),
          const SingleActivator(LogicalKeyboardKey.keyJ): () => move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => move(-1),
          const SingleActivator(LogicalKeyboardKey.keyK): () => move(-1),
          const SingleActivator(LogicalKeyboardKey.enter): () {
            if (cursor >= 0 && cursor < rows.length) rows[cursor].open();
          },
          const SingleActivator(LogicalKeyboardKey.keyD): () {
            if (cursor >= 0 && cursor < rows.length) rows[cursor].download?.call();
          },
        },
        child: Focus(focusNode: focus, child: child),
      );
  }

  Widget rowList({Widget? header}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Expanded(
            child: ListView.builder(
              controller: scroll,
              // Flutter is pinned to 3.47, which only has cacheExtent. Use scrollCacheExtent after unpinning (CLAUDE.md).
              // ignore: deprecated_member_use
              cacheExtent: 800,
              padding: const EdgeInsets.only(bottom: 32),
              itemExtent: kFileRowExtent,
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i].build(i == cursor),
            ),
          ),
        ],
      );
}

class _CourseList extends ConsumerStatefulWidget {
  const _CourseList({super.key, required this.onOpen});
  final ValueChanged<Course> onOpen;

  @override
  ConsumerState<_CourseList> createState() => _CourseListState();
}

class _CourseListState extends ConsumerState<_CourseList> with _RowCursor<_CourseList> {
  bool _showHidden = false;

  // Size of the offline folder: a directory walk, so once per cache change.
  int _bytes = 0;
  int _bytesRevision = -1;

  int _offlineBytes() {
    if (_bytesRevision != fileCacheRevision.value) {
      _bytesRevision = fileCacheRevision.value;
      _bytes = ref.read(filesRepositoryProvider).offlineBytes();
    }
    return _bytes;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final courses = ref.watch(coursesProvider).value;
    final disabled = ref.watch(disabledCoursesProvider);
    final selected = ref.watch(courseFilterProvider);
    final hiddenIds = ref.watch(hiddenFileCoursesProvider);
    final hiddenNotifier = ref.read(hiddenFileCoursesProvider.notifier);

    if (courses == null) return const ESkeletonList(rowHeight: kFileRowExtent);
    final base = [
      for (final course in courses)
        if (selected.isNotEmpty ? selected.contains(course.id) : !disabled.contains(course.id)) course,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final shown = [for (final x in base) if (!hiddenIds.contains(x.id)) x];
    final hidden = [for (final x in base) if (hiddenIds.contains(x.id)) x];

    if (shown.isEmpty && hidden.isEmpty) {
      return EEmptyState(
        icon: EIcons.files,
        title: 'No courses yet',
        message: 'Your courses appear here after the first sync with Canvas.',
        action: EButton(label: 'Refresh', icon: EIcons.refresh, onTap: () => ref.read(syncProvider.notifier).refresh()),
      );
    }

    _RowSpec courseRow(Course course, {required bool isHidden}) => (
          build: (sel) => HoverPrefetch(
                key: ValueKey('c${course.id}-$isHidden'),
                onPrefetch: () => ref.read(courseFilesProvider(course.id)),
                child: EntryRow(
                  icon: EIcons.files,
                  color: CoursePalette.colorFor(course.id),
                  title: course.name,
                  subtitle: 'Course files',
                  trailing: '',
                  hidden: isHidden,
                  selected: sel,
                  onTap: () => widget.onOpen(course),
                  onToggleHidden: () {
                    if (isHidden) {
                      hiddenNotifier.show(course.id);
                    } else {
                      hiddenNotifier.hide(course.id);
                      ref.read(toastProvider.notifier).show(
                            '${course.shortLabel} hidden from Files',
                            actionLabel: 'Undo',
                            onAction: () => hiddenNotifier.show(course.id),
                          );
                    }
                  },
                ),
              ),
          open: () => widget.onOpen(course),
          download: null,
        );

    return ValueListenableBuilder<int>(
      valueListenable: fileCacheRevision,
      builder: (context, _, _) {
        final bytes = _offlineBytes();
        void clearOffline() {
          ref.read(filesRepositoryProvider).clearOffline();
          ref.read(toastProvider.notifier).show('Offline files cleared');
        }

        void toggleHidden() => setState(() => _showHidden = !_showHidden);
        rows = [
          for (final x in shown) courseRow(x, isHidden: false),
          if (hidden.isNotEmpty)
            (
              build: (sel) => EntryRow(
                    key: const ValueKey('hidden-courses-toggle'),
                    icon: _showHidden ? EIcons.eye : EIcons.eyeOff,
                    color: c.textTertiary,
                    title: _showHidden ? 'Hide hidden courses' : 'Hidden courses',
                    subtitle: '${hidden.length} hidden',
                    trailing: '',
                    selected: sel,
                    onTap: toggleHidden,
                  ),
              open: toggleHidden,
              download: null,
            ),
          if (_showHidden)
            for (final x in hidden) courseRow(x, isHidden: true),
          if (bytes > 0)
            (
              build: (sel) => EntryRow(
                    key: const ValueKey('offline-files'),
                    icon: EIcons.download,
                    color: c.textTertiary,
                    title: 'Offline files',
                    subtitle: '${formatBytes(bytes)} saved on this computer',
                    trailing: 'Clear',
                    selected: sel,
                    onTap: clearOffline,
                  ),
              open: clearOffline,
              download: null,
            ),
        ];
        return withKeys(
          Padding(padding: const EdgeInsets.only(left: 16, right: 4), child: rowList()),
        );
      },
    );
  }
}

class _FileList extends StatefulWidget {
  const _FileList({
    super.key,
    required this.folders,
    required this.hiddenFolders,
    required this.files,
    required this.showHidden,
    required this.onToggleShowHidden,
    required this.onOpenFolder,
    required this.isOffline,
    required this.onOpen,
    required this.onDownload,
    required this.onHide,
    required this.onRestore,
    this.revealFileId,
    this.onRevealed,
  });

  /// A file to put the cursor on when the list first appears.
  final int? revealFileId;
  final VoidCallback? onRevealed;

  final List<FolderNode> folders;
  final List<FolderNode> hiddenFolders;
  final List<FileEntry> files;
  final bool showHidden;
  final VoidCallback onToggleShowHidden;
  final ValueChanged<FolderNode> onOpenFolder;
  final bool Function(FileEntry) isOffline;
  final ValueChanged<FileEntry> onOpen;
  final ValueChanged<FileEntry> onDownload;
  final ValueChanged<FolderNode> onHide;
  final ValueChanged<FolderNode> onRestore;

  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> with _RowCursor<_FileList> {
  // "Offline" needs a file-system check per file; do it once per file and
  // cache change, not on every rebuild of the visible rows.
  final Map<int, bool> _offline = {};
  int _offlineRevision = -1;

  @override
  void initState() {
    super.initState();
    final id = widget.revealFileId;
    if (id == null) return;
    final i = widget.files.indexWhere((f) => f.id == id);
    // Rows are the folders first, then the files.
    if (i >= 0) cursor = widget.folders.length + i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (i >= 0) scrollToCursor(center: true);
      widget.onRevealed?.call();
    });
  }

  bool _isOffline(FileEntry file) {
    if (_offlineRevision != fileCacheRevision.value) {
      _offline.clear();
      _offlineRevision = fileCacheRevision.value;
    }
    return _offline.putIfAbsent(file.id, () => widget.isOffline(file));
  }

  @override
  void didUpdateWidget(_FileList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.files, widget.files)) _offline.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final folders = widget.folders;
    final files = widget.files;
    final hidden = widget.hiddenFolders;
    if (folders.isEmpty && files.isEmpty && hidden.isEmpty) {
      return const EEmptyState(
        icon: EIcons.folderClosed,
        title: 'This folder is empty',
        message: 'Canvas shows nothing here. Some teachers add files later; Backspace goes up a folder.',
      );
    }
    final now = DateTime.now();

    return ValueListenableBuilder<int>(
      valueListenable: fileCacheRevision,
      builder: (context, _, _) {
        rows = [
          for (final f in folders)
            (
              build: (sel) => EntryRow(
                    key: ValueKey('d${f.id}'),
                    icon: EIcons.folderClosed,
                    color: _folderColor,
                    title: f.name,
                    subtitle: 'Folder',
                    trailing: '',
                    selected: sel,
                    onTap: () => widget.onOpenFolder(f),
                    onToggleHidden: () => widget.onHide(f),
                  ),
              open: () => widget.onOpenFolder(f),
              download: null,
            ),
          for (final file in files)
            (
              build: (sel) {
                final visual = fileVisual(file.name);
                return EntryRow(
                  key: ValueKey('f${file.id}'),
                  icon: visual.icon,
                  color: visual.color,
                  title: file.name,
                  subtitle: _isOffline(file) ? '${fileSubtitle(file)} · Offline' : fileSubtitle(file),
                  trailing: fileDate(file, now),
                  showDownload: true,
                  selected: sel,
                  onTap: () => widget.onOpen(file),
                  onActionTap: () => widget.onDownload(file),
                );
              },
              open: () => widget.onOpen(file),
              download: () => widget.onDownload(file),
            ),
          if (hidden.isNotEmpty)
            (
              build: (sel) => EntryRow(
                    key: const ValueKey('hidden-toggle'),
                    icon: widget.showHidden ? EIcons.eye : EIcons.eyeOff,
                    color: c.textTertiary,
                    title: widget.showHidden ? 'Hide hidden folders' : 'Hidden folders',
                    subtitle: '${hidden.length} hidden',
                    trailing: '',
                    selected: sel,
                    onTap: widget.onToggleShowHidden,
                  ),
              open: widget.onToggleShowHidden,
              download: null,
            ),
          if (widget.showHidden)
            for (final f in hidden)
              (
                build: (sel) => EntryRow(
                      key: ValueKey('h${f.id}'),
                      icon: EIcons.folderClosed,
                      color: _folderColor,
                      title: f.name,
                      subtitle: 'Hidden folder',
                      trailing: '',
                      hidden: true,
                      selected: sel,
                      onTap: () => widget.onOpenFolder(f),
                      onToggleHidden: () => widget.onRestore(f),
                    ),
                open: () => widget.onOpenFolder(f),
                download: null,
              ),
        ];
        return withKeys(
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: rowList(
              header: Container(
                height: 30,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.only(left: 12, right: 38),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                child: Row(
                  children: [
                    Expanded(child: Text('NAME', style: t.caption)),
                    Text('MODIFIED', style: t.caption),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
