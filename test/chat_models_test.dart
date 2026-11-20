import 'package:etherlex/features/chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 11, 20, 10);

  test('newChatId gives a different id every time', () {
    expect({for (var i = 0; i < 50; i++) newChatId()}.length, 50);
  });

  group('titleFrom', () {
    test('uses the first line, squeezed', () {
      expect(ChatConversation.titleFrom('  What is   due\nthis week?'), 'What is due');
    });

    test('shortens long text to 48 characters with a dot dot dot', () {
      final t = ChatConversation.titleFrom('a' * 100);
      expect(t.length, 48);
      expect(t.endsWith('…'), isTrue);
    });

    test('empty text becomes "New chat"', () {
      expect(ChatConversation.titleFrom('  \n '), 'New chat');
    });
  });

  group('JSON', () {
    test('a conversation survives a round trip', () {
      final c = ChatConversation(
        id: 'c1',
        title: 'Hello',
        createdAt: at,
        updatedAt: at,
        messages: [
          ChatMessage(id: 'm1', role: ChatRole.user, text: 'Hi', createdAt: at),
          ChatMessage(id: 'm2', role: ChatRole.assistant, text: 'Hello!', createdAt: at),
        ],
      );
      final back = ChatConversation.fromJson(c.toJson())!;
      expect(back.id, 'c1');
      expect(back.title, 'Hello');
      expect([for (final m in back.messages) (m.id, m.role, m.text)], [
        ('m1', ChatRole.user, 'Hi'),
        ('m2', ChatRole.assistant, 'Hello!'),
      ]);
      expect(back.updatedAt.toUtc(), at);
    });

    test('damaged data gives null instead of an error', () {
      expect(ChatConversation.fromJson(null), isNull);
      expect(ChatConversation.fromJson({'id': 1}), isNull);
      expect(ChatMessage.fromJson({'id': 'x', 'role': 'robot', 'text': 't', 'at': at.toIso8601String()}), isNull);
    });

    test('a bad message is skipped, the rest of the chat is kept', () {
      final c = ChatConversation.fromJson({
        'id': 'c',
        'title': 't',
        'created': at.toIso8601String(),
        'updated': at.toIso8601String(),
        'messages': [
          'junk',
          {'id': 'm', 'role': 'user', 'text': 'ok', 'at': at.toIso8601String()},
        ],
      })!;
      expect(c.messages.length, 1);
      expect(c.messages.single.text, 'ok');
    });
  });
}
