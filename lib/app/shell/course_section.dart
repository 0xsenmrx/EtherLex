import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/smooth_scroll.dart';
import '../../core/motion/spring_value.dart';
import '../../core/motion/springs.dart';
import '../../core/notify/toast.dart';
import '../../design_system/ether/controls.dart';
import '../../design_system/ether/icons.dart';
import '../../design_system/ether/tap.dart';
import '../../design_system/theme/course_palette.dart';
import '../../design_system/theme/ether_theme.dart';
import '../../features/assignments/presentation/assignments_providers.dart';

/// Sidebar list of courses. Click to filter (several can be on); hover a
/// course to move it to Disabled.
class CourseSection extends ConsumerStatefulWidget {
  const CourseSection({super.key});

  @override
  ConsumerState<CourseSection> createState() => _CourseSectionState();
}

class _CourseSectionState extends ConsumerState<CourseSection> {
  final SmoothScrollController _scroll = SmoothScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final entries = ref.watch(filterableCoursesProvider);
    final selected = ref.watch(courseFilterProvider);
    final disabledIds = ref.watch(disabledCoursesProvider);
    final filter = ref.read(courseFilterProvider.notifier);
    final disabledNotifier = ref.read(disabledCoursesProvider.notifier);
    if (entries.length < 2) return const SizedBox.shrink();

    final active = [for (final e in entries) if (!disabledIds.contains(e.course.id)) e];
    final inactive = [for (final e in entries) if (disabledIds.contains(e.course.id)) e];

    void disable(CourseEntry e) {
      disabledNotifier.disable(e.course.id);
      ref.read(toastProvider.notifier).show(
            '${e.course.shortLabel} moved to Disabled',
            actionLabel: 'Undo',
            onAction: () => disabledNotifier.enable(e.course.id),
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(
              children: [
                Text('COURSES', style: t.caption),
                const Spacer(),
                if (selected.isNotEmpty)
                  ETap(
                    onTap: filter.clear,
                    builder: (context, s) => Text(
                      'Clear',
                      style: t.meta.copyWith(color: s.hovered ? c.textPrimary : c.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            children: [
              for (final e in active)
                _CourseRow(
                  key: ValueKey<int>(e.course.id),
                  entry: e,
                  active: selected.contains(e.course.id),
                  disabled: false,
                  onTap: () => filter.toggle(e.course.id),
                  onToggleDisabled: () => disable(e),
                ),
              if (inactive.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _DisabledFolder(
                    entries: inactive,
                    selected: selected,
                    onTap: (e) => filter.toggle(e.course.id),
                    onEnable: (e) => disabledNotifier.enable(e.course.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DisabledFolder extends StatefulWidget {
  const _DisabledFolder({
    required this.entries,
    required this.selected,
    required this.onTap,
    required this.onEnable,
  });

  final List<CourseEntry> entries;
  final Set<int> selected;
  final void Function(CourseEntry) onTap;
  final void Function(CourseEntry) onEnable;

  @override
  State<_DisabledFolder> createState() => _DisabledFolderState();
}

class _DisabledFolderState extends State<_DisabledFolder> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ETap(
          onTap: () => setState(() => _open = !_open),
          pressedScale: 0.985,
          builder: (context, s) {
            final fg = s.hovered ? c.textSecondary : c.textTertiary;
            return Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: focusRing(c, s.focused),
              ),
              child: Row(
                children: [
                  SpringValue(
                    target: _open ? 1 : 0,
                    spring: Springs.snappy,
                    builder: (context, v, child) =>
                        Transform.rotate(angle: v * math.pi / 2, child: child),
                    child: Icon(EIcons.chevronRight, size: 14, color: fg),
                  ),
                  const SizedBox(width: 6),
                  Icon(EIcons.folderClosed, size: 14, color: fg),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Disabled', style: t.label.copyWith(color: fg))),
                  Text('${widget.entries.length}', style: t.metaMuted),
                ],
              ),
            );
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  children: [
                    for (final e in widget.entries)
                      _CourseRow(
                        key: ValueKey<int>(e.course.id),
                        entry: e,
                        active: widget.selected.contains(e.course.id),
                        disabled: true,
                        onTap: () => widget.onTap(e),
                        onToggleDisabled: () => widget.onEnable(e),
                      ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The disable/enable button shows on hover, and also while the row or the
/// button has keyboard focus, so Tab from a course reaches it.
class _CourseRow extends StatefulWidget {
  const _CourseRow({
    super.key,
    required this.entry,
    required this.active,
    required this.disabled,
    required this.onTap,
    required this.onToggleDisabled,
  });

  final CourseEntry entry;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;
  final VoidCallback onToggleDisabled;

  @override
  State<_CourseRow> createState() => _CourseRowState();
}

class _CourseRowState extends State<_CourseRow> {
  bool _focusWithin = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final entry = widget.entry;
    final active = widget.active;
    final disabled = widget.disabled;
    // Only for keyboard focus: a mouse click on the row must not show it.
    final keyboard = _focusWithin && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (v) => setState(() => _focusWithin = v),
        child: ETap(
        onTap: widget.onTap,
        pressedScale: 0.985,
        builder: (context, s) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 32,
          padding: EdgeInsets.only(left: disabled ? 24 : 12, right: 4),
          decoration: BoxDecoration(
            color: active ? c.selected : (s.hovered ? c.hover : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: focusRing(c, s.focused),
          ),
          child: Row(
            children: [
              ESwatch(CoursePalette.colorFor(entry.course.id), dim: disabled),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.course.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    color: disabled
                        ? c.textTertiary
                        : (active || s.hovered ? c.textPrimary : c.textSecondary),
                  ),
                ),
              ),
              if (s.hovered || keyboard)
                EIconButton(
                  icon: disabled ? EIcons.eye : EIcons.eyeOff,
                  tooltip: disabled ? 'Enable course' : 'Disable course',
                  size: 26,
                  iconSize: 14,
                  bordered: false,
                  onTap: widget.onToggleDisabled,
                )
              else if (entry.openCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${entry.openCount}', style: t.metaMuted),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
