import 'dart:io';

import 'package:etherlex/features/chat/data/ai_settings_store.dart';
import 'package:etherlex/features/chat/domain/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_ai_'));
  tearDown(() {
    // Windows can still hold a just-written file for a moment; a leftover temp folder is harmless.
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  test('defaults: Claude, its default model, the OpenAI address', () {
    const s = AiSettings();
    expect(s.provider, AiProvider.anthropic);
    expect(s.model, 'claude-sonnet-5-5');
    expect(s.modelFor(AiProvider.openai), '');
    expect(s.openAiBaseUrl, kOpenAiBaseUrl);
  });

  test('DeepSeek is a provider with its own default model and address', () {
    final s = const AiSettings().copyWith(provider: AiProvider.deepseek);
    expect(s.model, 'deepseek-chat');
    expect(AiProvider.deepseek.label, 'DeepSeek');
    expect(kDeepSeekBaseUrl, 'https://api.deepseek.com');
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

  test('each account has its own settings; the old shared file moves to the first one', () async {
    final old = File('${dir.path}/ai.json')..writeAsStringSync('{"provider":"deepseek"}');
    final a = AiSettingsStore.forScope('school.edu_u1', root: dir.path);
    expect((await a.read()).provider, AiProvider.deepseek);
    expect(old.existsSync(), isFalse);
    final b = AiSettingsStore.forScope('school.edu_u2', root: dir.path);
    expect(await b.read(), const AiSettings());
    await b.write(const AiSettings().copyWith(provider: AiProvider.openai));
    expect((await a.read()).provider, AiProvider.deepseek);
    expect((await b.read()).provider, AiProvider.openai);
  });

  test('without a scope the shared file is used; sample never adopts it', () async {
    final old = File('${dir.path}/ai.json')..writeAsStringSync('{"provider":"deepseek"}');
    expect((await AiSettingsStore.forScope(null, root: dir.path).read()).provider, AiProvider.deepseek);
    final sample = AiSettingsStore.forScope('sample', root: dir.path, adoptLegacy: false);
    expect(await sample.read(), const AiSettings());
    expect(old.existsSync(), isTrue);
  });
}
