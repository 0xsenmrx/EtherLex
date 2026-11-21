import 'dart:io';

import 'package:etherlex/core/storage/settings_store.dart';
import 'package:etherlex/features/assignments/presentation/assignments_providers.dart';
import 'package:etherlex/features/chat/domain/ai_settings.dart';
import 'package:etherlex/features/chat/presentation/ai_consent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> until(bool Function() done) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  // Reading a file the app is just renaming over fails on Windows: try again.
  bool ready() {
    try {
      return done();
    } catch (_) {
      return false;
    }
  }

  while (!ready()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_consent_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer container(String name) {
    final c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(FileSettingsStore(file: File('${dir.path}/$name.json'))),
    ]);
    addTearDown(c.dispose);
    c.listen(aiConsentProvider, (_, _) {});
    return c;
  }

  test('nobody has agreed at first; a yes is kept for that account only', () async {
    final a = container('a');
    expect(a.read(aiConsentProvider), isEmpty);
    a.read(aiConsentProvider.notifier).grant(AiProvider.deepseek);
    expect(a.read(aiConsentProvider), {AiProvider.deepseek});
    await until(() => File('${dir.path}/a.json').existsSync());

    final again = container('a');
    await until(() => again.read(aiConsentProvider).contains(AiProvider.deepseek));
    expect(container('b').read(aiConsentProvider), isEmpty);
  });

  test('revoking asks again next time', () async {
    final a = container('a');
    a.read(aiConsentProvider.notifier)
      ..grant(AiProvider.anthropic)
      ..grant(AiProvider.openai)
      ..revoke(AiProvider.anthropic);
    expect(a.read(aiConsentProvider), {AiProvider.openai});
    final file = File('${dir.path}/a.json');
    // The last of the three writes: openai kept, anthropic gone again.
    await until(() {
      if (!file.existsSync()) return false;
      final text = file.readAsStringSync();
      return text.contains('openai') && !text.contains('anthropic');
    });
    final again = container('a');
    await until(() => again.read(aiConsentProvider).isNotEmpty);
    expect(again.read(aiConsentProvider), {AiProvider.openai});
  });

  test('an answer given before the saved ones are read is not lost', () async {
    final a = container('a');
    // Straight after start: the saved answers (none yet) are still being read.
    a.read(aiConsentProvider.notifier).grant(AiProvider.deepseek);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(a.read(aiConsentProvider), {AiProvider.deepseek});
  });
}
