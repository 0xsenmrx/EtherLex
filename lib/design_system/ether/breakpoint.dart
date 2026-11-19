import 'package:flutter/widgets.dart';

/// Rebuilds [builder] only when the coarse layout [mode] changes (or this
/// widget is rebuilt by its parent). Plain resizes in between re-lay out the
/// same widgets without rebuilding them, which keeps window resizing smooth.
///
/// [mode] must have value equality (bool, num, enum, or a record of those).
class BreakpointBuilder<T> extends StatefulWidget {
  const BreakpointBuilder({super.key, required this.mode, required this.builder});

  final T Function(BoxConstraints constraints) mode;
  final Widget Function(BuildContext context, T mode) builder;

  @override
  State<BreakpointBuilder<T>> createState() => _BreakpointBuilderState<T>();
}

class _BreakpointBuilderState<T> extends State<BreakpointBuilder<T>> {
  T? _mode;
  Widget? _child;
  BoxConstraints? _constraints;

  @override
  void didUpdateWidget(covariant BreakpointBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _child = null; // the parent rebuilt: its data may have changed
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = widget.mode(constraints);
        final cached = _child;
        // Same constraints means this is not a resize: the builder's own
        // dependencies (theme, providers read here) changed, so build again.
        final resized = constraints != _constraints;
        _constraints = constraints;
        if (cached != null && resized && mode == _mode) return cached;
        _mode = mode;
        return _child = widget.builder(context, mode);
      },
    );
  }
}
