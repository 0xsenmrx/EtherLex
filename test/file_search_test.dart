import 'package:etherlex/features/courses/domain/course.dart';
import 'package:etherlex/features/files/domain/files_models.dart';
import 'package:etherlex/features/search/domain/search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const algebra = Course(id: 1, name: 'Linear Algebra', code: 'MATH2140J');
  const circuits = Course(id: 2, name: 'Electronic Circuits', code: 'ECE3110J');

  FileEntry file(int id, String name, {int course = 1, int daysAgo = 0}) => FileEntry(
        id: id,
        folderId: 10,
        name: name,
        size: 1,
        mime: 'application/pdf',
        updatedAt: DateTime(2026, 11, 20).subtract(Duration(days: daysAgo)),
        url: null,
        courseId: course,
      );

  final files = [
    (file(1, 'Syllabus.pdf'), algebra),
    (file(2, 'Problem_Set_3.pdf', daysAgo: 2), algebra),
    (file(3, 'Problem Set 2.pdf', daysAgo: 9), algebra),
    (file(4, 'Lab manual.pdf', course: 2), circuits),
    (file(5, 'syllabus-ece.pdf', course: 2, daysAgo: 1), circuits),
  ];

  List<int> ids(String q, {int limit = 6}) => [for (final h in searchFiles(q, files, limit: limit)) h.file.id];

  test('empty query finds nothing', () {
    expect(ids(''), isEmpty);
  });

  test('a name that starts with the word ranks first; newest breaks ties', () {
    expect(ids('syllabus'), [1, 5]);
  });

  test('a word that starts a part of the name beats one inside it', () {
    // "set" starts a part in both problem sets; newest first.
    expect(ids('set'), [2, 3]);
  });

  test('every word must match; the course counts too', () {
    expect(ids('syllabus ece3110j'), [5]);
    expect(ids('manual circuits'), [4]);
    // "lab" is inside "syllabus" too: both files of the course match.
    expect(ids('lab circuits'), [4, 5]);
    expect(ids('syllabus nothing'), isEmpty);
  });

  test('case is ignored and the limit is kept', () {
    expect(ids('PDF'), hasLength(5));
    expect(ids('pdf', limit: 2), hasLength(2));
  });

  group('searchConversations', () {
    ChatSearchText chat(String id, String title, List<String> texts) => (
          id: id,
          title: title,
          messages: [for (var i = 0; i < texts.length; i++) (id: '$id$i', text: texts[i].toLowerCase())],
        );
    final chats = <ChatSearchText>[
      chat('a', 'Grade plan for algebra', ['make a grade plan', 'here is a plan with weights']),
      chat('b', 'Hello', ['hello', 'can you explain eigenvalues of a matrix?']),
      chat('c', 'Eigenvalues help', ['eigenvalues help', 'sure']),
    ];
    List<(String, bool)> found(String q) =>
        [for (final h in searchConversations(q, chats)) (h.id, h.inMessages)];

    test('title hits first, then hits inside the messages', () {
      expect(found('eigenvalues'), [('c', false), ('b', true)]);
    });

    test('a later message counts, not only the first prompt', () {
      expect(found('matrix'), [('b', true)]);
      expect(found('weights'), [('a', true)]);
    });

    test('words may be split between the title and the messages', () {
      expect(found('hello matrix'), [('b', true)]);
    });

    test('nothing for an empty query or a missing word', () {
      expect(found(''), isEmpty);
      expect(found('eigenvalues banana'), isEmpty);
    });

    test('points at the message to show', () {
      final hit = searchConversations('weights', chats).single;
      expect(hit.messageId, 'a1');
      expect(searchConversations('eigenvalues', chats).map((h) => h.messageId).toList(), ['c0', 'b1']);
      // Every word in one message beats a message with only one of them.
      expect(searchConversations('plan weights', chats).single.messageId, 'a1');
    });
  });
}
