import 'dart:convert';
import 'dart:io';

import 'app_dir.dart';

/// One JSON file on disk that several quick saves can share safely.
///
/// Writes to the same path run one after another (even from different
/// [JsonFile] objects), so a quick second save is never overtaken by the
/// first, and each write replaces the file in one step, so a crash leaves the
/// old file or the new one, never half of one. Reads never throw: a missing or
/// damaged file reads as null.
class JsonFile {
  JsonFile(this.file);

  final File file;

  static final Map<String, Future<void>> _queues = {};

  /// The decoded content, or null when the file is missing or not JSON.
  /// Waits for writes to the same path that were queued before it, so it
  /// sees them, and never opens the file while it is being replaced
  /// (Windows can refuse that rename while the file is open).
  Future<Object?> read() async {
    final pending = _queues[file.path];
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // A failed write leaves the old file; read that.
      }
    }
    return _readNow();
  }

  Future<Object?> _readNow() async {
    try {
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// The content as a JSON object; empty when missing, damaged or not an object.
  Future<Map<String, dynamic>> readMap() async => _asMap(await read());

  static Map<String, dynamic> _asMap(Object? v) => v is Map<String, dynamic> ? v : <String, dynamic>{};

  /// Replaces the file with [json] (encoded now, written after earlier writes).
  Future<void> write(Object? json) {
    final text = jsonEncode(json);
    return _enqueue(() => writeFileAtomically(file, text));
  }

  /// Reads the object, lets [change] edit it, and writes it back, queued like
  /// [write] so two updates cannot each drop the other's change.
  Future<void> update(void Function(Map<String, dynamic> map) change) => _enqueue(() async {
        // Already in the queue: read directly (waiting would wait for itself).
        final map = _asMap(await _readNow());
        change(map);
        await writeFileAtomically(file, jsonEncode(map));
      });

  Future<void> _enqueue(Future<void> Function() job) {
    final key = file.path;
    final next = (_queues[key] ?? Future<void>.value()).catchError((Object _) {}).then((_) => job());
    _queues[key] = next;
    return next;
  }
}
