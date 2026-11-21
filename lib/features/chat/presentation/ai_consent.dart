import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../assignments/presentation/assignments_providers.dart' show settingsStoreProvider;
import '../domain/ai_settings.dart';

/// The AI services this account has agreed to send Canvas data to. Nothing
/// from Canvas goes to a service until the student has said yes to it once;
/// the answer belongs to the account, so another account on this computer is
/// asked again.
class AiConsentNotifier extends Notifier<Set<AiProvider>> {
  /// The student answered before the saved answers were read: their answer wins.
  bool _changed = false;

  @override
  Set<AiProvider> build() {
    _changed = false;
    _load(ref.watch(settingsStoreProvider));
    return const {};
  }

  Future<void> _load(SettingsStore store) async {
    try {
      final names = await store.readAiConsent();
      if (ref.mounted && !_changed && identical(store, ref.read(settingsStoreProvider))) {
        state = {for (final p in AiProvider.values) if (names.contains(p.name)) p};
      }
    } catch (_) {}
  }

  void _save() {
    ref.read(settingsStoreProvider).writeAiConsent({for (final p in state) p.name}).catchError((Object _) {});
  }

  void grant(AiProvider p) {
    _changed = true;
    state = {...state, p};
    _save();
  }

  void revoke(AiProvider p) {
    _changed = true;
    state = {...state}..remove(p);
    _save();
  }
}

final aiConsentProvider = NotifierProvider<AiConsentNotifier, Set<AiProvider>>(AiConsentNotifier.new);
