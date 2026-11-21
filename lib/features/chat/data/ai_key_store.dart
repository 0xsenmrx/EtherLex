import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/ai_settings.dart';

/// API keys for the AI services. Never written to a settings file or a log.
abstract interface class AiKeyStore {
  Future<String?> read(AiProvider provider);
  Future<void> save(AiProvider provider, String key);
  Future<void> clear(AiProvider provider);
}

/// Where secrets are kept: the OS credential store in the app, memory in tests.
abstract interface class SecretVault {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

/// Windows Credential Locker.
class OsSecretVault implements SecretVault {
  OsSecretVault([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) => _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}

/// Keys of one account. With a [scope] each account has its own keys, so a
/// second person on this computer never uses (or pays with) your key. Without
/// one, the old shared names are used (an account whose id is not known yet).
///
/// A key saved by an older version under the shared name moves to the first
/// account that reads it ([adoptLegacy]); it is not left behind for others.
class SecureAiKeyStore implements AiKeyStore {
  SecureAiKeyStore({SecretVault? vault, this.scope, this.adoptLegacy = true}) : _vault = vault ?? OsSecretVault();

  final SecretVault _vault;
  final String? scope;
  final bool adoptLegacy;

  static String _legacyName(AiProvider p) => 'ai_key_${p.name}';
  String _name(AiProvider p) => scope == null ? _legacyName(p) : 'ai_key_${p.name}__$scope';

  static String? _clean(String? key) => key == null || key.trim().isEmpty ? null : key;

  @override
  Future<String?> read(AiProvider provider) async {
    final own = _clean(await _vault.read(_name(provider)));
    if (own != null || scope == null || !adoptLegacy) return own;
    final old = _clean(await _vault.read(_legacyName(provider)));
    if (old == null) return null;
    await _vault.write(_name(provider), old);
    await _vault.delete(_legacyName(provider));
    return old;
  }

  @override
  Future<void> save(AiProvider provider, String key) => _vault.write(_name(provider), key.trim());

  @override
  Future<void> clear(AiProvider provider) => _vault.delete(_name(provider));
}
