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
  tearDown(() {
    // Windows can still hold a just-written file for a moment; a leftover temp folder is harmless.
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  ProviderContainer container(String name) {
    final c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(FileSettingsStore(file: File('${dir.path}/$name.json'))),
    ]);
    addTearDown(c.dispose);
    c.listen(aiConsentProvider, (_, _) {});
    return c;
  }

  const anthropic = AiSettings();
  const deepseek = AiSettings(provider: AiProvider.deepseek);
  const openai = AiSettings(provider: AiProvider.openai, openAiBaseUrl: 'https://api.example.com/v1');
  const otherServer = AiSettings(provider: AiProvider.openai, openAiBaseUrl: 'https://evil.example.net/v1');

  test('nobody has agreed at first; a yes is kept for that account only', () async {
    final a = container('a');
    expect(a.read(aiConsentProvider), isEmpty);
    a.read(aiConsentProvider.notifier).grant(deepseek);
    expect(a.read(aiConsentProvider), {'deepseek'});
    await until(() => File('${dir.path}/a.json').existsSync());

    final again = container('a');
    await until(() => again.read(aiConsentProvider.notifier).allows(deepseek));
    expect(container('b').read(aiConsentProvider), isEmpty);
  });

  test('revoking asks again next time', () async {
    final a = container('a');
    a.read(aiConsentProvider.notifier)
      ..grant(anthropic)
      ..grant(openai)
      ..revoke(anthropic);
    expect(a.read(aiConsentProvider), {'openai@api.example.com'});
    final file = File('${dir.path}/a.json');
    // The last of the three writes: openai kept, anthropic gone again.
    await until(() {
      if (!file.existsSync()) return false;
      final text = file.readAsStringSync();
      return text.contains('openai@api.example.com') && !text.contains('anthropic');
    });
    final again = container('a');
    await until(() => again.read(aiConsentProvider).isNotEmpty);
    expect(again.read(aiConsentProvider), {'openai@api.example.com'});
  });

  test('an answer given before the saved ones are read is not lost', () async {
    final a = container('a');
    // Straight after start: the saved answers (none yet) are still being read.
    a.read(aiConsentProvider.notifier).grant(deepseek);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(a.read(aiConsentProvider), {'deepseek'});
  });

  test('a yes for one OpenAI-compatible server does not cover another', () {
    final a = container('a');
    final consent = a.read(aiConsentProvider.notifier)..grant(openai);
    expect(consent.allows(openai), isTrue);
    expect(consent.allows(otherServer), isFalse);
    expect(consent.allows(deepseek), isFalse);
  });

  test('an old server-less yes counts once, and is dropped when the server changes', () async {
    final store = FileSettingsStore(file: File('${dir.path}/old.json'));
    await store.writeAiConsent({kLegacyOpenAiConsent, 'deepseek'});
    final a = container('old');
    await until(() => a.read(aiConsentProvider).isNotEmpty);
    final consent = a.read(aiConsentProvider.notifier);
    expect(consent.allows(openai), isTrue);
    consent.forgetLegacyOpenAi();
    expect(consent.allows(openai), isFalse);
    expect(consent.allows(otherServer), isFalse);
    expect(consent.allows(deepseek), isTrue);
  });

  test('granting binds the old yes to the current server', () async {
    final store = FileSettingsStore(file: File('${dir.path}/bind.json'));
    await store.writeAiConsent({kLegacyOpenAiConsent});
    final a = container('bind');
    await until(() => a.read(aiConsentProvider).isNotEmpty);
    a.read(aiConsentProvider.notifier).grant(openai);
    expect(a.read(aiConsentProvider), {'openai@api.example.com'});
    expect(a.read(aiConsentProvider.notifier).allows(otherServer), isFalse);
  });

  group('consent keys', () {
    test('services without an address are keyed by name', () {
      expect(consentKeyFor(anthropic), 'anthropic');
      expect(consentKeyFor(deepseek), 'deepseek');
    });

    test('the OpenAI-compatible service is keyed by its server', () {
      expect(consentKeyFor(openai), 'openai@api.example.com');
      expect(consentKeyFor(const AiSettings(provider: AiProvider.openai, openAiBaseUrl: 'https://API.Example.com/other')),
          'openai@api.example.com');
      expect(consentKeyFor(const AiSettings(provider: AiProvider.openai, openAiBaseUrl: 'http://localhost:11434/v1')),
          'openai@localhost:11434');
      expect(consentKeyFor(const AiSettings(provider: AiProvider.openai, openAiBaseUrl: 'nonsense')), 'openai@?');
    });

    test('aiHostOf', () {
      expect(aiHostOf('https://api.openai.com/v1'), 'api.openai.com');
      expect(aiHostOf('https://x.com:8443/v1'), 'x.com:8443');
      expect(aiHostOf(''), isNull);
    });

    test('the service name shows the server', () {
      expect(aiServiceName(openai), 'OpenAI-compatible (api.example.com)');
      expect(aiServiceName(deepseek), 'DeepSeek');
    });
  });
}
