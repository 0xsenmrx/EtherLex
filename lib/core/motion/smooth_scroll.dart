import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

/// A [ScrollController] whose mouse-wheel scrolling glides instead of jumping.
///
/// Each wheel notch moves the destination; the view eases toward it with an
/// exponential curve that starts at full speed (no sluggish spring start) and
/// settles softly, like a browser. Repeated notches accumulate. Touchpad,
/// drag, keyboard and programmatic scrolling behave as usual.
class SmoothScrollController extends ScrollController {
  SmoothScrollController({
    super.initialScrollOffset,
    this.wheelMultiplier = 1.0,
    this.smoothing = 0.085,
  });

  /// 1.0 = Flutter's default distance per wheel notch.
  final double wheelMultiplier;

  /// Time constant in seconds. Lower = snappier, higher = floatier.
  final double smoothing;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
      wheelMultiplier: wheelMultiplier,
      smoothing: smoothing,
    );
  }
}

class _SmoothScrollPosition extends ScrollPositionWithSingleContext {
  _SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    required this.wheelMultiplier,
    required this.smoothing,
  });

  final double wheelMultiplier;
  final double smoothing;

  Ticker? _ticker;
  double? _target;
  double _lastSet = 0;
  Duration _prev = Duration.zero;

  bool get _gliding => _target != null && (_ticker?.isActive ?? false);

  void _stop() {
    _target = null;
    _ticker?.stop();
  }

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      super.pointerScroll(delta);
      return;
    }
    // Continue from the old destination only if nothing else has moved us.
    final continuing = _gliding && (pixels - _lastSet).abs() < 1.0;
    final base = continuing ? _target! : pixels;
    final target = math.min(
      math.max(base + delta * wheelMultiplier, minScrollExtent),
      maxScrollExtent,
    );
    if (target == pixels) {
      if (!continuing) return;
      _stop();
      return;
    }
    if (!continuing) goIdle();
    _target = target;
    _lastSet = pixels;
    final ticker = _ticker ??= context.vsync.createTicker(_tick);
    if (!ticker.isActive) {
      _prev = Duration.zero;
      ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _prev).inMicroseconds / 1e6;
    _prev = elapsed;
    final target = _target;
    if (target == null) {
      _ticker?.stop();
      return;
    }
    if ((pixels - _lastSet).abs() > 1.0) {
      // Dragged or scrolled by something else: let go.
      _stop();
      return;
    }
    final remaining = target - pixels;
    final next = remaining.abs() < 0.5
        ? target
        : pixels + remaining * (1 - math.exp(-dt / smoothing));
    final old = pixels;
    forcePixels(math.min(math.max(next, minScrollExtent), maxScrollExtent));
    didStartScroll();
    didUpdateScrollPositionBy(pixels - old);
    didEndScroll();
    _lastSet = pixels;
    if (next == target) _stop();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}
