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
  Course? _picked;

  Course? _course(List<Course> courses) => _picked ?? matchCourse(widget.proposal.course, courses);

  Future<void> _choose(List<Course> courses) async {
    final course = await pickCourse(context, courses);
    if (course != null && mounted) setState(() => _picked = course);
  }

  Future<void> _allow(Course course) async {
    if (_busy) return;
    // The listing goes to the AI service like any attachment: the same permission.
    if (!await ensureConsent(context, ref) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await ref.read(courseFilesProvider(course.id).future);
      final text = fileTreeText(data, ref.read(hiddenFoldersProvider));
      ref.read(lookupAnswersProvider.notifier).answer(widget.source, true);
      await ref.read(chatControllerProvider.notifier).send(
        'Yes, go ahead. Here is the file list of ${course.name}.',
        items: [FileListContext(course: course.name, text: text)],
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
    final course = _course(courses);

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
          Text(
            course == null
                ? 'Which course? "${widget.proposal.course}" does not match exactly one.'
                : 'The file list of ${course.name}: folder and file names and sizes, no contents.',
            style: t.body,
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
                Expanded(child: Text('Allowed: the file list was sent with your message.', style: t.label)),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    answer == false ? 'Not shared.' : 'It is sent to your AI service only if you allow it.',
                    style: t.metaMuted,
                  ),
                ),
                const SizedBox(width: 12),
                if (answer == null && course == null)
                  EButton(label: 'Choose course', kind: EButtonKind.primary, onTap: () => _choose(courses))
                else if (answer == null) ...[
                  EButton(
                    label: 'Not now',
                    kind: EButtonKind.ghost,
                    onTap: _busy ? null : () => ref.read(lookupAnswersProvider.notifier).answer(widget.source, false),
                  ),
                  const SizedBox(width: 8),
                  EButton(label: 'Allow', icon: EIcons.check, kind: EButtonKind.primary, loading: _busy, onTap: () => _allow(course!)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
