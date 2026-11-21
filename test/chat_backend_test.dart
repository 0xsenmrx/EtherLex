import 'package:etherlex/features/chat/domain/chat_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a rejected key says so and never repeats the service text', () {
    final e = chatErrorForStatus(401, 'invalid x-api-key sk-secret');
    expect(e.kind, ChatErrorKind.unauthorized);
    expect(e.message.contains('sk-secret'), isFalse);
    expect(chatErrorForStatus(403).kind, ChatErrorKind.unauthorized);
  });

  test('429 is a rate limit', () {
    expect(chatErrorForStatus(429).kind, ChatErrorKind.rateLimited);
  });

  test('too long input is recognised from 413 and from the 400 text', () {
    expect(chatErrorForStatus(413).kind, ChatErrorKind.tooLong);
    expect(chatErrorForStatus(400, 'prompt is too long: 250000 tokens').kind, ChatErrorKind.tooLong);
    expect(chatErrorForStatus(400, "This model's maximum context length is 8192").kind, ChatErrorKind.tooLong);
  });

  test('other 400s are unexpected and keep the service message', () {
    final e = chatErrorForStatus(400, 'model: unknown');
    expect(e.kind, ChatErrorKind.unexpected);
    expect(e.message, contains('model: unknown'));
  });

  test('5xx (including 529 busy) is a server problem', () {
    expect(chatErrorForStatus(500).kind, ChatErrorKind.server);
    expect(chatErrorForStatus(529).kind, ChatErrorKind.server);
  });

  test('offline has a fixed message', () {
    expect(kChatOffline.kind, ChatErrorKind.offline);
  });
}
