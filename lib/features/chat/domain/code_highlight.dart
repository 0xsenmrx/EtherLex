enum CodeTokenKind { plain, keyword, string, comment, number, type, function, added, removed, meta }

class CodeToken {
  const CodeToken(this.text, this.kind);

  final String text;
  final CodeTokenKind kind;

  @override
  bool operator ==(Object other) => other is CodeToken && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  /// Plain text as it is, anything else as `kind:text` (for tests).
  @override
  String toString() => kind == CodeTokenKind.plain ? text : '${kind.name}:$text';
}

Set<String> _words(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

/// What one language looks like to the scanner.
class _Lang {
  _Lang({
    required this.keywords,
    this.lineComments = const [],
    this.blockComment,
    this.quotes = '"\'',
    this.tripleQuotes = false,
    this.ignoreCase = false,
    this.types = false,
    this.sigils = '',
    this.hyphenIdents = false,
    this.keyChars = '',
    this.units = false,
    this.hashColors = false,
    this.markup = false,
    this.keyStrings = false,
    this.spaceBeforeComment = false,
  });

  final Set<String> keywords;
  final List<String> lineComments;
  final (String, String)? blockComment;

  /// Characters that open a string.
  final String quotes;
  final bool tripleQuotes;
  final bool ignoreCase;

  /// Capitalised names are types.
  final bool types;

  /// A sigil followed by letters is a keyword: `@media`, `\\section`, `#let`.
  final String sigils;
  final bool hyphenIdents;

  /// A name followed by one of these is a key (`color:` in CSS, `name =` in TOML).
  final String keyChars;
  final bool units;
  final bool hashColors;
  final bool markup;

  /// A string followed by a colon is a key (JSON).
  final bool keyStrings;

  /// A comment character only counts at the start or after a space (shell, YAML).
  final bool spaceBeforeComment;
}

const String _clike = 'abstract as async await break case catch class const continue default do else enum extends '
    'false final finally for if implements import in instanceof interface new null package private protected '
    'public return static super switch this throw throws true try var void while yield';

final _Lang _js = _Lang(
  keywords: _words(
    'abstract as async await break case catch class const continue debugger default delete do else enum export extends '
    'false finally for from function get if implements import in instanceof interface let new null of private protected '
    'public readonly return set static super switch this throw true try type typeof undefined var void while with yield',
  ),
  lineComments: const ['//'],
  blockComment: ('/*', '*/'),
  quotes: '"\'`',
  types: true,
);

final _Lang _dart = _Lang(
  keywords: _words(
    'abstract as assert async await break case catch class const continue covariant default deferred do dynamic else '
    'enum export extends extension external factory false final finally for Function get hide if implements import in '
    'interface is late library mixin new null on operator part required rethrow return sealed set show static super '
    'switch sync this throw true try typedef var void while with yield',
  ),
  lineComments: const ['//'],
  blockComment: ('/*', '*/'),
  types: true,
);

final _Lang _python = _Lang(
  keywords: _words(
    'False None True and as assert async await break case class continue def del elif else except finally for from '
    'global if import in is lambda match nonlocal not or pass raise return try while with yield',
  ),
  lineComments: const ['#'],
  tripleQuotes: true,
  types: true,
);

final _Lang _jvm = _Lang(
  keywords: _words(
    '$_clike boolean byte char double float int long short native synchronized volatile val fun object when by data '
    'sealed override open internal namespace using string bool let func guard struct protocol extension inout',
  ),
  lineComments: const ['//'],
  blockComment: ('/*', '*/'),
  types: true,
);

final _Lang _c = _Lang(
  keywords: _words(
    'auto break case char const continue default do double else enum extern float for goto if inline int long register '
    'return short signed sizeof static struct switch typedef union unsigned void volatile while class namespace template '
    'typename public private protected virtual new delete this nullptr true false bool using try catch throw',
  ),
  lineComments: const ['//'],
  blockComment: ('/*', '*/'),
  types: true,
);

final _Lang _go = _Lang(
  keywords: _words(
    'break case chan const continue default defer else fallthrough for func go goto if import interface map package '
    'range return select struct switch type var true false nil',
  ),
  lineComments: const ['//'],
  blockComment: ('/*', '*/'),
  quotes: '"\'`',
  types: true,
);

final _Lang _rust = _Lang(
  keywords: _words(
    'as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut '
    'pub ref return self Self static struct super trait true type unsafe use where while',
  ),
  lineComments: const ['//'],
  blockComment: ('/*', '*/'),
  quotes: '"',
  types: true,
);

final _Lang _shell = _Lang(
  keywords: _words(
    'if then else elif fi for while do done case esac function in return exit export local echo cd ls cat grep sed awk '
    'set unset source alias read true false git npm pip flutter dart sudo mkdir rm cp mv curl',
  ),
  lineComments: const ['#'],
  spaceBeforeComment: true,
);

final _Lang _sql = _Lang(
  keywords: _words(
    'select from where and or not null insert into values update set delete create table alter drop index primary key '
    'foreign references join left right inner outer full on group by order having limit offset as distinct union all '
    'case when then else end in is like between exists count sum avg min max asc desc default unique check constraint '
    'view begin commit rollback',
  ),
  lineComments: const ['--'],
  blockComment: ('/*', '*/'),
  ignoreCase: true,
);

final _Lang _json = _Lang(
  keywords: _words('true false null'),
  quotes: '"',
  keyStrings: true,
);

final _Lang _yaml = _Lang(
  keywords: _words('true false null yes no on off'),
  lineComments: const ['#'],
  spaceBeforeComment: true,
  hyphenIdents: true,
  keyChars: ':',
);

final _Lang _toml = _Lang(
  keywords: _words('true false'),
  lineComments: const ['#'],
  spaceBeforeComment: true,
  hyphenIdents: true,
  keyChars: '=',
);

final _Lang _markup = _Lang(keywords: const {}, quotes: '"', markup: true);

final _Lang _css = _Lang(
  keywords: const {},
  blockComment: ('/*', '*/'),
  sigils: '@',
  hyphenIdents: true,
  keyChars: ':',
  units: true,
  hashColors: true,
);

final _Lang _latex = _Lang(keywords: const {}, lineComments: const ['%'], quotes: '', sigils: r'\');

final _Lang _typst = _Lang(
  keywords: _words('let set show if else for in while return import include'),
  lineComments: const ['//'],
  blockComment: ('/*', '*/'),
  quotes: '"',
  sigils: '#',
);

final Map<String, _Lang> _langs = {
  for (final k in ['js', 'javascript', 'jsx', 'mjs', 'ts', 'typescript', 'tsx', 'node']) k: _js,
  'dart': _dart,
  for (final k in ['py', 'python', 'python3']) k: _python,
  for (final k in ['java', 'kotlin', 'kt', 'scala', 'cs', 'csharp', 'c#', 'swift', 'php']) k: _jvm,
  for (final k in ['c', 'h', 'cpp', 'c++', 'cc', 'hpp', 'cxx']) k: _c,
  'go': _go,
  'golang': _go,
  'rs': _rust,
  'rust': _rust,
  for (final k in ['sh', 'bash', 'zsh', 'shell', 'console', 'ps1', 'powershell', 'bat', 'cmd']) k: _shell,
  for (final k in ['sql', 'postgres', 'postgresql', 'mysql', 'sqlite', 'plsql']) k: _sql,
  'json': _json,
  'jsonc': _json,
  'yaml': _yaml,
  'yml': _yaml,
  'toml': _toml,
  'ini': _toml,
  for (final k in ['html', 'xml', 'svg', 'xhtml']) k: _markup,
  for (final k in ['css', 'scss', 'less']) k: _css,
  'latex': _latex,
  'tex': _latex,
  'typst': _typst,
  'typ': _typst,
};

/// [code] split into coloured pieces. [language] is the word after the three
/// backticks (any case, a few common aliases). An unknown or missing language
/// gives one plain piece; an unfinished string or comment runs to its end, so
/// code that is still arriving never breaks.
List<CodeToken> highlightCode(String code, String? language) {
  if (code.isEmpty) return const [];
  final lang = (language ?? '').trim().toLowerCase().replaceFirst(RegExp(r'^language-'), '');
  if (lang == 'diff' || lang == 'patch') return _diff(code);
  final l = _langs[lang];
  if (l == null) return [CodeToken(code, CodeTokenKind.plain)];
  return _scan(code, l);
}

List<CodeToken> _diff(String code) {
  final out = <CodeToken>[];
  final lines = code.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final CodeTokenKind kind;
    if (line.startsWith('+++') || line.startsWith('---') || line.startsWith('@@') || line.startsWith('diff ') || line.startsWith('index ')) {
      kind = CodeTokenKind.meta;
    } else if (line.startsWith('+')) {
      kind = CodeTokenKind.added;
    } else if (line.startsWith('-')) {
      kind = CodeTokenKind.removed;
    } else {
      kind = CodeTokenKind.plain;
    }
    if (line.isNotEmpty) out.add(CodeToken(line, kind));
    if (i < lines.length - 1) out.add(const CodeToken('\n', CodeTokenKind.plain));
  }
  return _mergePlain(out);
}

List<CodeToken> _mergePlain(List<CodeToken> tokens) {
  final merged = <CodeToken>[];
  for (final t in tokens) {
    if (merged.isNotEmpty && merged.last.kind == CodeTokenKind.plain && t.kind == CodeTokenKind.plain) {
      merged[merged.length - 1] = CodeToken(merged.last.text + t.text, CodeTokenKind.plain);
    } else {
      merged.add(t);
    }
  }
  return merged;
}

final RegExp _ident = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');
final RegExp _identHyphen = RegExp(r'[A-Za-z_][A-Za-z0-9_-]*');
final RegExp _number = RegExp(r'0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?');
final RegExp _hexColor = RegExp(r'#[0-9a-fA-F]{3,8}(?![\w])');
final RegExp _tag = RegExp(r'<[/!?]?[A-Za-z][\w:.-]*');
final RegExp _letter = RegExp(r'[A-Za-z]');

bool _isLetter(String ch) => _letter.hasMatch(ch);

/// The first character after [from] that is not a space or tab, or ''.
String _nextChar(String code, int from) {
  var i = from;
  while (i < code.length && (code[i] == ' ' || code[i] == '\t')) {
    i++;
  }
  return i < code.length ? code[i] : '';
}

List<CodeToken> _scan(String code, _Lang l) {
  final out = <CodeToken>[];
  final plain = StringBuffer();

  void flushPlain() {
    if (plain.isEmpty) return;
    out.add(CodeToken(plain.toString(), CodeTokenKind.plain));
    plain.clear();
  }

  void emit(CodeTokenKind kind, String text) {
    flushPlain();
    out.add(CodeToken(text, kind));
  }

  var i = 0;
  while (i < code.length) {
    final ch = code[i];

    final block = l.blockComment;
    if (block != null && code.startsWith(block.$1, i)) {
      final close = code.indexOf(block.$2, i + block.$1.length);
      final end = close < 0 ? code.length : close + block.$2.length;
      emit(CodeTokenKind.comment, code.substring(i, end));
      i = end;
      continue;
    }

    if (l.markup && code.startsWith('<!--', i)) {
      final close = code.indexOf('-->', i + 4);
      final end = close < 0 ? code.length : close + 3;
      emit(CodeTokenKind.comment, code.substring(i, end));
      i = end;
      continue;
    }

    final startsComment = l.lineComments.any((p) => code.startsWith(p, i)) &&
        (!l.spaceBeforeComment || i == 0 || code[i - 1] == ' ' || code[i - 1] == '\t' || code[i - 1] == '\n');
    if (startsComment) {
      var end = code.indexOf('\n', i);
      if (end < 0) end = code.length;
      emit(CodeTokenKind.comment, code.substring(i, end));
      i = end;
      continue;
    }

    if (l.tripleQuotes && (code.startsWith('"""', i) || code.startsWith("'''", i))) {
      final q = code.substring(i, i + 3);
      final close = code.indexOf(q, i + 3);
      final end = close < 0 ? code.length : close + 3;
      emit(CodeTokenKind.string, code.substring(i, end));
      i = end;
      continue;
    }

    if (l.quotes.contains(ch)) {
      var j = i + 1;
      while (j < code.length) {
        final c = code[j];
        if (c == r'\') {
          j += 2;
          continue;
        }
        if (c == ch) {
          j++;
          break;
        }
        if (c == '\n' && ch != '`') break;
        j++;
      }
      if (j > code.length) j = code.length;
      final isKey = l.keyStrings && _nextChar(code, j) == ':';
      emit(isKey ? CodeTokenKind.type : CodeTokenKind.string, code.substring(i, j));
      i = j;
      continue;
    }

    if (l.markup && ch == '<') {
      final m = _tag.matchAsPrefix(code, i);
      if (m != null) {
        emit(CodeTokenKind.keyword, m.group(0)!);
        i = m.end;
        continue;
      }
    }

    if (l.hashColors && ch == '#') {
      final m = _hexColor.matchAsPrefix(code, i);
      if (m != null) {
        emit(CodeTokenKind.number, m.group(0)!);
        i = m.end;
        continue;
      }
    }

    if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
      final m = _number.matchAsPrefix(code, i);
      if (m != null) {
        var end = m.end;
        if (l.units) {
          while (end < code.length && (_isLetter(code[end]) || code[end] == '%')) {
            end++;
          }
        }
        emit(CodeTokenKind.number, code.substring(i, end));
        i = end;
        continue;
      }
    }

    if (l.sigils.contains(ch) && i + 1 < code.length && _isLetter(code[i + 1])) {
      final m = (l.hyphenIdents ? _identHyphen : _ident).matchAsPrefix(code, i + 1);
      if (m != null) {
        emit(CodeTokenKind.keyword, code.substring(i, m.end));
        i = m.end;
        continue;
      }
    }

    final name = (l.hyphenIdents ? _identHyphen : _ident).matchAsPrefix(code, i);
    if (name != null) {
      final word = name.group(0)!;
      final next = _nextChar(code, name.end);
      final CodeTokenKind kind;
      if (l.keywords.contains(l.ignoreCase ? word.toLowerCase() : word)) {
        kind = CodeTokenKind.keyword;
      } else if (l.keyChars.isNotEmpty && next.isNotEmpty && l.keyChars.contains(next) && !code.startsWith('://', name.end)) {
        kind = CodeTokenKind.type;
      } else if (l.types && word.codeUnitAt(0) >= 65 && word.codeUnitAt(0) <= 90) {
        kind = CodeTokenKind.type;
      } else if (next == '(' && !l.markup) {
        kind = CodeTokenKind.function;
      } else {
        kind = CodeTokenKind.plain;
      }
      if (kind == CodeTokenKind.plain) {
        plain.write(word);
      } else {
        emit(kind, word);
      }
      i = name.end;
      continue;
    }

    plain.write(ch);
    i++;
  }
  flushPlain();
  return out;
}
