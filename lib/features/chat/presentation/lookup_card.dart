import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../courses/domain/course.dart';
import '../../files/domain/files_models.dart';
import '../../files/presentation/files_providers.dart';
import '../../grades/domain/plan_proposal.dart';
import '../domain/attach_rules.dart';
import '../domain/context_builders.dart';
import '../domain/context_item.dart';
import '../domain/file_tree_text.dart';
import '../domain/proposed_files.dart';
import '../domain/proposed_lookup.dart';
import 'chat_attach.dart';
import 'ai_providers.dart';
import 'chat_controller.dart';
import 'choice_pick.dart';
import 'course_pick.dart';

/// What the student answered on a lookup card: true = allowed and sent, false = not now.
class LookupAnswersNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    ref.watch(settingsStoreProvider); // starts over with the account
    return const {};
  }

  void answer(String key, bool allowed) => state = {...state, key: allowed};
}

final lookupAnswersProvider = NotifierProvider<LookupAnswersNotifier, Map<String, bool>>(LookupAnswersNotifier.new);

/// "To do that I need to see ...": the assistant asks for what it was not given
/// (a course's file list, its assignments, the text of a file), the student
/// decides. Allowing loads it and sends it with a short message, so the
/// assistant can carry on with exact names and item numbers.
class LookupCard extends ConsumerStatefulWidget {
  const LookupCard({super.key, required this.proposal, required this.source});

  final LookupProposal proposal;
  final String source;

  @override
  ConsumerState<LookupCard> createState() => _LookupCardState();
}

class _LookupCardState extends ConsumerState<LookupCard> {
  bool _busy = false;
  String? _error;

  /// Courses the student picked for names that did not match: key ('f0', 'a1', 'r0') -> course.
  final Map<String, Course> _picked = {};

  Course? _course(String key, String name, List<Course> courses) => _picked[key] ?? matchCourse(name, courses);

  Future<void> _choose(String key, List<Course> courses) async {
    final course = await pickCourse(context, courses);
    if (course != null && mounted) setState(() => _picked[key] = course);
  }

  Future<void> _allow(List<Course> courses) async {
    if (_busy) return;
    // What is loaded goes to the AI service like any attachment: the same permission.
    if (!await ensureConsent(context, ref) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final p = widget.proposal;
    try {
      final hidden = ref.read(hiddenFoldersProvider);
      final readsImages = ref.read(aiSettingsProvider).provider.readsImages;
      final items = <ContextItem>[];
      final said = <String>[];
      final missed = <String>[];
      for (final (i, name) in p.courses.indexed) {
        final course = _course('f$i', name, courses)!;
        final data = await ref.read(courseFilesProvider(course.id).future);
        items.add(FileListContext(course: course.name, text: fileTreeText(data, hidden)));
        said.add('the file list of ${course.name}');
      }
      for (final (i, name) in p.assignmentCourses.indexed) {
        final course = _course('a$i', name, courses)!;
        items.add(courseAssignmentsContext(course, ref.read(assignmentsProvider).value ?? const <Assignment>[]));
        said.add('the assignments of ${course.name}');
      }
      for (final (i, r) in p.reads.indexed) {
        final course = _course('r$i', r.course, courses)!;
        final data = await ref.read(courseFilesProvider(course.id).future);
        final found = fileMatches(data.files, r.file);
        FileEntry? file;
        if (found.length == 1) {
          file = found.single;
        } else if (found.length > 1) {
          if (!mounted) return;
          final byId = {for (final f in data.folders) f.id: folderPath(data, f)};
          final id = await pickChoice(context, 'Which file is "${r.file}"?', [
            for (final f in found) PickOption(id: f.id, label: f.name, sub: [if ((byId[f.folderId] ?? '').isNotEmpty) byId[f.folderId]!, sizeText(f.size)].join(' · ')),
          ]);
          if (!mounted) return;
          file = found.where((f) => f.id == id).firstOrNull;
          if (file == null) {
            missed.add('"${r.file}" in ${course.name} (you chose none)');
            continue;
          }
        } else {
          missed.add('no file like "${r.file}" in ${course.name}');
          continue;
        }
        final problem = attachProblemFor(file.name, file.size, readsImages: readsImages);
        if (problem != null) {
          missed.add('${file.name}: $problem');
          continue;
        }
        try {
          items.add(await contextForFile(ref, file));
          said.add(file.name);
        } on AttachException catch (e) {
          missed.add('${file.name}: ${e.message}');
        }
      }
      if (!mounted) return;
      ref.read(lookupAnswersProvider.notifier).answer(widget.source, true);
      final text = StringBuffer('Yes, go ahead.');
      if (said.isNotEmpty) text.write(' Attached: ${said.join('; ')}.');
      if (missed.isNotEmpty) text.write(' Could not get: ${missed.join('; ')}.');
      await ref.read(chatControllerProvider.notifier).send(text.toString(), items: items);
    } on CanvasException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load that. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(BuildContext context, String key, String what, String name, List<Course> courses, bool asking, {String? extra}) {
    final t = context.text;
    final course = _course(key, name, courses);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(what, style: t.label)),
          Expanded(
            child: Text(
              course == null ? '"$name": which course?' : '${course.name}${extra == null ? '' : ' · $extra'}',
              style: course == null ? t.meta : t.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (course == null && asking) EButton(label: 'Choose course', kind: EButtonKind.ghost, onTap: () => _choose(key, courses)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final answer = ref.watch(lookupAnswersProvider)[widget.source];
    final p = widget.proposal;
    final service = ref.watch(aiSettingsProvider).provider.label;
    final asking = answer == null;
    final allKnown = [
      for (final (i, n) in p.courses.indexed) _course('f$i', n, courses),
      for (final (i, n) in p.assignmentCourses.indexed) _course('a$i', n, courses),
      for (final (i, r) in p.reads.indexed) _course('r$i', r.course, courses),
    ].every((r) => r != null);

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
              Expanded(child: Text('Needs to look at some of your data', style: t.label)),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, n) in p.courses.indexed) _row(context, 'f$i', 'File list', n, courses, asking),
          for (final (i, n) in p.assignmentCourses.indexed) _row(context, 'a$i', 'Assignments', n, courses, asking),
          for (final (i, r) in p.reads.indexed) _row(context, 'r$i', 'Read file', r.course, courses, asking, extra: r.file),
          const SizedBox(height: 2),
          Text('File lists are names and sizes only. A file is read as text. Nothing else is sent.', style: t.metaMuted),
          if (p.note != null) ...[
            const SizedBox(height: 4),
            Text(p.note!, style: t.metaMuted),
          ],
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: t.meta.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 10),
          Container(height: 1, color: c.line),
          const SizedBox(height: 10),
          if (answer == true)
            Row(
              children: [
                Icon(EIcons.check, size: 15, color: c.success),
                const SizedBox(width: 6),
                Expanded(child: Text('Allowed: sent with your message.', style: t.label)),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    answer == false ? 'Not shared.' : 'Goes to $service only if you allow it.',
                    style: t.metaMuted,
                  ),
                ),
                const SizedBox(width: 12),
                if (asking) ...[
                  EButton(
                    label: 'Not now',
                    kind: EButtonKind.ghost,
                    onTap: _busy ? null : () => ref.read(lookupAnswersProvider.notifier).answer(widget.source, false),
                  ),
                  const SizedBox(width: 8),
                  EButton(label: 'Allow', icon: EIcons.check, kind: EButtonKind.primary, loading: _busy, onTap: allKnown ? () => _allow(courses) : null),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
