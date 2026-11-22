import 'package:etherlex/features/chat/domain/file_tree_text.dart';
import 'package:etherlex/features/chat/domain/proposed_files.dart';
import 'package:etherlex/features/chat/domain/proposed_lookup.dart';
import 'package:etherlex/features/files/domain/files_models.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(int id, int folder, String name, {int size = 1000}) =>
    FileEntry(id: id, folderId: folder, name: name, size: size, mime: '', updatedAt: null, url: null, courseId: 1);

final _data = CourseFiles(
  folders: const [
    FolderNode(id: 10, name: 'course files', parentId: null),
    FolderNode(id: 11, name: 'TA', parentId: 10),
    FolderNode(id: 12, name: 'Old', parentId: 11),
    FolderNode(id: 13, name: 'Lectures', parentId: 10),
  ],
  files: [_f(1, 10, 'Syllabus.pdf'), _f(2, 12, 'hw0.pdf'), _f(3, 13, 'week1.pdf', size: 2 << 20)],
);

void main() {
  test('the tree shows paths, counts, sizes and what is hidden', () {
    final text = fileTreeText(_data, {12});
    expect(text, '- Syllabus.pdf (1000 B)\n'
        '[folder] Lectures · 1 file\n'
        '  - week1.pdf (2.0 MB)\n'
        '[folder] TA · 1 file\n'
        '  [folder] TA/Old (hidden) · 1 file\n'
        '    - hw0.pdf (1000 B)');
  });

  test('a file name that occurs twice is marked, so the assistant gives its folder', () {
    final twice = CourseFiles(folders: _data.folders, files: [..._data.files, _f(9, 13, 'syllabus.PDF')]);
    final text = fileTreeText(twice, {});
    expect(text, contains('- Syllabus.pdf (1000 B) [same name elsewhere: give its folder]'));
    expect(text, contains('- syllabus.PDF (1000 B) [same name elsewhere: give its folder]'));
    expect(text, isNot(contains('week1.pdf (2.0 MB) [')));
  });

  test('the paths in the tree are the ones the folder matcher understands', () {
    expect(resolveFolder(_data, 'TA/Old')?.id, 12);
    expect(resolveFolder(_data, 'ta')?.id, 11);
  });

  test('a long listing is cut, and says how much', () {
    final many = CourseFiles(
      folders: const [FolderNode(id: 1, name: 'root', parentId: null)],
      files: [for (var i = 0; i < 10; i++) _f(i, 1, 'f$i.pdf')],
    );
    final text = fileTreeText(many, {}, maxLines: 4);
    expect(text.split('\n').length, 5);
    expect(text, contains('6 more lines left out'));
  });

  test('an empty course', () {
    expect(fileTreeText(const CourseFiles(folders: [], files: []), {}), 'No files.');
  });

  group('parseLookup', () {
    test('asks for one course file list', () {
      final p = parseLookup('{"lookup":{"files":" Discrete Math "},"note":"x"}')!;
      expect(p.courses, ['Discrete Math']);
      expect(p.note, 'x');
    });

    test('several courses at once, up to four, without repeats', () {
      expect(parseLookup('{"lookup":{"files":["A","B","A"]}}')!.courses, ['A', 'B']);
      expect(parseLookup('{"lookup":{"files":["A","B","C","D","E"]}}'), isNull);
      expect(parseLookup('{"lookup":{"files":[]}}'), isNull);
      expect(parseLookup('{"lookup":{"files":["A",3]}}'), isNull);
    });

    test('anything else is not a card', () {
      expect(parseLookup('{"lookup":{"files":""}}'), isNull);
      expect(parseLookup('{"lookup":{"files":"a","grades":"b"}}'), isNull);
      expect(parseLookup('{"lookup":{"grades":"a"}}'), isNull);
      expect(parseLookup('{"files":"a"}'), isNull);
      expect(parseLookup('nope'), isNull);
    });
  });
}
