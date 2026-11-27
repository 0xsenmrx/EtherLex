import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notify/toast.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../chat/presentation/course_pick.dart';
import '../../courses/domain/course.dart';
import '../domain/custom_task.dart';
import 'assignments_providers.dart';

/// Adds a task of your own, or edits [existing] (see custom_task.dart).
Future<void> showTaskEditor(BuildContext context, {CustomTask? existing}) =>
    showEtherDialog<void>(context, (_) => _TaskEditor(existing: existing), maxWidth: 520);

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({this.existing});

  final CustomTask? existing;

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _due = TextEditingController(
    text: widget.existing?.dueAt == null ? '' : formatTaskDue(widget.existing!.dueAt!),
  );
  late final TextEditingController _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late int _courseId = widget.existing?.courseId ?? kPersonalCourseId;
  String? _titleError;
  String? _dueError;

  @override
  void dispose() {
    _title.dispose();
    _due.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setDue(DateTime d) => setState(() {
        _due.text = formatTaskDue(d);
        _dueError = null;
      });

  Future<void> _pickCourse(List<Course> courses) async {
    final picked = await pickCourse(context, courses);
    if (picked != null && mounted) setState(() => _courseId = picked.id);
  }

  void _save() {
    final title = _title.text.trim();
    final dueText = _due.text.trim();
    final due = dueText.isEmpty ? null : parseTaskDue(dueText);
    final titleError = title.isEmpty ? 'Give the task a title.' : null;
    final dueError = dueText.isNotEmpty && due == null ? 'Use 2026-12-05 or 2026-12-05 18:30.' : null;
    if (titleError != null || dueError != null) {
      setState(() {
        _titleError = titleError;
        _dueError = dueError;
      });
      return;
    }
    final list = ref.read(customTasksProvider);
    final notes = _notes.text.trim();
    final old = widget.existing;
    if (old == null) {
      list.create(title: title, courseId: _courseId, dueAt: due, notes: notes);
      ref.read(toastProvider.notifier).show('Task added');
    } else {
      // Start from the saved copy: it may have been ticked off meanwhile.
      final current = list.tasks.where((t) => t.id == old.id).firstOrNull ?? old;
      list.update(current.copyWith(title: title, courseId: _courseId, dueAt: due, clearDue: due == null, notes: notes));
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final old = widget.existing;
    if (old == null) return;
    final ok = await confirmAction(
      context,
      title: 'Delete this task?',
      message: '"${old.title}" will be removed from this computer. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    ref.read(customTasksProvider).remove(old.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final disabled = ref.watch(disabledCoursesProvider);
    final all = ref.watch(coursesProvider).value ?? const <Course>[];
    final courses = [for (final course in all) if (!disabled.contains(course.id)) course];
    final chosen = all.where((course) => course.id == _courseId).firstOrNull;
    final now = DateTime.now();
    DateTime at(int plusDays) => DateTime(now.year, now.month, now.day + plusDays, 23, 59);

    return EDialog(
      eyebrow: 'Personal task',
      title: widget.existing == null ? 'New task' : 'Edit task',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _title,
            label: 'Title',
            hint: 'Read chapter 4, call the registrar…',
            autofocus: true,
            error: _titleError,
            onSubmitted: _save,
          ),
          const SizedBox(height: 16),
          Text('Course (optional)', style: t.meta),
          const SizedBox(height: 6),
          Row(
            children: [
              ETap(
                onTap: () => _pickCourse(courses),
                builder: (context, s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: s.hovered ? c.hover : c.sunken,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          chosen?.shortLabel ?? (_courseId == kPersonalCourseId ? 'No course' : 'Course $_courseId'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.body,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(EIcons.edit, size: 13, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
              if (_courseId != kPersonalCourseId) ...[
                const SizedBox(width: 8),
                EButton(
                  label: 'No course',
                  kind: EButtonKind.ghost,
                  onTap: () => setState(() => _courseId = kPersonalCourseId),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _due,
            label: 'Due (optional)',
            hint: '2026-12-05 18:30',
            error: _dueError,
            onSubmitted: _save,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EButton(label: 'Today', kind: EButtonKind.ghost, onTap: () => _setDue(at(0))),
              EButton(label: 'Tomorrow', kind: EButtonKind.ghost, onTap: () => _setDue(at(1))),
              EButton(label: 'In a week', kind: EButtonKind.ghost, onTap: () => _setDue(at(7))),
              EButton(
                label: 'No date',
                kind: EButtonKind.ghost,
                onTap: () => setState(() {
                  _due.clear();
                  _dueError = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(controller: _notes, label: 'Notes (optional)', multiline: true),
        ],
      ),
      leading: [
        if (widget.existing != null) EButton(label: 'Delete', icon: EIcons.trash, kind: EButtonKind.ghost, onTap: _delete),
      ],
      actions: [
        EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop()),
        EButton(label: widget.existing == null ? 'Add task' : 'Save', kind: EButtonKind.primary, onTap: _save),
      ],
    );
  }
}
