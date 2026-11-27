import 'dart:async';
import 'dart:io' show HttpException, SocketException;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../app/app_info.dart';
import '../../../core/utils/open_url.dart';
import '../../../design_system/ether/icons.dart';
import '../../../design_system/ether/tap.dart';
import '../../../design_system/theme/ether_theme.dart';
import '../../grades/domain/plan_proposal.dart';
import '../../viewer/presentation/markdown_view.dart';
import '../domain/chat_blocks.dart';
import '../domain/chat_inline.dart';
import '../domain/code_highlight.dart';
import '../domain/proposed_actions.dart';
import '../domain/proposed_courses.dart';
import '../domain/proposed_files.dart';
import '../domain/proposed_lookup.dart';
import '../domain/proposed_submit.dart';
import 'actions_card.dart';
import 'copy_button.dart';
import 'courses_card.dart';
import 'files_card.dart';
import 'lookup_card.dart';
import 'plan_card.dart';
import 'submit_card.dart';

/// An assistant answer, drawn as GitHub-style Markdown: headings, nested and
/// task lists, tables, quotes, rules, links, highlighted code with a copy
/// button, and images that load only when you ask.
class ChatMarkdown extends StatefulWidget {
  const ChatMarkdown(this.source, {super.key, this.scope = ''});

  final String source;

  /// Tells one message from another (its id), so a card in one is not taken
  /// for the same card in another that happens to have the same text.
  final String scope;

  @override
  State<ChatMarkdown> createState() => _ChatMarkdownState();
}

class _ChatMarkdownState extends State<ChatMarkdown> {
  final List<TapGestureRecognizer> _taps = [];
  String? _parsedSource;
  List<ChatBlock> _blocks = const [];

  void _disposeTaps() {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
  }

  @override
  void dispose() {
    _disposeTaps();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_parsedSource != widget.source) {
      _parsedSource = widget.source;
      _blocks = parseBlocks(widget.source);
    }
    _disposeTaps();
    return _Render(context, _taps, widget.scope).blocks(_blocks, readerStyle(context), depth: 0, gap: 10);
  }
}

/// Builds the widgets of one pass. Link recognizers go into [taps], which the
/// widget disposes before the next pass.
class _Render {
  _Render(this.context, this.taps, [this.scope = '']) : c = context.colors;

  final String scope;

  final BuildContext context;
  final List<TapGestureRecognizer> taps;
  final EtherColors c;

  TextStyle get _mono => TextStyle(
        fontFamily: kMonoFallback.first,
        fontFamilyFallback: kMonoFallback.sublist(1),
      );

  Widget blocks(List<ChatBlock> list, TextStyle base, {required int depth, required double gap}) {
    final children = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      if (i > 0) children.add(SizedBox(height: list[i] is HeadingBlock ? gap + 6 : gap));
      children.add(block(list[i], base, depth));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget block(ChatBlock b, TextStyle base, int depth) => switch (b) {
        ParagraphBlock p => paragraph(p.text, base),
        HeadingBlock h => heading(h, base),
        CodeBlock k => _codeBlock(k),
        QuoteBlock q => quote(q, base, depth),
        ListBlock l => list(l, base, depth),
        RuleBlock() => Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 6), color: c.line),
        TableBlock t => table(t, base),
      };

  /// A grade plan or a set of changes the assistant proposes becomes a card;
  /// anything else (or a proposal that does not pass the checks) stays a code block.
  Widget _codeBlock(CodeBlock k) {
    if (k.language == kPlanFence) {
      final proposal = parseProposal(k.code);
      if (proposal != null) return PlanCard(proposal: proposal, source: '$scope|${k.code}');
    } else if (k.language == kActionsFence) {
      final proposal = parseActions(k.code);
      if (proposal != null) return ActionsCard(proposal: proposal, source: '$scope|${k.code}');
    } else if (k.language == kLookupFence) {
      final proposal = parseLookup(k.code);
      if (proposal != null) return LookupCard(proposal: proposal, source: '$scope|${k.code}');
    } else if (k.language == kSubmitFence) {
      final proposal = parseSubmit(k.code);
      if (proposal != null) return SubmitCard(proposal: proposal, source: '$scope|${k.code}');
    } else if (k.language == kFilesFence) {
      final proposal = parseFileActions(k.code);
      if (proposal != null) return FilesCard(proposal: proposal, source: '$scope|${k.code}');
    } else if (k.language == kCoursesFence) {
      final filter = parseCourseList(k.code);
      if (filter != null) return CoursesCard(filter: filter, source: '$scope|${k.code}');
    }
    return _CodeBlockView(language: k.language, code: k.code);
  }

  Widget paragraph(String text, TextStyle base) {
    final runs = parseInline(text);
    if (runs.length == 1 && runs.first.image) {
      final url = safeWebUrl(runs.first.link);
      if (url != null) return _ImageBlock(url: url, alt: runs.first.text);
    }
    return richText(runs, base);
  }

  Widget heading(HeadingBlock h, TextStyle base) {
    final size = const [22.0, 19.0, 17.0, 15.5, 14.5, 14.0][h.level - 1];
    return richText(parseInline(h.text), base.copyWith(fontSize: size, fontWeight: FontWeight.w700, height: 1.3));
  }

  Widget quote(QuoteBlock q, TextStyle base, int depth) => Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: c.lineStrong, width: 3))),
        child: blocks(q.blocks, base.copyWith(color: c.textSecondary), depth: depth, gap: 6),
      );

  Widget list(ListBlock l, TextStyle base, int depth) {
    final lineHeight = (base.fontSize ?? 14.5) * (base.height ?? 1.6);
    final digits = '${l.start + l.items.length - 1}'.length;
    final markerWidth = l.ordered ? 26.0 + 8.0 * (digits - 1) : 22.0;
    final rows = <Widget>[];
    for (var n = 0; n < l.items.length; n++) {
      final item = l.items[n];
      final checked = item.checked;
      final Widget marker = checked != null
          ? _checkBox(checked, lineHeight)
          : Text(
              l.ordered ? '${l.start + n}.' : const ['•', '◦', '▪'][depth % 3],
              style: base.copyWith(color: c.textSecondary),
            );
      rows.add(Padding(
        padding: EdgeInsets.only(top: n == 0 ? 0 : 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: markerWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(alignment: Alignment.topRight, child: marker),
              ),
            ),
            Expanded(child: blocks(item.blocks, base, depth: depth + 1, gap: 4)),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _checkBox(bool checked, double lineHeight) => Container(
        width: 16,
        height: 16,
        margin: EdgeInsets.only(top: ((lineHeight - 16) / 2).clamp(0.0, 8.0).toDouble()),
        decoration: BoxDecoration(
          color: checked ? c.accentFill : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: checked ? c.accentFill : c.lineStrong, width: 1.5),
        ),
        child: checked ? Icon(EIcons.check, size: 12, color: c.onAccent) : null,
      );

  Widget table(TableBlock t, TextStyle base) {
    TextAlign alignOf(int i) => switch (t.aligns[i]) {
          ColumnAlign.center => TextAlign.center,
          ColumnAlign.right => TextAlign.right,
          _ => TextAlign.left,
        };

    // Cells are plain Text (the page's SelectionArea makes them selectable).
    Widget cell(String text, int col, {bool header = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: richText(
              parseInline(text),
              header ? base.copyWith(fontWeight: FontWeight.w700) : base,
              align: alignOf(col),
            ),
          ),
        );

    final grid = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(color: c.line),
      children: [
        TableRow(
          decoration: BoxDecoration(color: c.sunken),
          children: [for (var i = 0; i < t.header.length; i++) cell(t.header[i], i, header: true)],
        ),
        for (final row in t.rows) TableRow(children: [for (var i = 0; i < row.length; i++) cell(row[i], i)]),
      ],
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid),
      ),
    );
  }

  /// Plain text: the chat wraps all messages in one SelectionArea, so a
  /// selection can cross paragraphs, lists, tables and messages. A
  /// SelectableText per paragraph made each one its own island.
  Widget richText(List<InlineRun> runs, TextStyle base, {TextAlign? align}) {
    return Text.rich(TextSpan(style: base, children: spans(runs, base)), textAlign: align);
  }

  List<InlineSpan> spans(List<InlineRun> runs, TextStyle base) {
    final out = <InlineSpan>[];
    for (final r in runs) {
      final url = safeWebUrl(r.link);
      var style = const TextStyle();
      if (r.code) {
        style = _mono.copyWith(
          fontSize: (base.fontSize ?? 14.5) - 1.5,
          color: c.textPrimary,
          backgroundColor: c.sunken,
        );
      }
      final decorations = [
        if (r.strike) TextDecoration.lineThrough,
        if (url != null) TextDecoration.underline,
      ];
      style = style.copyWith(
        fontWeight: r.bold ? FontWeight.w700 : null,
        fontStyle: r.italic ? FontStyle.italic : null,
        decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
        color: url != null ? c.accent : null,
        decorationColor: url != null ? c.accent : null,
      );
      TapGestureRecognizer? tap;
      if (url != null) {
        tap = TapGestureRecognizer()..onTap = () => openExternal(url);
        taps.add(tap);
      }
      // A picture inside a line of text is a link to the picture.
      final text = r.image && r.text.isEmpty ? 'image' : r.text;
      out.add(TextSpan(
        text: text,
        style: style,
        recognizer: tap,
        mouseCursor: tap == null ? null : SystemMouseCursors.click,
      ));
    }
    return out;
  }
}

/// A fenced code block: the language, a copy button and highlighted code.
class _CodeBlockView extends StatefulWidget {
  const _CodeBlockView({required this.language, required this.code});

  final String language;
  final String code;

  @override
  State<_CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<_CodeBlockView> {
  bool _copied = false;
  Timer? _timer;
  String? _tokensFor;
  List<CodeToken> _tokens = const [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  TextStyle? _styleOf(CodeTokenKind kind, EtherColors c) => switch (kind) {
        CodeTokenKind.plain => null,
        CodeTokenKind.keyword => TextStyle(color: c.accent, fontWeight: FontWeight.w600),
        CodeTokenKind.string => TextStyle(color: c.success),
        CodeTokenKind.comment => TextStyle(color: c.textTertiary, fontStyle: FontStyle.italic),
        CodeTokenKind.number => TextStyle(color: c.dueSoon),
        CodeTokenKind.type => TextStyle(color: c.star),
        CodeTokenKind.function => TextStyle(color: c.accentHover),
        CodeTokenKind.added => TextStyle(color: c.success, backgroundColor: c.success.withValues(alpha: 0.12)),
        CodeTokenKind.removed => TextStyle(color: c.danger, backgroundColor: c.danger.withValues(alpha: 0.12)),
        CodeTokenKind.meta => TextStyle(color: c.textTertiary, fontWeight: FontWeight.w600),
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final key = '${widget.language}\u0000${widget.code}';
    if (_tokensFor != key) {
      _tokensFor = key;
      _tokens = highlightCode(widget.code, widget.language);
    }
    final mono = TextStyle(
      fontFamily: kMonoFallback.first,
      fontFamilyFallback: kMonoFallback.sublist(1),
      fontSize: 13,
      height: 1.5,
      color: c.textPrimary,
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.sunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(
              children: [
                Expanded(child: Text(widget.language.isEmpty ? 'code' : widget.language, style: t.metaMuted)),
                ETap(
                  onTap: _copy,
                  builder: (context, s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: s.hovered ? c.hover : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CopyIcon(copied: _copied, size: 13, color: _copied ? c.success : c.textSecondary),
                        const SizedBox(width: 5),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            child: Text(_copied ? 'Copied' : 'Copy', key: ValueKey<bool>(_copied), style: t.metaMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text.rich(
              TextSpan(
                style: mono,
                children: [for (final tok in _tokens) TextSpan(text: tok.text, style: _styleOf(tok.kind, c))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A picture from an answer. Nothing is fetched until you click: loading an
/// image contacts the site that hosts it, and an answer should not do that on
/// its own.
class _ImageBlock extends StatefulWidget {
  const _ImageBlock({required this.url, required this.alt});

  final String url;
  final String alt;

  @override
  State<_ImageBlock> createState() => _ImageBlockState();
}

class _ImageBlockState extends State<_ImageBlock> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final host = Uri.tryParse(widget.url)?.host ?? '';
    if (!_show) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ETap(
          onTap: () => setState(() => _show = true),
          builder: (context, s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: s.hovered ? Color.alphaBlend(c.hover, c.sunken) : c.sunken,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(EIcons.fileImage, size: 16, color: c.textSecondary),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.alt.isEmpty ? 'Show image' : 'Show image: ${widget.alt}', style: t.label),
                      Text('Loads from $host', style: t.metaMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            widget.url,
            // Some hosts (Wikimedia) refuse or throttle the default Dart client.
            headers: const {'User-Agent': '$kAppName/$kAppVersion'},
            fit: BoxFit.contain,
            semanticLabel: widget.alt,
            errorBuilder: (context, error, stack) => Text(
              'Could not load the image from $host${_why(error)}.',
              style: t.meta,
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : SizedBox(height: 120, child: Center(child: Text('Loading image…', style: t.meta))),
          ),
        ),
      ),
    );
  }

  /// A short reason for the error line: the HTTP status when there is one.
  static String _why(Object error) {
    if (error is NetworkImageLoadException) return ' (HTTP ${error.statusCode})';
    if (error is HttpException || error is SocketException) return ' (network error)';
    return ' (not a readable image)';
  }
}
