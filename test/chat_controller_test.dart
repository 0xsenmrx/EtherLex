import 'dart:async';
import 'dart:io';

import 'package:etherlex/features/chat/data/chat_store.dart';
import 'package:etherlex/features/chat/domain/chat_backend.dart';
import 'package:etherlex/features/chat/domain/chat_models.dart';
import 'package:etherlex/features/chat/presentation/ai_providers.dart';
import 'package:etherlex/features/chat/presentation/chat_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class ScriptBackend implements ChatBackend {
  ScriptBackend(this.script);

  /// Called for every question; returns what the "service" streams back.
  final Stream<String> Function(int call) script;
  final List<List<ChatMessage>> seen = [];
  String? system;

  @override
  Stream<String> reply({required List<ChatMessage> messages, required String system}) {
    seen.add(messages);
    this.system = system;
    return script(seen.length);
  }
}

Stream<String> pieces(List<String> parts) => Stream.fromIterable(parts);

Stream<String> failingAfter(List<String> parts, Object error) async* {
  for (final p in parts) {
    yield p;
  }
  throw error;
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_chatc_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ChatStore store() => ChatStore.forScope('test', root: dir.path);

  ({ProviderContainer container, ChatController controller}) start(ScriptBackend backend) {
    final c = ProviderContainer(overrides: [
      chatStoreProvider.overrideWithValue(store()),
      chatBackendProvider.overrideWithValue(() async => backend),
    ]);
    addTearDown(c.dispose);
    c.listen(chatControllerProvider, (_, _) {});
    return (container: c, controller: c.read(chatControllerProvider.notifier));
  }

  test('an answer streams into the chat, the chat is titled and saved', () async {
    final backend = ScriptBackend((_) => pieces(['Hel', 'lo ', 'there']));
    final t = start(backend);
    await t.controller.send('  What is due this week?  ');

    final s = t.container.read(chatControllerProvider);
    expect(s.streaming, isFalse);
    expect(s.error, isNull);
    final chat = s.current!;
    expect(chat.title, 'What is due this week?');
    expect([for (final m in chat.messages) (m.role, m.text)], [
      (ChatRole.user, 'What is due this week?'),
      (ChatRole.assistant, 'Hello there'),
    ]);
    final saved = await store().read();
    expect(saved.single.id, chat.id);
    expect(saved.single.messages.last.text, 'Hello there');
  });

  test('the service gets the whole conversation and a system prompt with the date', () async {
    final backend = ScriptBackend((n) => pieces(['answer $n']));
    final t = start(backend);
    await t.controller.send('one');
    await t.controller.send('two');

    expect([for (final m in backend.seen.last) m.text], ['one', 'answer 1', 'two']);
    expect(backend.system, contains('Today is'));
    expect(t.container.read(chatControllerProvider).conversations.length, 1);
  });

  test('empty text is ignored', () async {
    final backend = ScriptBackend((_) => pieces(['x']));
    final t = start(backend);
    await t.controller.send('   ');
    expect(backend.seen, isEmpty);
    expect(t.container.read(chatControllerProvider).conversations, isEmpty);
  });

  test('a failure keeps the part that arrived and shows the error', () async {
    final backend = ScriptBackend((_) => failingAfter(['Par'], kChatOffline));
    final t = start(backend);
    await t.controller.send('hi');

    final s = t.container.read(chatControllerProvider);
    expect(s.error?.kind, ChatErrorKind.offline);
    expect(s.streaming, isFalse);
    expect(s.current!.messages.last.text, 'Par');
  });

  test('a failure with no text leaves no empty answer, and retry works', () async {
    final backend = ScriptBackend((n) => n == 1
        ? failingAfter([], const ChatException(ChatErrorKind.unauthorized, 'bad key'))
        : pieces(['fine']));
    final t = start(backend);
    await t.controller.send('hi');

    var s = t.container.read(chatControllerProvider);
    expect(s.error?.kind, ChatErrorKind.unauthorized);
    expect([for (final m in s.current!.messages) m.role], [ChatRole.user]);

    await t.controller.regenerate();
    s = t.container.read(chatControllerProvider);
    expect(s.error, isNull);
    expect([for (final m in s.current!.messages) m.text], ['hi', 'fine']);
  });

  test('an unexpected error is shown as a safe message', () async {
    final backend = ScriptBackend((_) => failingAfter([], StateError('secret sk-123')));
    final t = start(backend);
    await t.controller.send('hi');
    final e = t.container.read(chatControllerProvider).error!;
    expect(e.kind, ChatErrorKind.unexpected);
    expect(e.message.contains('sk-123'), isFalse);
  });

  test('regenerate replaces the last answer', () async {
    final backend = ScriptBackend((n) => pieces(['answer $n']));
    final t = start(backend);
    await t.controller.send('q');
    await t.controller.regenerate();

    final messages = t.container.read(chatControllerProvider).current!.messages;
    expect([for (final m in messages) m.text], ['q', 'answer 2']);
    expect(backend.seen.last.map((m) => m.text), ['q']);
  });

  test('stop keeps what has arrived', () async {
    final source = StreamController<String>();
    final backend = ScriptBackend((_) => source.stream);
    final t = start(backend);
    final sending = t.controller.send('hi');
    await tick();
    source.add('ab');
    await tick();
    expect(t.container.read(chatControllerProvider).streaming, isTrue);

    t.controller.stop();
    await sending;
    await source.close();

    final s = t.container.read(chatControllerProvider);
    expect(s.streaming, isFalse);
    expect(s.error, isNull);
    expect(s.current!.messages.last.text, 'ab');
  });

  test('a second question while an answer arrives is ignored', () async {
    final source = StreamController<String>();
    final backend = ScriptBackend((_) => source.stream);
    final t = start(backend);
    final first = t.controller.send('one');
    await tick();
    await t.controller.send('two');
    expect(backend.seen.length, 1);

    await source.close();
    await first;
  });

  test('new chat, select and delete', () async {
    final backend = ScriptBackend((n) => pieces(['a$n']));
    final t = start(backend);
    await t.controller.send('first');
    final firstId = t.container.read(chatControllerProvider).currentId!;

    t.controller.newChat();
    expect(t.container.read(chatControllerProvider).current, isNull);
    await t.controller.send('second');
    final s = t.container.read(chatControllerProvider);
    expect(s.conversations.length, 2);
    expect(s.conversations.first.title, 'second');

    t.controller.select(firstId);
    expect(t.container.read(chatControllerProvider).current!.title, 'first');

    await t.controller.delete(firstId);
    final after = t.container.read(chatControllerProvider);
    expect(after.conversations.length, 1);
    expect(after.current, isNull);
    expect((await store().read()).single.title, 'second');
  });

  test('saved conversations are there at the next start', () async {
    final backend = ScriptBackend((_) => pieces(['ok']));
    final first = start(backend);
    await first.controller.send('remember me');

    final second = start(backend);
    await second.controller.whenLoaded();
    final s = second.container.read(chatControllerProvider);
    expect(s.loaded, isTrue);
    expect(s.conversations.single.title, 'remember me');
  });
}
