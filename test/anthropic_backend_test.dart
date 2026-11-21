import 'package:dio/dio.dart';
import 'package:etherlex/features/chat/data/anthropic_backend.dart';
import 'package:etherlex/features/chat/data/sse.dart';
import 'package:etherlex/features/chat/domain/chat_backend.dart';
import 'package:etherlex/features/chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/chat_http_fakes.dart';

final _at = DateTime.utc(2026, 11, 20);

ChatMessage _m(ChatRole role, String text) => ChatMessage(id: text, role: role, text: text, createdAt: _at);

const _stream = '''
event: message_start
data: {"type":"message_start","message":{"id":"msg_1","role":"assistant","content":[]}}

event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: ping
data: {"type":"ping"}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}

event: content_block_stop
data: {"type":"content_block_stop","index":0}

event: message_stop
data: {"type":"message_stop"}

''';

void main() {
  group('anthropicBody', () {
    test('has the model, limit, streaming flag, system prompt and chat turns', () {
      final body = anthropicBody(
        model: 'claude-x',
        maxTokens: 100,
        system: 'Be brief.',
        messages: [_m(ChatRole.user, 'Hi'), _m(ChatRole.assistant, 'Hello'), _m(ChatRole.user, 'Bye')],
      );
      expect(body['model'], 'claude-x');
      expect(body['max_tokens'], 100);
      expect(body['stream'], true);
      expect(body['system'], 'Be brief.');
      expect(body['messages'], [
        {'role': 'user', 'content': 'Hi'},
        {'role': 'assistant', 'content': 'Hello'},
        {'role': 'user', 'content': 'Bye'},
      ]);
    });

    test('empty messages are left out', () {
      final body = anthropicBody(
        model: 'm',
        maxTokens: 1,
        system: '',
        messages: [_m(ChatRole.user, 'Hi'), _m(ChatRole.assistant, '  ')],
      );
      expect(body['messages'], [
        {'role': 'user', 'content': 'Hi'},
      ]);
    });
  });

  group('anthropicTextOf', () {
    test('returns the text of a text delta and nothing for other events', () {
      expect(anthropicTextOf(const SseEvent('x', '{"type":"content_block_delta","delta":{"type":"text_delta","text":"A"}}')), 'A');
      expect(anthropicTextOf(const SseEvent('x', '{"type":"ping"}')), isNull);
      expect(anthropicTextOf(const SseEvent('x', '{"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{}"}}')), isNull);
      expect(anthropicTextOf(const SseEvent('x', 'not json')), isNull);
    });

    test('an error event is thrown with a readable kind', () {
      ChatException caught(String data) {
        try {
          anthropicTextOf(SseEvent('error', data));
        } on ChatException catch (e) {
          return e;
        }
        throw StateError('expected a ChatException');
      }

      expect(caught('{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}').kind, ChatErrorKind.server);
      expect(caught('{"type":"error","error":{"type":"rate_limit_error","message":"slow down"}}').kind, ChatErrorKind.rateLimited);
      expect(caught('{"type":"error","error":{"type":"invalid_request_error","message":"bad"}}').message, 'bad');
    });
  });

  group('AnthropicBackend', () {
    AnthropicBackend backend(FakeAdapter adapter, {String key = 'sk-test', String model = 'claude-x'}) =>
        AnthropicBackend(apiKey: key, model: model, dio: Dio()..httpClientAdapter = adapter);

    test('streams the text pieces and sends the key and version headers', () async {
      final adapter = FakeAdapter((_) => sse(_stream));
      final pieces = await backend(adapter).reply(messages: [_m(ChatRole.user, 'Hi')], system: 's').toList();
      expect(pieces, ['Hel', 'lo']);
      expect(adapter.last!.uri.toString(), 'https://api.anthropic.com/v1/messages');
      expect(adapter.last!.headers['x-api-key'], 'sk-test');
      expect(adapter.last!.headers['anthropic-version'], '2023-06-01');
    });

    test('a missing key or model fails before any request', () async {
      final adapter = FakeAdapter((_) => sse(_stream));
      final noKey = await failure(backend(adapter, key: ' ').reply(messages: [], system: ''));
      expect(noKey.kind, ChatErrorKind.noKey);
      final noModel = await failure(backend(adapter, model: '').reply(messages: [], system: ''));
      expect(noModel.kind, ChatErrorKind.noModel);
      expect(adapter.last, isNull);
    });

    test('a rejected key becomes an unauthorized error', () async {
      final adapter = FakeAdapter((_) => jsonBody('{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}', 401));
      final e = await failure(backend(adapter).reply(messages: [_m(ChatRole.user, 'Hi')], system: ''));
      expect(e.kind, ChatErrorKind.unauthorized);
    });
  });
}
