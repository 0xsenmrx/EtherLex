import '../domain/chat_backend.dart';
import '../domain/chat_models.dart';

/// The assistant of sample mode: a fixed answer, streamed word by word, and
/// no network at all.
class SampleChatBackend implements ChatBackend {
  const SampleChatBackend({this.delay = const Duration(milliseconds: 30)});

  final Duration delay;

  static const String answer = 'This is **sample mode**, so no AI service is contacted.\n\n'
      'To chat for real, sign in with your Canvas token and add an API key '
      'under **Settings > AI assistant**.';

  @override
  Stream<String> reply({required List<ChatMessage> messages, required String system}) async* {
    final words = answer.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      yield i == 0 ? words[i] : ' ${words[i]}';
    }
  }
}
