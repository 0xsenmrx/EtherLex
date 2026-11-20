enum ChatRole { user, assistant }

int _counter = 0;

/// A short id that is unique on this computer (time plus a counter).
String newChatId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_counter++}';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;

  ChatMessage copyWith({String? text}) =>
      ChatMessage(id: id, role: role, text: text ?? this.text, createdAt: createdAt);

  Map<String, Object> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'at': createdAt.toUtc().toIso8601String(),
      };

  /// Null when [j] is not a message (a damaged file never throws).
  static ChatMessage? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final text = j['text'];
    final at = DateTime.tryParse('${j['at']}')?.toLocal();
    final role = ChatRole.values.where((r) => r.name == j['role']).firstOrNull;
    if (id is! String || text is! String || at == null || role == null) return null;
    return ChatMessage(id: id, role: role, text: text, createdAt: at);
  }
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatConversation copyWith({String? title, DateTime? updatedAt, List<ChatMessage>? messages}) =>
      ChatConversation(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
      );

  /// A title from the first thing the user wrote: one line, at most 48 characters.
  static String titleFrom(String text) {
    final line = text.trim().split('\n').first.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isEmpty) return 'New chat';
    return line.length <= 48 ? line : '${line.substring(0, 47).trimRight()}…';
  }

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'created': createdAt.toUtc().toIso8601String(),
        'updated': updatedAt.toUtc().toIso8601String(),
        'messages': [for (final m in messages) m.toJson()],
      };

  static ChatConversation? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final title = j['title'];
    final created = DateTime.tryParse('${j['created']}')?.toLocal();
    final updated = DateTime.tryParse('${j['updated']}')?.toLocal();
    final raw = j['messages'];
    if (id is! String || title is! String || created == null || updated == null) return null;
    return ChatConversation(
      id: id,
      title: title,
      createdAt: created,
      updatedAt: updated,
      messages: [
        if (raw is List)
          for (final m in raw) ?ChatMessage.fromJson(m),
      ],
    );
  }
}
