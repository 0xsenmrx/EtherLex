import 'chat_models.dart';

enum ChatErrorKind { noKey, noModel, unauthorized, rateLimited, offline, tooLong, server, unexpected }

/// A problem with a safe, readable [message] (never contains the key).
class ChatException implements Exception {
  const ChatException(this.kind, this.message);

  final ChatErrorKind kind;
  final String message;

  @override
  String toString() => 'ChatException(${kind.name}): $message';
}

/// An AI service that answers a conversation.
abstract interface class ChatBackend {
  /// The answer as it arrives, piece by piece. [messages] ends with the
  /// user's newest message. Cancelling the subscription cancels the request.
  /// Failures arrive as a [ChatException] on the stream.
  Stream<String> reply({required List<ChatMessage> messages, required String system});
}

/// The error for an HTTP answer. [detail] is the service's own message, if it sent one.
ChatException chatErrorForStatus(int status, [String? detail]) {
  final d = detail?.trim();
  final extra = d == null || d.isEmpty ? '' : ' ($d)';
  if (status == 401 || status == 403) {
    return const ChatException(
      ChatErrorKind.unauthorized,
      'The API key was not accepted. Check it in Settings.',
    );
  }
  if (status == 429) {
    return ChatException(
      ChatErrorKind.rateLimited,
      'Too many requests, or the usage limit was reached. Try again in a moment.$extra',
    );
  }
  final lower = d?.toLowerCase() ?? '';
  if (status == 413 ||
      (status == 400 && (lower.contains('too long') || lower.contains('too large') || lower.contains('context length') || lower.contains('maximum context')))) {
    return const ChatException(
      ChatErrorKind.tooLong,
      'That is too long for the model. Start a new chat or send less text.',
    );
  }
  if (status >= 500) {
    return ChatException(
      ChatErrorKind.server,
      'The AI service had a problem or is busy. Try again in a moment.$extra',
    );
  }
  return ChatException(ChatErrorKind.unexpected, 'The AI service refused the request ($status).$extra');
}

const ChatException kChatOffline = ChatException(
  ChatErrorKind.offline,
  'Could not reach the AI service. Check your internet connection.',
);
