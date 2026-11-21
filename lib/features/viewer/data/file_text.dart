import 'dart:convert';
import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import '../domain/preview_kind.dart';
import 'doc_text.dart';

/// Most bytes read from a text file or characters read from a PDF; the chat
/// cuts what it sends much shorter, this only keeps a huge file from being read whole.
const int kMaxReadBytes = 2 * 1024 * 1024;

/// Paragraphs as plain text: headings with '#', bullets with '-'.
String blocksToText(List<DocBlock> blocks) {
  final out = <String>[];
  for (final b in blocks) {
    final text = b.plain.trim();
    if (text.isEmpty) continue;
    if (b.level > 0) {
      out.add('${'#' * b.level.clamp(1, 6)} $text');
    } else if (b.bullet) {
      out.add('- $text');
    } else {
      out.add(text);
    }
  }
  return out.join('\n');
}

/// The words in the file at [path], or null when it is not a kind that has
/// readable text (or is empty, for example a scanned PDF).
Future<String?> readFileText(String path, String name) async {
  try {
    final String? text = switch (previewKindFor(name)) {
      PreviewKind.markdown || PreviewKind.text => await _readTextFile(path),
      PreviewKind.docx => _fromBlocks(await readDocx(path)),
      PreviewKind.pptx => _fromBlocks(await readPptx(path)),
      PreviewKind.pdf => await _readPdf(path),
      PreviewKind.image || PreviewKind.none => null,
    };
    final t = text?.trim();
    return t == null || t.isEmpty ? null : t;
  } catch (_) {
    return null;
  }
}

String? _fromBlocks(List<DocBlock>? blocks) => blocks == null ? null : blocksToText(blocks);

Future<String> _readTextFile(String path) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in File(path).openRead(0, kMaxReadBytes)) {
    bytes.add(chunk);
  }
  return utf8.decode(bytes.takeBytes(), allowMalformed: true);
}

Future<String?> _readPdf(String path) async {
  final doc = await PdfDocument.openFile(path);
  try {
    final out = StringBuffer();
    for (final page in doc.pages) {
      final PdfPageText? text = await page.loadText();
      if (text != null) out.writeln(text.fullText);
      if (out.length >= kMaxReadBytes) break;
    }
    return out.toString();
  } finally {
    doc.dispose();
  }
}

/// The picture type to send for [name] (e.g. "image/png"), or null if it is not
/// a picture the AI services accept (they read PNG, JPEG, GIF and WebP).
String? imageMimeFor(String name) => switch (extensionOf(name)) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => null,
    };
