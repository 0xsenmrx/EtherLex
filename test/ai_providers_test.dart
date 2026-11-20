import 'dart:io';

import 'package:etherlex/features/chat/data/ai_key_store.dart';
import 'package:etherlex/features/chat/data/ai_settings_store.dart';
import 'package:etherlex/features/chat/domain/ai_settings.dart';
import 'package:etherlex/features/chat/presentation/ai_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeKeyStore implements AiKeyStore {
  final Map<AiProvider, String> keys = {};

  @override
  Future<String?> read(AiProvider provider) async => keys[provider];

  @override
  Future<void> save(AiProvider provider, String key) async => keys[provider] = key.trim();

  @override
  Future<void> clear(AiProvider provider) async => keys.remove(provider);
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  late Directory dir;
  late FakeKeyStore keys;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('etherlex_aip_');
    keys = FakeKeyStore();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      aiSettingsStoreProvider.overrideWithValue(AiSettingsStore(file: File('${dir.path}/ai.json'))),
      aiKeyStoreProvider.overrideWithValue(keys),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('settings changes are saved and loaded by the next start', () async {
    final first = container();
    first.listen(aiSettingsProvider, (_, _) {});
    first.read(aiSettingsProvider.notifier)
      ..setProvider(AiProvider.openai)
      ..setModel(AiProvider.openai, 'gpt-x')
      ..setOpenAiBaseUrl(' http://localhost:11434/v1 ');
    await settle();

    final second = container();
    second.listen(aiSettingsProvider, (_, _) {});
    await settle();
    final s = second.read(aiSettingsProvider);
    expect(s.provider, AiProvider.openai);
    expect(s.model, 'gpt-x');
    expect(s.openAiBaseUrl, 'http://localhost:11434/v1');
  });

  test('keys: saving, clearing and finding saved ones at start', () async {
    keys.keys[AiProvider.anthropic] = 'sk-old';
    final c = container();
    c.listen(aiKeysProvider, (_, _) {});
    await settle();
    expect(c.read(aiKeysProvider), {AiProvider.anthropic});

    await c.read(aiKeysProvider.notifier).save(AiProvider.openai, '  sk-new ');
    expect(c.read(aiKeysProvider), {AiProvider.anthropic, AiProvider.openai});
    expect(keys.keys[AiProvider.openai], 'sk-new');

    await c.read(aiKeysProvider.notifier).clear(AiProvider.anthropic);
    expect(c.read(aiKeysProvider), {AiProvider.openai});
    expect(keys.keys.containsKey(AiProvider.anthropic), isFalse);
  });

  test('an empty key is not saved', () async {
    final c = container();
    c.listen(aiKeysProvider, (_, _) {});
    await c.read(aiKeysProvider.notifier).save(AiProvider.openai, '   ');
    expect(keys.keys, isEmpty);
    expect(c.read(aiKeysProvider), isEmpty);
  });
}
