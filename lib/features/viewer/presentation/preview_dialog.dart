import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart' show SelectableText;
import 'package:pdfrx/pdfrx.dart';

import '../../../core/network/canvas_exception.dart';
import '../../../core/notify/toast.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/open_path.dart';
import '../../../design_system/ether/controls.dart';
import '../../../design_system/ether/dialog.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../files/domain/files_models.dart';
import '../../files/presentation/file_row.dart';
import '../../files/presentation/files_providers.dart';
import '../data/doc_text.dart';
import '../domain/preview_kind.dart';
import 'markdown_view.dart';

Future<void> showFilePreview(BuildContext context, FileEntry file) {
  return showEtherDialog<void>(context, (_) => FilePreviewDialog(file: file), maxWidth: 1180);
}

const int _maxTextBytes = 2 * 1024 * 1024;

class FilePreviewDialog extends ConsumerStatefulWidget {
  const FilePreviewDialog({super.key, required this.file});
  final FileEntry file;

  @override
  ConsumerState<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends ConsumerState<FilePreviewDialog> {
  late final Future<String> _path;
  Animation<double>? _routeAnim;
  bool _ready = false;
  bool _closing = false;

  // The heavy viewer is only built once the open animation has finished and
  // is dropped the moment the close animation starts, so neither animation
  // has to share frames with PDF rendering.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeAnim != null) return;
    final a = ModalRoute.of(context)?.animation;
    _routeAnim = a;
    if (a == null || a.isCompleted) {
      _ready = true;
    } else {
      a.addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus s) {
    if (!mounted) return;
    if (s == AnimationStatus.completed) {
      setState(() => _ready = true);
    } else if (s == AnimationStatus.reverse) {
      setState(() => _closing = true);
    }
  }

  @override
  void dispose() {
    _routeAnim?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final repo = ref.read(filesRepositoryProvider);
    _path = repo.localPath(widget.file);
  }

  String _errorText(Object e) =>
      e is CanvasException ? e.message : 'Could not load this file. Please try again.';

  Future<void> _saveToDownloads() async {
    final toast = ref.read(toastProvider.notifier);
    try {
      final cached = await _path;
      final dir = Directory(downloadsDirPath())..createSync(recursive: true);
      final target = uniquePath(dir.path, sanitizeFileName(widget.file.name));
      await File(cached).copy(target); // async: large files must not freeze the UI
      toast.show(
        'Saved to Downloads',
        actionLabel: 'Show',
        onAction: () => revealInFolder(target),
      );
    } catch (_) {
      toast.show('Could not save the file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final c = context.colors;
    final t = context.text;
    final visual = fileVisual(f.name);
    final height = MediaQuery.sizeOf(context).height * 0.85;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: c.isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(visual.icon, size: 17, color: visual.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.label),
                      const SizedBox(height: 3),
                      Text(f.size > 0 ? formatBytes(f.size) : 'Preview', style: t.metaMuted),
                    ],
                  ),
                ),
                EButton(
                  label: 'Open',
                  icon: EIcons.externalLink,
                  kind: EButtonKind.ghost,
                  onTap: () async {
                    try {
                      await openDownloaded(await _path);
                    } catch (_) {}
                  },
                ),
                const SizedBox(width: 6),
                EButton(label: 'Save', icon: EIcons.download, kind: EButtonKind.ghost, onTap: _saveToDownloads),
                const SizedBox(width: 10),
                EIconButton(icon: EIcons.close, tooltip: 'Close', onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          Container(height: 1, color: c.line),
          Expanded(
            child: FutureBuilder<String>(
              future: _path,
              builder: (context, snap) {
                if (snap.hasError) {
                  return _Message(_errorText(snap.error!));
                }
                if (!snap.hasData || !_ready) return const _Message('Loading…');
                if (_closing) return const SizedBox.shrink();
                return _Body(path: snap.data!, kind: previewKindFor(f.name));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, style: context.text.bodySecondary, textAlign: TextAlign.center),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.path, required this.kind});
  final String path;
  final PreviewKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case PreviewKind.pdf:
        return PdfViewer.file(
          path,
          params: PdfViewerParams(
            backgroundColor: context.colors.sunken,
            // Default 0.2 feels sluggish with a mouse wheel.
            scrollByMouseWheel: 0.5,
          ),
        );
      case PreviewKind.image:
        return InteractiveViewer(
          maxScale: 6,
          child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
        );
      case PreviewKind.markdown:
        return _TextLoader(path: path, builder: (text) => MarkdownView(source: text));
      case PreviewKind.text:
        return _TextLoader(path: path, builder: (text) => _PlainText(text: text));
      case PreviewKind.docx:
        return _DocLoader(load: () => readDocx(path));
      case PreviewKind.pptx:
        return _DocLoader(load: () => readPptx(path));
      case PreviewKind.none:
        return const _Message('No preview for this file type. Use Open.');
    }
  }
}

// The loaders read the file once (initState), not in build: the dialog
// rebuilds while the window is resized, and a new future each time would
// blank the preview and read and parse the file again on every frame.
class _TextLoader extends StatefulWidget {
  const _TextLoader({required this.path, required this.builder});
  final String path;
  final Widget Function(String text) builder;

  @override
  State<_TextLoader> createState() => _TextLoaderState();
}

class _TextLoaderState extends State<_TextLoader> {
  late final Future<String> _text = _read(widget.path);

  static Future<String> _read(String path) async {
    final file = File(path);
    final len = await file.length();
    final stream = file.openRead(0, len > _maxTextBytes ? _maxTextBytes : len);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytes.add(chunk);
    }
    final text = utf8.decode(bytes.takeBytes(), allowMalformed: true);
    return len > _maxTextBytes ? '$text\n\n... (file truncated for preview)' : text;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _text,
      builder: (context, snap) {
        if (snap.hasError) return const _Message('Could not read this file.');
        if (!snap.hasData) return const SizedBox.shrink();
        return widget.builder(snap.data!);
      },
    );
  }
}

/// Long text as chunks of lines so only what is on screen is laid out.
class _PlainText extends StatefulWidget {
  const _PlainText({required this.text});
  final String text;

  @override
  State<_PlainText> createState() => _PlainTextState();
}

class _PlainTextState extends State<_PlainText> {
  static const int _chunk = 120;

  // Split once; rebuilds (window resizes) reuse the lines.
  late final List<String> _lines = widget.text.replaceAll('\r\n', '\n').split('\n');

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    const chunk = _chunk;
    final count = (lines.length / chunk).ceil();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
      // Flutter is pinned to 3.47, which only has cacheExtent. Use scrollCacheExtent after unpinning (CLAUDE.md).
      // ignore: deprecated_member_use
      cacheExtent: 800,
      itemCount: count,
      itemBuilder: (context, i) {
        final part = lines.sublist(i * chunk, ((i + 1) * chunk).clamp(0, lines.length)).join('\n');
        return SelectableText(
          part,
          style: readerStyle(context).copyWith(
            fontFamily: 'Cascadia Mono',
            fontFamilyFallback: kMonoFallback,
            fontSize: 13,
            height: 1.5,
          ),
        );
      },
    );
  }
}

class _DocLoader extends StatefulWidget {
  const _DocLoader({required this.load});
  final Future<List<DocBlock>?> Function() load;

  @override
  State<_DocLoader> createState() => _DocLoaderState();
}

class _DocLoaderState extends State<_DocLoader> {
  late final Future<List<DocBlock>?> _blocks = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocBlock>?>(
      future: _blocks,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final blocks = snap.data;
        if (blocks == null || blocks.isEmpty) {
          return const _Message(
            'Could not read the text of this document.\nUse Open to view it in Word or PowerPoint.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(36, 22, 36, 32),
          // Flutter is pinned to 3.47, which only has cacheExtent. Use scrollCacheExtent after unpinning (CLAUDE.md).
          // ignore: deprecated_member_use
          cacheExtent: 800,
          itemCount: blocks.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'Text preview. Layout, images and tables are simplified.',
                  style: context.text.metaMuted,
                ),
              );
            }
            final b = blocks[i - 1];
            final size = switch (b.level) {
              1 => 24.0,
              2 => 19.0,
              3 => 16.0,
              _ => 14.0,
            };
            final base = readerStyle(context).copyWith(
              fontSize: size,
              height: 1.5,
              fontWeight: b.level > 0 ? FontWeight.w700 : FontWeight.w400,
            );
            return Padding(
              padding: EdgeInsets.only(top: b.level > 0 ? 12 : 0, bottom: 6, left: b.bullet ? 18 : 0),
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    if (b.bullet) TextSpan(text: '•  ', style: base),
                    for (final r in b.runs)
                      TextSpan(
                        text: r.text,
                        style: base.copyWith(
                          fontWeight: r.bold ? FontWeight.w700 : null,
                          fontStyle: r.italic ? FontStyle.italic : null,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
