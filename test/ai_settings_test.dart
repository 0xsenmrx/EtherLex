import 'dart:io';

import 'package:etherlex/features/chat/data/ai_settings_store.dart';
import 'package:etherlex/features/chat/domain/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_ai_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('defaults: Claude, its default model, the OpenAI address', () {
    const s = AiSettings();
    expect(s.provider, AiProvider.anthropic);
    expect(s.model, 'claude-sonnet-5-5');
    expect(s.modelFor(AiProvider.openai), '');
    expect(s.openAiBaseUrl, kOpenAiBaseUrl);
  });

  test('each provider remembers its own model', () {
    final s = const AiSettings().withModel(AiProvider.openai, ' gpt-x ').copyWith(provider: AiProvider.openai);
    expect(s.model, 'gpt-x');
    expect(s.modelFor(AiProvider.anthropic), 'claude-sonnet-5-5');
  });

  test('json round trip keeps everything', () {
    final s = const AiSettings()
        .withModel(AiProvider.anthropic, 'claude-y')
        .withModel(AiProvider.openai, 'llama3')
        .copyWith(provider: AiProvider.openai, openAiBaseUrl: 'http://localhost:11434/v1');
    expect(AiSettings.fromJson(s.toJson()), s);
  });

  test('broken or unknown values fall back to the defaults', () {
    expect(AiSettings.fromJson(null), const AiSettings());
    expect(AiSettings.fromJson('x'), const AiSettings());
    expect(AiSettings.fromJson({'provider': 'skynet', 'models': 3, 'openAiBaseUrl': ' '}), const AiSettings());
  });

  test('the file holds no key', () async {
    final f = File('${dir.path}/ai.json');
    await AiSettingsStore(file: f).write(const AiSettings().withModel(AiProvider.openai, 'm'));
    final text = f.readAsStringSync();
    expect(text.contains('key'), isFalse);
    expect(text.contains('"openai":"m"'), isTrue);
  });

  test('store writes and reads back; a missing or corrupt file gives defaults', () async {
    final f = File('${dir.path}/sub/ai.json');
    final store = AiSettingsStore(file: f);
    expect(await store.read(), const AiSettings());
    final s = const AiSettings().copyWith(provider: AiProvider.openai);
    await store.write(s);
    expect(await store.read(), s);
    f.writeAsStringSync('{not json');
    expect(await store.read(), const AiSettings());
  });
}
