import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show InputBorder, InputDecoration, SelectableText, TextField;

import '../../../core/motion/smooth_scroll.dart';
import '../../../core/utils/date_format.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../auth/domain/auth_provider.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../domain/chat_backend.dart';
import '../domain/chat_models.dart';
import 'ai_providers.dart';
import 'chat_controller.dart';
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

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || ref.read(chatControllerProvider).streaming) return;
    _input.clear();
    ref.read(chatControllerProvider.notifier).send(text);
    _toEnd();
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
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _InputBar(
                controller: _input,
                focus: _inputFocus,
                onKey: _onKey,
                streaming: state.streaming,
                onSend: _send,
                onStop: controller.stop,
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
  });

  final TextEditingController controller;
  final FocusNode focus;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final bool streaming;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
                child: SelectableText(message.text, style: t.body),
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
