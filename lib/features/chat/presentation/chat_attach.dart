import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
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
import '../../files/presentation/files_providers.dart';
import '../../grades/presentation/grades_providers.dart';
import '../../viewer/data/file_text.dart';
import '../../viewer/domain/preview_kind.dart';
import '../../../core/utils/format.dart';
import '../domain/context_builders.dart';
import '../domain/context_item.dart';
import 'ai_consent.dart';
import 'ai_providers.dart';

/// Makes the item when the student picks it (some need a moment to load).
typedef ContextBuilder = Future<ContextItem?> Function();

/// Asks, once per AI service and account, whether Canvas data may be sent to
/// it. True when it is allowed (now or before). Sample mode has no real
/// service, so it never asks.
Future<bool> ensureConsent(BuildContext context, WidgetRef ref) async {
  final session = ref.read(authProvider).value;
  if (session == null || session.isSample) return true;
  final provider = ref.read(aiSettingsProvider).provider;
  if (ref.read(aiConsentProvider).contains(provider)) return true;
  final ok = await confirmAction(
    context,
    title: 'Send Canvas data to ${provider.label}?',
    message: 'What you attach (assignments, grades, announcements, files or pictures) is sent to '
        '${provider.label} together with your question, using your own API key. '
        'EtherLex sends nothing else, and only when you attach it. '
        'You can take this permission back in Settings.',
    confirmLabel: 'Allow',
  );
  if (ok) ref.read(aiConsentProvider.notifier).grant(provider);
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
    return EDialog(
      title: 'Attach from Canvas',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(
            context,
            icon: EIcons.assignments,
            title: 'Open assignments',
            subtitle: 'Everything not done yet, with due dates',
            build: () async => openAssignmentsContext(
              [
                for (final a in ref.read(assignmentsProvider).value ?? const <Assignment>[])
                  if (!disabled.contains(a.courseId)) a,
              ],
              ref.read(coursesByIdProvider),
            ),
          ),
          _row(
            context,
            icon: EIcons.grades,
            title: 'Grades overview',
            subtitle: 'Your current grade in each course',
            build: () async {
              // Grades are only fetched when the Grades page is opened; fetch them now if they were not.
              if (ref.read(courseGradesProvider).isEmpty) await ref.read(gradesSyncProvider.notifier).refresh();
              return gradesOverviewContext(visibleCourses(), ref.read(courseGradesProvider));
            },
          ),
          _row(
            context,
            icon: EIcons.announcement,
            title: 'Recent announcements',
            subtitle: 'The latest ten',
            build: () async => recentAnnouncementsContext(
              [
                for (final a in ref.read(activityProvider).value ?? const <ActivityItem>[])
                  if (a.courseId == null || !disabled.contains(a.courseId)) a,
              ],
              ref.read(coursesByIdProvider),
            ),
          ),
          const EMenuDivider(),
          _row(
            context,
            icon: EIcons.fileImage,
            title: 'A file or picture from this computer',
            subtitle: 'PDF, Word, PowerPoint, text, PNG, JPEG, GIF, WebP',
            build: () async {
              final picked = await openFile(
                acceptedTypeGroups: [
                  const XTypeGroup(label: 'Documents and pictures', extensions: [
                    'pdf', 'docx', 'pptx', 'md', 'markdown', 'txt', 'csv', 'tex', 'png', 'jpg', 'jpeg', 'gif', 'webp',
                  ]),
                ],
              );
              if (picked == null) return null;
              if (!_attachable(picked.name)) throw AttachException('${picked.name} is not a kind of file the assistant can read.');
              return contextForPath(picked.path, picked.name);
            },
          ),
          if (courses.isNotEmpty) ...[
            const EMenuDivider(),
            const EMenuCaption('A file or picture from a course'),
            for (final course in courses)
              _row(
                context,
                icon: EIcons.files,
                title: course.shortLabel,
                subtitle: 'Syllabus, slides, notes, pictures…',
                onPick: () async {
                  final build = await showEtherDialog<ContextBuilder>(context, (_) => _FilesDialog(ref, course), maxWidth: 520);
                  if (build != null && context.mounted) Navigator.of(context).pop(build);
                },
              ),
            const EMenuDivider(),
            const EMenuCaption('Grades of one course'),
            for (final course in courses)
              _row(
                context,
                icon: EIcons.grades,
                title: course.shortLabel,
                subtitle: course.name == course.shortLabel ? null : course.name,
                build: () async {
                  final work = await ref.read(courseWorkProvider(course.id).future);
                  return courseGradesContext(course, ref.read(courseGradesProvider)[course.id], work.items);
                },
              ),
          ],
        ],
      ),
      actions: [EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
    );
  }
}

/// Biggest picture sent, as the services accept about this much.
const int kMaxImageBytes = 5 * 1024 * 1024;

bool _attachable(String name) {
  final k = previewKindFor(name);
  if (k == PreviewKind.image) return imageMimeFor(name) != null;
  return k != PreviewKind.none;
}

/// Reads [file] (downloading it if needed) into something to attach.
Future<ContextItem> contextForFile(WidgetRef ref, FileEntry file) async {
  final String path;
  try {
    path = await ref.read(filesRepositoryProvider).localPath(file);
  } catch (_) {
    throw const AttachException('Could not download that file from Canvas. Check your connection and try again.');
  }
  return contextForPath(path, file.name, fileId: file.id);
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
    throw AttachException('No readable text in $name. A scanned PDF is only pictures; attach a text version instead.');
  }
  return FileContext(name: name, content: text, fileId: fileId);
}

class _FilesDialog extends StatelessWidget {
  const _FilesDialog(this.ref, this.course);

  final WidgetRef ref;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return EDialog(
      title: course.shortLabel,
      body: FutureBuilder<CourseFiles>(
        future: ref.read(courseFilesProvider(course.id).future),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Padding(padding: const EdgeInsets.all(16), child: Text('Loading files…', style: t.meta));
          }
          if (snap.hasError) {
            return Padding(padding: const EdgeInsets.all(16), child: Text('Could not load the files of this course.', style: t.meta));
          }
          final hidden = ref.read(hiddenFoldersProvider);
          final files = [
            for (final f in filesUnder(snap.data!, null, skip: hidden))
              if (_attachable(f.name)) f,
          ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (files.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No PDF, Word, PowerPoint, text or picture files in this course.', style: t.meta),
            );
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in files)
                    ETap(
                      onTap: () => Navigator.of(context).pop<ContextBuilder>(() => contextForFile(ref, f)),
                      builder: (context, s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(color: s.hovered ? c.hover : const Color(0x00000000), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Icon(previewKindFor(f.name) == PreviewKind.image ? EIcons.fileImage : EIcons.fileText, size: 16, color: c.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(child: Text(f.name, style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text(formatBytes(f.size), style: t.meta),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [EButton(label: 'Back', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
    );
  }
}

/// What will be sent with the next message, each with an x to take it off.
class AttachChips extends StatelessWidget {
  const AttachChips({super.key, required this.items, required this.onRemove});

  final List<ContextItem> items;
  final void Function(ContextItem item) onRemove;

  static IconData _icon(ContextKind k) => switch (k) {
        ContextKind.assignments => EIcons.assignments,
        ContextKind.grades => EIcons.grades,
        ContextKind.announcements => EIcons.announcement,
        ContextKind.file => EIcons.fileText,
        ContextKind.image => EIcons.fileImage,
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
