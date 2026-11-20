const String kOpenAiBaseUrl = 'https://api.openai.com/v1';

enum AiProvider {
  anthropic('Anthropic (Claude)', 'claude-sonnet-5-5'),
  openai('OpenAI-compatible', '');

  const AiProvider(this.label, this.defaultModel);

  final String label;

  /// Empty when there is no sensible default: the user types a model name.
  final String defaultModel;
}

/// Which AI service the assistant uses. The API keys are not here: they live
/// in the OS credential store (see AiKeyStore).
class AiSettings {
  const AiSettings({
    this.provider = AiProvider.anthropic,
    this.models = const {},
    this.openAiBaseUrl = kOpenAiBaseUrl,
  });

  final AiProvider provider;

  /// The model typed for each provider; a provider missing here uses its default.
  final Map<AiProvider, String> models;
  final String openAiBaseUrl;

  String modelFor(AiProvider p) => models[p] ?? p.defaultModel;

  String get model => modelFor(provider);

  AiSettings copyWith({AiProvider? provider, String? openAiBaseUrl}) => AiSettings(
        provider: provider ?? this.provider,
        models: models,
        openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
      );

  AiSettings withModel(AiProvider p, String model) =>
      AiSettings(provider: provider, models: {...models, p: model.trim()}, openAiBaseUrl: openAiBaseUrl);

  Map<String, Object> toJson() => {
        'provider': provider.name,
        'models': {for (final e in models.entries) e.key.name: e.value},
        'openAiBaseUrl': openAiBaseUrl,
      };

  static AiSettings fromJson(Object? json) {
    if (json is! Map) return const AiSettings();
    final provider = AiProvider.values.where((p) => p.name == json['provider']).firstOrNull ?? AiProvider.anthropic;
    final rawModels = json['models'];
    final models = <AiProvider, String>{};
    if (rawModels is Map) {
      for (final p in AiProvider.values) {
        final v = rawModels[p.name];
        if (v is String) models[p] = v;
      }
    }
    final url = json['openAiBaseUrl'];
    return AiSettings(
      provider: provider,
      models: models,
      openAiBaseUrl: url is String && url.trim().isNotEmpty ? url.trim() : kOpenAiBaseUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AiSettings &&
      other.provider == provider &&
      other.openAiBaseUrl == openAiBaseUrl &&
      other.models.length == models.length &&
      models.entries.every((e) => other.models[e.key] == e.value);

  @override
  int get hashCode => Object.hash(provider, openAiBaseUrl, Object.hashAllUnordered(models.entries.map((e) => (e.key, e.value))));
}
