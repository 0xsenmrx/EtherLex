import 'dart:io';

import 'package:etherlex/features/chat/data/chat_store.dart';
import 'package:etherlex/features/chat/domain/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

ChatConversation _chat(String id, int minute, {String text = 'hi'}) {
  final at = DateTime.utc(2026, 11, 20, 10, minute);
  return ChatConversation(
    id: id,
    title: id,
    createdAt: at,
    updatedAt: at,
    messages: [ChatMessage(id: '$id-m', role: ChatRole.user, text: text, createdAt: at)],
  );
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('etherlex_chat_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('a missing file gives an empty list', () async {
    expect(await ChatStore.forScope('school.edu', root: dir.path).read(), isEmpty);
  });

  test('saves and reads back, newest first', () async {
    final store = ChatStore.forScope('school.edu', root: dir.path);
    await store.write([_chat('old', 1), _chat('new', 5, text: 'later')]);
    final back = await store.read();
    expect([for (final c in back) c.id], ['new', 'old']);
    expect(back.first.messages.single.text, 'later');
  });

  test('each account has its own file, and odd names are made safe', () async {
    await ChatStore.forScope('a.edu', root: dir.path).write([_chat('a', 1)]);
    expect(await ChatStore.forScope('b.edu', root: dir.path).read(), isEmpty);
    final odd = ChatStore.forScope('../x:y', root: dir.path);
    await odd.write([_chat('o', 1)]);
    expect(Directory('${dir.path}/chats').listSync().length, 2);
  });

  test('a damaged file gives an empty list, a bad entry is skipped', () async {
    final store = ChatStore.forScope('s', root: dir.path);
    await store.write([_chat('ok', 1)]);
    final f = File('${dir.path}/chats/s.json');
    f.writeAsStringSync('{"conversations":[1,"x"]}');
    expect(await store.read(), isEmpty);
    f.writeAsStringSync('{not json');
    expect(await store.read(), isEmpty);
  });

  test('only the newest $kMaxConversations conversations are kept', () async {
    final store = ChatStore.forScope('s', root: dir.path);
    await store.write([for (var i = 0; i < kMaxConversations + 5; i++) _chat('c$i', 0).copyWith(updatedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i)))]);
    final back = await store.read();
    expect(back.length, kMaxConversations);
    expect(back.first.id, 'c${kMaxConversations + 4}');
    expect(back.any((c) => c.id == 'c0'), isFalse);
  });

  test('two quick saves end with the second', () async {
    final store = ChatStore.forScope('s', root: dir.path);
    final a = store.write([_chat('first', 1)]);
    final b = store.write([_chat('second', 2)]);
    await Future.wait([a, b]);
    expect([for (final c in await store.read()) c.id], ['second']);
  });
}
