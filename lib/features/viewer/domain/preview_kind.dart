enum PreviewKind { pdf, markdown, text, image, docx, pptx, none }

const _text = {
  'txt', 'log', 'csv', 'tsv', 'json', 'xml', 'yaml', 'yml', 'ini', 'toml', 'tex', 'bib',
  'py', 'java', 'c', 'h', 'cpp', 'hpp', 'js', 'ts', 'dart', 'html', 'css', 'm', 'r', 'sql',
  'sh', 'bat', 'rs', 'go', 'kt', 'swift', 'ipynb',
};
const _images = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

String extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
}

PreviewKind previewKindFor(String name) {
  final ext = extensionOf(name);
  if (ext == 'pdf') return PreviewKind.pdf;
  if (ext == 'md' || ext == 'markdown') return PreviewKind.markdown;
  if (ext == 'docx') return PreviewKind.docx;
  if (ext == 'pptx') return PreviewKind.pptx;
  if (_images.contains(ext)) return PreviewKind.image;
  if (_text.contains(ext)) return PreviewKind.text;
  return PreviewKind.none;
}
