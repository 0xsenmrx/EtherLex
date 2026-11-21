import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/canvas_client.dart';
import '../../../core/network/canvas_url.dart';
import '../../../core/storage/account_scope.dart';
import '../data/credentials_store.dart';

class AuthSession {
  const AuthSession({
    required this.baseUrl,
    required this.token,
    required this.userName,
    this.userId,
    this.isSample = false,
  });

  const AuthSession.sample()
      : baseUrl = '',
        token = '',
        userName = 'Sample data',
        userId = null,
        isSample = true;

  final String baseUrl;
  final String token;
  final String userName;

  /// The Canvas user id; null only for a sign-in saved by an older version
  /// whose id could not be fetched yet.
  final int? userId;
  final bool isSample;

  /// What this account's data is called on disk (see [accountScope]).
  String get scope => isSample ? 'sample' : accountScope(baseUrl, userId);

  /// Moves data kept under the old host-only name to this account. A no-op
  /// without an id; safe to call again.
  void adoptLegacyData() {
    if (isSample || userId == null) return;
    adoptLegacyAccountData(host: Uri.tryParse(baseUrl)?.host ?? '', scope: scope);
  }
}

final credentialsStoreProvider =
    Provider<CredentialsStore>((ref) => SecureCredentialsStore());

typedef CanvasClientFactory = CanvasClient Function(String baseUrl, String token);

final canvasClientFactoryProvider = Provider<CanvasClientFactory>(
  (ref) => (baseUrl, token) => CanvasClient(baseUrl: baseUrl, token: token),
);

/// null = signed out. Loading only during the first restore at startup.
class AuthNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    try {
      final c = await ref.read(credentialsStoreProvider).read();
      if (c == null) return null;
      var id = c.userId;
      if (id == null) {
        // Saved by an older version: learn the id now. Offline or rejected, the
        // session still opens and the id is tried again at the next start.
        try {
          id = (await ref.read(canvasClientFactoryProvider)(c.baseUrl, c.token).fetchSelf()).id;
          await ref.read(credentialsStoreProvider).save(
                Credentials(baseUrl: c.baseUrl, token: c.token, userName: c.userName, userId: id),
              );
        } catch (_) {}
      }
      final session = AuthSession(baseUrl: c.baseUrl, token: c.token, userName: c.userName, userId: id);
      session.adoptLegacyData();
      return session;
    } catch (_) {
      return null;
    }
  }

  /// Throws [CanvasException] with a user-safe message on failure.
  Future<void> signIn(String rawUrl, String rawToken) async {
    final baseUrl = normalizeCanvasUrl(rawUrl);
    final token = rawToken.trim();
    final user = await ref.read(canvasClientFactoryProvider)(baseUrl, token).fetchSelf();
    await ref.read(credentialsStoreProvider).save(
          Credentials(baseUrl: baseUrl, token: token, userName: user.name, userId: user.id),
        );
    final session = AuthSession(baseUrl: baseUrl, token: token, userName: user.name, userId: user.id);
    session.adoptLegacyData();
    state = AsyncData(session);
  }

  void useSample() => state = const AsyncData(AuthSession.sample());

  Future<void> signOut() async {
    try {
      await ref.read(credentialsStoreProvider).clear();
    } catch (_) {}
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthSession?>(AuthNotifier.new);
