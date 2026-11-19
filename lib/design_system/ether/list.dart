import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';
import '../../core/sync/sync_state.dart';
import '../../core/utils/math.dart';
import '../theme/ether_theme.dart';
import 'controls.dart';
import 'icons.dart';
import 'tap.dart';

const Color _clear = Color(0x00000000);

/// Title, one quiet line under it, and actions on the right.
class EPageHeader extends StatelessWidget {
  const EPageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final sub = subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.display, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(sub, style: t.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 10), a],
        ],
      ),
    );
  }
}

/// "Updated 11:19" plus a refresh button whose icon spins while loading.
class ESyncButton extends StatelessWidget {
  const ESyncButton({super.key, required this.state, required this.onRefresh});

  final SyncState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final last = state.lastUpdated;
    final String? label;
    if (state.loading) {
      label = 'Updating…';
    } else if (state.error != null) {
      label = 'Update failed';
    } else if (last != null) {
      label = 'Updated ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    } else {
      label = null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label, style: t.metaMuted.copyWith(color: state.error != null ? c.danger : null)),
          const SizedBox(width: 10),
        ],
        ETap(
          onTap: state.loading ? null : onRefresh,
          pressedScale: 0.92,
          builder: (context, s) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: s.hovered ? c.hover : _clear,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: s.hovered ? c.lineStrong : c.line),
              boxShadow: focusRing(c, s.focused),
            ),
            child: _Spin(
              spinning: state.loading,
              child: Icon(EIcons.refresh, size: 16, color: s.hovered ? c.textPrimary : c.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

class _Spin extends StatefulWidget {
  const _Spin({required this.spinning, required this.child});
  final bool spinning;
  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  bool _disposed = false;

  @override
  void didUpdateWidget(_Spin old) {
    super.didUpdateWidget(old);
    if (widget.spinning == old.spinning) return;
    if (widget.spinning) {
      // Also takes over a turn that was still finishing.
      _c.repeat();
    } else {
      // Finish the turn instead of snapping back. If a new sync starts
      // meanwhile, repeat() cancels this and the reset is skipped.
      _c.animateTo(1).whenCompleteOrCancel(() {
        if (!_disposed && !widget.spinning) _c.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _c.dispose();
    super.dispose();
  }

  // Own layer: the rotation repaints only the icon, not the page around it.
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: RotationTransition(turns: _c, child: widget.child));
}

/// Segmented filter, like Oleafly's list/grid toggle.
class ESegmented extends StatelessWidget {
  const ESegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.canvas,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            ETap(
              onTap: () => onChanged(i),
              pressedScale: 0.96,
              builder: (context, s) {
                final on = i == selected;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? c.selected : (s.hovered ? c.hover : _clear),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: focusRing(c, s.focused),
                  ),
                  child: Text(
                    labels[i],
                    style: t.label.copyWith(color: on || s.hovered ? c.textPrimary : c.textSecondary),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Spaced caps label with a count and a hairline, between groups of rows.
class EGroupHeader extends StatelessWidget {
  const EGroupHeader({
    super.key,
    required this.label,
    required this.count,
    this.onTap,
    this.expanded,
  });

  static const double extent = 40;

  final String label;
  final int count;

  /// When set, the header folds its group (with a chevron).
  final VoidCallback? onTap;
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    Widget content(bool hovered) => Padding(
          padding: const EdgeInsets.only(left: 12, right: 4, top: 12),
          child: Row(
            children: [
              if (expanded != null) ...[
                SpringValue(
                  target: expanded! ? 1 : 0,
                  spring: Springs.snappy,
                  builder: (context, v, child) => Transform.rotate(angle: v * math.pi / 2, child: child),
                  child: Icon(EIcons.chevronRight, size: 13, color: hovered ? c.textPrimary : c.textTertiary),
                ),
                const SizedBox(width: 6),
              ],
              Text(label.toUpperCase(),
                  style: t.caption.copyWith(color: hovered ? c.textSecondary : null)),
              const SizedBox(width: 8),
              Text('$count', style: t.caption),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 1, color: c.line)),
            ],
          ),
        );
    final tap = onTap;
    return SizedBox(
      height: extent,
      child: tap == null
          ? content(false)
          : ETap(onTap: tap, pressedScale: 1, builder: (context, s) => content(s.hovered)),
    );
  }
}

/// Section label inside a details pane.
class ESectionLabel extends StatelessWidget {
  const ESectionLabel(this.label, {super.key, this.trailing});
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final tr = trailing;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: t.caption),
          if (tr != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr, style: t.metaMuted, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    );
  }
}

/// Round checkbox: the fill grows with a spring, the tick draws along its path.
class ECheck extends StatelessWidget {
  const ECheck({super.key, required this.checked, required this.onTap});

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: SpringValue(
              target: checked ? 1 : 0,
              spring: Springs.glide,
              builder: (context, v, _) => CustomPaint(
                size: const Size(18, 18),
                painter: _CheckPainter(v, ring: c.textTertiary, fill: c.accent, tick: c.onAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, {required this.ring, required this.fill, required this.tick});
  final double t;
  final Color ring;
  final Color fill;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 0.8;
    final tt = clamp01(t);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(ring, fill, tt)!,
    );
    if (t <= 0) return;
    canvas.drawCircle(center, (r + 0.75) * clamp01(t), Paint()..color = fill);
    final progress = clamp01((t - 0.35) / 0.65);
    if (progress <= 0) return;
    final s = size.width / 20;
    final path = Path()
      ..moveTo(5.8 * s, 10.4 * s)
      ..lineTo(8.8 * s, 13.4 * s)
      ..lineTo(14.4 * s, 7.2 * s);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tick,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.t != t || old.ring != ring || old.fill != fill || old.tick != tick;
}

/// Star toggle with a small pop when it turns on. [visible] false keeps its
/// space but draws nothing (rows show it on hover only).
class EStar extends StatefulWidget {
  const EStar({super.key, required this.starred, required this.onTap, this.visible = true});

  final bool starred;
  final VoidCallback onTap;
  final bool visible;

  @override
  State<EStar> createState() => _EStarState();
}

class _EStarState extends State<EStar> {
  bool _hover = false;

  // Pops only when the star is switched on here, not whenever a starred row
  // is built (scrolled into view, filtered, re-synced).
  int _pops = 0;

  @override
  void didUpdateWidget(EStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.starred && !oldWidget.starred) _pops++;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final show = widget.visible || widget.starred;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: !show
              ? null
              : Center(
                  child: SpringValue(
                    key: ValueKey<int>(_pops),
                    initial: _pops > 0 ? 0.55 : null,
                    target: 1,
                    spring: Springs.bouncy,
                    builder: (context, v, child) => Transform.scale(scale: v, child: child),
                    child: Icon(
                      widget.starred ? EIcons.starFilled : EIcons.star,
                      size: widget.starred ? 19 : 16,
                      color: widget.starred
                          ? c.star
                          : (_hover ? c.textPrimary : c.textTertiary),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Calm empty state: an icon, a line and an optional action.
class EEmptyState extends StatelessWidget {
  const EEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final msg = message;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.canvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.line),
              ),
              child: Icon(icon, size: 22, color: c.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(title, style: t.heading, textAlign: TextAlign.center),
            if (msg != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(msg, style: t.bodySecondary, textAlign: TextAlign.center),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class EErrorState extends StatelessWidget {
  const EErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EEmptyState(
        icon: EIcons.alert,
        title: 'Could not load this',
        message: message,
        action: EButton(label: 'Try again', icon: EIcons.refresh, onTap: onRetry),
      );
}

/// Placeholder rows that breathe while the first data loads.
class ESkeletonList extends StatefulWidget {
  const ESkeletonList({super.key, this.rows = 8, this.rowHeight = 52});
  final int rows;
  final double rowHeight;

  @override
  State<ESkeletonList> createState() => _ESkeletonListState();
}

class _ESkeletonListState extends State<ESkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.45,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: c.selected, borderRadius: BorderRadius.circular(6)),
        );
    return FadeTransition(
      opacity: _c,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            for (var i = 0; i < widget.rows; i++)
              SizedBox(
                height: widget.rowHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: c.selected, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          bar(140.0 + (i * 53) % 180, 11),
                          const SizedBox(height: 7),
                          bar(90.0 + (i * 31) % 70, 8),
                        ],
                      ),
                    ),
                    bar(64, 10),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
