import 'package:etherlex/features/chat/domain/chat_inline.dart';
import 'package:flutter_test/flutter_test.dart';

/// The runs as short strings: `text{flags}` (see InlineRun.toString).
List<String> runs(String s) => [for (final r in parseInline(s)) r.toString()];

void main() {
  test('plain text is one run', () {
    expect(runs('plain text'), ['plain text']);
    expect(parseInline(''), isEmpty);
  });

  test('bold, italic and strikethrough', () {
    expect(runs('**bold** and *it* and ~~gone~~'), ['bold{b}', ' and ', 'it{i}', ' and ', 'gone{s}']);
    expect(runs('__bold__ and _it_'), ['bold{b}', ' and ', 'it{i}']);
  });

  test('bold italic together and nested', () {
    expect(runs('***both***'), ['both{b,i}']);
    expect(runs('**bold *and italic* text**'), ['bold {b}', 'and italic{b,i}', ' text{b}']);
    expect(runs('~~**x**~~'), ['x{b,s}']);
    expect(runs('*it **bold** it*'), ['it {i}', 'bold{b,i}', ' it{i}']);
  });

  test('inline code protects its content', () {
    expect(runs('use `a*b` here'), ['use ', 'a*b{c}', ' here']);
    expect(runs('``a`b``'), ['a`b{c}']);
    expect(runs('**`code`**'), ['code{b,c}']);
  });

  test('links, with styled text and a title', () {
    expect(runs('[docs](https://a.b/c)'), ['docs{>https://a.b/c}']);
    expect(runs('[**x**](https://a.b)'), ['x{b,>https://a.b}']);
    expect(runs('see [a](https://x.y "the title") now'), ['see ', 'a{>https://x.y}', ' now']);
    expect(runs('**[a](https://x.y)**'), ['a{b,>https://x.y}']);
  });

  test('bare addresses and autolinks lose the punctuation that ends a sentence', () {
    expect(runs('see https://example.com/a. Next'), [
      'see ',
      'https://example.com/a{>https://example.com/a}',
      '. Next',
    ]);
    expect(runs('(see https://a.b/c)'), ['(see ', 'https://a.b/c{>https://a.b/c}', ')']);
    expect(runs('https://en.wikipedia.org/wiki/Foo_(bar)'), [
      'https://en.wikipedia.org/wiki/Foo_(bar){>https://en.wikipedia.org/wiki/Foo_(bar)}',
    ]);
    expect(runs('<https://a.b>'), ['https://a.b{>https://a.b}']);
  });

  test('images keep their alt text and address', () {
    expect(runs('![cat](https://x.y/c.png)'), ['cat{img,>https://x.y/c.png}']);
    expect(runs('look ![a *cat*](https://x.y/c.png) here'), ['look ', 'a cat{img,>https://x.y/c.png}', ' here']);
  });

  test('things that only look like Markup stay as written', () {
    expect(runs('use snake_case_name now'), ['use snake_case_name now']);
    expect(runs('2 * 3 * 4'), ['2 * 3 * 4']);
    expect(runs('**unfinished'), ['**unfinished']);
    expect(runs('a [b] c'), ['a [b] c']);
    expect(runs('~one tilde~'), ['~one tilde~']);
  });

  test('a backslash escapes Markup', () {
    expect(runs(r'\*not italic\*'), ['*not italic*']);
    expect(runs(r'a \_ b'), ['a _ b']);
  });

  test('a line break inside text survives', () {
    expect(runs('a\nb'), ['a\nb']);
  });
}
