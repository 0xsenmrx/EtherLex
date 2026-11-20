import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_state.dart';
import '../../design_system/ether/controls.dart';
import '../../design_system/theme/ether_theme.dart';
import '../../features/activity/presentation/activity_providers.dart';
import '../../features/assignments/presentation/assignments_providers.dart';
import '../../features/auth/domain/auth_provider.dart';
import '../../features/grades/presentation/grades_providers.dart';

/// Canvas turned the token down on the last refresh of any screen. Cleared by
/// the next refresh that works (or by signing in again).
final tokenRejectedProvider = Provider<bool>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  if (session == null || session.isSample) return false;
  return anyAuthFailed([
    ref.watch(syncProvider),
    ref.watch(activitySyncProvider),
    ref.watch(gradesSyncProvider),
  ]);
});

/// A bar under the title bar with the way out: sign in again.
class TokenBanner extends ConsumerWidget {
  const TokenBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.danger),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Canvas rejected your token. It may have been revoked or have expired. '
              'Sign in again with a new one; your settings stay.',
              style: t.body,
            ),
          ),
          const SizedBox(width: 12),
          EButton(
            label: 'Sign in again',
            kind: EButtonKind.primary,
            onTap: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}
