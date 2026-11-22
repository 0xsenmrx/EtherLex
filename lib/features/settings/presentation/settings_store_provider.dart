import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../../auth/domain/auth_provider.dart';

/// Settings of the signed-in account (stars live in that account's database).
/// Switching accounts gives a new store, so everything that watches it reloads.
final settingsStoreProvider = Provider<SettingsStore>((ref) {
  final s = ref.watch(authProvider.select((a) => a.value));
  final scope = s == null
      ? 'signed_out'
      : s.isSample
          ? 'sample'
          : s.scope;
  return FileSettingsStore.forScope(scope);
});
