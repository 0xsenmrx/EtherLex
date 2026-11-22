import 'package:flutter/widgets.dart';

import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../domain/proposed_files.dart';

/// Asks which of [options] is meant. Returns its id, or null when cancelled.
Future<int?> pickChoice(BuildContext context, String title, List<PickOption> options) =>
    showEtherDialog<int>(context, (_) => _ChoicePick(title, options), maxWidth: 520);

class _ChoicePick extends StatelessWidget {
  const _ChoicePick(this.title, this.options);

  final String title;
  final List<PickOption> options;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return EDialog(
      title: title,
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final o in options)
                ETap(
                  onTap: () => Navigator.of(context).pop(o.id),
                  builder: (context, s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(color: s.hovered ? c.hover : const Color(0x00000000), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.label, style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (o.sub.isNotEmpty) Text(o.sub, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [EButton(label: 'Cancel', kind: EButtonKind.ghost, onTap: () => Navigator.of(context).pop())],
    );
  }
}
