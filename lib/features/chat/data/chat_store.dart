import 'dart:io';

import '../../../core/storage/account_scope.dart';
import '../../../core/storage/app_dir.dart';
import '../../../core/storage/json_file.dart';
import '../domain/chat_models.dart';

/// The most conversations kept per account; older ones are dropped.
const int kMaxConversations = 100;

/// Saved conversations of one account: `%APPDATA%/EtherLex/chats/<scope>.json`.
class ChatStore {
  ChatStore(File file) : _json = JsonFile(file);

  factory ChatStore.forScope(String scope, {String? root}) {
    final clean = cleanScope(scope);
    final sep = Platform.pathSeparator;
    return ChatStore(File('${root ?? appDataPath()}${sep}chats$sep${clean.isEmpty ? 'account' : clean}.json'));
  }

  final JsonFile _json;

  /// Newest first. A missing or damaged file gives an empty list.
  Future<List<ChatConversation>> read() async {
    try {
      final json = await _json.read();
      final raw = json is Map ? json['conversations'] : null;
      final all = [
        if (raw is List)
          for (final c in raw) ?ChatConversation.fromJson(c),
      ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return all;
    } catch (_) {
      return const [];
    }
  }

  /// Saves [all] (at most [kMaxConversations], newest kept). Writes run one
  /// after another, so a quick second save cannot be overtaken by the first.
  Future<void> write(List<ChatConversation> all) {
    final newest = [...all]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _json.write({
      'conversations': [for (final c in newest.take(kMaxConversations)) c.toJson()],
    });
  }
}
