import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ai_settings.dart';

/// API keys for the AI services. Never written to a settings file or a log.
abstract interface class AiKeyStore {
  Future<String?> read(AiProvider provider);
  Future<void> save(AiProvider provider, String key);
  Future<void> clear(AiProvider provider);
}

/// Keys live in the OS credential store (Windows Credential Locker).
class SecureAiKeyStore implements AiKeyStore {
  SecureAiKeyStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _name(AiProvider p) => 'ai_key_${p.name}';

  @override
  Future<String?> read(AiProvider provider) async {
    final key = await _storage.read(key: _name(provider));
    return key == null || key.trim().isEmpty ? null : key;
  }

  @override
  Future<void> save(AiProvider provider, String key) => _storage.write(key: _name(provider), value: key.trim());

  @override
  Future<void> clear(AiProvider provider) => _storage.delete(key: _name(provider));
}
