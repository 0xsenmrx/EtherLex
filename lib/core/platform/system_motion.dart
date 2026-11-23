import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _window = MethodChannel('etherlex/window');

/// True when Windows' "Animation effects" is off (Settings > Accessibility >
/// Visual effects). Flutter does not report it on Windows, so the runner is
/// asked at start and whenever EtherLex comes back to the front. The app
/// folds it into `MediaQuery.disableAnimations`, which every animation reads.
final ValueNotifier<bool> systemAnimationsOff = ValueNotifier<bool>(false);

/// For code without a BuildContext (route durations): Windows' setting or
/// the one Flutter reports itself.
bool get animationsOff =>
    systemAnimationsOff.value || WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

Future<void> refreshSystemAnimations() async {
  if (!Platform.isWindows) return;
  try {
    final on = await _window.invokeMethod<bool>('animationsEnabled');
    if (on != null) systemAnimationsOff.value = !on;
  } on MissingPluginException {
    // Not in the EtherLex runner (tests).
  } on PlatformException {
    // The window is not ready; the next refresh asks again.
  }
}

/// Asks now, and again each time EtherLex comes back to the front (the
/// setting may have changed meanwhile).
void watchSystemAnimations() {
  unawaited(refreshSystemAnimations());
  WidgetsBinding.instance.addObserver(_MotionObserver());
}

class _MotionObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshSystemAnimations());
  }
}
