/// Runs an action unless the previous one is still running.
///
/// For things a person can trigger twice before the first has shown anything:
/// a second click on a file while its preview is still opening must not open a
/// second preview.
class SingleFlight {
  bool _busy = false;

  /// True while an action started with [run] has not finished.
  bool get busy => _busy;

  /// Runs [action] and returns its result, or returns null at once (without
  /// running it) when an earlier one is still going. Always free again
  /// afterwards, also when [action] throws.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }
}

/// Like [SingleFlight], but one at a time per key: two different files can
/// download together, while a second click on the same file is ignored.
class KeyedSingleFlight<K> {
  final Set<K> _running = {};

  /// True while an action for [key] has not finished.
  bool isBusy(K key) => _running.contains(key);

  /// Runs [action] for [key], or returns null at once when one for the same
  /// key is still going. Free again afterwards, also when [action] throws.
  Future<T?> run<T>(K key, Future<T> Function() action) async {
    if (!_running.add(key)) return null;
    try {
      return await action();
    } finally {
      _running.remove(key);
    }
  }
}
