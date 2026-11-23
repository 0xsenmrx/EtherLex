import 'chat_models.dart';

/// How long conversations with the assistant are kept on this computer.
enum ChatRetention {
  always('Always'),
  month('30 days'),
  session('Until I close EtherLex');

  const ChatRetention(this.label);
  final String label;

  static ChatRetention fromName(Object? name) =>
      ChatRetention.values.where((r) => r.name == name).firstOrNull ?? ChatRetention.always;
}

const Duration kChatMonth = Duration(days: 30);

/// What is written to disk: everything, the last 30 days, or nothing.
List<ChatConversation> chatsToSave(List<ChatConversation> all, ChatRetention r, DateTime now) => switch (r) {
      ChatRetention.always => all,
      ChatRetention.month => [for (final c in all) if (now.difference(c.updatedAt) <= kChatMonth) c],
      ChatRetention.session => const [],
    };

/// What stays on screen: like [chatsToSave], except that "until I close"
/// keeps this session's conversations until EtherLex closes.
List<ChatConversation> chatsToShow(List<ChatConversation> all, ChatRetention r, DateTime now) =>
    r == ChatRetention.session ? all : chatsToSave(all, r, now);
