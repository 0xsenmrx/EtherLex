import 'dart:convert';
import 'dart:io';

/// A run of text inside a paragraph.
class DocRun {
  const DocRun(this.text, {this.bold = false, this.italic = false});
  final String text;
  final bool bold;
  final bool italic;
}

/// One paragraph: [level] 0 = body, 1..3 = heading.
class DocBlock {
  const DocBlock(this.runs, {this.level = 0, this.bullet = false});
  final List<DocRun> runs;
  final int level;
  final bool bullet;

  String get plain => runs.map((r) => r.text).join();
}

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
    .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
    .replaceAll('&amp;', '&');

/// Text of a Word document.xml: paragraphs, headings, bullets, bold/italic.
List<DocBlock> parseDocxXml(String xml) {
  final blocks = <DocBlock>[];
  for (final p in RegExp(r'<w:p[ >][\s\S]*?</w:p>').allMatches(xml)) {
    final para = p.group(0)!;
    var level = 0;
    final style = RegExp(r'<w:pStyle w:val="([^"]+)"').firstMatch(para)?.group(1);
    if (style != null) {
      final h = RegExp(r'^(?:Heading|heading)\s?(\d)$').firstMatch(style);
      if (h != null) {
        level = int.parse(h.group(1)!).clamp(1, 3);
      } else if (style == 'Title') {
        level = 1;
      }
    }
    final bullet = para.contains('<w:numPr>');
    final runs = <DocRun>[];
    for (final r in RegExp(r'<w:r[ >][\s\S]*?</w:r>').allMatches(para)) {
      final run = r.group(0)!;
      final bold = RegExp(r'<w:b/>|<w:b w:val="(?:1|true)"/>').hasMatch(run);
      final italic = RegExp(r'<w:i/>|<w:i w:val="(?:1|true)"/>').hasMatch(run);
      final buf = StringBuffer();
      for (final t in RegExp(r'<w:t(?: [^>]*)?>([\s\S]*?)</w:t>|<w:tab/>|<w:br/>').allMatches(run)) {
        final g = t.group(0)!;
        if (g.startsWith('<w:tab')) {
          buf.write('\t');
        } else if (g.startsWith('<w:br')) {
          buf.write('\n');
        } else {
          buf.write(_unescape(t.group(1) ?? ''));
        }
      }
      if (buf.isNotEmpty) runs.add(DocRun(buf.toString(), bold: bold, italic: italic));
    }
    if (runs.isEmpty) continue;
    blocks.add(DocBlock(runs, level: level, bullet: bullet));
  }
  return blocks;
}

/// Text of one PowerPoint slide: one block per paragraph.
List<DocBlock> parsePptxSlideXml(String xml) {
  final blocks = <DocBlock>[];
  for (final p in RegExp(r'<a:p>[\s\S]*?</a:p>|<a:p [\s\S]*?</a:p>').allMatches(xml)) {
    final text = RegExp(r'<a:t>([\s\S]*?)</a:t>|<a:t [^>]*>([\s\S]*?)</a:t>')
        .allMatches(p.group(0)!)
        .map((m) => _unescape(m.group(1) ?? m.group(2) ?? ''))
        .join();
    if (text.trim().isNotEmpty) blocks.add(DocBlock([DocRun(text)]));
  }
  return blocks;
}

/// Reads one entry out of an Office zip with the `tar` that ships with
/// Windows 10+, macOS and Linux, so no extra package is needed.
Future<String?> _readZipEntry(String zipPath, String entry) =>
    _withSafePath(zipPath, (p) => _readZipEntryAt(p, entry));

/// The tar that ships with Windows can fail on paths with accented letters
/// (like "Résumés.docx"), so such a file is read from an ASCII-named copy.
Future<T> _withSafePath<T>(String path, Future<T> Function(String path) run) async {
  if (path.codeUnits.every((c) => c < 128)) return run(path);
  final dir = await Directory.systemTemp.createTemp('etherlex_zip_');
  try {
    final copy = '${dir.path}${Platform.pathSeparator}file.zip';
    await File(path).copy(copy);
    return await run(copy);
  } finally {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

Future<String?> _readZipEntryAt(String zipPath, String entry) async {
  try {
    final r = await Process.run(
      'tar',
      ['-xOf', zipPath, entry],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (r.exitCode != 0) return null;
    final out = r.stdout as String;
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

Future<List<DocBlock>?> readDocx(String path) async {
  var xml = await _readZipEntry(path, 'word/document.xml');
  if (xml == null) {
    // Some programs name the main part differently (word/document2.xml).
    final other = await _zipEntries(path, RegExp(r'^word/document\d*\.xml$'));
    if (other.isNotEmpty) xml = await _readZipEntry(path, other.first);
  }
  return xml == null ? null : parseDocxXml(xml);
}

Future<List<String>> _zipEntries(String zipPath, RegExp match) => _withSafePath(zipPath, (p) async {
      try {
        final r = await Process.run('tar', ['-tf', p], stdoutEncoding: utf8);
        if (r.exitCode != 0) return const <String>[];
        return [
          for (final line in (r.stdout as String).split(RegExp(r'\r?\n')))
            if (match.hasMatch(line.trim())) line.trim(),
        ];
      } catch (_) {
        return const <String>[];
      }
    });

/// Slides in order, each a heading block ("Slide N") followed by its text.
Future<List<DocBlock>?> readPptx(String path) async {
  try {
    final slides = <int, String>{};
    for (final line in await _zipEntries(path, RegExp(r'^ppt/slides/slide\d+\.xml$'))) {
      slides[int.parse(RegExp(r'(\d+)\.xml$').firstMatch(line)!.group(1)!)] = line;
    }
    final out = <DocBlock>[];
    for (final n in (slides.keys.toList()..sort())) {
      final xml = await _readZipEntry(path, slides[n]!);
      out.add(DocBlock([DocRun('Slide $n', bold: true)], level: 2));
      if (xml != null) out.addAll(parsePptxSlideXml(xml));
    }
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}
