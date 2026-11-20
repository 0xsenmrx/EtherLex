/// Canvas file links inside plain text.
///
/// Messages are stored as plain text, so a link to a Canvas file travels as a
/// small marker: `<course>:<file><name>`. The characters are
/// from the Unicode private-use area and never appear in real text. Course
/// `0` means "the link did not say which course".
const String _open = '';
const String _sep = '';
const String _close = '';

final RegExp fileLinkPattern = RegExp('$_open(\\d+):(\\d+)$_sep([^$_close]*)$_close');

/// An unfinished marker at the very end (text that was cut in the middle).
final RegExp _cutMarker = RegExp('$_open[^$_close]*\$');

String _clean(String s) => s.replaceAll(RegExp('[$_open$_sep$_close]'), '');

/// The marker for one file link; [name] is what the reader sees.
String fileLinkMarker({required int courseId, required int fileId, required String name}) {
  final shown = _clean(name).trim();
  return '$_open$courseId:$fileId$_sep${shown.isEmpty ? 'File' : shown}$_close';
}

/// [text] as a person reads it: every marker replaced by its name.
String stripFileLinks(String text) => text.replaceAllMapped(fileLinkPattern, (m) => m.group(3)!);

/// Removes a marker that [text] ends in the middle of (after shortening it).
String dropCutFileLink(String text) => text.replaceFirst(_cutMarker, '');

/// A file link found by [fileLinkPattern].
typedef FileLinkRef = ({int courseId, int fileId, String name});

FileLinkRef fileLinkOf(Match m) =>
    (courseId: int.parse(m.group(1)!), fileId: int.parse(m.group(2)!), name: m.group(3)!);
