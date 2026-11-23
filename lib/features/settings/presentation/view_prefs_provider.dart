import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';
import '../domain/view_prefs.dart';
import 'settings_store_provider.dart';

/// How each page was left, for the signed-in account (see [ViewPrefs]).
/// Pages read it while building and change it through [update].
class ViewPrefsNotifier extends Notifier<ViewPrefs> {
  Completer<void> _ready = Completer<void>();

  /// Done once the account's saved choices have been read from disk. Read
  /// the provider after it for the current choices (they may have changed
  /// since loading).
  Future<void> get ready => _ready.future;

  /// A change made before the saved choices arrived wins over them.
  bool _changed = false;

  @override
  ViewPrefs build() {
    _changed = false;
    _ready = Completer<void>();
    _load(ref.watch(settingsStoreProvider));
    return const ViewPrefs();
  }

  Future<void> _load(SettingsStore store) async {
    var saved = const ViewPrefs();
    try {
      saved = ViewPrefs.fromJson(await store.readViewPrefs());
    } catch (_) {}
    if (!ref.mounted || !identical(store, ref.read(settingsStoreProvider))) return;
    if (!_changed) state = saved;
    if (!_ready.isCompleted) _ready.complete();
  }

  void update(ViewPrefs Function(ViewPrefs p) change) {
    final next = change(state);
    if (next == state) return;
    _changed = true;
    state = next;
    ref.read(settingsStoreProvider).writeViewPrefs(next.toJson()).catchError((Object _) {});
  }
}

final viewPrefsProvider = NotifierProvider<ViewPrefsNotifier, ViewPrefs>(ViewPrefsNotifier.new);
