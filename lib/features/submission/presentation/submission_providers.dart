import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_provider.dart';
import '../../files/domain/files_models.dart';
import '../../files/presentation/files_providers.dart';
import '../data/canvas_submission_repository.dart';
import '../data/mock_submission_repository.dart';
import '../domain/submission.dart';

final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) {
  final session = ref.watch(authProvider.select((a) => a.value));
  if (session == null || session.isSample) return MockSubmissionRepository();
  return CanvasSubmissionRepository(
    ref.read(canvasClientFactoryProvider)(session.baseUrl, session.token),
  );
});

typedef AssignmentRef = ({int courseId, int assignmentId});

final submissionInfoProvider =
    FutureProvider.autoDispose.family<SubmissionInfo, AssignmentRef>((ref, key) async {
  // Kept so reopening (or a hover prefetch) makes the dialog instant.
  final link = ref.keepAlive();
  try {
    return await ref.watch(submissionRepositoryProvider).info(key.courseId, key.assignmentId);
  } catch (_) {
    link.close();
    rethrow;
  }
});

/// The files linked from an assignment, with sizes and links resolved.
final attachmentsProvider =
    FutureProvider.autoDispose.family<List<FileEntry>, AssignmentRef>((ref, key) async {
  final info = await ref.watch(submissionInfoProvider(key).future);
  final repo = ref.watch(filesRepositoryProvider);
  final resolved = await Future.wait([
    for (final a in info.attachments)
      () async {
        try {
          return await repo.fileInfo(key.courseId, a.fileId);
        } catch (_) {
          return null;
        }
      }(),
  ]);
  return [for (final f in resolved) ?f];
});

/// The student's own turned-in files and the teacher's feedback. Not kept
/// alive: it is re-read each time the dialog opens, so new feedback shows up.
final mySubmissionProvider =
    FutureProvider.autoDispose.family<MySubmission, AssignmentRef>((ref, key) async {
  try {
    return await ref.watch(submissionRepositoryProvider).mine(key.courseId, key.assignmentId);
  } catch (_) {
    return MySubmission.empty; // nothing submitted yet, or not readable: show nothing
  }
});
