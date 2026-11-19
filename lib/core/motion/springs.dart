import 'package:flutter/physics.dart';

/// The only spring presets the app uses for interruptible motion.
abstract final class Springs {
  /// Hover, press, toggles: fast with a tiny overshoot.
  static final SpringDescription snappy =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 520, ratio: 0.9);

  /// Panels, scrolling, content: critically damped, never overshoots.
  static final SpringDescription smooth =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 240, ratio: 1.0);

  /// Selection pill gliding between items: a hint of overshoot.
  static final SpringDescription glide =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.82);

  /// Delight moments (star pop, switch knob).
  static final SpringDescription bouncy =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.45);

  /// Dialog entrance.
  static final SpringDescription dialog =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 320, ratio: 0.72);
}
