import 'package:dio/dio.dart';
import 'package:etherlex/features/chat/data/http_stream.dart';
import 'package:etherlex/features/chat/domain/chat_backend.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/chat_http_fakes.dart';

void main() {
  group('errorTextFromBody', () {
    test('reads error.message', () {
      expect(errorTextFromBody('{"type":"error","error":{"type":"x","message":"bad model"}}'), 'bad model');
      expect(errorTextFromBody('{"error":"plain"}'), 'plain');
    });

    test('anything else is null', () {
      expect(errorTextFromBody('not json'), isNull);
      expect(errorTextFromBody('{"error":{}}'), isNull);
      expect(errorTextFromBody('[]'), isNull);
    });
  });

  group('postEvents', () {
    test('yields the events and sends JSON with the given headers', () async {
      final adapter = FakeAdapter((_) => sse('data: one\n\nevent: x\ndata: two\n\n'));
      final dio = Dio()..httpClientAdapter = adapter;
      final events = await postEvents(dio, 'https://ai.test/v1', headers: {'x-key': 'k'}, body: {'a': 1}).toList();
      expect([for (final e in events) (e.event, e.data)], [(null, 'one'), ('x', 'two')]);
      expect(adapter.last!.headers['x-key'], 'k');
      expect(adapter.last!.data, {'a': 1});
      expect(adapter.last!.contentType, Headers.jsonContentType);
    });

    test('a 401 becomes an unauthorized error without the service text', () async {
      final dio = Dio()..httpClientAdapter = FakeAdapter((_) => jsonBody('{"error":{"message":"bad key sk-123"}}', 401));
      final e = await failure(postEvents(dio, 'https://ai.test/v1', headers: {}, body: {}));
      expect(e.kind, ChatErrorKind.unauthorized);
      expect(e.message.contains('sk-123'), isFalse);
    });

    test('a 400 keeps the service message', () async {
      final dio = Dio()..httpClientAdapter = FakeAdapter((_) => jsonBody('{"error":{"message":"model: nope"}}', 400));
      final e = await failure(postEvents(dio, 'https://ai.test/v1', headers: {}, body: {}));
      expect(e.kind, ChatErrorKind.unexpected);
      expect(e.message, contains('model: nope'));
    });

    test('a connection failure is "offline"', () async {
      final dio = Dio()
        ..httpClientAdapter = FakeAdapter(
          (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError),
        );
      final e = await failure(postEvents(dio, 'https://ai.test/v1', headers: {}, body: {}));
      expect(e.kind, ChatErrorKind.offline);
    });
  });
}
