import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'springs.dart';

/// Animates one double toward [target] with a spring. Changing [target]
/// mid-flight keeps the current velocity, so motion is always interruptible.
class SpringValue extends StatefulWidget {
  const SpringValue({
    super.key,
    required this.target,
    required this.builder,
    this.spring,
    this.initial,
    this.delay = Duration.zero,
    this.child,
  });

  final double target;

  /// If set (and different from [target]) the value animates from here on first build.
  final double? initial;
  final SpringDescription? spring;
  final Duration delay;
  final Widget? child;
  final Widget Function(BuildContext context, double value, Widget? child) builder;

  @override
  State<SpringValue> createState() => _SpringValueState();
}

class _SpringValueState extends State<SpringValue> with SingleTickerProviderStateMixin {
  // Created on the first animation only: most instances (a press effect on
  // every list row) never animate, and a controller also means a ticker.
  AnimationController? _controller;
  late final double _resting = widget.initial ?? widget.target;
  Timer? _delayTimer;

  SpringDescription get _spring => widget.spring ?? Springs.snappy;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null && widget.initial != widget.target) {
      _animateTo(widget.target, widget.delay);
    }
  }

  @override
  void didUpdateWidget(SpringValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _animateTo(widget.target, Duration.zero);
    }
  }

  void _animateTo(double target, Duration delay) {
    _delayTimer?.cancel();
    // From initState/didUpdateWidget a build follows anyway; from the delay
    // timer we must ask for one when the controller is new.
    void start({required bool rebuild}) {
      if (!mounted) return;
      var controller = _controller;
      if (controller == null) {
        controller = _controller = AnimationController.unbounded(vsync: this, value: _resting);
        if (rebuild) setState(() {});
      }
      controller.animateWith(
        SpringSimulation(_spring, controller.value, target, controller.velocity),
      );
    }

    if (delay == Duration.zero) {
      start(rebuild: false);
    } else {
      _delayTimer = Timer(delay, () => start(rebuild: true));
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // Windows' "Animation effects" off (or Flutter's disableAnimations): no
    // spring, the value is simply at its target.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      if (controller != null && controller.isAnimating) controller.stop();
      return AnimatedBuilder(
        animation: const AlwaysStoppedAnimation<double>(0),
        child: widget.child,
        builder: (context, child) => widget.builder(context, widget.target, child),
      );
    }
    // Always an AnimatedBuilder, so the subtree keeps its place (and state)
    // when the controller appears.
    return AnimatedBuilder(
      animation: controller ?? const AlwaysStoppedAnimation<double>(0),
      child: widget.child,
      builder: (context, child) => widget.builder(context, controller?.value ?? _resting, child),
    );
  }
}

/// A [Curve] shaped by a spring, for APIs that only accept curves
/// (route transitions, ScrollPosition.animateTo). Use [duration] with it.
class SpringCurve extends Curve {
  SpringCurve(this.spring) : _simulation = SpringSimulation(spring, 0, 1, 0);

  final SpringDescription spring;
  final SpringSimulation _simulation;
  late final double _settleSeconds = _findSettleSeconds();

  Duration get duration => Duration(milliseconds: (_settleSeconds * 1000).ceil());

  double _findSettleSeconds() {
    var t = 0.0;
    while (t < 3 && !_simulation.isDone(t)) {
      t += 1 / 120;
    }
    return t;
  }

  @override
  double transformInternal(double t) => _simulation.x(t * _settleSeconds);
}
