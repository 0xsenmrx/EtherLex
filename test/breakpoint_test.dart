import 'package:etherlex/design_system/ether/breakpoint.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resizes within a mode reuse the build; dependency changes rebuild', (tester) async {
    var builds = 0;
    TextDirection? seen;
    // One instance for the whole test, so only constraints and inherited
    // data change around it.
    final breakpoint = BreakpointBuilder<bool>(
      mode: (box) => box.maxWidth >= 500,
      builder: (context, wide) {
        builds++;
        seen = Directionality.of(context);
        return const SizedBox.expand();
      },
    );

    Future<void> pump(double width, TextDirection direction) => tester.pumpWidget(
          Directionality(
            textDirection: direction,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, height: 100, child: breakpoint),
            ),
          ),
        );

    await pump(600, TextDirection.ltr);
    expect(builds, 1);

    await pump(700, TextDirection.ltr); // resize, same mode
    expect(builds, 1);

    await pump(400, TextDirection.ltr); // resize into the other mode
    expect(builds, 2);

    await pump(400, TextDirection.rtl); // same size, inherited data changed
    expect(builds, 3);
    expect(seen, TextDirection.rtl);
  });
}
