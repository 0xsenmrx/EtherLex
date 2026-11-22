import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assignments/presentation/assignments_providers.dart';
import '../../auth/domain/auth_provider.dart';
import '../../courses/domain/course.dart';
import '../data/chat_store.dart';
import '../domain/chat_backend.dart';
import '../domain/chat_models.dart';
import '../domain/chat_prompt.dart';
import '../domain/context_item.dart';
import 'ai_consent.dart';
import 'ai_providers.dart';

/// The saved conversations of the signed-in account (sample mode has its own).
final chatStoreProvider = Provider<ChatStore>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  return ChatStore.forScope(session == null || session.isSample ? 'sample' : session.scope);
});

class ChatState {
  const ChatState({
    this.conversations = const [],
    this.currentId,
    this.streaming = false,
    this.error,
    this.loaded = false,
  });

  /// Newest first.
  final List<ChatConversation> conversations;

  /// The conversation on screen; null is a new chat that has no message yet.
  final String? currentId;

  /// An answer is arriving.
  final bool streaming;

  /// Why the last question failed; cleared by the next one.
  final ChatException? error;

  /// The saved conversations have been read.
  final bool loaded;

  ChatConversation? get current => conversations.where((c) => c.id == currentId).firstOrNull;

  ChatState copyWith({List<ChatConversation>? conversations, bool? streaming, bool? loaded}) => ChatState(
        conversations: conversations ?? this.conversations,
        currentId: currentId,
        streaming: streaming ?? this.streaming,
        error: error,
        loaded: loaded ?? this.loaded,
      );

  ChatState withCurrent(String? id) => ChatState(
        conversations: conversations,
        currentId: id,
        streaming: streaming,
        error: error,
        loaded: loaded,
      );

  ChatState withError(ChatException? e) => ChatState(
        conversations: conversations,
        currentId: currentId,
        streaming: streaming,
        error: e,
        loaded: loaded,
      );
}

class ChatController extends Notifier<ChatState> {
  StreamSubscription<String>? _sub;
  Completer<void>? _running;
  Future<void>? _loading;

  @override
  ChatState build() {
    final store = ref.watch(chatStoreProvider);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      final running = _running;
      if (running != null && !running.isCompleted) running.complete();
    });
    _loading = _load(store);
    return const ChatState();
  }

  bool _stale(ChatStore store) => !ref.mounted || !identical(store, ref.read(chatStoreProvider));

  Future<void> _load(ChatStore store) async {
    final all = await store.read();
    if (_stale(store)) return;
    state = ChatState(conversations: all, loaded: true);
  }

  /// Completes when the saved conversations have been read.
  Future<void> whenLoaded() => _loading ?? Future<void>.value();

  Future<void> _save(ChatStore store) async {
    try {
      await store.write(state.conversations);
    } catch (_) {
      // Chats are a convenience; a full disk must not break the conversation.
    }
  }

  ChatConversation? _find(String id) => state.conversations.where((c) => c.id == id).firstOrNull;

  void _put(ChatConversation c) {
    state = state.copyWith(conversations: [c, ...state.conversations.where((x) => x.id != c.id)]);
  }

  /// Starts a new, empty chat.
  void newChat() {
    stop();
    state = state.withCurrent(null).withError(null);
  }

  void select(String id) {
    if (id == state.currentId) return;
    stop();
    state = state.withCurrent(id).withError(null);
  }

  Future<void> delete(String id) async {
    if (id == state.currentId) stop();
    final store = ref.read(chatStoreProvider);
    state = state.copyWith(conversations: [...state.conversations.where((c) => c.id != id)]);
    if (id == state.currentId) state = state.withCurrent(null).withError(null);
    await _save(store);
  }

  void dismissError() => state = state.withError(null);

  /// Sends [text] as the next question, with what the student attached from
  /// Canvas ([items]), and streams the answer into the chat. Completes when the
  /// answer is finished, stopped or failed.
  Future<void> send(String text, {List<ContextItem> items = const []}) async {
    final t = text.trim();
    if (t.isEmpty || state.streaming) return;
    await whenLoaded();
    if (state.streaming) return;
    final store = ref.read(chatStoreProvider);
    final now = DateTime.now();
    final base = state.current ??
        ChatConversation(id: newChatId(), title: ChatConversation.titleFrom(t), createdAt: now, updatedAt: now);
    final conv = base.copyWith(
      updatedAt: now,
      messages: [
        ...base.messages,
        ChatMessage(
          id: newChatId(),
          role: ChatRole.user,
          text: t,
          createdAt: now,
          context: contextPromptFor(items),
          attached: [for (final i in items) i.label],
          images: [
            for (final i in items.whereType<ImageContext>())
              ChatImage(name: i.name, mimeType: i.mimeType, bytes: i.bytes),
          ],
        ),
      ],
    );
    _put(conv);
    state = state.withCurrent(conv.id).withError(null);
    await _run(store, conv.id);
  }

  /// Asks again: drops the last answer (if any) and answers the last question.
  Future<void> regenerate() async {
    if (state.streaming) return;
    await whenLoaded();
    final conv = state.current;
    if (conv == null || state.streaming) return;
    var messages = conv.messages;
    if (messages.isNotEmpty && messages.last.role == ChatRole.assistant) {
      messages = messages.sublist(0, messages.length - 1);
    }
    if (messages.isEmpty || messages.last.role != ChatRole.user) return;
    _put(conv.copyWith(messages: messages, updatedAt: DateTime.now()));
    state = state.withError(null);
    await _run(ref.read(chatStoreProvider), conv.id);
  }

  /// Stops the answer that is arriving; what came so far is kept.
  void stop() {
    _sub?.cancel();
    _sub = null;
    final running = _running;
    if (running != null && !running.isCompleted) running.complete();
  }

  ChatException _asChatException(Object e) => e is ChatException
      ? e
      : const ChatException(ChatErrorKind.unexpected, 'Something went wrong. Please try again.');

  /// The student's course names, so "hide my math courses" can be answered
  /// exactly. Sent only after they allowed sending Canvas data to this service.
  CoursesContext? _courseList() {
    final session = ref.read(authProvider).value;
    final allowed = session != null && (session.isSample || ref.read(aiConsentProvider.notifier).allows(ref.read(aiSettingsProvider)));
    if (!allowed) return null;
    final disabled = ref.read(disabledCoursesProvider);
    final courses = [...(ref.read(coursesProvider).value ?? const <Course>[])]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return CoursesContext(lines: [for (final c in courses) CourseLine(name: c.name, code: c.code, hidden: disabled.contains(c.id))]);
  }

  Future<void> _run(ChatStore store, String conversationId) async {
    final conv = _find(conversationId);
    if (conv == null) return;
    final history = conv.messages;
    final answer = ChatMessage(id: newChatId(), role: ChatRole.assistant, text: '', createdAt: DateTime.now());
    _put(conv.copyWith(messages: [...history, answer]));
    state = state.copyWith(streaming: true).withError(null);
    await _save(store);

    ChatException? failure;
    final done = Completer<void>();
    _running = done;
    try {
      final backend = await ref.read(chatBackendProvider)();
      // Stop may have been pressed while the backend was being made.
      if (!done.isCompleted) {
        // The model sees each question together with what was attached to it.
        final forModel = [
          for (final m in history)
            ChatMessage(id: m.id, role: m.role, text: m.promptText, createdAt: m.createdAt, images: m.images),
        ];
        _sub = backend.reply(messages: forModel, system: chatSystemPrompt(DateTime.now(), courses: _courseList())).listen(
          (piece) => _append(conversationId, answer.id, piece),
          onError: (Object e, StackTrace _) {
            failure = _asChatException(e);
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
        await done.future;
      }
    } catch (e) {
      failure = _asChatException(e);
    } finally {
      await _sub?.cancel();
      _sub = null;
      if (identical(_running, done)) _running = null;
    }
    if (_stale(store)) return;
    _finish(conversationId, answer.id, failure);
    await _save(store);
  }

  void _append(String conversationId, String messageId, String piece) {
    final conv = _find(conversationId);
    if (conv == null) return;
    _put(conv.copyWith(
      messages: [
        for (final m in conv.messages) m.id == messageId ? m.copyWith(text: m.text + piece) : m,
      ],
    ));
  }

  void _finish(String conversationId, String messageId, ChatException? failure) {
    final conv = _find(conversationId);
    if (conv != null) {
      // An answer with no text (failed at once, or stopped at once) is not kept.
      final messages = [
        for (final m in conv.messages)
          if (m.id != messageId || m.text.isNotEmpty) m,
      ];
      _put(conv.copyWith(messages: messages, updatedAt: DateTime.now()));
    }
    state = state.copyWith(streaming: false).withError(failure);
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
