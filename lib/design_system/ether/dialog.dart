import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Material, MaterialType, SelectionArea;

import '../../core/platform/system_motion.dart';
import '../theme/ether_theme.dart';
import 'controls.dart';

/// Opens [builder] in the shared dialog frame: at most 85% of the window
/// height, Esc or a click outside closes it. No backdrop blur (too costly).
///
/// [selectable] makes the text in it selectable and copyable (dialogs that
/// show something to read: a post, an assignment, a course's grades).
Future<T?> showEtherDialog<T>(
  BuildContext context,
  WidgetBuilder builder, {
  double maxWidth = 480,
  double? topFraction,
  bool selectable = false,
}) {
  final c = context.colors;
  final still = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || animationsOff;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: c.scrim,
    // Animation effects off: the dialog appears and goes at once.
    transitionDuration: still ? Duration.zero : const Duration(milliseconds: 180),
    pageBuilder: (context, _, _) =>
        _Frame(maxWidth: maxWidth, topFraction: topFraction, selectable: selectable, child: builder(context)),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      if (still) return child;
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, required this.maxWidth, this.topFraction, this.selectable = false});

  final Widget child;
  final double maxWidth;
  final bool selectable;

  /// Pins the dialog this far down the window (as a share of its height)
  /// instead of centring it, so it does not jump when its height changes.
  final double? topFraction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final height = MediaQuery.sizeOf(context).height;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Align(
          alignment: topFraction == null ? Alignment.center : Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, topFraction == null ? 24 : height * topFraction!, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: height * (topFraction == null ? 0.85 : 0.85 - topFraction!),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.line),
                  boxShadow: [
                    BoxShadow(color: c.shadow, blurRadius: 40, offset: const Offset(0, 16)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  // Own layer, so hover effects and spinners inside do not
                  // repaint the large shadow around the dialog.
                  child: RepaintBoundary(
                    child: Material(
                      type: MaterialType.transparency,
                      child: selectable ? SelectionArea(child: child) : child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard dialog layout: pinned header and footer, scrolling body.
class EDialog extends StatelessWidget {
  const EDialog({
    super.key,
    required this.title,
    this.eyebrow,
    this.body,
    this.actions = const [],
    this.leading = const [],
  });

  /// Small line above the title (for example the course).
  final String? eyebrow;
  final String title;
  final Widget? body;

  /// Right-aligned footer buttons; the last one is the main action.
  final List<Widget> actions;

  /// Left-aligned footer content.
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final eyebrow = this.eyebrow;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
              ],
              Text(title, style: t.title),
            ],
          ),
        ),
        if (body != null)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: body,
            ),
          ),
        if (actions.isNotEmpty || leading.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  ..._spaced(leading),
                  const Spacer(),
                  ..._spaced(actions),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static List<Widget> _spaced(List<Widget> items) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          items[i],
        ],
      ];
}

/// Yes/no question in the shared frame. Returns true only on confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showEtherDialog<bool>(
    context,
    (context) => EDialog(
      title: title,
      body: Text(message, style: context.text.bodySecondary),
      actions: [
        EButton(
          label: 'Cancel',
          kind: EButtonKind.ghost,
          onTap: () => Navigator.of(context).pop(false),
        ),
        EButton(
          label: confirmLabel,
          kind: destructive ? EButtonKind.danger : EButtonKind.primary,
          autofocus: true,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
    maxWidth: 420,
  );
  return ok ?? false;
}
