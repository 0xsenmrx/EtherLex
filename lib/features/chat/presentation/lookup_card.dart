import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../assignments/presentation/assignments_providers.dart';
import '../../courses/domain/course.dart';
import '../../files/presentation/files_providers.dart';
import '../../grades/domain/plan_proposal.dart';
import '../domain/context_item.dart';
import '../domain/file_tree_text.dart';
import '../domain/proposed_lookup.dart';
import 'chat_attach.dart';
import 'chat_controller.dart';
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

/// "To do that I need to see the file list of the course": the assistant asks,
/// the student decides. Allowing loads the listing and sends it with a short
/// message, so the assistant can carry on with the exact folder names.
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

  /// Courses the student picked for names that did not match: place in the list -> course.
  final Map<int, Course> _picked = {};

  /// The course each name means, or null where none or several fit.
  List<Course?> _resolve(List<Course> courses) => [
        for (final (i, name) in widget.proposal.courses.indexed) _picked[i] ?? matchCourse(name, courses),
      ];

  Future<void> _choose(int index, List<Course> courses) async {
    final course = await pickCourse(context, courses);
    if (course != null && mounted) setState(() => _picked[index] = course);
  }

  Future<void> _allow(List<Course> resolved) async {
    if (_busy) return;
    // The listings go to the AI service like any attachment: the same permission.
    if (!await ensureConsent(context, ref) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final hidden = ref.read(hiddenFoldersProvider);
      final items = <FileListContext>[];
      for (final course in resolved) {
        final data = await ref.read(courseFilesProvider(course.id).future);
        items.add(FileListContext(course: course.name, text: fileTreeText(data, hidden)));
      }
      if (!mounted) return;
      ref.read(lookupAnswersProvider.notifier).answer(widget.source, true);
      final names = resolved.map((c) => c.name).join(', ');
      await ref.read(chatControllerProvider.notifier).send(
        resolved.length == 1 ? 'Yes, go ahead. Here is the file list of $names.' : 'Yes, go ahead. Here are the file lists of $names.',
        items: items,
      );
    } on CanvasException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the files. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final courses = ref.watch(coursesProvider).value ?? const <Course>[];
    final answer = ref.watch(lookupAnswersProvider)[widget.source];
    final resolved = _resolve(courses);
    final allKnown = resolved.every((r) => r != null);

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
              Expanded(child: Text('Needs to look at your files', style: t.label)),
            ],
          ),
          const SizedBox(height: 8),
          Text('The file lists (folder and file names and sizes, no contents) of:', style: t.meta),
          const SizedBox(height: 4),
          for (final (i, r) in resolved.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r?.name ?? '"${widget.proposal.courses[i]}": which course?',
                      style: r == null ? t.meta : t.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (r == null && answer == null) EButton(label: 'Choose course', kind: EButtonKind.ghost, onTap: () => _choose(i, courses)),
                ],
              ),
            ),
          if (widget.proposal.note != null) ...[
            const SizedBox(height: 4),
            Text(widget.proposal.note!, style: t.metaMuted),
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
                Expanded(child: Text('Allowed: the file lists were sent with your message.', style: t.label)),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    answer == false ? 'Not shared.' : 'They are sent to your AI service only if you allow it.',
                    style: t.metaMuted,
                  ),
                ),
                const SizedBox(width: 12),
                if (answer == null) ...[
                  EButton(
                    label: 'Not now',
                    kind: EButtonKind.ghost,
                    onTap: _busy ? null : () => ref.read(lookupAnswersProvider.notifier).answer(widget.source, false),
                  ),
                  const SizedBox(width: 8),
                  EButton(
                    label: 'Allow',
                    icon: EIcons.check,
                    kind: EButtonKind.primary,
                    loading: _busy,
                    onTap: allKnown ? () => _allow([for (final r in resolved) r!]) : null,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
