import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/chat_backend.dart';
import '../domain/chat_models.dart';
import 'http_stream.dart';
import 'sse.dart';

/// Claude through the Anthropic Messages API (streaming).
class AnthropicBackend implements ChatBackend {
  AnthropicBackend({
    required this.apiKey,
    required this.model,
    Dio? dio,
    this.baseUrl = 'https://api.anthropic.com',
    this.maxTokens = 8192,
  }) : _dio = dio ?? (Dio()..options.connectTimeout = const Duration(seconds: 15));

  final String apiKey;
  final String model;
  final String baseUrl;
  final int maxTokens;
  final Dio _dio;

  @override
  Stream<String> reply({required List<ChatMessage> messages, required String system}) async* {
    if (apiKey.trim().isEmpty) {
      throw const ChatException(ChatErrorKind.noKey, 'Add your Anthropic API key in Settings first.');
    }
    if (model.trim().isEmpty) {
      throw const ChatException(ChatErrorKind.noModel, 'Choose a model in Settings first.');
    }
    final events = postEvents(
      _dio,
      '$baseUrl/v1/messages',
      headers: {'x-api-key': apiKey.trim(), 'anthropic-version': '2023-06-01'},
      body: anthropicBody(model: model.trim(), maxTokens: maxTokens, system: system, messages: messages),
    );
    await for (final event in events) {
      final piece = anthropicTextOf(event);
      if (piece != null && piece.isNotEmpty) yield piece;
    }
  }
}

/// The request body. Messages with no text are left out (the API refuses them).
Map<String, Object> anthropicBody({
  required String model,
  required int maxTokens,
  required String system,
  required List<ChatMessage> messages,
}) =>
    {
      'model': model,
      'max_tokens': maxTokens,
      'stream': true,
      'system': system,
      'messages': [
        for (final m in messages)
          if (m.text.trim().isNotEmpty) {'role': m.role.name, 'content': m.text},
      ],
    };

/// The new text of one event, null for events that carry none. An `error`
/// event (sent when a stream fails half way) is thrown as a [ChatException].
String? anthropicTextOf(SseEvent e) {
  final Object? j;
  try {
    j = jsonDecode(e.data);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  switch (j['type']) {
    case 'content_block_delta':
      final delta = j['delta'];
      if (delta is Map && delta['type'] == 'text_delta' && delta['text'] is String) return delta['text'] as String;
      return null;
    case 'error':
      final error = j['error'];
      final kind = error is Map ? error['type'] : null;
      final message = error is Map ? error['message'] : null;
      if (kind == 'overloaded_error' || kind == 'api_error') {
        throw const ChatException(
          ChatErrorKind.server,
          'The AI service had a problem or is busy. Try again in a moment.',
        );
      }
      if (kind == 'rate_limit_error') {
        throw const ChatException(
          ChatErrorKind.rateLimited,
          'Too many requests, or the usage limit was reached. Try again in a moment.',
        );
      }
      throw ChatException(
        ChatErrorKind.unexpected,
        message is String && message.isNotEmpty ? message : 'The AI service stopped the answer.',
      );
    default:
      return null;
  }
}
