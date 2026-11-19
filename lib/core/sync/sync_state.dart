class SyncState {
  const SyncState({this.loading = false, this.error, this.lastUpdated});
  final bool loading;
  final String? error;
  final DateTime? lastUpdated;
}
