import 'package:flutter/widgets.dart';

import '../theme/ether_theme.dart';

/// A small accent dot that marks something new.
class ENewDot extends StatelessWidget {
  const ENewDot({super.key, this.size = 8});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'New',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: context.colors.accentFill, shape: BoxShape.circle),
        ),
      );
}
