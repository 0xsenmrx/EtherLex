import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show InputBorder, InputDecoration, SelectableText, TextField;

import '../../../core/motion/smooth_scroll.dart';
import '../../../core/network/canvas_exception.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../auth/domain/auth_provider.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../domain/ai_settings.dart';
import '../domain/chat_backend.dart';
import '../domain/chat_models.dart';
import '../domain/context_item.dart';
import 'ai_providers.dart';
import 'chat_controller.dart';
import 'chat_attach.dart';
import 'chat_markdown_view.dart';
import 'copy_button.dart';

/// The assistant: one conversation on screen, older ones under History.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = SmoothScrollController();

  /// What will be sent with the next message.
  final List<ContextItem> _attached = [];

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  bool _sending = false;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || ref.read(chatControllerProvider).streaming) return;
    _sending = true;
    try {
      // The service may have been changed since the items were attached.
      if (_attached.isNotEmpty && !await ensureConsent(context, ref)) return;
      if (!mounted) return;
      final provider = ref.read(aiSettingsProvider).provider;
      if (!provider.readsImages && _attached.any((a) => a is ImageContext)) {
        setState(() => _attachError = ChatException(ChatErrorKind.unexpected, _noPictures(provider)));
        return;
      }
      final items = [..._attached];
      _input.clear();
      setState(_attached.clear);
      ref.read(chatControllerProvider.notifier).send(text, items: items);
      _toEnd();
    } finally {
      _sending = false;
    }
  }

  /// Fetching something to attach can take a moment, and can fail.
  bool _loadingAttach = false;
  ChatException? _attachError;
  ContextBuilder? _failedBuild;

  static String _noPictures(AiProvider p) =>
      '${p.label} cannot read pictures yet. Choose another service in Settings, or attach a text file instead.';

  Future<void> _attach() async {
    if (_loadingAttach) return;
    if (!await ensureConsent(context, ref) || !mounted) return;
    final build = await pickContext(context, ref);
    if (build == null || !mounted) return;
    await _load(build);
  }

  Future<void> _load(ContextBuilder build) async {
    setState(() {
      _loadingAttach = true;
      _attachError = null;
      _failedBuild = null;
    });
    try {
      final item = await build();
      if (!mounted) return;
      final provider = ref.read(aiSettingsProvider).provider;
      if (item is ImageContext && !provider.readsImages) {
        setState(() {
          _loadingAttach = false;
          _attachError = ChatException(ChatErrorKind.unexpected, _noPictures(provider));
        });
        return;
      }
      setState(() {
        _loadingAttach = false;
        if (item != null) {
          _attached.removeWhere((a) => a.key == item.key);
          _attached.add(item);
        }
      });
      _inputFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAttach = false;
        _failedBuild = e is AttachException && !e.retryable ? null : build;
        _attachError = ChatException(
          ChatErrorKind.unexpected,
          e is CanvasException ? e.message : e is AttachException ? e.message : 'Could not load that from Canvas. Check your connection and try again.',
        );
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final settings = ref.watch(aiSettingsProvider);
    final keys = ref.watch(aiKeysProvider);
    final session = ref.watch(authProvider.select((a) => a.value));
    final sample = session == null || session.isSample;
    ref.listen(chatControllerProvider.select((s) => s.current?.messages.lastOrNull?.text.length), (_, _) => _toEnd());

    final messages = state.current?.messages ?? const <ChatMessage>[];
    final needsKey = !sample && !keys.contains(settings.provider) && messages.isEmpty;

    return Column(
      children: [
        EPageHeader(
          title: 'Assistant',
          subtitle: settings.model.isEmpty ? settings.provider.label : '${settings.provider.label} · ${settings.model}',
          actions: [
            EIconButton(icon: EIcons.history, tooltip: 'History', onTap: () => _showHistory(context)),
            EButton(label: 'New chat', icon: EIcons.plus, onTap: messages.isEmpty ? null : controller.newChat),
          ],
        ),
        Expanded(
          child: messages.isEmpty
              ? (needsKey
                  ? EEmptyState(
                      icon: EIcons.sparkles,
                      title: 'Add an API key to start',
                      message: 'The assistant uses your own key from ${settings.provider.label}. It stays on this computer.',
                      action: EButton(label: 'Open settings', onTap: () => showSettings(context)),
                    )
                  : const EEmptyState(
                      icon: EIcons.sparkles,
                      title: 'Ask anything',
                      message: 'Explain a topic, plan your week, or draft a message.',
                    ))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final last = i == messages.length - 1;
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _Bubble(
                          message: m,
                          thinking: last && state.streaming && m.role == ChatRole.assistant && m.text.isEmpty,
                          onRegenerate: last && !state.streaming && m.role == ChatRole.assistant
                              ? controller.regenerate
                              : null,
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (state.error case final e?)
          _ErrorBanner(
            error: e,
            onRetry: messages.isEmpty ? null : controller.regenerate,
            onSettings: e.kind == ChatErrorKind.noKey || e.kind == ChatErrorKind.noModel || e.kind == ChatErrorKind.unauthorized
                ? () => showSettings(context)
                : null,
            onDismiss: controller.dismissError,
          ),
        if (_attachError case final e?)
          _ErrorBanner(
            error: e,
            // Tries the same fetch again; it never re-asks the last question.
            onRetry: _failedBuild == null ? null : () => _load(_failedBuild!),
            onSettings: null,
            onDismiss: () => setState(() {
              _attachError = null;
              _failedBuild = null;
            }),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loadingAttach)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Loading from Canvas…', style: context.text.meta),
                    ),
                  if (_attached.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AttachChips(items: _attached, onRemove: (i) => setState(() => _attached.remove(i))),
                    ),
                  _InputBar(
                    controller: _input,
                    focus: _inputFocus,
                    onKey: _onKey,
                    streaming: state.streaming,
                    onSend: _send,
                    onStop: controller.stop,
                    onAttach: _attach,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showHistory(BuildContext context) =>
      showEtherDialog<void>(context, (_) => const _HistoryDialog());
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focus,
    required this.onKey,
    required this.streaming,
    required this.onSend,
    required this.onStop,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final bool streaming;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          EIconButton(icon: EIcons.attach, tooltip: 'Attach from Canvas', onTap: onAttach, bordered: false),
          const SizedBox(width: 8),
          Expanded(
            // At least as tall as the send button, with the text centred in it.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Focus(
                  onKeyEvent: onKey,
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 8,
                    style: t.body,
                    cursorColor: c.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: InputBorder.none,
                      hintText: 'Message the assistant. Enter sends, Shift+Enter adds a line.',
                      hintStyle: t.body.copyWith(color: c.textTertiary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          streaming
              ? EIconButton(icon: EIcons.stop, tooltip: 'Stop', onTap: onStop, bordered: false)
              : EIconButton(icon: EIcons.send, tooltip: 'Send', onTap: onSend, selected: true),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.thinking, this.onRegenerate});

  final ChatMessage message;
  final bool thinking;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final mine = message.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: mine
            ? Container(
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(message.text, style: t.body),
                    if (message.attached.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Attached: ${message.attached.join(', ')}', style: t.meta),
                    ],
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thinking)
                    Text('Thinking…', style: t.meta)
                  else
                    ChatMarkdown(message.text),
                  if (!thinking && message.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CopyButton(text: message.text),
                        if (onRegenerate != null)
                          EIconButton(
                            icon: EIcons.refresh,
                            tooltip: 'Answer again',
                            size: 28,
                            iconSize: 14,
                            bordered: false,
                            onTap: onRegenerate,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onDismiss, this.onRetry, this.onSettings});

  final ChatException error;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.danger),
            ),
            child: Row(
              children: [
                Expanded(child: Text(error.message, style: t.body)),
                if (onSettings != null) ...[
                  const SizedBox(width: 8),
                  EButton(label: 'Settings', onTap: onSettings),
                ],
                if (onRetry != null) ...[
                  const SizedBox(width: 8),
                  EButton(label: 'Retry', onTap: onRetry),
                ],
                const SizedBox(width: 4),
                EIconButton(icon: EIcons.close, tooltip: 'Dismiss', size: 28, iconSize: 14, bordered: false, onTap: onDismiss),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryDialog extends ConsumerWidget {
  const _HistoryDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final t = context.text;
    final now = DateTime.now();
    return EDialog(
      title: 'History',
      body: state.conversations.isEmpty
          ? Text('No chats yet.', style: t.meta)
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final conv in state.conversations)
                    ETap(
                      onTap: () {
                        controller.select(conv.id);
                        Navigator.of(context).pop();
                      },
                      builder: (context, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(conv.title, style: t.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(formatAgo(conv.updatedAt, now), style: t.meta),
                                ],
                              ),
                            ),
                            EIconButton(
                              icon: EIcons.trash,
                              tooltip: 'Delete',
                              size: 28,
                              iconSize: 14,
                              bordered: false,
                              onTap: () => controller.delete(conv.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      actions: [EButton(label: 'Close', onTap: () => Navigator.of(context).pop())],
    );
  }
}
