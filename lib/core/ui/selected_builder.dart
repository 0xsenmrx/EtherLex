import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

/// Rebuilds [builder] only when this row's selected state changes.
///
/// A plain ValueListenableBuilder on the list's cursor rebuilds every visible
/// row on each cursor move; with this, moving the cursor rebuilds two rows
/// (the old and the new one).
class SelectedBuilder<T> extends StatefulWidget {
  const SelectedBuilder({
    super.key,
    required this.cursor,
    required this.id,
    required this.builder,
    this.child,
  });

  final ValueListenable<T?> cursor;
  final T id;
  final Widget Function(BuildContext context, bool selected, Widget? child) builder;
  final Widget? child;

  @override
  State<SelectedBuilder<T>> createState() => _SelectedBuilderState<T>();
}

class _SelectedBuilderState<T> extends State<SelectedBuilder<T>> {
  late bool _selected = widget.cursor.value == widget.id;

  @override
  void initState() {
    super.initState();
    widget.cursor.addListener(_changed);
  }

  @override
  void didUpdateWidget(SelectedBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.cursor, widget.cursor)) {
      oldWidget.cursor.removeListener(_changed);
      widget.cursor.addListener(_changed);
    }
    _selected = widget.cursor.value == widget.id;
  }

  @override
  void dispose() {
    widget.cursor.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final selected = widget.cursor.value == widget.id;
    if (selected != _selected) setState(() => _selected = selected);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _selected, widget.child);
}
