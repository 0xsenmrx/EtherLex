import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:etherlex/core/network/canvas_client.dart';
import 'package:etherlex/core/utils/format.dart';
import 'package:etherlex/core/utils/open_path.dart';
import 'package:etherlex/features/files/data/canvas_files_repository.dart';
import 'package:etherlex/features/files/data/files_mapper.dart';
import 'package:etherlex/features/files/domain/files_models.dart';
import 'package:etherlex/features/files/domain/folder_view.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Object Function(String path) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(respond(options.path)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

FileEntry _file(int id, int folder, String name) => FileEntry(
      id: id,
      folderId: folder,
      name: name,
      size: 1,
      mime: '',
      updatedAt: null,
      url: null,
      courseId: 1,
    );

void main() {
  const data = CourseFiles(
    folders: [
      FolderNode(id: 1, name: 'course files', parentId: null),
      FolderNode(id: 2, name: 'Lectures', parentId: 1),
      FolderNode(id: 3, name: 'week 1', parentId: 2),
      FolderNode(id: 4, name: 'Exams', parentId: 1),
    ],
    files: [],
  );
  final withFiles = CourseFiles(folders: data.folders, files: [
    _file(10, 1, 'syllabus.pdf'),
    _file(11, 2, 'b.pdf'),
    _file(12, 2, 'A.pdf'),
  ]);

  group('viewFolder', () {
    test('root lists its subfolders and files, sorted', () {
      final v = viewFolder(withFiles, null);
      expect(v.breadcrumb, isEmpty);
      expect(v.folders.map((f) => f.name), ['Exams', 'Lectures']);
      expect(v.files.map((f) => f.name), ['syllabus.pdf']);
    });

    test('nested folder has a breadcrumb and case-insensitive file order', () {
      final v = viewFolder(withFiles, 2);
      expect(v.breadcrumb.map((f) => f.name), ['Lectures']);
      expect(v.files.map((f) => f.name), ['A.pdf', 'b.pdf']);
      expect(viewFolder(withFiles, 3).breadcrumb.map((f) => f.name), ['Lectures', 'week 1']);
    });

    test('unknown folder falls back to root; no folders shows all files', () {
      expect(viewFolder(withFiles, 999).current!.id, 1);
      final flat = viewFolder(CourseFiles(folders: const [], files: withFiles.files), null);
      expect(flat.files.length, 3);
    });
  });

  group('mappers', () {
    test('parseFile reads Canvas field names and skips locked files', () {
      final f = parseFile({
        'id': 5,
        'folder_id': 2,
        'display_name': 'Notes.pdf',
        'size': 1234,
        'content-type': 'application/pdf',
        'modified_at': '2026-11-01T10:00:00Z',
        'url': 'https://s.instructure.com/files/5/download?verifier=x',
      }, courseId: 9)!;
      expect(f.name, 'Notes.pdf');
      expect(f.size, 1234);
      expect(f.courseId, 9);
      expect(parseFile({'id': 6, 'folder_id': 2, 'display_name': 'x', 'locked_for_user': true}, courseId: 9), isNull);
    });
  });

  group('utils', () {
    test('formatBytes', () {
      expect(formatBytes(500), '500 B');
      expect(formatBytes(2048), '2 KB');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(5 * 1024 * 1024), '5 MB');
    });

    test('sanitizeFileName', () {
      expect(sanitizeFileName('a/b:c?.pdf'), 'a_b_c_.pdf');
      expect(sanitizeFileName('CON.txt'), '_CON.txt');
      expect(sanitizeFileName('...'), 'file');
    });

    test('isRiskyFile', () {
      expect(isRiskyFile('C:/x/setup.EXE'), isTrue);
      expect(isRiskyFile('C:/x/notes.pdf'), isFalse);
    });
  });

  test('CanvasFilesRepository.load maps folders and files', () async {
    final client = CanvasClient(
      baseUrl: 'https://school.instructure.com',
      token: 't',
      dio: Dio()
        ..httpClientAdapter = _Adapter((path) {
          if (path.endsWith('/folders')) {
            return [
              {'id': 1, 'name': 'course files', 'parent_folder_id': null},
              {'id': 2, 'name': 'Lectures', 'parent_folder_id': 1},
            ];
          }
          return [
            {'id': 5, 'folder_id': 2, 'display_name': 'L1.pdf', 'size': 10},
          ];
        }),
    );
    final loaded = await CanvasFilesRepository(client).load(3);
    expect(loaded.folders.length, 2);
    expect(loaded.files.single.courseId, 3);
  });
}
