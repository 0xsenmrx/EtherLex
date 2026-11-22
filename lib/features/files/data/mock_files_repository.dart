import 'dart:convert';
import 'dart:io';

import '../../../core/utils/open_path.dart';
import '../domain/files_models.dart';
import '../domain/files_repository.dart';
import 'file_cache.dart';

class MockFilesRepository implements FilesRepository {
  final FileCache _cache = FileCache('sample');

  @override
  Future<String> localPath(FileEntry file) => _cache.ensure(file, (p) => fetchTo(file, p));

  @override
  String? cachedPath(FileEntry file) => _cache.lookup(file);

  @override
  int offlineBytes() => _cache.sizeBytes();

  @override
  void clearOffline() => _cache.clear();

  @override
  Future<CourseFiles> load(int courseId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final root = courseId * 100;
    FileEntry f(int n, int folder, String name, int size, String mime, int daysAgo) => FileEntry(
          id: courseId * 1000 + n,
          folderId: folder,
          name: name,
          size: size,
          mime: mime,
          updatedAt: DateTime.now().subtract(Duration(days: daysAgo)),
          url: 'https://example.invalid/$n',
          courseId: courseId,
        );
    return CourseFiles(
      folders: [
        FolderNode(id: root, name: 'course files', parentId: null),
        FolderNode(id: root + 1, name: 'Lectures', parentId: root),
        FolderNode(id: root + 2, name: 'Problem sets', parentId: root),
        FolderNode(id: root + 3, name: 'Week 1', parentId: root + 1),
      ],
      files: [
        f(1, root, 'Syllabus.pdf', 218000, 'application/pdf', 40),
        f(2, root + 1, 'Lecture 1 - Introduction.pdf', 3400000, 'application/pdf', 30),
        f(3, root + 1, 'Lecture 2 - Foundations.pptx', 8200000, 'application/vnd.ms-powerpoint', 22),
        f(4, root + 2, 'Problem Set 1.pdf', 120000, 'application/pdf', 21),
        f(5, root + 2, 'Problem Set 1 - Solutions.pdf', 190000, 'application/pdf', 14),
        f(6, root + 3, 'Reading notes.txt', 8200, 'text/plain', 35),
      ],
    );
  }

  @override
  Future<FileEntry?> fileInfo(int courseId, int fileId) async => FileEntry(
        id: fileId,
        folderId: courseId * 100,
        name: sampleAttachmentNames[fileId] ?? 'Attachment $fileId.pdf',
        size: 24000,
        mime: '',
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        url: 'https://example.invalid/$fileId',
        courseId: courseId,
      );

  @override
  Future<void> fetchTo(FileEntry file, String savePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    File(savePath).writeAsBytesSync(sampleBytesFor(file.name));
  }

  @override
  Future<String> download(FileEntry file) async {
    final saved = await localPath(file);
    final dir = Directory(downloadsDirPath())..createSync(recursive: true);
    final path = uniquePath(dir.path, sanitizeFileName(file.name));
    File(saved).copySync(path);
    await markFromInternet(path);
    return path;
  }
}

/// Attachments the sample assignments pretend to have.
const sampleAttachmentNames = {
  9001: 'Problem Set.pdf',
  9002: 'Instructions.md',
  9003: 'Data.csv',
};

List<int> sampleBytesFor(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return utf8.encode(_samplePdf);
  if (lower.endsWith('.md')) return utf8.encode(_sampleMarkdown);
  if (lower.endsWith('.csv')) {
    return utf8.encode('week,topic,hours\n1,Intro,3\n2,Limits,4\n3,Series,5\n');
  }
  return utf8.encode('Sample file from EtherLex sample mode.\n');
}

const _sampleMarkdown = '''# Sample instructions

This is a **sample** file shown by the built-in viewer.

## Checklist
- Read the problem statement
- Solve *all* parts
- Submit a single `PDF`

> Quotes look like this.

```
code blocks keep their spacing
```
''';

const _samplePdf = '''%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj
4 0 obj<</Length 72>>stream
BT /F1 28 Tf 72 700 Td (EtherLex sample PDF) Tj ET
endstream
endobj
5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj
trailer<</Root 1 0 R/Size 6>>
%%EOF
''';
