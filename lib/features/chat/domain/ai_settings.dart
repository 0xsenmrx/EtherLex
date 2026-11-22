const String kOpenAiBaseUrl = 'https://api.openai.com/v1';
const String kDeepSeekBaseUrl = 'https://api.deepseek.com';

enum AiProvider {
  anthropic('Anthropic (Claude)', 'claude-sonnet-5-5'),
  openai('OpenAI-compatible', ''),
  deepseek('DeepSeek', 'deepseek-chat', readsImages: false);

  const AiProvider(this.label, this.defaultModel, {this.readsImages = true});

  final String label;

  /// False when the service has no way to take a picture, so EtherLex says so
  /// instead of sending it. (For "OpenAI-compatible" it depends on the model
  /// typed in Settings; the service answers with an error if it cannot.)
  final bool readsImages;

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

/// The server part of an address ("api.example.com", or "localhost:11434"
/// when a port is written), lower case; null when it is not an address.
String? aiHostOf(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || u.host.isEmpty) return null;
  final host = u.host.toLowerCase();
  return u.hasPort ? '$host:${u.port}' : host;
}

/// What the student's "yes, send Canvas data" is tied to. For the
/// OpenAI-compatible service it is the service and its server, so pointing
/// EtherLex at another server asks again.
String consentKeyFor(AiSettings s) => switch (s.provider) {
      AiProvider.openai => 'openai@${aiHostOf(s.openAiBaseUrl) ?? '?'}',
      final p => p.name,
    };

/// Consent saved by 0.3 previews: "openai" without a server. It still counts
/// until it is bound to the current server ([consentAllows] and the notifier).
const String kLegacyOpenAiConsent = 'openai';

/// True when [keys] hold a yes for the service and server in [s].
bool consentAllows(Set<String> keys, AiSettings s) =>
    keys.contains(consentKeyFor(s)) || (s.provider == AiProvider.openai && keys.contains(kLegacyOpenAiConsent));

/// How the service is named to the student: with its server for the
/// OpenAI-compatible one ("OpenAI-compatible (api.example.com)").
String aiServiceName(AiSettings s) =>
    s.provider == AiProvider.openai ? '${s.provider.label} (${aiHostOf(s.openAiBaseUrl) ?? 'no address'})' : s.provider.label;
