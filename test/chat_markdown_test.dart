import 'package:etherlex/features/chat/domain/chat_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paragraphs are split by blank lines and soft line breaks are joined', () {
    expect(parseChatMarkdown('One\ntwo\n\nThree'), const [
      MdBlock(MdKind.paragraph, 'One two'),
      MdBlock(MdKind.paragraph, 'Three'),
    ]);
  });

  test('headings, bullets, numbers and quotes', () {
    expect(parseChatMarkdown('## Plan\n- a\n* b\n1. first\n2) second\n> note'), const [
      MdBlock(MdKind.heading, 'Plan'),
      MdBlock(MdKind.bullet, 'a'),
      MdBlock(MdKind.bullet, 'b'),
      MdBlock(MdKind.numbered, 'first', marker: '1.'),
      MdBlock(MdKind.numbered, 'second', marker: '2.'),
      MdBlock(MdKind.quote, 'note'),
    ]);
  });

  test('bold text at the start of a line is not a bullet', () {
    expect(parseChatMarkdown('**Note:** read this'), const [MdBlock(MdKind.paragraph, '**Note:** read this')]);
  });

  test('a code fence keeps its lines and blank lines', () {
    expect(parseChatMarkdown('Before\n```dart\nvar a = 1;\n\nvar b = 2;\n```\nAfter'), const [
      MdBlock(MdKind.paragraph, 'Before'),
      MdBlock(MdKind.code, 'var a = 1;\n\nvar b = 2;'),
      MdBlock(MdKind.paragraph, 'After'),
    ]);
  });

  test('an unclosed fence (half-streamed answer) runs to the end', () {
    expect(parseChatMarkdown('```\nlet x'), const [MdBlock(MdKind.code, 'let x')]);
  });

  test('empty text has no blocks and windows line ends work', () {
    expect(parseChatMarkdown(''), isEmpty);
    expect(parseChatMarkdown('a\r\n\r\nb'), const [
      MdBlock(MdKind.paragraph, 'a'),
      MdBlock(MdKind.paragraph, 'b'),
    ]);
  });
}
