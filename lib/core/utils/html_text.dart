import 'char_code.dart';
import 'file_link_markup.dart';

/// Canvas messages are HTML. This keeps the readable text and paragraph breaks.
///
/// With [links], `<a href>` becomes "text (url)" so the link survives as plain
/// text (the UI makes URLs tappable). Canvas file links are left as plain text
/// because they are shown as attachments, unless [fileLinks] is on: then a link
/// to a file on [origin] becomes a marker (see file_link_markup.dart) that the
/// UI turns into a link to the file. [origin] resolves "/relative" links.
String htmlToText(
  String html, {
  int maxLength = 2000,
  bool links = false,
  String? origin,
  bool fileLinks = false,
}) {
  // The marker characters are ours: text from Canvas must not forge a link.
  html = stripFileLinkChars(html);
  if (links) html = _inlineLinks(html, origin, fileLinks);
  var s = html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>|<style[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*(p|div|li|h[1-6]|tr)\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    return charFromCode(int.tryParse(m.group(1)!));
  }).replaceAll('&amp;', '&');
  s = s
      .replaceAll(RegExp(r'[ \t ]+'), ' ')
      .replaceAll(RegExp(r' ?\n ?'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  if (s.length > maxLength) s = '${dropCutFileLink(s.substring(0, maxLength)).trimRight()}…';
  return s;
}

String _inlineLinks(String html, String? origin, bool fileLinks) {
  return html.replaceAllMapped(
    RegExp(r'''<a\b[^>]*?\bhref\s*=\s*(["'])(.*?)\1[^>]*>([\s\S]*?)</a\s*>''', caseSensitive: false),
    (m) {
      final inner = m.group(3)!;
      var href = m.group(2)!.replaceAll('&amp;', '&').trim();
      if (href.startsWith('/') && !href.startsWith('//') && origin != null) href = '$origin$href';
      final isWeb = href.startsWith('https://') || href.startsWith('http://');
      final file = RegExp(r'/files/(\d+)').firstMatch(href);
      // An id too long to be real (or to fit an int) is no file link.
      final fileId = file == null ? null : int.tryParse(file.group(1)!);
      if (fileLinks && fileId != null && origin != null && href.startsWith('$origin/') && !inner.contains('<img')) {
        final course = RegExp(r'/courses/(\d+)/').firstMatch(href)?.group(1);
        return fileLinkMarker(
          courseId: int.tryParse(course ?? '') ?? 0,
          fileId: fileId,
          name: inner.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' '),
        );
      }
      if (!isWeb || file != null) return inner;
      final text = inner.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ').trim();
      if (text.isEmpty || text == href) return ' $href ';
      return '$inner ($href)';
    },
  );
}
