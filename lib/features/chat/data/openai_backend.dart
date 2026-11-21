import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/ai_settings.dart';
import '../domain/chat_backend.dart';
import '../domain/chat_models.dart';
import 'http_stream.dart';
import 'sse.dart';

/// Any service that speaks the OpenAI "chat completions" protocol: OpenAI,
/// OpenRouter, Groq, or a model running on this computer (Ollama, LM Studio).
class OpenAiBackend implements ChatBackend {
  OpenAiBackend({
    required this.apiKey,
    required this.model,
    this.baseUrl = kOpenAiBaseUrl,
    Dio? dio,
  }) : _dio = dio ?? (Dio()..options.connectTimeout = const Duration(seconds: 15));

  /// May be empty: some local servers need no key.
  final String apiKey;
  final String model;
  final String baseUrl;
  final Dio _dio;

  @override
  Stream<String> reply({required List<ChatMessage> messages, required String system}) async* {
    if (model.trim().isEmpty) {
      throw const ChatException(ChatErrorKind.noModel, 'Choose a model in Settings first.');
    }
    final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (!base.startsWith('https://') && !base.startsWith('http://')) {
      throw const ChatException(ChatErrorKind.unexpected, 'The server address in Settings must start with https://');
    }
    final key = apiKey.trim();
    final events = postEvents(
      _dio,
      '$base/chat/completions',
      headers: {if (key.isNotEmpty) 'Authorization': 'Bearer $key'},
      body: openAiBody(model: model.trim(), system: system, messages: messages),
    );
    await for (final event in events) {
      final piece = openAiTextOf(event);
      if (piece != null && piece.isNotEmpty) yield piece;
    }
  }
}

/// The request body. Messages with no text are left out.
Map<String, Object> openAiBody({
  required String model,
  required String system,
  required List<ChatMessage> messages,
}) =>
    {
      'model': model,
      'stream': true,
      'messages': [
        if (system.trim().isNotEmpty) {'role': 'system', 'content': system},
        for (final m in messages)
          if (m.text.trim().isNotEmpty) {'role': m.role.name, 'content': openAiContent(m)},
      ],
    };

/// Plain text, or (with pictures) the text and then each picture as a data URL.
Object openAiContent(ChatMessage m) => m.images.isEmpty
    ? m.text
    : [
        {'type': 'text', 'text': m.text},
        for (final i in m.images)
          {
            'type': 'image_url',
            'image_url': {'url': 'data:${i.mimeType};base64,${base64Encode(i.bytes)}'},
          },
      ];

/// The new text of one event: null for events that carry none and for the
/// closing `[DONE]`. An error object in the stream is thrown as a [ChatException].
String? openAiTextOf(SseEvent e) {
  final data = e.data.trim();
  if (data == '[DONE]') return null;
  final Object? j;
  try {
    j = jsonDecode(data);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final error = j['error'];
  if (error != null) {
    final message = error is Map ? error['message'] : error;
    throw ChatException(
      ChatErrorKind.unexpected,
      message is String && message.isNotEmpty ? message : 'The AI service stopped the answer.',
    );
  }
  final choices = j['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final first = choices.first;
  final delta = first is Map ? first['delta'] : null;
  final content = delta is Map ? delta['content'] : null;
  return content is String ? content : null;
}
