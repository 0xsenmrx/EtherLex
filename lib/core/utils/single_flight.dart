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
