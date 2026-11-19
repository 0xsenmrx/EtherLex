import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Credentials {
  const Credentials({required this.baseUrl, required this.token, required this.userName});
  final String baseUrl;
  final String token;
  final String userName;
}

abstract interface class CredentialsStore {
  Future<Credentials?> read();
  Future<void> save(Credentials credentials);
  Future<void> clear();
}

/// Token lives in the OS credential store (Windows Credential Locker).
class SecureCredentialsStore implements CredentialsStore {
  SecureCredentialsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kUrl = 'canvas_base_url';
  static const _kToken = 'canvas_token';
  static const _kName = 'canvas_user_name';

  @override
  Future<Credentials?> read() async {
    final url = await _storage.read(key: _kUrl);
    final token = await _storage.read(key: _kToken);
    if (url == null || token == null) return null;
    return Credentials(
      baseUrl: url,
      token: token,
      userName: await _storage.read(key: _kName) ?? 'Canvas user',
    );
  }

  @override
  Future<void> save(Credentials c) async {
    await _storage.write(key: _kUrl, value: c.baseUrl);
    await _storage.write(key: _kToken, value: c.token);
    await _storage.write(key: _kName, value: c.userName);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kUrl);
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kName);
  }
}
