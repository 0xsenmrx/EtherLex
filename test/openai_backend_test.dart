import 'package:dio/dio.dart';
import 'package:etherlex/features/chat/data/openai_backend.dart';
import 'package:etherlex/features/chat/data/sse.dart';
import 'package:etherlex/features/chat/domain/ai_settings.dart';
import 'package:etherlex/features/chat/domain/chat_backend.dart';
import 'package:etherlex/features/chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/chat_http_fakes.dart';

final _at = DateTime.utc(2026, 11, 20);

ChatMessage _m(ChatRole role, String text) => ChatMessage(id: text, role: role, text: text, createdAt: _at);

const _stream = '''
data: {"choices":[{"index":0,"delta":{"role":"assistant","content":""}}]}

data: {"choices":[{"index":0,"delta":{"content":"Hel"}}]}

data: {"choices":[{"index":0,"delta":{"content":"lo"}}]}

data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: [DONE]

''';

void main() {
  test('openAiBody puts the system prompt first and leaves out empty messages', () {
    final body = openAiBody(
      model: 'gpt-x',
      system: 'Be brief.',
      messages: [_m(ChatRole.user, 'Hi'), _m(ChatRole.assistant, ' ')],
    );
    expect(body['model'], 'gpt-x');
    expect(body['stream'], true);
    expect(body['messages'], [
      {'role': 'system', 'content': 'Be brief.'},
      {'role': 'user', 'content': 'Hi'},
    ]);
  });

  group('openAiTextOf', () {
    test('returns delta content and null for the rest', () {
      expect(openAiTextOf(const SseEvent(null, '{"choices":[{"delta":{"content":"A"}}]}')), 'A');
      expect(openAiTextOf(const SseEvent(null, '{"choices":[{"delta":{}}]}')), isNull);
      expect(openAiTextOf(const SseEvent(null, '{"choices":[]}')), isNull);
      expect(openAiTextOf(const SseEvent(null, '[DONE]')), isNull);
      expect(openAiTextOf(const SseEvent(null, 'junk')), isNull);
    });

    test('an error object is thrown', () {
      expect(
        () => openAiTextOf(const SseEvent(null, '{"error":{"message":"quota used up"}}')),
        throwsA(isA<ChatException>().having((e) => e.message, 'message', 'quota used up')),
      );
    });
  });

  group('OpenAiBackend', () {
    OpenAiBackend backend(FakeAdapter adapter, {String key = 'sk-test', String model = 'gpt-x', String? base}) =>
        OpenAiBackend(
          apiKey: key,
          model: model,
          baseUrl: base ?? kOpenAiBaseUrl,
          dio: Dio()..httpClientAdapter = adapter,
        );

    test('streams the text and sends the bearer key to the chat completions address', () async {
      final adapter = FakeAdapter((_) => sse(_stream));
      final pieces = await backend(adapter).reply(messages: [_m(ChatRole.user, 'Hi')], system: 's').toList();
      expect(pieces, ['Hel', 'lo']);
      expect(adapter.last!.uri.toString(), 'https://api.openai.com/v1/chat/completions');
      expect(adapter.last!.headers['Authorization'], 'Bearer sk-test');
    });

    test('a custom address is used, trailing slashes are ignored, and no key sends no header', () async {
      final adapter = FakeAdapter((_) => sse(_stream));
      await backend(adapter, key: '', base: 'http://localhost:11434/v1//').reply(messages: [], system: '').toList();
      expect(adapter.last!.uri.toString(), 'http://localhost:11434/v1/chat/completions');
      expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
    });

    test('a missing model or a bad address fails before any request', () async {
      final adapter = FakeAdapter((_) => sse(_stream));
      expect((await failure(backend(adapter, model: '').reply(messages: [], system: ''))).kind, ChatErrorKind.noModel);
      expect((await failure(backend(adapter, base: 'ftp://x').reply(messages: [], system: ''))).kind, ChatErrorKind.unexpected);
      expect(adapter.last, isNull);
    });

    test('a rejected key becomes an unauthorized error', () async {
      final adapter = FakeAdapter((_) => jsonBody('{"error":{"message":"Incorrect API key provided: sk-test"}}', 401));
      final e = await failure(backend(adapter).reply(messages: [_m(ChatRole.user, 'Hi')], system: ''));
      expect(e.kind, ChatErrorKind.unauthorized);
      expect(e.message.contains('sk-test'), isFalse);
    });
  });
}
