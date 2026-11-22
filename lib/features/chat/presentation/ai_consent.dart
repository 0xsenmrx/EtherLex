import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../settings/presentation/settings_store_provider.dart';
import '../domain/ai_settings.dart';

/// The AI services (and, for the OpenAI-compatible one, the servers) this
/// account has agreed to send Canvas data to, as [consentKeyFor] keys. Nothing
/// from Canvas goes to a service until the student has said yes to it once;
/// the answer belongs to the account, so another account on this computer is
/// asked again.
class AiConsentNotifier extends Notifier<Set<String>> {
  /// The student answered before the saved answers were read: their answer wins.
  bool _changed = false;

  @override
  Set<String> build() {
    _changed = false;
    _load(ref.watch(settingsStoreProvider));
    return const {};
  }

  Future<void> _load(SettingsStore store) async {
    try {
      final keys = await store.readAiConsent();
      if (ref.mounted && !_changed && identical(store, ref.read(settingsStoreProvider))) {
        state = {...keys};
      }
    } catch (_) {}
  }

  void _save() {
    ref.read(settingsStoreProvider).writeAiConsent(state).catchError((Object _) {});
  }

  bool allows(AiSettings s) => consentAllows(state, s);

  /// Yes for the service and server in [s]. An old server-less "openai" yes
  /// is replaced by this one.
  void grant(AiSettings s) {
    _changed = true;
    state = {...state, consentKeyFor(s)}..remove(kLegacyOpenAiConsent);
    _save();
  }

  /// Takes the yes for [s] back (and an old server-less one for the same service).
  void revoke(AiSettings s) {
    _changed = true;
    state = {...state}
      ..remove(consentKeyFor(s))
      ..removeWhere((k) => s.provider == AiProvider.openai && k == kLegacyOpenAiConsent);
    _save();
  }

  /// The OpenAI-compatible address is changing: an old server-less yes must
  /// not follow it to the new server.
  void forgetLegacyOpenAi() {
    if (!state.contains(kLegacyOpenAiConsent)) return;
    _changed = true;
    state = {...state}..remove(kLegacyOpenAiConsent);
    _save();
  }
}

final aiConsentProvider = NotifierProvider<AiConsentNotifier, Set<String>>(AiConsentNotifier.new);
