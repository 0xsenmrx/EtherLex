import 'package:material_ui/material_ui.dart';

import '../theme/ether_theme.dart';

const Color _clear = Color(0x00000000);

/// Popover menu surface (used with [MenuAnchor]).
MenuStyle etherMenuStyle(EtherColors c) => MenuStyle(
      backgroundColor: WidgetStatePropertyAll(c.surface),
      surfaceTintColor: const WidgetStatePropertyAll(_clear),
      shadowColor: WidgetStatePropertyAll(c.shadow),
      elevation: const WidgetStatePropertyAll(12),
      side: WidgetStatePropertyAll(BorderSide(color: c.line)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
    );

/// Menu row style. [danger] paints it red (sign out, delete).
ButtonStyle etherMenuItemStyle(EtherColors c, EtherText t, {bool danger = false}) {
  final fg = danger ? c.danger : c.textPrimary;
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color?>(
      (s) => s.contains(WidgetState.hovered) || s.contains(WidgetState.focused) ? c.hover : _clear,
    ),
    foregroundColor: WidgetStatePropertyAll(fg),
    iconColor: WidgetStatePropertyAll(danger ? c.danger : c.textSecondary),
    iconSize: const WidgetStatePropertyAll(16),
    overlayColor: const WidgetStatePropertyAll(_clear),
    textStyle: WidgetStatePropertyAll(t.label),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    minimumSize: const WidgetStatePropertyAll(Size(236, 36)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class EMenuDivider extends StatelessWidget {
  const EMenuDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(height: 1, color: context.colors.line),
      );
}

class EMenuCaption extends StatelessWidget {
  const EMenuCaption(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text(label.toUpperCase(), style: context.text.caption),
      );
}
