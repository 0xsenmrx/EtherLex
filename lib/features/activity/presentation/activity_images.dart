import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/theme/ether_theme.dart';
import '../../files/presentation/files_providers.dart';

/// "url:https://..." is used as is; "file:123" is a Canvas file whose
/// download link (it carries its own access key) is looked up once.
final activityImageUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, token) async {
  if (token.startsWith('url:')) return token.substring(4);
  final id = int.tryParse(token.replaceFirst('file:', ''));
  if (id == null) return null;
  final link = ref.keepAlive();
  try {
    return (await ref.watch(filesRepositoryProvider).fileInfo(0, id))?.url;
  } catch (_) {
    link.close();
    return null;
  }
});

/// The pictures that were inside an announcement's text.
class ActivityImages extends ConsumerWidget {
  const ActivityImages({super.key, required this.tokens});
  final List<String> tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in tokens) _Picture(url: ref.watch(activityImageUrlProvider(t)).value),
      ],
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Image.network(
            u,
            fit: BoxFit.contain,
            cacheWidth: 1400,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : SizedBox(height: 120, child: ColoredBox(color: context.colors.selected)),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
