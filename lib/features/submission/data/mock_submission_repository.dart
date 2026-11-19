import '../../files/domain/files_models.dart';
import '../domain/submission.dart';

/// Sample mode: nothing leaves the computer. Behaves differently per
/// assignment so every state can be tried:
/// id % 7 == 0 -> closed, id % 3 == 0 -> PDF only, otherwise anything.
class MockSubmissionRepository implements SubmissionRepository {
  @override
  Future<SubmissionInfo> info(int courseId, int assignmentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (assignmentId % 7 == 0) {
      return const SubmissionInfo(
        acceptsUpload: true,
        locked: true,
        lockReason: 'This assignment was locked.',
      );
    }
    return SubmissionInfo(
      acceptsUpload: true,
      allowedExtensions: assignmentId % 3 == 0 ? const ['pdf'] : const [],
      description: 'Complete the attached problem set and upload your solutions as a single file. '
          'Show your reasoning; partial credit is given.',
      attachments: [
        if (assignmentId % 2 == 0) const AttachmentRef(9001, 'Problem Set.pdf'),
        if (assignmentId % 2 == 0) const AttachmentRef(9002, 'Instructions.md'),
        if (assignmentId % 5 == 0) const AttachmentRef(9003, 'Data.csv'),
      ],
    );
  }

  @override
  Future<MySubmission> mine(int courseId, int assignmentId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (assignmentId % 2 != 0 || assignmentId % 7 == 0) return MySubmission.empty;
    FileEntry file(int id, String name) => FileEntry(
          id: id,
          folderId: 0,
          name: name,
          size: 31000,
          mime: '',
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
          url: null,
          courseId: courseId,
        );
    return MySubmission(
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
      grade: '92',
      score: 92,
      files: [file(9101, 'My Solution.pdf')],
      feedback: [
        FeedbackComment(
          author: 'Prof. Example',
          text: 'Good work. See the marked-up copy for details.',
          at: DateTime.now().subtract(const Duration(days: 1)),
          files: [file(9102, 'Marked Solution.pdf')],
        ),
      ],
    );
  }

  @override
  Future<void> submit(
    int courseId,
    int assignmentId,
    List<String> paths,
    void Function(double progress) onProgress,
  ) async {
    for (var i = 1; i <= 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 130));
      onProgress(i / 10);
    }
  }
}
