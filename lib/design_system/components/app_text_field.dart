import 'package:material_ui/material_ui.dart';

import '../theme/ether_theme.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmitted,
    this.error,
    this.multiline = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  /// Shown under the field in the danger colour, and the border turns red.
  final String? error;

  /// Several lines (3 to 6 shown, Enter makes a new line) instead of one.
  final bool multiline;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: t.meta),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: widget.multiline ? null : 42,
          constraints: widget.multiline ? const BoxConstraints(minHeight: 42) : null,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.multiline ? 10 : 0),
          decoration: BoxDecoration(
            color: c.sunken,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.error != null ? c.danger : (_focused ? c.accent : c.line)),
            boxShadow: _focused ? [BoxShadow(color: c.accentSoft, spreadRadius: 3)] : const [],
          ),
          alignment: widget.multiline ? Alignment.topLeft : Alignment.centerLeft,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            obscureText: widget.obscure,
            minLines: widget.multiline ? 3 : null,
            maxLines: widget.multiline ? 6 : 1,
            style: t.body,
            cursorColor: c.accent,
            onSubmitted: (_) => widget.onSubmitted?.call(),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: widget.hint,
              hintStyle: t.body.copyWith(color: c.textTertiary),
            ),
          ),
        ),
        if (widget.error case final error?) ...[
          const SizedBox(height: 5),
          Text(error, style: t.meta.copyWith(color: c.danger)),
        ],
      ],
    );
  }
}
