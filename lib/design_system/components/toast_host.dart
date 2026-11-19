import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';
import '../../core/notify/toast.dart';
import '../../core/utils/math.dart';
import '../ether/tap.dart';
import '../theme/ether_theme.dart';

/// Wraps the app; shows the current toast above everything.
class ToastHost extends ConsumerStatefulWidget {
  const ToastHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends ConsumerState<ToastHost> {
  ToastMessage? _shown;

  @override
  Widget build(BuildContext context) {
    final msg = ref.watch(toastProvider);
    if (msg != null) _shown = msg;
    final shown = _shown;
    final visible = msg != null;

    return Stack(
      children: [
        widget.child,
        if (shown != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: IgnorePointer(
              ignoring: !visible,
              child: Center(
                child: SpringValue(
                  target: visible ? 1 : 0,
                  spring: Springs.dialog,
                  builder: (context, v, child) {
                    final o = clamp01(v);
                    if (o <= 0.01 && !visible) return const SizedBox.shrink();
                    return Opacity(
                      opacity: o,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * 18),
                        child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
                      ),
                    );
                  },
                  child: _ToastPill(message: shown),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastPill extends ConsumerWidget {
  const _ToastPill({required this.message});
  final ToastMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final action = message.actionLabel;
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: EdgeInsets.fromLTRB(16, 9, action == null ? 16 : 8, 9),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.lineStrong),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(message.text, style: t.label, maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (action != null) ...[
            const SizedBox(width: 12),
            ETap(
              onTap: () {
                message.onAction?.call();
                ref.read(toastProvider.notifier).dismiss();
              },
              builder: (context, s) => AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: s.hovered ? c.accentSoft : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: focusRing(c, s.focused),
                ),
                child: Text(action, style: t.button.copyWith(color: c.accent)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
