import 'dart:convert';
import 'dart:io';

import '../../../core/storage/app_dir.dart';
import '../domain/chat_models.dart';

/// The most conversations kept per account; older ones are dropped.
const int kMaxConversations = 100;

/// Saved conversations of one account: `%APPDATA%/EtherLex/chats/<scope>.json`.
class ChatStore {
  ChatStore(this._file);

  factory ChatStore.forScope(String scope, {String? root}) {
    final clean = scope.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final sep = Platform.pathSeparator;
    return ChatStore(File('${root ?? appDataPath()}${sep}chats$sep${clean.isEmpty ? 'account' : clean}.json'));
  }

  final File _file;

  /// Newest first. A missing or damaged file gives an empty list.
  Future<List<ChatConversation>> read() async {
    try {
      if (!await _file.exists()) return const [];
      final json = jsonDecode(await _file.readAsString());
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

  Future<void>? _pending;

  /// Saves [all] (at most [kMaxConversations], newest kept). Writes run one
  /// after another, so a quick second save cannot be overtaken by the first.
  Future<void> write(List<ChatConversation> all) {
    final newest = [...all]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final text = jsonEncode({
      'conversations': [for (final c in newest.take(kMaxConversations)) c.toJson()],
    });
    final next = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => writeFileAtomically(_file, text));
    _pending = next;
    return next;
  }
}
