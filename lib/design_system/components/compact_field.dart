import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show InputBorder, InputDecoration, TextField;

import '../theme/ether_theme.dart';

/// A small number box for forms packed with values (weights, scores).
/// Reports every edit as text; the parent decides what it means.
class CompactField extends StatefulWidget {
  const CompactField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.width = 76,
    this.hint,
    this.suffix,
    this.numeric = true,
    this.autofocus = false,
    this.focusNode,
  });

  final String initial;
  final ValueChanged<String> onChanged;
  final double width;
  final String? hint;
  final String? suffix;

  /// Numbers only (the default); false lets any text in, for a search box.
  final bool numeric;
  final bool autofocus;

  /// Lets the parent move the cursor here; the parent owns and disposes it.
  final FocusNode? focusNode;

  @override
  State<CompactField> createState() => _CompactFieldState();
}

class _CompactFieldState extends State<CompactField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
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
    _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: widget.width,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _focused ? c.accent : c.line, width: _focused ? 1.4 : 1),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: widget.onChanged,
        autofocus: widget.autofocus,
        keyboardType: widget.numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: widget.numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
        style: (widget.numeric ? t.number : t.body).copyWith(color: c.textPrimary),
        cursorColor: c.accent,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          hintText: widget.hint,
          hintStyle: t.number.copyWith(color: c.textTertiary),
          suffixText: widget.suffix,
          suffixStyle: t.metaMuted,
        ),
      ),
    );
  }
}
