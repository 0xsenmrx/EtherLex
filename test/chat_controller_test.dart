import 'dart:async';
import 'dart:io';

import 'package:etherlex/core/storage/settings_store.dart';
import 'package:etherlex/features/chat/data/chat_store.dart';
import 'package:etherlex/features/chat/domain/chat_backend.dart';
import 'package:etherlex/features/chat/domain/chat_models.dart';
import 'package:etherlex/features/chat/domain/chat_retention.dart';
import 'package:etherlex/features/chat/domain/context_item.dart';
import 'package:etherlex/features/chat/presentation/ai_providers.dart';
import 'package:etherlex/features/chat/presentation/chat_controller.dart';
import 'package:etherlex/features/settings/presentation/settings_store_provider.dart';
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

/// Waits until [done] is true. A fixed delay is too short on a slow CI runner.
Future<void> until(bool Function() done) async {
  final end = DateTime.now().add(const Duration(seconds: 10));
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('timed out waiting for the controller');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_chatc_'));
  tearDown(() {
    // Windows can still hold a just-written file for a moment; a leftover temp folder is harmless.
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore
    }
  });

  ChatStore store() => ChatStore.forScope('test', root: dir.path);

  ({ProviderContainer container, ChatController controller}) start(ScriptBackend backend) {
    final c = ProviderContainer(overrides: [
      chatStoreProvider.overrideWithValue(store()),
      chatBackendProvider.overrideWithValue(() async => backend),
      settingsStoreProvider.overrideWithValue(FileSettingsStore(file: File('${dir.path}/settings.json'))),
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
    await until(() => backend.seen.isNotEmpty);
    source.add('ab');
    await until(() => t.container.read(chatControllerProvider).current?.messages.last.text == 'ab');
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
    await until(() => backend.seen.isNotEmpty);
    await t.controller.send('two');
    expect(backend.seen.length, 1);

    await source.close();
    await first;
  });

  test('attachments go to the model with the question but the chat shows only the question', () async {
    final backend = ScriptBackend((_) => pieces(['ok']));
    final t = start(backend);
    await t.controller.send(
      'What is due first?',
      items: [
        AssignmentsContext(title: 'Open assignments', lines: [
          AssignmentLine(course: 'PHYS101', title: 'Lab 2', dueAt: DateTime(2026, 11, 25)),
        ]),
      ],
    );
    final sent = backend.seen.last.single.text;
    expect(sent, contains('PHYS101: Lab 2'));
    expect(sent, endsWith('What is due first?'));

    final shown = t.container.read(chatControllerProvider).current!.messages.first;
    expect(shown.text, 'What is due first?');
    expect(shown.attached, ['Open assignments (1)']);

    await t.controller.send('And after that?');
    final second = backend.seen.last;
    expect(second.first.text, contains('PHYS101: Lab 2'));
    expect(second.last.text, 'And after that?');
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

  group('keep conversations (#52)', () {
    test('"until I close" keeps the chat on screen but writes nothing', () async {
      final t = start(ScriptBackend((_) => pieces(['ok'])));
      await t.controller.whenLoaded();
      t.container.read(chatRetentionProvider.notifier).set(ChatRetention.session);
      await t.controller.send('First question');
      expect(t.container.read(chatControllerProvider).conversations, hasLength(1));
      expect(await store().read(), isEmpty);
    });

    test('delete all empties the screen and the file', () async {
      final t = start(ScriptBackend((_) => pieces(['ok'])));
      await t.controller.whenLoaded();
      await t.controller.send('One');
      t.controller.newChat();
      await t.controller.send('Two');
      expect(await store().read(), hasLength(2));
      await t.controller.deleteAll();
      final s = t.container.read(chatControllerProvider);
      expect(s.conversations, isEmpty);
      expect(s.current, isNull);
      expect(await store().read(), isEmpty);
    });

    test('switching to 30 days removes old chats from the file', () async {
      final now = DateTime.now();
      ChatConversation chat(String id, int daysAgo) => ChatConversation(
            id: id,
            title: id,
            createdAt: now.subtract(Duration(days: daysAgo)),
            updatedAt: now.subtract(Duration(days: daysAgo)),
          );
      await store().write([chat('new', 1), chat('old', 45)]);
      final t = start(ScriptBackend((_) => pieces(['ok'])));
      await t.controller.whenLoaded();
      expect(t.container.read(chatControllerProvider).conversations, hasLength(2));
      t.container.read(chatRetentionProvider.notifier).set(ChatRetention.month);
      await until(() => t.container.read(chatControllerProvider).conversations.length == 1);
      var saved = await store().read();
      for (var i = 0; i < 200 && saved.length != 1; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        saved = await store().read();
      }
      expect([for (final c in saved) c.id], ['new']);
    });
  });
}
