import 'dart:io';

import '../../../core/network/canvas_client.dart';
import '../domain/submission.dart';

class CanvasSubmissionRepository implements SubmissionRepository {
  CanvasSubmissionRepository(this._client);
  final CanvasClient _client;

  @override
  Future<SubmissionInfo> info(int courseId, int assignmentId) async =>
      parseSubmissionInfo(
        await _client.fetchAssignmentJson(courseId, assignmentId),
        host: _client.host,
      );

  @override
  Future<MySubmission> mine(int courseId, int assignmentId) async => parseMySubmission(
        await _client.fetchMySubmissionJson(courseId, assignmentId),
        courseId: courseId,
      );

  @override
  Future<void> submit(
    int courseId,
    int assignmentId,
    List<String> paths,
    void Function(double progress) onProgress,
  ) async {
    final sizes = [for (final p in paths) File(p).lengthSync()];
    final total = sizes.fold<int>(0, (a, b) => a + b).clamp(1, 1 << 62);
    var before = 0;
    final ids = <int>[];
    for (var i = 0; i < paths.length; i++) {
      final base = before;
      ids.add(
        await _client.uploadSubmissionFile(
          courseId,
          assignmentId,
          paths[i],
          onProgress: (sent, _) => onProgress(((base + sent) / total).clamp(0.0, 1.0) * 0.95),
        ),
      );
      before += sizes[i];
    }
    await _client.submitUpload(courseId, assignmentId, ids);
    onProgress(1);
  }
}
