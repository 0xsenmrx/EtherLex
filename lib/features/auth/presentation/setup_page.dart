import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' hide Springs;

import '../../../app/app_info.dart';
import '../../../app/window/window_chrome.dart';
import '../../../core/appearance/appearance.dart';
import '../../../core/motion/smooth_scroll.dart';
import '../../../core/motion/spring_value.dart';
import '../../../core/motion/springs.dart';
import '../../../core/network/canvas_exception.dart';
import '../../../core/utils/math.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/ether/breakpoint.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dot_grid.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../domain/auth_provider.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  final SmoothScrollController _scroll = SmoothScrollController();
  bool _loading = false;
  bool _help = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_loading) return;
    if (_url.text.trim().isEmpty || _token.text.trim().isEmpty) {
      setState(() => _error = _url.text.trim().isEmpty
          ? 'Enter your school\'s Canvas address.'
          : 'Paste your access token.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signIn(_url.text, _token.text);
      // Success: the router redirects away from this page.
    } on CanvasException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _useSample() => ref.read(authProvider.notifier).useSample();

  static const Duration _helpDuration = Duration(milliseconds: 220);
  final GlobalKey _stepsKey = GlobalKey();

  void _toggleHelp() {
    setState(() => _help = !_help);
    if (!_help) return;
    // The steps open below the button and can land under the window's bottom
    // edge: once they have grown, scroll just enough to show them.
    Future<void>.delayed(_helpDuration + const Duration(milliseconds: 20), () {
      final steps = _stepsKey.currentContext;
      if (!mounted || steps == null || !steps.mounted) return;
      Scrollable.ensureVisible(
        steps,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return DotGrid(
      child: Stack(
        children: [
          // Empty title bar space moves the window; it lies under the brand
          // row so the theme button stays clickable.
          Positioned(
            top: 0,
            left: 0,
            right: windowButtonsInset,
            height: kTitleBarHeight,
            child: const WindowDragArea(),
          ),
          // Brand and theme toggle in the title bar area.
          Positioned(
            top: 0,
            left: 20,
            right: windowButtonsInset + 14,
            height: kTitleBarHeight,
            child: Row(
              children: [
                Icon(EIcons.brand, size: 20, color: c.accent),
                const SizedBox(width: 8),
                Text(kAppName, style: t.brand),
                const Spacer(),
                const _ThemeToggle(),
              ],
            ),
          ),
          // Everything below the title bar scrolls, at full width: the card is
          // centred while it fits, and scrolls (with room for its shadow) when
          // the window is short or the token steps are open.
          Positioned.fill(
            top: kTitleBarHeight,
            child: BreakpointBuilder<bool>(
              mode: (box) => box.maxHeight < 640,
              builder: (context, compact) {
                final top = compact ? 4.0 : 12.0;
                // Built once per mode, so resizing re-lays it out without
                // rebuilding it.
                final card = SpringValue(
                  initial: 0,
                  target: 1,
                  spring: Springs.dialog,
                  builder: (context, v, child) => Opacity(
                    opacity: clamp01(v),
                    child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
                  ),
                  child: _card(compact),
                );
                // Laid out at its real height (no intrinsic estimate, which
                // measured the text at the full window width and cut the card
                // short): at least the window's height so it stays centred.
                return LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(24, top, 24, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (box.maxHeight - top - 32).clamp(0.0, double.infinity),
                      ),
                      child: Center(child: card),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(bool compact) {
    final c = context.colors;
    final t = context.text;
    final error = _error;
    return Container(
      width: 440,
      padding: compact ? const EdgeInsets.fromLTRB(28, 22, 28, 20) : const EdgeInsets.fromLTRB(32, 30, 32, 26),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Short windows drop the mark: the title bar already shows it.
          if (!compact) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(13)),
                child: Icon(EIcons.brand, size: 22, color: c.accent),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text('Connect to Canvas', style: t.title),
          const SizedBox(height: 6),
          Text(
            '$kAppName reads your courses with a personal access token. '
            'It is stored securely on this computer and only ever sent to your Canvas.',
            style: t.bodySecondary,
          ),
          SizedBox(height: compact ? 16 : 22),
          AppTextField(
            controller: _url,
            label: 'Canvas address',
            hint: 'https://school.instructure.com',
            autofocus: true,
            onSubmitted: () => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _token,
            label: 'Access token',
            hint: 'Paste the token from Canvas',
            obscure: true,
            onSubmitted: _connect,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(EIcons.alert, size: 15, color: c.danger),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(error, style: t.meta.copyWith(color: c.danger))),
                      ],
                    ),
                  ),
          ),
          SizedBox(height: compact ? 18 : 22),
          EButton(
            label: _loading ? 'Connecting…' : 'Connect',
            kind: EButtonKind.primary,
            expand: true,
            loading: _loading,
            onTap: _connect,
          ),
          const SizedBox(height: 12),
          _HelpToggle(open: _help, onTap: _toggleHelp),
          AnimatedSize(
            duration: _helpDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: _help ? _TokenSteps(key: _stepsKey) : const SizedBox(width: double.infinity),
          ),
          SizedBox(height: compact ? 14 : 18),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: c.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: t.metaMuted),
              ),
              Expanded(child: Container(height: 1, color: c.line)),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          EButton(
            label: 'Explore with sample data',
            kind: EButtonKind.secondary,
            expand: true,
            onTap: _useSample,
          ),
        ],
      ),
    );
  }
}

class _HelpToggle extends StatelessWidget {
  const _HelpToggle({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Center(
      child: ETap(
        onTap: onTap,
        builder: (context, s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: focusRing(c, s.focused),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(EIcons.help, size: 14, color: s.hovered ? c.textPrimary : c.textTertiary),
              const SizedBox(width: 6),
              Text(
                open ? 'Hide the steps' : 'Where do I get a token?',
                style: t.meta.copyWith(color: s.hovered ? c.textPrimary : c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenSteps extends StatelessWidget {
  const _TokenSteps({super.key});

  static const _steps = [
    'Open Canvas in your browser and sign in.',
    'Go to Account, then Settings.',
    'Under Approved integrations, choose New access token, give it a name, and generate it.',
    'Copy the token and paste it above. Canvas shows it only once.',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _steps.length - 1 ? 0 : 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: t.metaMuted.copyWith(color: c.accent, fontSize: 11)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_steps[i], style: t.meta.copyWith(height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return EIconButton(
      icon: dark ? EIcons.sun : EIcons.moon,
      tooltip: dark ? 'Light theme' : 'Dark theme',
      onTap: () => ref.read(appearanceProvider.notifier).toggleBrightness(brightness),
    );
  }
}
