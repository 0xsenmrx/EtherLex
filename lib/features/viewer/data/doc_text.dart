import 'dart:async';
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

/// Biggest Office file we open, and the most text we take out of one part.
/// A zip can be tiny and still unpack to gigabytes.
const int kMaxOfficeFileBytes = 50 * 1024 * 1024;
const int kMaxOfficePartBytes = 20 * 1024 * 1024;

/// The system tar by its full path, so a look-alike `tar.exe` in the PATH or
/// the working folder is never run.
String get _tarExe {
  if (Platform.isWindows) {
    final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final system = '$root\\System32\\tar.exe';
    if (File(system).existsSync()) return system;
  }
  return 'tar';
}

/// Runs tar and returns its output, or null on failure or if it is too big.
Future<String?> _tarOutput(List<String> args, {int maxBytes = kMaxOfficePartBytes}) async {
  try {
    final proc = await Process.start(_tarExe, args);
    final bytes = <int>[];
    var tooBig = false;
    final sub = proc.stdout.listen((chunk) {
      if (tooBig) return;
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) {
        tooBig = true;
        proc.kill();
      }
    });
    unawaited(proc.stderr.drain<void>());
    final code = await proc.exitCode.timeout(const Duration(seconds: 20), onTimeout: () {
      proc.kill();
      return -1;
    });
    await sub.asFuture<void>().timeout(const Duration(seconds: 2), onTimeout: () {});
    if (tooBig || code != 0) return null;
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return null;
  }
}

Future<String?> _readZipEntryAt(String zipPath, String entry) async {
  if (!await _smallEnough(zipPath)) return null;
  final out = await _tarOutput(['-xOf', zipPath, entry]);
  return out == null || out.isEmpty ? null : out;
}

Future<bool> _smallEnough(String path) async {
  try {
    return await File(path).length() <= kMaxOfficeFileBytes;
  } catch (_) {
    return false;
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
      if (!await _smallEnough(p)) return const <String>[];
      final listing = await _tarOutput(['-tf', p]);
      if (listing == null) return const <String>[];
      return [
        for (final line in listing.split(RegExp(r'\r?\n')))
          if (match.hasMatch(line.trim())) line.trim(),
      ];
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
