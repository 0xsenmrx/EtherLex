import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../core/notify/toast.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../domain/submission.dart';
import 'submission_providers.dart';

/// Drop zone + file list + Submit, shown inside the assignment dialog.
/// Dropping never submits by itself: files are only staged until "Submit".
class SubmitSection extends ConsumerStatefulWidget {
  const SubmitSection({super.key, required this.assignment});
  final Assignment assignment;

  @override
  ConsumerState<SubmitSection> createState() => _SubmitSectionState();
}

class _SubmitSectionState extends ConsumerState<SubmitSection> {
  final List<String> _files = [];
  bool _dragging = false;
  bool _sending = false;
  double _progress = 0;
  String? _error;

  AssignmentRef get _key =>
      (courseId: widget.assignment.courseId, assignmentId: widget.assignment.id);

  /// Adds dropped or picked files. A folder, or a file of a type this assignment
  /// does not accept, is not added and the reason is shown.
  void _add(Iterable<String> paths, SubmissionInfo info) {
    final added = <String>[];
    String? problem;
    for (final p in paths) {
      if (_files.contains(p) || added.contains(p)) continue;
      if (FileSystemEntity.typeSync(p) != FileSystemEntityType.file) {
        problem ??= '${fileBaseName(p)} is a folder. Folders cannot be submitted: drop the files inside it.';
        continue;
      }
      final refused = validateFiles(info, [p]);
      if (refused != null) {
        problem ??= refused;
        continue;
      }
      added.add(p);
    }
    if (added.isEmpty && problem == null) return;
    setState(() {
      _files.addAll(added);
      _error = problem;
    });
  }

  Future<void> _browse(SubmissionInfo info) async {
    final groups = info.allowedExtensions.isEmpty
        ? <XTypeGroup>[]
        : [XTypeGroup(label: 'Accepted files', extensions: info.allowedExtensions)];
    final picked = await openFiles(acceptedTypeGroups: groups);
    if (!mounted) return;
    _add(picked.map((f) => f.path), info);
  }

  Future<void> _submit(SubmissionInfo info) async {
    final problem = validateFiles(info, _files);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _sending = true;
      _progress = 0;
      _error = null;
    });
    // Taken before the upload: the dialog may be closed while it runs, and
    // the submission must still be marked done and confirmed afterwards.
    final submissions = ref.read(submissionRepositoryProvider);
    final assignments = ref.read(assignmentsRepositoryProvider);
    final toast = ref.read(toastProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final key = _key;
    try {
      await submissions.submit(
        key.courseId,
        key.assignmentId,
        List.of(_files),
        (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await assignments.setDone(key.assignmentId, true);
      container.invalidate(mySubmissionProvider(key));
      toast.show('Submitted to Canvas');
      if (mounted) {
        setState(() {
          _files.clear();
          _sending = false;
        });
      }
    } on CanvasException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Could not read or send the file. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(submissionInfoProvider(_key));
    final info = infoAsync.value;
    if (info == null || !info.acceptsUpload) return const SizedBox.shrink();
    final c = context.colors;
    final t = context.text;

    if (info.locked) {
      return Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Text(
          info.lockReason ?? 'Submissions are closed for this assignment.',
          style: t.metaMuted,
        ),
      );
    }

    final hint = info.allowedExtensions.isEmpty
        ? 'Any file type'
        : 'Accepted: ${info.allowedExtensions.join(', ')}';
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ESectionLabel('Submit'),
        DropTarget(
          enable: !_sending,
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (d) {
            setState(() => _dragging = false);
            _add(d.files.map((f) => f.path), info);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _dragging ? c.accentSoft : c.sunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dragging ? c.accentFill : c.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _dragging ? c.accentFill : c.canvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _dragging ? c.accentFill : c.line),
                      ),
                      child: Icon(
                        EIcons.upload,
                        size: 16,
                        color: _dragging ? c.onAccent : c.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_dragging ? 'Drop to add' : 'Drop files here', style: t.label),
                          const SizedBox(height: 3),
                          Text(hint, style: t.metaMuted, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    EButton(label: 'Browse', onTap: _sending ? null : () => _browse(info)),
                  ],
                ),
                if (_files.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final p in _files)
                    _FileChip(
                      path: p,
                      onRemove: _sending ? null : () => setState(() => _files.remove(p)),
                    ),
                  const SizedBox(height: 12),
                  if (_sending)
                    _ProgressBar(value: _progress)
                  else
                    Row(
                      children: [
                        Expanded(child: Text('Turns in as a new attempt on Canvas.', style: t.metaMuted)),
                        const SizedBox(width: 8),
                        EButton(
                          label: _files.length == 1 ? 'Submit file' : 'Submit ${_files.length} files',
                          kind: EButtonKind.primary,
                          onTap: () => _submit(info),
                        ),
                      ],
                    ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error, style: t.meta.copyWith(color: c.danger)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.path, required this.onRemove});
  final String path;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    int size = 0;
    try {
      size = File(path).lengthSync();
    } catch (_) {}
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(EIcons.file, size: 15, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(fileBaseName(path), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.body),
          ),
          const SizedBox(width: 8),
          Text(formatBytes(size), style: t.metaMuted),
          const SizedBox(width: 4),
          EIconButton(
            icon: EIcons.close,
            tooltip: 'Remove',
            size: 26,
            iconSize: 14,
            bordered: false,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value >= 1 ? 'Finishing…' : 'Uploading ${(value * 100).round()}%', style: t.metaMuted),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: c.line)),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.02, 1.0),
                    child: ColoredBox(color: c.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
