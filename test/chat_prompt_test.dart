import 'package:etherlex/features/chat/data/sample_chat_backend.dart';
import 'package:etherlex/features/chat/domain/chat_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the prompt carries the date and the weekday', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20)); // a Friday
    expect(p, contains('Friday, 2026-11-20'));
    expect(chatSystemPrompt(DateTime(2026, 3, 2)), contains('Monday, 2026-03-02'));
  });

  test('the sample assistant streams its answer in pieces that add up', () async {
    final pieces = await const SampleChatBackend(delay: Duration.zero).reply(messages: [], system: '').toList();
    expect(pieces.length, greaterThan(5));
    expect(pieces.join(), SampleChatBackend.answer);
  });
}
