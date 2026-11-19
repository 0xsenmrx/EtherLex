import 'dart:async';

import 'package:flutter/widgets.dart';

/// Runs [onPrefetch] once the pointer has rested on [child] for [delay], so
/// the data is already loading by the time the user clicks. Moving across a
/// list quickly triggers nothing.
class HoverPrefetch extends StatefulWidget {
  const HoverPrefetch({
    super.key,
    required this.onPrefetch,
    required this.child,
    this.delay = const Duration(milliseconds: 180),
  });

  final VoidCallback onPrefetch;
  final Duration delay;
  final Widget child;

  @override
  State<HoverPrefetch> createState() => _HoverPrefetchState();
}

class _HoverPrefetchState extends State<HoverPrefetch> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onEnter: (_) {
        _timer?.cancel();
        _timer = Timer(widget.delay, widget.onPrefetch);
      },
      onExit: (_) => _timer?.cancel(),
      child: widget.child,
    );
  }
}
