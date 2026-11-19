import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app_info.dart';
import 'app/router.dart';
import 'app/window/window_chrome.dart';
import 'core/appearance/appearance.dart';
import 'core/diag.dart';
import 'design_system/components/toast_host.dart';
import 'design_system/theme/ether_theme.dart';

/// F9 toggles Flutter's frame-time graphs, to check smoothness in profile mode.
class PerfOverlayNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final perfOverlayProvider = NotifierProvider<PerfOverlayNotifier, bool>(PerfOverlayNotifier.new);

final _lightThemeProvider = Provider<ThemeData>((ref) => buildEtherTheme(
      EtherColors.light,
      handwritten: ref.watch(appearanceProvider.select((a) => a.handwritten)) && !diag('cleanfont'),
    ));

final _darkThemeProvider = Provider<ThemeData>((ref) => buildEtherTheme(
      EtherColors.dark,
      handwritten: ref.watch(appearanceProvider.select((a) => a.handwritten)) && !diag('cleanfont'),
    ));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearance = await AppearanceStore().read();
  unawaited(WindowControl.instance.attach());
  runApp(
    ProviderScope(
      overrides: [initialAppearanceProvider.overrideWithValue(appearance)],
      child: const EtherLexApp(),
    ),
  );
}

class EtherLexApp extends ConsumerWidget {
  const EtherLexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appearanceProvider.select((a) => a.theme));
    return MaterialApp.router(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: ref.watch(perfOverlayProvider),
      theme: ref.watch(_lightThemeProvider),
      darkTheme: ref.watch(_darkThemeProvider),
      themeMode: switch (theme) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      },
      themeAnimationDuration: const Duration(milliseconds: 220),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f9): ref.read(perfOverlayProvider.notifier).toggle,
        },
        child: ToastHost(
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                // Above every route, dialogs included, so the window can always be closed.
                const Positioned(top: 0, right: 0, child: WindowButtons()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
