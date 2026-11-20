class SyncState {
  const SyncState({this.loading = false, this.error, this.authFailed = false, this.lastUpdated});
  final bool loading;
  final String? error;

  /// Canvas turned the token down (revoked, expired or mistyped), as opposed to
  /// a network or server problem. Signing in again is the only way out.
  final bool authFailed;
  final DateTime? lastUpdated;
}

/// True when any of [states] failed because Canvas rejected the token.
bool anyAuthFailed(Iterable<SyncState> states) => states.any((s) => s.authFailed);
