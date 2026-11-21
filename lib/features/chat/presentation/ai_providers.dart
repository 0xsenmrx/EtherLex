import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_provider.dart';
import '../data/ai_key_store.dart';
import '../data/ai_settings_store.dart';
import '../data/anthropic_backend.dart';
import '../data/openai_backend.dart';
import '../data/sample_chat_backend.dart';
import '../domain/ai_settings.dart';
import '../domain/chat_backend.dart';

/// Whose AI settings and keys these are: the signed-in account, so two people
/// on one computer never share a key. Null while the account's id is not known
/// (the old shared names are used then); 'sample' for sample mode and signed out.
final aiScopeProvider = Provider<({String? scope, bool adoptLegacy})>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  if (session == null || session.isSample) return (scope: 'sample', adoptLegacy: false);
  return (scope: session.userId == null ? null : session.scope, adoptLegacy: true);
});

final aiSettingsStoreProvider = Provider<AiSettingsStore>((ref) {
  final s = ref.watch(aiScopeProvider);
  return AiSettingsStore.forScope(s.scope, adoptLegacy: s.adoptLegacy);
});

final aiKeyStoreProvider = Provider<AiKeyStore>((ref) {
  final s = ref.watch(aiScopeProvider);
  return SecureAiKeyStore(scope: s.scope, adoptLegacy: s.adoptLegacy);
});

/// Which service and model the assistant uses (the keys are separate).
class AiSettingsNotifier extends Notifier<AiSettings> {
  @override
  AiSettings build() {
    // A new account gives a new store: start over and load that account's.
    _load(ref.watch(aiSettingsStoreProvider));
    return const AiSettings();
  }

  Future<void> _load(AiSettingsStore store) async {
    final saved = await store.read();
    if (ref.mounted && identical(store, ref.read(aiSettingsStoreProvider)) && state == const AiSettings()) {
      state = saved;
    }
  }

  void setProvider(AiProvider p) => _set(state.copyWith(provider: p));

  void setModel(AiProvider p, String model) => _set(state.withModel(p, model));

  void setOpenAiBaseUrl(String url) => _set(state.copyWith(openAiBaseUrl: url.trim()));

  void _set(AiSettings next) {
    if (next == state) return;
    state = next;
    ref.read(aiSettingsStoreProvider).write(next).catchError((Object _) {});
  }
}

final aiSettingsProvider = NotifierProvider<AiSettingsNotifier, AiSettings>(AiSettingsNotifier.new);

/// For which services a key is saved. The keys themselves are never held here.
class AiKeysNotifier extends Notifier<Set<AiProvider>> {
  @override
  Set<AiProvider> build() {
    _load(ref.watch(aiKeyStoreProvider));
    return const {};
  }

  Future<void> _load(AiKeyStore store) async {
    final found = <AiProvider>{};
    for (final p in AiProvider.values) {
      try {
        if (await store.read(p) != null) found.add(p);
      } catch (_) {}
    }
    if (ref.mounted && identical(store, ref.read(aiKeyStoreProvider))) state = {...state, ...found};
  }

  Future<void> save(AiProvider p, String key) async {
    if (key.trim().isEmpty) return;
    await ref.read(aiKeyStoreProvider).save(p, key);
    state = {...state, p};
  }

  Future<void> clear(AiProvider p) async {
    await ref.read(aiKeyStoreProvider).clear(p);
    state = {...state}..remove(p);
  }
}

final aiKeysProvider = NotifierProvider<AiKeysNotifier, Set<AiProvider>>(AiKeysNotifier.new);

/// Makes the service for the next question: the sample assistant in sample
/// mode, else the chosen provider with its saved key (read only now, so the
/// key is not kept anywhere longer than the request needs it).
final chatBackendProvider = Provider<Future<ChatBackend> Function()>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  final sample = session == null || session.isSample;
  return () async {
    if (sample) return const SampleChatBackend();
    final settings = ref.read(aiSettingsProvider);
    final key = await ref.read(aiKeyStoreProvider).read(settings.provider) ?? '';
    return switch (settings.provider) {
      AiProvider.anthropic => AnthropicBackend(apiKey: key, model: settings.model),
      AiProvider.openai => OpenAiBackend(apiKey: key, model: settings.model, baseUrl: settings.openAiBaseUrl),
      AiProvider.deepseek => OpenAiBackend(apiKey: key, model: settings.model, baseUrl: kDeepSeekBaseUrl),
    };
  };
});
