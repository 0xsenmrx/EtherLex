import 'dart:typed_data';

enum ChatRole { user, assistant }

int _counter = 0;

/// A short id that is unique on this computer (time plus a counter).
String newChatId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_counter++}';

/// A picture sent with a message. Only kept in memory: saved chats keep the
/// chip label but not the bytes.
class ChatImage {
  const ChatImage({required this.name, required this.mimeType, required this.bytes});

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.context = '',
    this.attached = const [],
    this.images = const [],
  });

  final String id;
  final ChatRole role;

  /// What the student typed (or the answer). This is what the chat shows.
  final String text;
  final DateTime createdAt;

  /// The text of what the student attached from Canvas, as sent to the model.
  /// Kept so later questions in the chat still see it. Never shown as text.
  final String context;

  /// The chips shown under the message, e.g. "Open assignments (4)".
  final List<String> attached;

  /// Pictures attached to this message (not saved with the chat).
  final List<ChatImage> images;

  /// Everything the model gets for this message: attachments, then the words.
  String get promptText => context.isEmpty ? text : '$context\n\n$text';

  ChatMessage copyWith({String? text}) => ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        context: context,
        attached: attached,
        images: images,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'at': createdAt.toUtc().toIso8601String(),
        if (context.isNotEmpty) 'ctx': context,
        if (attached.isNotEmpty) 'att': attached,
      };

  /// Null when [j] is not a message (a damaged file never throws).
  static ChatMessage? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final text = j['text'];
    final at = DateTime.tryParse('${j['at']}')?.toLocal();
    final role = ChatRole.values.where((r) => r.name == j['role']).firstOrNull;
    if (id is! String || text is! String || at == null || role == null) return null;
    final ctx = j['ctx'];
    final att = j['att'];
    return ChatMessage(
      id: id,
      role: role,
      text: text,
      createdAt: at,
      context: ctx is String ? ctx : '',
      attached: [if (att is List) for (final a in att) if (a is String) a],
    );
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
