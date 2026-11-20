import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/app_text_field.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/list.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../domain/ai_settings.dart';
import 'ai_providers.dart';

/// Settings for the assistant: which service, your own API key, the model.
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
  void dispose() {
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
    _url.text = s.openAiBaseUrl;
  }

  void _save() {
    final settings = ref.read(aiSettingsProvider.notifier);
    final provider = ref.read(aiSettingsProvider).provider;
    settings.setModel(provider, _model.text);
    if (provider == AiProvider.openai) settings.setOpenAiBaseUrl(_url.text);
    if (_key.text.trim().isNotEmpty) {
      ref.read(aiKeysProvider.notifier).save(provider, _key.text.trim());
      _key.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final settings = ref.watch(aiSettingsProvider);
    final hasKey = ref.watch(aiKeysProvider).contains(settings.provider);
    _sync(settings);
    final provider = settings.provider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ESectionLabel('AI assistant', trailing: 'Your own API key, kept on this computer'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ESegmented(
              labels: [for (final p in AiProvider.values) p.label],
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
          AppTextField(controller: _url, label: 'Base URL', hint: kOpenAiBaseUrl, onSubmitted: _save),
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
          'Your messages go to the service you chose, nothing else. Nothing from Canvas is sent yet.',
          style: t.metaMuted,
        ),
      ],
    );
  }
}
