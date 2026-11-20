import 'package:etherlex/core/sync/sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a normal state has not failed on the token', () {
    expect(const SyncState().authFailed, isFalse);
    expect(const SyncState(error: 'Canvas is rate limiting requests.').authFailed, isFalse);
  });

  test('anyAuthFailed is true when one screen was turned down by Canvas', () {
    const ok = SyncState();
    const network = SyncState(error: 'No connection');
    const rejected = SyncState(error: 'Canvas rejected this token.', authFailed: true);
    expect(anyAuthFailed([ok, network]), isFalse);
    expect(anyAuthFailed([ok, rejected, network]), isTrue);
    expect(anyAuthFailed(const []), isFalse);
  });
}
