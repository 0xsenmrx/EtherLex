import 'package:etherlex/core/motion/spring_value.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Windows' "Animation effects" off reaches the app as
/// MediaQuery.disableAnimations (#61).
void main() {
  double? seen;
  Widget spring(double target, {required bool off}) => MediaQuery(
        data: MediaQueryData(disableAnimations: off),
        child: SpringValue(
          target: target,
          builder: (context, v, _) {
            seen = v;
            return const SizedBox();
          },
        ),
      );

  testWidgets('with animations off a spring is at its target at once', (tester) async {
    await tester.pumpWidget(spring(0, off: true));
    expect(seen, 0);
    await tester.pumpWidget(spring(1, off: true));
    expect(seen, 1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(seen, 1);
  });

  testWidgets('with animations on it moves there over frames', (tester) async {
    await tester.pumpWidget(spring(0, off: false));
    await tester.pumpWidget(spring(1, off: false));
    expect(seen, lessThan(1));
    await tester.pumpAndSettle();
    expect(seen, closeTo(1, 0.01));
  });
}
