import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notify/toast.dart';
import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../data/openai_backend.dart' show isAllowedAiBaseUrl;
import '../domain/ai_settings.dart';
import 'ai_consent.dart';
import 'ai_providers.dart';

/// Settings > Assistant: which service, your own API key, the model.
class AiSettingsSection extends ConsumerStatefulWidget {
  const AiSettingsSection({super.key});

  @override
  ConsumerState<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<AiSettingsSection> {
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _url = TextEditingController();
  AiProvider? _shown;

  @override
  void initState() {
    super.initState();
    _url.addListener(_onUrl);
  }

  String _lastUrl = '';
  void _onUrl() {
    if (_url.text == _lastUrl) return; // caret moves notify too
    _lastUrl = _url.text;
    setState(() {});
  }

  /// The address as it will be saved: no trailing slash, the default when empty.
  String get _typedUrl {
    final u = _url.text.trim().replaceAll(RegExp(r'/+$'), '');
    return u.isEmpty ? kOpenAiBaseUrl : u;
  }

  String? get _urlError => isAllowedAiBaseUrl(_typedUrl)
      ? null
      : 'Use an https:// address (http:// only for a model on this computer, like http://localhost:11434/v1).';

  @override
  void dispose() {
    _url.removeListener(_onUrl);
    _key.dispose();
    _model.dispose();
    _url.dispose();
    super.dispose();
  }

  /// Fill the fields when the provider on screen changes.
  void _sync(AiSettings s) {
    if (_shown == s.provider) return;
    _shown = s.provider;
    _key.clear();
    _model.text = s.modelFor(s.provider);
    _lastUrl = s.openAiBaseUrl; // filled during build: the listener must not setState
    _url.text = s.openAiBaseUrl;
  }

  Future<void> _save() async {
    final settings = ref.read(aiSettingsProvider.notifier);
    final current = ref.read(aiSettingsProvider);
    final provider = current.provider;
    final newKey = _key.text.trim();
    if (provider == AiProvider.openai) {
      final url = _typedUrl;
      if (_urlError != null) return; // the field already says why
      if (url != current.openAiBaseUrl) {
        final oldHost = aiHostOf(current.openAiBaseUrl);
        final newHost = aiHostOf(url) ?? url;
        // A key saved for one server must not quietly start going to another.
        if (newHost != oldHost && newKey.isEmpty && ref.read(aiKeysProvider).contains(provider)) {
          final ok = await confirmAction(
            context,
            title: 'Send your API key to $newHost?',
            message: 'Your saved key for the OpenAI-compatible service will be sent to $newHost with every '
                'question. Canvas data needs your permission again for this server. '
                'If this is not your own server, choose Cancel and remove the key first.',
            confirmLabel: 'Use $newHost',
          );
          if (!mounted) return;
          if (!ok) {
            _url.text = current.openAiBaseUrl;
            return;
          }
        }
        if (newHost != oldHost) ref.read(aiConsentProvider.notifier).forgetLegacyOpenAi();
        settings.setOpenAiBaseUrl(url);
      }
    }
    settings.setModel(provider, _model.text);
    if (newKey.isNotEmpty) {
      await ref.read(aiKeysProvider.notifier).save(provider, newKey);
      _key.clear();
    }
    if (!mounted) return;
    ref.read(toastProvider.notifier).show(
          newKey.isNotEmpty
              ? 'Saved. Your ${provider.label} key is in the Windows credential store.'
              : 'Saved ${provider.label} settings',
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final settings = ref.watch(aiSettingsProvider);
    final hasKey = ref.watch(aiKeysProvider).contains(settings.provider);
    final allowed = consentAllows(ref.watch(aiConsentProvider), settings);
    _sync(settings);
    final provider = settings.provider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: ESegmented(
              labels: [for (final p in AiProvider.values) p.shortLabel],
              selected: provider.index,
              onChanged: (i) => ref.read(aiSettingsProvider.notifier).setProvider(AiProvider.values[i]),
            ),
          ),
        ),
        AppTextField(
          controller: _key,
          label: hasKey ? 'API key (saved, type to replace)' : 'API key',
          hint: hasKey ? '••••••••' : 'Paste your key',
          obscure: true,
          onSubmitted: _save,
        ),
        const SizedBox(height: 10),
        AppTextField(
          controller: _model,
          label: 'Model',
          hint: provider.defaultModel.isEmpty ? 'Type a model name' : provider.defaultModel,
          onSubmitted: _save,
        ),
        if (provider == AiProvider.openai) ...[
          const SizedBox(height: 10),
          AppTextField(
            controller: _url,
            label: 'Server address',
            hint: kOpenAiBaseUrl,
            onSubmitted: _save,
            error: _urlError,
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            EButton(label: 'Save', kind: EButtonKind.primary, onTap: _save),
            const SizedBox(width: 8),
            if (hasKey)
              EButton(
                label: 'Remove key',
                kind: EButtonKind.ghost,
                onTap: () => ref.read(aiKeysProvider.notifier).clear(provider),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Your messages go to the service you chose, nothing else. Data from Canvas is sent only when you attach it to a question, apart from the names of your courses.',
          style: t.metaMuted,
        ),
        if (allowed) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('You allowed sending attached Canvas data to ${aiServiceName(settings)}.', style: t.meta)),
              const SizedBox(width: 8),
              EButton(
                label: 'Take permission back',
                kind: EButtonKind.ghost,
                onTap: () => ref.read(aiConsentProvider.notifier).revoke(settings),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
