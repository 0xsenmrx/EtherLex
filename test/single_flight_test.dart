import 'dart:async';

import 'package:etherlex/core/utils/single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a second call while the first runs does nothing', () async {
    final once = SingleFlight();
    final gate = Completer<void>();
    var runs = 0;
    final first = once.run(() async {
      runs++;
      await gate.future;
      return 'a';
    });
    expect(once.busy, isTrue);
    expect(await once.run(() async => 'b'), isNull);
    expect(runs, 1);
    gate.complete();
    expect(await first, 'a');
    expect(once.busy, isFalse);
  });

  test('runs again after the first finished', () async {
    final once = SingleFlight();
    expect(await once.run(() async => 1), 1);
    expect(await once.run(() async => 2), 2);
  });

  test('is free again after a failure', () async {
    final once = SingleFlight();
    await expectLater(once.run<void>(() async => throw StateError('x')), throwsStateError);
    expect(once.busy, isFalse);
    expect(await once.run(() async => 3), 3);
  });

  test('keyed: the same key is ignored while running, other keys are not', () async {
    final once = KeyedSingleFlight<int>();
    final gate = Completer<void>();
    final first = once.run(1, () async {
      await gate.future;
      return 'a';
    });
    expect(once.isBusy(1), isTrue);
    expect(await once.run(1, () async => 'again'), isNull);
    expect(await once.run(2, () async => 'other'), 'other');
    gate.complete();
    expect(await first, 'a');
    expect(once.isBusy(1), isFalse);
    expect(await once.run(1, () async => 'later'), 'later');
  });

  test('keyed: free again after a failure', () async {
    final once = KeyedSingleFlight<int>();
    await expectLater(once.run<void>(1, () async => throw StateError('x')), throwsStateError);
    expect(once.isBusy(1), isFalse);
  });
}
