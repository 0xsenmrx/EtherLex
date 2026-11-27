import 'dart:async';

import '../../../core/storage/settings_store.dart';
import '../domain/custom_task.dart';

/// The tasks you added yourself, kept in the account's settings file.
///
/// Loads once; every change is shown at once and saved after. Nothing changes
/// before the file has been read, so a slow read can never be overwritten by
/// a task added in the meantime.
class CustomTaskList {
  CustomTaskList(this._store) {
    _ready = _load();
  }

  final SettingsStore _store;
  late final Future<void> _ready;
  List<CustomTask> _tasks = const [];
  bool _closed = false;
  final StreamController<List<CustomTask>> _changes = StreamController<List<CustomTask>>.broadcast();

  List<CustomTask> get tasks => _tasks;

  /// The current list, then every change.
  Stream<List<CustomTask>> watch() => Stream<List<CustomTask>>.multi((controller) {
        controller.add(_tasks);
        final sub = _changes.stream.listen(controller.add);
        controller.onCancel = sub.cancel;
      });

  Future<void> _load() async {
    try {
      final tasks = parseCustomTasks(await _store.readCustomTasks());
      if (_closed) return;
      _tasks = List<CustomTask>.unmodifiable(tasks);
      _changes.add(_tasks);
    } catch (_) {}
  }

  Future<void> _set(List<CustomTask> next) async {
    if (_closed) return;
    _tasks = List<CustomTask>.unmodifiable(next);
    _changes.add(_tasks);
    try {
      await _store.writeCustomTasks([for (final t in _tasks) t.toJson()]);
    } catch (_) {}
  }

  /// Adds a task and returns it (with its new id).
  Future<CustomTask> create({
    required String title,
    int courseId = kPersonalCourseId,
    DateTime? dueAt,
    String notes = '',
  }) async {
    await _ready;
    final task = CustomTask(
      id: nextCustomTaskId(_tasks.map((t) => t.id)),
      title: title.trim(),
      courseId: courseId,
      dueAt: dueAt,
      notes: notes,
    );
    await _set([..._tasks, task]);
    return task;
  }

  Future<void> update(CustomTask task) async {
    await _ready;
    await _set([for (final t in _tasks) t.id == task.id ? task : t]);
  }

  Future<void> remove(int id) async {
    await _ready;
    await _set([for (final t in _tasks) if (t.id != id) t]);
  }

  Future<void> setDone(int id, bool value) => _change(id, (t) => t.copyWith(done: value));

  Future<void> setStarred(int id, bool value) => _change(id, (t) => t.copyWith(starred: value));

  Future<void> _change(int id, CustomTask Function(CustomTask) f) async {
    await _ready;
    await _set([for (final t in _tasks) t.id == id ? f(t) : t]);
  }

  void dispose() {
    _closed = true;
    _changes.close();
  }
}
