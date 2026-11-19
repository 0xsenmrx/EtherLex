import 'package:flutter/widgets.dart';

import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';
import '../../core/utils/math.dart';
import '../theme/ether_theme.dart';
import 'controls.dart';
import 'icons.dart';

/// Content width from which list screens show details beside the list
/// instead of in a dialog.
const double kDetailPaneBreakpoint = 860;

double detailPaneWidthFor(double contentWidth) => contentWidth >= 1180 ? 460 : 400;

/// Raised panel on the right of a list. Slides open when [child] is set and
/// closed when it is null (keeping the last content while it closes). The
/// content is laid out at full width during the slide, so it never reflows.
class DetailPane extends StatefulWidget {
  const DetailPane({
    super.key,
    required this.child,
    required this.identity,
    required this.width,
    required this.onClose,
  });

  final Widget? child;

  /// Changes when a different item is shown, which resets the scroll.
  final Object? identity;
  final double width;
  final VoidCallback onClose;

  @override
  State<DetailPane> createState() => _DetailPaneState();
}

class _DetailPaneState extends State<DetailPane> {
  Widget? _last;
  Object? _lastIdentity;

  @override
  Widget build(BuildContext context) {
    final open = widget.child != null;
    if (open) {
      _last = widget.child;
      _lastIdentity = widget.identity;
    }
    return SpringValue(
      target: open ? 1 : 0,
      spring: Springs.smooth,
      builder: (context, v, _) {
        final t = clamp01(v);
        final last = _last;
        if (t <= 0.001 || last == null) return const SizedBox.shrink();
        return SizedBox(
          width: widget.width * t,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: widget.width,
              maxWidth: widget.width,
              // Own layer: while the pane slides, only the clip changes and
              // the content is not repainted.
              child: RepaintBoundary(
                child: _Frame(identity: _lastIdentity, onClose: widget.onClose, child: last),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, required this.identity, required this.onClose});

  final Widget child;
  final Object? identity;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  key: ValueKey<Object?>(identity),
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
                  child: child,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: EIconButton(
                  icon: EIcons.close,
                  tooltip: 'Close',
                  size: 30,
                  iconSize: 15,
                  bordered: false,
                  onTap: onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
