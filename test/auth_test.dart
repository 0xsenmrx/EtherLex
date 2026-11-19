import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:etherlex/core/network/canvas_client.dart';
import 'package:etherlex/core/network/canvas_exception.dart';
import 'package:etherlex/core/network/canvas_url.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

CanvasClient _client(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return CanvasClient(baseUrl: 'https://school.instructure.com', token: 'tok123', dio: dio);
}

Future<CanvasErrorKind> _failureKind(CanvasClient c) async {
  try {
    await c.fetchSelf();
  } on CanvasException catch (e) {
    return e.kind;
  }
  throw StateError('expected a CanvasException');
}

void main() {
  group('normalizeCanvasUrl', () {
    test('adds https and strips path', () {
      expect(normalizeCanvasUrl('school.instructure.com/courses/1'), 'https://school.instructure.com');
      expect(normalizeCanvasUrl('  HTTPS://School.Instructure.com/ '), 'https://school.instructure.com');
    });
    test('rejects junk and plain http', () {
      expect(() => normalizeCanvasUrl(''), throwsA(isA<CanvasException>()));
      expect(() => normalizeCanvasUrl('localhost'), throwsA(isA<CanvasException>()));
      expect(() => normalizeCanvasUrl('http://school.instructure.com'), throwsA(isA<CanvasException>()));
    });
  });

  group('CanvasClient.fetchSelf', () {
    test('parses the user and sends the bearer token', () async {
      final adapter = _FakeAdapter((_) => _json('{"id": 42, "name": "Arsen"}', 200));
      final user = await _client(adapter).fetchSelf();
      expect(user.id, 42);
      expect(user.name, 'Arsen');
      expect(adapter.last!.headers['Authorization'], 'Bearer tok123');
      expect(adapter.last!.path, '/api/v1/users/self');
    });

    test('401 -> unauthorized', () async {
      final c = _client(_FakeAdapter((_) => _json('{"errors":[{"message":"Invalid access token."}]}', 401)));
      expect(await _failureKind(c), CanvasErrorKind.unauthorized);
    });

    test('429 -> rateLimited, 500 -> server, 404 -> invalidUrl', () async {
      expect(await _failureKind(_client(_FakeAdapter((_) => _json('{}', 429)))), CanvasErrorKind.rateLimited);
      expect(await _failureKind(_client(_FakeAdapter((_) => _json('{}', 500)))), CanvasErrorKind.server);
      expect(await _failureKind(_client(_FakeAdapter((_) => _json('{}', 404)))), CanvasErrorKind.invalidUrl);
    });

    test('a 200 that is not Canvas JSON -> invalidUrl', () async {
      final c = _client(_FakeAdapter((_) => _json('"<html>hi</html>"', 200)));
      expect(await _failureKind(c), CanvasErrorKind.invalidUrl);
    });
  });
}
