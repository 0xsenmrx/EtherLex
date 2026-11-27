import '../../../core/utils/format.dart';
import '../../assignments/domain/assignment.dart';
import '../../courses/domain/course.dart';
import '../../viewer/data/file_text.dart';
import '../../viewer/domain/preview_kind.dart';

/// Biggest picture sent: the services accept about this much.
const int kMaxImageBytes = 5 * 1024 * 1024;

/// Biggest document that is downloaded and read for the chat.
const int kMaxDocumentBytes = 25 * 1024 * 1024;

/// Why a file cannot be attached, judged from its name and size alone (so
/// nothing is downloaded first), or null when it can. [readsImages] is false
/// for a service that cannot take pictures.
String? attachProblemFor(String name, int size, {bool readsImages = true}) {
  final kind = previewKindFor(name);
  if (kind == PreviewKind.none) return 'Cannot be read yet';
  if (kind == PreviewKind.image) {
    if (!readsImages) return 'This AI service cannot read pictures yet';
    if (imageMimeFor(name) == null) return 'Only PNG, JPEG, GIF and WebP pictures';
    if (size > kMaxImageBytes) return 'Too big: ${formatBytes(size)}, up to ${formatBytes(kMaxImageBytes)}';
    return null;
  }
  if (size > kMaxDocumentBytes) return 'Too big: ${formatBytes(size)}, up to ${formatBytes(kMaxDocumentBytes)}';
  return null;
}

/// True when every word of [query] is somewhere in [name], ignoring case.
bool nameMatches(String name, String query) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final n = name.toLowerCase();
  return words.every(n.contains);
}

/// The assignments to choose from when attaching the files of one assignment:
/// Canvas ones only (your own tasks have no files), none from a hidden course,
/// open ones first (soonest due first, no date last), then done ones (latest
/// first), and only those where every word of [query] is in the title or the
/// course name.
List<Assignment> assignmentsWithFiles(
  List<Assignment> all,
  Map<int, Course> courses, {
  Set<int> disabled = const {},
  String query = '',
}) {
  final out = [
    for (final a in all)
      if (!a.isPersonal &&
          !disabled.contains(a.courseId) &&
          (query.trim().isEmpty || nameMatches('${a.title} ${courses[a.courseId]?.label ?? ''}', query)))
        a,
  ];
  int byDue(Assignment a, Assignment b, {required bool soonestFirst}) {
    final x = a.dueAt, y = b.dueAt;
    if (x == null && y == null) return a.title.compareTo(b.title);
    if (x == null) return 1;
    if (y == null) return -1;
    return soonestFirst ? x.compareTo(y) : y.compareTo(x);
  }

  out.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    return byDue(a, b, soonestFirst: !a.done);
  });
  return out;
}
