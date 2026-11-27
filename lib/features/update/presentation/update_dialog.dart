import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_info.dart';
import '../../../core/utils/format.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../domain/release_notes.dart';
import 'update_providers.dart';

/// "What's new" for the available release, with the Update button.
Future<void> showUpdateDialog(BuildContext context) =>
    showEtherDialog<void>(context, (_) => const UpdateDialog(), maxWidth: 520, selectable: true);

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final state = ref.watch(updateProvider);
    final updates = ref.read(updateProvider.notifier);
    final info = state.info;
    if (info == null) {
      return EDialog(
        title: 'Updates',
        body: Text(state.message ?? 'EtherLex is up to date.', style: t.bodySecondary),
        actions: [
          EButton(label: 'Done', kind: EButtonKind.primary, onTap: () => Navigator.of(context).pop()),
        ],
      );
    }
    final downloading = state.status == UpdateStatus.downloading;
    final failed = state.status == UpdateStatus.failed;
    final size = info.size;
    return EDialog(
      eyebrow: 'You have version $kAppVersion',
      title: '$kAppName ${info.version} is available',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What's new", style: t.label),
          const SizedBox(height: 8),
          ReleaseNotesView(info.notes),
          if (downloading) ...[
            const SizedBox(height: 16),
            _ProgressBar(value: state.progress),
            const SizedBox(height: 6),
            Text(
              state.progress >= 1
                  ? 'Starting the installer...'
                  : 'Downloading ${(state.progress * 100).floor()}%${size == null ? '' : ' of ${formatBytes(size)}'}',
              style: t.metaMuted,
            ),
          ],
          if (failed) ...[
            const SizedBox(height: 16),
            Text(state.message ?? 'The update failed.', style: t.meta.copyWith(color: c.danger)),
          ],
          if (!downloading) ...[
            const SizedBox(height: 16),
            Text(
              'EtherLex closes, updates and opens again. Your settings and offline files stay.',
              style: t.metaMuted,
            ),
          ],
        ],
      ),
      leading: [
        EButton(
          label: 'Skip this version',
          kind: EButtonKind.ghost,
          onTap: downloading
              ? null
              : () {
                  updates.skipVersion();
                  Navigator.of(context).pop();
                },
        ),
      ],
      actions: [
        EButton(
          label: 'Later',
          kind: EButtonKind.ghost,
          onTap: downloading ? null : () => Navigator.of(context).pop(),
        ),
        EButton(
          label: failed ? 'Try again' : 'Update and restart',
          kind: EButtonKind.primary,
          loading: downloading,
          autofocus: true,
          onTap: downloading ? null : () => updates.install(),
        ),
      ],
    );
  }
}

/// Release description as plain headings, bullets and paragraphs.
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView(this.body, {super.key});

  final String body;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final lines = parseReleaseNotes(body);
    if (lines.isEmpty) return Text('No release notes.', style: t.bodySecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          switch (line.kind) {
            NoteKind.heading => Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(line.text, style: t.meta.copyWith(fontWeight: FontWeight.w600)),
              ),
            NoteKind.bullet => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: t.bodySecondary),
                    Expanded(child: Text(line.text, style: t.body)),
                  ],
                ),
              ),
            NoteKind.text => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line.text, style: t.body),
              ),
          },
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: ColoredBox(
          color: c.line,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: c.accent),
            ),
          ),
        ),
      ),
    );
  }
}
