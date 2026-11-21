import 'package:etherlex/features/chat/data/ai_key_store.dart';
import 'package:etherlex/features/chat/domain/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vault implements SecretVault {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String name) async => data[name];

  @override
  Future<void> write(String name, String value) async => data[name] = value;

  @override
  Future<void> delete(String name) async => data.remove(name);
}

void main() {
  test('two accounts keep separate keys', () async {
    final vault = _Vault();
    final a = SecureAiKeyStore(vault: vault, scope: 'school.edu_u1');
    final b = SecureAiKeyStore(vault: vault, scope: 'school.edu_u2');
    await a.save(AiProvider.deepseek, ' sk-a ');
    expect(await a.read(AiProvider.deepseek), 'sk-a');
    expect(await b.read(AiProvider.deepseek), isNull);
    await b.save(AiProvider.deepseek, 'sk-b');
    await a.clear(AiProvider.deepseek);
    expect(await a.read(AiProvider.deepseek), isNull);
    expect(await b.read(AiProvider.deepseek), 'sk-b');
  });

  test('a key saved by an older version moves to the first account only', () async {
    final vault = _Vault()..data['ai_key_deepseek'] = 'sk-old';
    final a = SecureAiKeyStore(vault: vault, scope: 'school.edu_u1');
    final b = SecureAiKeyStore(vault: vault, scope: 'school.edu_u2');
    expect(await a.read(AiProvider.deepseek), 'sk-old');
    expect(await b.read(AiProvider.deepseek), isNull);
    expect(vault.data.containsKey('ai_key_deepseek'), isFalse);
    expect(await a.read(AiProvider.deepseek), 'sk-old');
  });

  test('without a scope the old shared name is used; sample never adopts', () async {
    final vault = _Vault()..data['ai_key_openai'] = 'sk-old';
    expect(await SecureAiKeyStore(vault: vault).read(AiProvider.openai), 'sk-old');
    final sample = SecureAiKeyStore(vault: vault, scope: 'sample', adoptLegacy: false);
    expect(await sample.read(AiProvider.openai), isNull);
    expect(vault.data['ai_key_openai'], 'sk-old');
  });
}
