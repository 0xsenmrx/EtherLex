import 'package:etherlex/features/chat/domain/code_highlight.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pieces as strings: plain text as it is, the rest as `kind:text`.
List<String> pieces(String code, String? lang) => [for (final t in highlightCode(code, lang)) t.toString()];

void main() {
  test('keywords, numbers and comments in Dart', () {
    expect(pieces('final x = 42; // note', 'dart'), [
      'keyword:final',
      ' x = ',
      'number:42',
      '; ',
      'comment:// note',
    ]);
  });

  test('Python: functions, strings, comments and triple quotes', () {
    expect(pieces('def greet(name):\n    return "hi"  # x', 'python'), [
      'keyword:def',
      ' ',
      'function:greet',
      '(name):\n    ',
      'keyword:return',
      ' ',
      'string:"hi"',
      '  ',
      'comment:# x',
    ]);
    expect(pieces('s = """a\nb"""', 'py'), ['s = ', 'string:"""a\nb"""']);
  });

  test('types are the capitalised names', () {
    expect(pieces('String name', 'dart'), ['type:String', ' name']);
  });

  test('numbers: hex, decimals and exponents', () {
    expect(pieces('0xFF 3.14e-2', 'js'), ['number:0xFF', ' ', 'number:3.14e-2']);
  });

  test('block comments, and a string or comment that is not finished yet', () {
    expect(pieces('/* a */ x', 'js'), ['comment:/* a */', ' x']);
    expect(pieces('"open', 'js'), ['string:"open']);
    expect(pieces('x /* open', 'c'), ['x ', 'comment:/* open']);
    expect(pieces('`a\nb`', 'ts'), ['string:`a\nb`']);
  });

  test('JSON keys are told apart from string values', () {
    expect(pieces('{"a": [1, true, null, "b"]}', 'json'), [
      '{',
      'type:"a"',
      ': [',
      'number:1',
      ', ',
      'keyword:true',
      ', ',
      'keyword:null',
      ', ',
      'string:"b"',
      ']}',
    ]);
  });

  test('SQL keywords in any case', () {
    expect(pieces('SELECT name FROM users -- all', 'sql'), [
      'keyword:SELECT',
      ' name ',
      'keyword:FROM',
      ' users ',
      'comment:-- all',
    ]);
  });

  test('shell and YAML comments need a space before them', () {
    expect(pieces('echo "\$HOME" # hi', 'bash'), ['keyword:echo', ' ', 'string:"\$HOME"', ' ', 'comment:# hi']);
    expect(pieces('a#b', 'sh'), ['a#b']);
    expect(pieces('name: Ada # hi\nok: true', 'yaml'), [
      'type:name',
      ': Ada ',
      'comment:# hi',
      '\n',
      'type:ok',
      ': ',
      'keyword:true',
    ]);
    expect(pieces('url: https://a.b', 'yml'), ['type:url', ': https://a.b']);
  });

  test('CSS and HTML', () {
    expect(pieces('a { color: #fff; margin: 10px; }', 'css'), [
      'a { ',
      'type:color',
      ': ',
      'number:#fff',
      '; ',
      'type:margin',
      ': ',
      'number:10px',
      '; }',
    ]);
    expect(pieces('<p class="x">Hi</p>', 'html'), ['keyword:<p', ' class=', 'string:"x"', '>Hi', 'keyword:</p', '>']);
    expect(pieces('<!-- c --><b>', 'xml'), ['comment:<!-- c -->', 'keyword:<b', '>']);
  });

  test('LaTeX commands and Typst functions', () {
    expect(pieces(r'\section{A} % note', 'latex'), [r'keyword:\section', '{A} ', 'comment:% note']);
    expect(pieces('#let x = 1 // n', 'typst'), ['keyword:#let', ' x = ', 'number:1', ' ', 'comment:// n']);
  });

  test('a diff colours added, removed and header lines', () {
    expect(pieces('--- a\n+++ b\n@@ -1 +1 @@\n-old\n+new\n ctx', 'diff'), [
      'meta:--- a',
      '\n',
      'meta:+++ b',
      '\n',
      'meta:@@ -1 +1 @@',
      '\n',
      'removed:-old',
      '\n',
      'added:+new',
      '\n ctx',
    ]);
  });

  test('language names: any case, common aliases, a language- prefix', () {
    expect(pieces('let a', 'TypeScript'), ['keyword:let', ' a']);
    expect(pieces('let a', 'language-js'), ['keyword:let', ' a']);
    expect(pieces('fn a', 'Rust'), ['keyword:fn', ' a']);
  });

  test('an unknown or missing language, and empty code, stay plain', () {
    expect(pieces('let a = 1', 'brainfuck'), ['let a = 1']);
    expect(pieces('let a = 1', null), ['let a = 1']);
    expect(pieces('', 'dart'), isEmpty);
  });
}
