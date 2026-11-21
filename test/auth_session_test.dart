import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:etherlex/core/network/canvas_client.dart';
import 'package:etherlex/features/auth/data/credentials_store.dart';
import 'package:etherlex/features/auth/domain/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryCredentials implements CredentialsStore {
  _MemoryCredentials([this.saved]);
  Credentials? saved;

  @override
  Future<Credentials?> read() async => saved;

  @override
  Future<void> save(Credentials credentials) async => saved = credentials;

  @override
  Future<void> clear() async => saved = null;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  final int status;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('{"id": 77, "name": "Arsen"}', status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(_MemoryCredentials store, int status) {
  final c = ProviderContainer(overrides: [
    credentialsStoreProvider.overrideWithValue(store),
    canvasClientFactoryProvider.overrideWithValue(
      (url, token) => CanvasClient(baseUrl: url, token: token, dio: Dio()..httpClientAdapter = _Adapter(status)),
    ),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('signing in keeps the Canvas user id in the session and the store', () async {
    final store = _MemoryCredentials();
    final c = _container(store, 200);
    await c.read(authProvider.future);
    await c.read(authProvider.notifier).signIn('school.instructure.com', ' tok ');
    expect(c.read(authProvider).value!.userId, 77);
    expect(store.saved!.userId, 77);
  });

  test('a saved sign-in without an id learns it at startup', () async {
    final store = _MemoryCredentials(
      const Credentials(baseUrl: 'https://school.instructure.com', token: 't', userName: 'Arsen'),
    );
    final c = _container(store, 200);
    final session = await c.read(authProvider.future);
    expect(session!.userId, 77);
    expect(store.saved!.userId, 77);
  });

  test('a saved sign-in still opens when the id cannot be fetched', () async {
    final store = _MemoryCredentials(
      const Credentials(baseUrl: 'https://school.instructure.com', token: 't', userName: 'Arsen'),
    );
    final c = _container(store, 500);
    final session = await c.read(authProvider.future);
    expect(session, isNotNull);
    expect(session!.userId, isNull);
    expect(store.saved!.userId, isNull);
  });

  test('a saved id is used without asking Canvas', () async {
    final store = _MemoryCredentials(
      const Credentials(baseUrl: 'https://school.instructure.com', token: 't', userName: 'Arsen', userId: 5),
    );
    final c = _container(store, 500);
    expect((await c.read(authProvider.future))!.userId, 5);
  });

  test('two accounts on one Canvas site get different data names', () {
    const a = AuthSession(baseUrl: 'https://canvas.school.edu', token: 't', userName: 'A', userId: 1);
    const b = AuthSession(baseUrl: 'https://canvas.school.edu', token: 't', userName: 'B', userId: 2);
    expect(a.scope, isNot(b.scope));
    expect(a.scope, startsWith('canvas.school.edu'));
    expect(const AuthSession.sample().scope, 'sample');
  });
}
