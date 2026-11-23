import 'package:etherlex/features/chat/domain/chat_models.dart';
import 'package:etherlex/features/chat/domain/chat_retention.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 23, 12);
  ChatConversation chat(String id, Duration ago) =>
      ChatConversation(id: id, title: id, createdAt: now.subtract(ago), updatedAt: now.subtract(ago));
  final all = [
    chat('today', Duration.zero),
    chat('edge', kChatMonth),
    chat('old', kChatMonth + const Duration(minutes: 1)),
  ];
  List<String> ids(List<ChatConversation> cs) => [for (final c in cs) c.id];

  test('always keeps everything', () {
    expect(ids(chatsToSave(all, ChatRetention.always, now)), ['today', 'edge', 'old']);
    expect(ids(chatsToShow(all, ChatRetention.always, now)), ['today', 'edge', 'old']);
  });

  test('30 days drops chats not used for more than 30 days, on disk and on screen', () {
    expect(ids(chatsToSave(all, ChatRetention.month, now)), ['today', 'edge']);
    expect(ids(chatsToShow(all, ChatRetention.month, now)), ['today', 'edge']);
  });

  test('until I close saves nothing but keeps the session on screen', () {
    expect(chatsToSave(all, ChatRetention.session, now), isEmpty);
    expect(ids(chatsToShow(all, ChatRetention.session, now)), ['today', 'edge', 'old']);
  });

  test('unknown or missing names fall back to always', () {
    expect(ChatRetention.fromName('month'), ChatRetention.month);
    expect(ChatRetention.fromName('session'), ChatRetention.session);
    expect(ChatRetention.fromName(null), ChatRetention.always);
    expect(ChatRetention.fromName('forever'), ChatRetention.always);
    expect(ChatRetention.fromName(3), ChatRetention.always);
  });
}
