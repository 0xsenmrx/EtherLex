import 'dart:typed_data';

import 'package:etherlex/features/chat/data/anthropic_backend.dart';
import 'package:etherlex/features/chat/data/openai_backend.dart';
import 'package:etherlex/features/chat/domain/ai_settings.dart';
import 'package:etherlex/features/chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime.utc(2026, 11, 21);
final _png = Uint8List.fromList([1, 2, 3, 4]); // base64: AQIDBA==

ChatMessage _withImage() => ChatMessage(
      id: 'a',
      role: ChatRole.user,
      text: 'What is in this plot?',
      createdAt: _at,
      attached: const ['plot.png'],
      images: [ChatImage(name: 'plot.png', mimeType: 'image/png', bytes: _png)],
    );

void main() {
  test('Anthropic gets the picture first, then the text', () {
    final body = anthropicBody(model: 'm', maxTokens: 10, system: '', messages: [_withImage()]);
    final content = (body['messages'] as List).single['content'] as List;
    expect(content.first, {
      'type': 'image',
      'source': {'type': 'base64', 'media_type': 'image/png', 'data': 'AQIDBA=='},
    });
    expect(content.last, {'type': 'text', 'text': 'What is in this plot?'});
  });

  test('OpenAI-style services get the text, then each picture as a data URL', () {
    final body = openAiBody(model: 'm', system: '', messages: [_withImage()]);
    final content = (body['messages'] as List).single['content'] as List;
    expect(content.first, {'type': 'text', 'text': 'What is in this plot?'});
    expect(content.last, {
      'type': 'image_url',
      'image_url': {'url': 'data:image/png;base64,AQIDBA=='},
    });
  });

  test('a message without pictures stays a plain string', () {
    final m = ChatMessage(id: 'b', role: ChatRole.user, text: 'hi', createdAt: _at);
    expect(anthropicContent(m), 'hi');
    expect(openAiContent(m), 'hi');
  });

  test('pictures are kept in memory but never saved with the chat', () {
    final m = _withImage();
    expect(m.copyWith(text: 'x').images, hasLength(1));
    final json = m.toJson();
    expect(json.toString(), isNot(contains('AQIDBA')));
    final back = ChatMessage.fromJson(json)!;
    expect(back.images, isEmpty);
    expect(back.attached, ['plot.png']);
  });

  test('only DeepSeek is known not to read pictures', () {
    expect(AiProvider.anthropic.readsImages, isTrue);
    expect(AiProvider.openai.readsImages, isTrue);
    expect(AiProvider.deepseek.readsImages, isFalse);
  });
}
