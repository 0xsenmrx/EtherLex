import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../design_system/ether/icons.dart';
import '../../design_system/theme/ether_theme.dart';

/// EtherLex draws its own title bar on Windows. The runner
/// (`windows/runner/window_frame.cpp`) removes the native caption but keeps a
/// normal window: borders, shadow, Aero Snap and the Snap Layouts flyout on
/// the maximise button. Run with the environment variable
/// `ETHERLEX_NATIVE_FRAME=1` to get the native caption back for comparisons.
final bool hasCustomFrame =
    Platform.isWindows && Platform.environment['ETHERLEX_NATIVE_FRAME'] != '1';

const double kTitleBarHeight = 52;

// Caption buttons: three hit areas of [_kButtonWidth] at the top right,
// [_kButtonsEndPadding] from the edge, the full title bar high.
const double _kButtonWidth = 44;
const double _kButtonsEndPadding = 8;

/// Space the top bar must leave free on the right for [WindowButtons].
double get windowButtonsInset =>
    hasCustomFrame ? _kButtonWidth * 3 + _kButtonsEndPadding : 0;

/// The window, through the runner's `etherlex/window` channel.
class WindowControl {
  WindowControl._();
  static final WindowControl instance = WindowControl._();

  static const MethodChannel _channel = MethodChannel('etherlex/window');

  final ValueNotifier<bool> maximized = ValueNotifier(false);

  /// The maximise button is a native hit area (that is what gives Snap
  /// Layouts), so Windows reports its state: 0 idle, 1 hovered, 2 pressed.
  final ValueNotifier<int> maxButton = ValueNotifier(0);

  bool _attached = false;

  /// Starts listening and tells the runner where the maximise button is.
  Future<void> attach() async {
    if (!hasCustomFrame || _attached) return;
    _attached = true;
    _channel.setMethodCallHandler(_onCall);
    await _invoke('setMaxButton', <double>[
      _kButtonsEndPadding + _kButtonWidth,
      0,
      _kButtonWidth,
      kTitleBarHeight,
    ]);
    try {
      final state = await _channel.invokeMapMethod<String, Object?>('state');
      maximized.value = state?['maximized'] == true;
    } on MissingPluginException {
      // Not running in the EtherLex runner (tests).
    }
  }

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'maximized':
        maximized.value = call.arguments == true;
      case 'maxButton':
        maxButton.value = call.arguments is int ? call.arguments as int : 0;
    }
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Not running in the EtherLex runner (tests).
    } on PlatformException {
      // The window refused (for example while it is being destroyed).
    }
  }

  void startDrag() => _invoke('startDrag');
  void minimize() => _invoke('minimize');
  void toggleMaximize() => _invoke('toggleMaximize');
  void close() => _invoke('close');
  void showSystemMenu() => _invoke('showSystemMenu');
}

/// Drag here to move the window; double-click to maximise or restore;
/// right-click for the window menu.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasCustomFrame) return const SizedBox.expand();
    final window = WindowControl.instance;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => window.startDrag(),
      onDoubleTap: window.toggleMaximize,
      onSecondaryTap: window.showSystemMenu,
      child: const SizedBox.expand(),
    );
  }
}

/// Minimise, maximise/restore and close, drawn in the app's own style.
class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    if (!hasCustomFrame) return const SizedBox.shrink();
    final window = WindowControl.instance;
    return RepaintBoundary(
      child: SizedBox(
        height: kTitleBarHeight,
        child: Padding(
          padding: const EdgeInsets.only(right: _kButtonsEndPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CaptionButton(icon: EIcons.minimize, onTap: window.minimize),
              // Windows handles this one's hover and clicks (Snap Layouts);
              // we only draw it.
              ValueListenableBuilder<bool>(
                valueListenable: window.maximized,
                builder: (context, maximized, _) => ValueListenableBuilder<int>(
                  valueListenable: window.maxButton,
                  builder: (context, state, _) => _CaptionButton(
                    icon: maximized ? EIcons.restore : EIcons.maximize,
                    iconSize: 13,
                    nativeState: state,
                    onTap: window.toggleMaximize,
                  ),
                ),
              ),
              _CaptionButton(icon: EIcons.close, danger: true, onTap: window.close),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 16,
    this.danger = false,
    this.nativeState,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  final bool danger;

  /// Hover/press reported by Windows (maximise button); null when Flutter
  /// receives the pointer itself.
  final int? nativeState;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hover = _hover || (widget.nativeState ?? 0) >= 1;
    final pressed = _pressed || widget.nativeState == 2;
    final Color bg;
    if (!hover) {
      bg = const Color(0x00000000);
    } else if (widget.danger) {
      bg = pressed ? const Color(0xFFC53A3F) : const Color(0xFFE5484D);
    } else {
      bg = pressed ? c.selected : c.hover;
    }
    final fg = hover && widget.danger ? const Color(0xFFFFFFFF) : c.textSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = _pressed = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: SizedBox(
          width: _kButtonWidth,
          height: kTitleBarHeight,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 40,
              height: 32,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: widget.iconSize, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
