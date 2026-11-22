import 'package:etherlex/features/chat/domain/proposed_files.dart';
import 'package:etherlex/features/courses/domain/course.dart';
import 'package:etherlex/features/files/domain/files_models.dart';
import 'package:flutter_test/flutter_test.dart';

FileEntry _f(int id, int folder, String name, {int size = 1000}) =>
    FileEntry(id: id, folderId: folder, name: name, size: size, mime: '', updatedAt: null, url: null, courseId: 1);

const _courses = [Course(id: 1, name: 'Physics II', code: 'PHYS2'), Course(id: 2, name: 'Chemistry', code: 'CHEM1')];

final _data = CourseFiles(
  folders: const [
    FolderNode(id: 10, name: 'course files', parentId: null),
    FolderNode(id: 11, name: 'Lectures', parentId: 10),
    FolderNode(id: 12, name: 'Week 1', parentId: 11),
    FolderNode(id: 13, name: 'Week 1', parentId: 14),
    FolderNode(id: 14, name: 'Labs', parentId: 10),
  ],
  files: [
    _f(1, 12, 'Slides week 1.pdf', size: 2 << 20),
    _f(2, 11, 'Syllabus.pdf'),
    _f(3, 13, 'Lab 1.pdf'),
  ],
);

List<FileLine> _preview(String json, {Set<int> hidden = const {}, Set<int> saved = const {}, CourseFiles? Function(int)? dataFor}) =>
    previewFileActions(parseFileActions(json)!, _courses,
        dataFor: dataFor ?? (_) => _data, hiddenFolders: hidden, saved: (f) => saved.contains(f.id));

void main() {
  group('parseFileActions', () {
    test('reads the three kinds', () {
      final p = parseFileActions(
          '{"files":[{"type":"hide_folder","course":"Physics","folder":"Lectures"},{"type":"hide_folder","course":"Physics","folder":"Labs","value":false},'
          '{"type":"offline","course":"Physics"},{"type":"download","course":"Physics","file":"Syllabus.pdf"}],"note":" ok "}')!;
      expect(p.actions.map((a) => a.kind), [FileActionKind.hideFolder, FileActionKind.hideFolder, FileActionKind.offline, FileActionKind.download]);
      expect(p.actions[0].value, true);
      expect(p.actions[1].value, false);
      expect(p.note, 'ok');
    });

    test('anything wrong makes the whole block invalid', () {
      expect(parseFileActions('not json'), isNull);
      expect(parseFileActions('{"files":[]}'), isNull);
      expect(parseFileActions('{"files":[{"type":"delete","course":"x"}]}'), isNull);
      expect(parseFileActions('{"files":[{"type":"hide_folder","course":"x"}]}'), isNull); // no folder
      expect(parseFileActions('{"files":[{"type":"download","course":"x"}]}'), isNull); // no file
      expect(parseFileActions('{"files":[{"type":"hide_folder","course":"","folder":"a"}]}'), isNull);
      expect(parseFileActions('{"files":[{"type":"hide_folder","course":"x","folder":"a","value":"yes"}]}'), isNull);
      expect(parseFileActions('{"files":[{"type":"offline","course":"x","folder":5}]}'), isNull);
    });
  });

  group('resolveFolder', () {
    test('a plain name, a path, and the ambiguous ones', () {
      expect(resolveFolder(_data, 'lectures')?.id, 11);
      expect(resolveFolder(_data, 'Lectures/Week 1')?.id, 12);
      expect(resolveFolder(_data, 'Labs/week1')?.id, 13);
      expect(resolveFolder(_data, 'Week 1'), isNull); // two of them
      expect(resolveFolder(_data, 'course files'), isNull); // the course itself
      expect(resolveFolder(_data, 'Nope'), isNull);
      expect(resolveFolder(_data, '  / '), isNull);
    });

    test('a folder tree includes what is inside', () {
      expect(folderTree(_data, 11), {11, 12});
      expect(folderTree(_data, 10), {10, 11, 12, 13, 14});
    });
  });

  test('resolveFile: exact first, then contained, never several', () {
    final files = [_f(1, 1, 'Slides week 1.pdf'), _f(2, 1, 'Slides week 2.pdf'), _f(3, 1, 'Syllabus.pdf')];
    expect(resolveFile(files, 'syllabus.PDF')?.id, 3);
    expect(resolveFile(files, 'Syllabus')?.id, 3);
    expect(resolveFile(files, 'slides'), isNull);
    expect(resolveFile(files, 'week 2')?.id, 2);
    expect(resolveFile(files, 'xyz'), isNull);
  });

  group('previewFileActions', () {
    test('hiding a folder: change, or already so', () {
      final l = _preview('{"files":[{"type":"hide_folder","course":"physics","folder":"Lectures"}]}');
      expect(l.single.effect, FileEffect.change);
      expect(l.single.folderId, 11);
      expect(l.single.detail, 'PHYS2 · Lectures');
      expect(_preview('{"files":[{"type":"hide_folder","course":"physics","folder":"Lectures"}]}', hidden: {11}).single.effect, FileEffect.same);
      expect(_preview('{"files":[{"type":"hide_folder","course":"physics","folder":"Lectures","value":false}]}', hidden: {11}).single.effect, FileEffect.change);
    });

    test('offline counts only what is not saved yet', () {
      final all = _preview('{"files":[{"type":"offline","course":"physics"}]}');
      expect(all.single.files.length, 3);
      expect(all.single.note, startsWith('3 files'));
      final folder = _preview('{"files":[{"type":"offline","course":"physics","folder":"Lectures"}]}', saved: {2});
      expect(folder.single.files.map((f) => f.id), [1]); // Lectures holds Week 1 too; the syllabus is saved
      expect(_preview('{"files":[{"type":"offline","course":"physics","folder":"Lectures"}]}', saved: {1, 2}).single.effect, FileEffect.same);
    });

    test('download finds one file, in a folder if one is given', () {
      final l = _preview('{"files":[{"type":"download","course":"physics","file":"syllabus"}]}');
      expect(l.single.files.single.id, 2);
      expect(l.single.note, '1000 B');
      expect(_preview('{"files":[{"type":"download","course":"physics","folder":"Labs","file":"syllabus"}]}').single.effect, FileEffect.unknown);
    });

    test('nothing is guessed: unknown course, loading, no files', () {
      expect(_preview('{"files":[{"type":"offline","course":"biology"}]}').single.effect, FileEffect.unknown);
      expect(_preview('{"files":[{"type":"offline","course":"physics"}]}', dataFor: (_) => null).single.effect, FileEffect.loading);
      expect(_preview('{"files":[{"type":"offline","course":"chem"}]}', dataFor: (_) => const CourseFiles(folders: [], files: [])).single.effect, FileEffect.unknown);
    });
  });

  test('sizes read naturally', () {
    expect(sizeText(900), '900 B');
    expect(sizeText(2048), '2 KB');
    expect(sizeText(3 << 20), '3.0 MB');
    expect(sizeText(48 << 20), '48 MB');
    expect(sizeText(3 << 30), '3.0 GB');
  });
}
