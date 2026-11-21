import 'package:etherlex/features/chat/domain/chat_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// The blocks as short strings (see the toString of each block).
List<String> blocks(String s) => [for (final b in parseBlocks(s)) b.toString()];

void main() {
  test('paragraphs are split by blank lines and soft line breaks are joined', () {
    expect(blocks('One\ntwo\n\nThree'), ['P(One two)', 'P(Three)']);
    expect(blocks(''), isEmpty);
    expect(blocks('A\r\nB'), ['P(A B)']);
  });

  test('two spaces or a backslash end a line for real', () {
    expect(blocks('a  \nb'), ['P(a\nb)']);
    expect(blocks('a\\\nb'), ['P(a\nb)']);
  });

  test('headings, with a closing hash run and without a space after the hashes', () {
    expect(blocks('# A\n### B ###\n###### F'), ['H1(A)', 'H3(B)', 'H6(F)']);
    expect(blocks('#hashtag'), ['P(#hashtag)']);
    expect(blocks('# C#'), ['H1(C#)']);
  });

  test('bullets, numbers (with their start) and a list that interrupts a paragraph', () {
    expect(blocks('- a\n* b\n+ c'), ['UL[P(a)|P(b)|P(c)]']);
    expect(blocks('3. x\n4) y'), ['OL3[P(x)|P(y)]']);
    expect(blocks('Steps:\n- one\n- two'), ['P(Steps:)', 'UL[P(one)|P(two)]']);
  });

  test('bold text at the start of a line is not a bullet', () {
    expect(blocks('**Note:** read this'), ['P(**Note:** read this)']);
  });

  test('nested lists, with two, three or four spaces', () {
    expect(blocks('- a\n  - b\n  - c\n- d'), ['UL[P(a),UL[P(b)|P(c)]|P(d)]']);
    expect(blocks('1. a\n   - b\n2. c'), ['OL1[P(a),UL[P(b)]|P(c)]']);
    expect(blocks('- a\n    - b\n        - c'), ['UL[P(a),UL[P(b),UL[P(c)]]]']);
  });

  test('blank lines between items keep one list; a different kind starts another', () {
    expect(blocks('- a\n\n- b'), ['UL[P(a)|P(b)]']);
    expect(blocks('- a\n1. b'), ['UL[P(a)]', 'OL1[P(b)]']);
  });

  test('an item can hold several paragraphs, code and a lazy line', () {
    expect(blocks('1. Run:\n   ```sh\n   ls\n   ```\n2. Done'), ['OL1[P(Run:),CODE[sh](ls)|P(Done)]']);
    expect(blocks('- one\n\n  more of one\n- two'), ['UL[P(one),P(more of one)|P(two)]']);
    expect(blocks('- one\nstill one'), ['UL[P(one still one)]']);
  });

  test('task lists', () {
    expect(blocks('- [x] done\n- [ ] todo\n- [X] also'), ['UL[[x] P(done)|[ ] P(todo)|[x] P(also)]']);
  });

  test('a code fence keeps its lines, blank lines and language', () {
    expect(blocks('Before\n```Dart\nvar a = 1;\n\nvar b = 2;\n```\nAfter'), [
      'P(Before)',
      'CODE[dart](var a = 1;\n\nvar b = 2;)',
      'P(After)',
    ]);
    expect(blocks('```\nplain\n```'), ['CODE[](plain)']);
  });

  test('an unclosed fence runs to the end; a longer fence can hold a shorter one', () {
    expect(blocks('```py\nprint(1)'), ['CODE[py](print(1))']);
    expect(blocks('````md\n```\nx\n```\n````'), ['CODE[md](```\nx\n```)']);
    expect(blocks('~~~\na\n~~~'), ['CODE[](a)']);
  });

  test('quotes, including nested ones and a lazy line', () {
    expect(blocks('> a\n> b\n\nafter'), ['Q{P(a b)}', 'P(after)']);
    expect(blocks('> > nested'), ['Q{Q{P(nested)}}']);
    expect(blocks('> one\ntwo'), ['Q{P(one two)}']);
    expect(blocks('> # Title\n> - x'), ['Q{H1(Title);UL[P(x)]}']);
  });

  test('horizontal rules', () {
    expect(blocks('a\n\n---\n\n***\n_ _ _'), ['P(a)', 'HR', 'HR', 'HR']);
  });

  test('tables with alignment, short rows and no outer pipes', () {
    expect(blocks('| a | b |\n|---|:-:|\n| 1 | 2 |\n| 3 |'), ['T(a|b; nc; 1|2 / 3|)']);
    expect(blocks('a | b\n--|--:\n1 | 2'), ['T(a|b; nr; 1|2)']);
    expect(blocks('| a\\|b | c |\n|:--|--|\n| x | y |\n\nafter'), ['T(a|b|c; ln; x|y)', 'P(after)']);
  });

  test('a pipe in a sentence is not a table', () {
    expect(blocks('a | b\nnext line'), ['P(a | b next line)']);
    expect(blocks('| a | b |\n| c | d |'), ['P(| a | b | | c | d |)']);
  });
}
