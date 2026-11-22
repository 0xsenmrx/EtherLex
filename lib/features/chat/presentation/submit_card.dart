import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../core/notify/toast.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../submission/domain/submission.dart';
import '../../submission/presentation/submission_providers.dart';
import '../domain/proposed_submit.dart';

/// Cards whose files were handed in, by block key (so asking again shows a fresh card).
class SubmittedCardsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(settingsStoreProvider); // starts over with the account
    return const {};
  }

  void mark(String key) => state = {...state, key};
}

final submittedCardsProvider = NotifierProvider<SubmittedCardsNotifier, Set<String>>(SubmittedCardsNotifier.new);

/// "Hand this in": the assistant only names the assignment. The student picks
/// the files here, sees exactly what will be sent in a consent dialog, and
/// nothing leaves the computer before "Submit to Canvas" is pressed there.
class SubmitCard extends ConsumerStatefulWidget {
  const SubmitCard({super.key, required this.proposal, required this.source});

  final SubmitProposal proposal;
  final String source;

  @override
  ConsumerState<SubmitCard> createState() => _SubmitCardState();
}

class _SubmitCardState extends ConsumerState<SubmitCard> {
  final List<String> _files = [];
  bool _sending = false;
  double _progress = 0;
  String? _error;

  Future<void> _browse(SubmissionInfo info) async {
    final groups = info.allowedExtensions.isEmpty ? <XTypeGroup>[] : [XTypeGroup(label: 'Accepted files', extensions: info.allowedExtensions)];
    final picked = await openFiles(acceptedTypeGroups: groups);
    if (!mounted) return;
    setState(() {
      for (final f in picked) {
        if (!_files.contains(f.path) && FileSystemEntity.typeSync(f.path) == FileSystemEntityType.file) _files.add(f.path);
      }
      _error = null;
    });
  }

  Future<void> _submit(Assignment a, SubmissionInfo info, String courseName) async {
    if (_sending) return;
    final problem = submitProblem(info, _files);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final names = [for (final p in _files) fileBaseName(p)];
    final ok = await confirmAction(
      context,
      title: 'Hand in to your teacher?',
      message: consentMessage(course: courseName, title: a.title, fileNames: names, late: a.dueAt != null && a.dueAt!.isBefore(DateTime.now())),
      confirmLabel: 'Submit to Canvas',
    );
    if (!ok || !mounted) return;
    setState(() {
      _sending = true;
      _progress = 0;
      _error = null;
    });
    // Taken before the upload: the card may scroll away while it runs.
    final submissions = ref.read(submissionRepositoryProvider);
    final assignments = ref.read(assignmentsRepositoryProvider);
    final toast = ref.read(toastProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    final marked = ref.read(submittedCardsProvider.notifier);
    final key = (courseId: a.courseId, assignmentId: a.id);
    try {
      await submissions.submit(a.courseId, a.id, List.of(_files), (p) {
        if (mounted) setState(() => _progress = p);
      });
      await assignments.setDone(a.id, true);
      container.invalidate(mySubmissionProvider(key));
      marked.mark(widget.source);
      toast.show('Submitted to Canvas');
    } on CanvasException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read or send the file. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final assignment = (ref.watch(assignmentsProvider).value ?? const <Assignment>[]).where((a) => a.id == widget.proposal.assignmentId).firstOrNull;
    final submitted = ref.watch(submittedCardsProvider).contains(widget.source);
    final info = assignment == null ? null : ref.watch(submissionInfoProvider((courseId: assignment.courseId, assignmentId: assignment.id))).value;
    final courseName = assignment == null ? '' : (ref.watch(coursesByIdProvider)[assignment.courseId]?.shortLabel ?? '');

    Widget body;
    if (assignment == null) {
      body = Text('That assignment was not found, so nothing can be handed in from here.', style: t.meta);
    } else if (submitted) {
      body = Row(
        children: [
          Icon(EIcons.check, size: 15, color: c.success),
          const SizedBox(width: 6),
          Expanded(child: Text('Handed in "${assignment.title}"', style: t.label)),
        ],
      );
    } else if (info == null) {
      body = Text('Checking what this assignment accepts...', style: t.metaMuted);
    } else if (info.locked || !info.acceptsUpload) {
      body = Text(submitProblem(info, const ['x'])!, style: t.meta);
    } else {
      final hint = info.allowedExtensions.isEmpty ? 'Any file type' : 'Accepted: ${info.allowedExtensions.join(', ')}';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${assignment.title}${courseName.isEmpty ? '' : ' · $courseName'}',
            style: t.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(hint, style: t.metaMuted),
          const SizedBox(height: 8),
          if (_files.isEmpty)
            Text('You choose the files: the assistant cannot pick or read anything on your computer.', style: t.meta)
          else
            for (final p in _files)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(fileBaseName(p), style: t.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (!_sending) EIconButton(icon: EIcons.close, tooltip: 'Remove', onTap: () => setState(() => _files.remove(p))),
                  ],
                ),
              ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: t.meta.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              EButton(label: _files.isEmpty ? 'Choose files' : 'Add files', kind: EButtonKind.ghost, onTap: _sending ? null : () => _browse(info)),
              const Spacer(),
              if (_sending)
                Text('${(_progress * 100).round()}%', style: t.metaMuted)
              else
                EButton(
                  label: _files.length == 1 ? 'Submit 1 file' : 'Submit ${_files.length} files',
                  icon: EIcons.check,
                  kind: EButtonKind.primary,
                  onTap: _files.isEmpty ? null : () => _submit(assignment, info, courseName),
                ),
            ],
          ),
        ],
      );
    }

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
              Expanded(child: Text('Hand in an assignment', style: t.label)),
            ],
          ),
          const SizedBox(height: 8),
          body,
          if (widget.proposal.note != null && !submitted) ...[
            const SizedBox(height: 6),
            Text(widget.proposal.note!, style: t.metaMuted),
          ],
        ],
      ),
    );
  }
}
