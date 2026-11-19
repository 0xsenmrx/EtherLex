import 'package:etherlex/core/ui/selected_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('moving the cursor rebuilds only the rows it leaves and enters', (tester) async {
    final cursor = ValueNotifier<int?>(null);
    addTearDown(cursor.dispose);
    final builds = <int, int>{};

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            for (var id = 0; id < 5; id++)
              SelectedBuilder<int>(
                cursor: cursor,
                id: id,
                builder: (context, selected, _) {
                  builds[id] = (builds[id] ?? 0) + 1;
                  return Text(selected ? 'on' : 'off');
                },
              ),
          ],
        ),
      ),
    );
    expect(builds, {0: 1, 1: 1, 2: 1, 3: 1, 4: 1});

    cursor.value = 2;
    await tester.pump();
    expect(builds, {0: 1, 1: 1, 2: 2, 3: 1, 4: 1});
    expect(find.text('on'), findsOneWidget);

    cursor.value = 3;
    await tester.pump();
    expect(builds, {0: 1, 1: 1, 2: 3, 3: 2, 4: 1});

    cursor.value = null;
    await tester.pump();
    expect(find.text('on'), findsNothing);
  });
}
