import '../../courses/domain/course.dart';
import '../domain/assignment.dart';
import '../domain/assignments_repository.dart';
import 'custom_task_list.dart';

/// Canvas (or sample) assignments plus the tasks you added yourself, as one
/// list. Everything that reads or changes assignments (the list, the calendar,
/// search, alerts, the assistant's "mark done") goes through this, so your own
/// tasks work everywhere without each place knowing about them. Done and star
/// of a task (a negative id) are kept in the task list, not in Canvas data.
class WithCustomTasksRepository implements AssignmentsRepository {
  WithCustomTasksRepository(this._inner, this._tasks);

  final AssignmentsRepository _inner;
  final CustomTaskList _tasks;

  @override
  Stream<List<Course>> watchCourses() => _inner.watchCourses();

  @override
  Stream<List<Assignment>> watch() => Stream<List<Assignment>>.multi((controller) {
        List<Assignment>? canvas;
        var mine = [for (final t in _tasks.tasks) t.toAssignment()];
        void push() {
          final list = canvas;
          if (list != null) controller.add([...list, ...mine]);
        }

        final a = _inner.watch().listen(
          (list) {
            canvas = list;
            push();
          },
          onError: controller.addError,
        );
        final b = _tasks.watch().listen((list) {
          mine = [for (final t in list) t.toAssignment()];
          push();
        });
        controller.onCancel = () async {
          await a.cancel();
          await b.cancel();
        };
      });

  @override
  Future<void> refresh() => _inner.refresh();

  @override
  Future<DateTime?> lastSyncedAt() => _inner.lastSyncedAt();

  @override
  Future<void> setStarred(int id, bool value) => id < 0 ? _tasks.setStarred(id, value) : _inner.setStarred(id, value);

  @override
  Future<void> setDone(int id, bool value) => id < 0 ? _tasks.setDone(id, value) : _inner.setDone(id, value);

  @override
  void dispose() => _inner.dispose();
}
