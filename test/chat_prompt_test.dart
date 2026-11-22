import 'package:etherlex/features/chat/data/sample_chat_backend.dart';
import 'package:etherlex/features/chat/domain/chat_prompt.dart';
import 'package:etherlex/features/chat/domain/context_item.dart';
import 'package:etherlex/features/chat/domain/proposed_actions.dart';
import 'package:etherlex/features/chat/domain/proposed_courses.dart';
import 'package:etherlex/features/chat/domain/proposed_files.dart';
import 'package:etherlex/features/chat/domain/proposed_submit.dart';
import 'package:etherlex/features/grades/domain/plan_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the prompt carries the date and the weekday', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20)); // a Friday
    expect(p, contains('Friday, 2026-11-20'));
    expect(chatSystemPrompt(DateTime(2026, 3, 2)), contains('Monday, 2026-03-02'));
  });

  test('the course names are in the prompt when given, and only then', () {
    const list = CoursesContext(lines: [CourseLine(name: 'Discrete Mathematics', code: 'MATH2160J'), CourseLine(name: 'Linear Algebra', hidden: true)]);
    final withList = chatSystemPrompt(DateTime(2026, 11, 20), courses: list);
    expect(withList, contains('- Discrete Mathematics (MATH2160J); shown'));
    expect(withList, contains('- Linear Algebra; hidden in EtherLex'));
    expect(chatSystemPrompt(DateTime(2026, 11, 20)), isNot(contains('Discrete Mathematics')));
    expect(chatSystemPrompt(DateTime(2026, 11, 20), courses: const CoursesContext(lines: [])), isNot(contains("The student's courses")));
  });

  test('it tells the assistant how to ask for a course and how to show the course list', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20));
    expect(p, contains('write "?" as the course name'));
    expect(p, contains('language is $kCoursesFence'));
  });

  test('it tells the assistant how to propose file changes, without doing them', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20));
    expect(p, contains('language is $kFilesFence'));
    expect(p, contains('Never delete or upload files'));
  });

  test('it tells the assistant it only names the assignment to hand in, never files', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20));
    expect(p, contains('language is $kSubmitFence'));
    expect(p, contains('Never put files, paths or text in it'));
    expect(p, contains('must never say that you did'));
  });

  test('the sample assistant streams its answer in pieces that add up', () async {
    final pieces = await const SampleChatBackend(delay: Duration.zero).reply(messages: [], system: '').toList();
    expect(pieces.length, greaterThan(5));
    expect(pieces.join(), SampleChatBackend.answer);
  });

  test('it tells the assistant how to propose a grade plan, without applying it', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20));
    expect(p, contains('language is $kPlanFence'));
    expect(p, contains('Never say the plan is applied'));
  });

  test('it explains the actions block, the item numbers, and that it cannot submit', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20));
    expect(p, contains('language is $kActionsFence'));
    expect(p, contains('[#12]'));
    expect(p, contains('submits nothing to Canvas'));
    expect(p, contains('"moves"'));
  });

  test('guessing is allowed only for the curve and counts, and must be flagged', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20));
    expect(p, contains('never guess'));
    expect(p, contains('"guessed":["curve"]'));
    expect(p, contains('call it an estimate'));
  });

  test('it lists the settings it may propose', () {
    final p = chatSystemPrompt(DateTime(2026, 11, 20));
    for (final w in ['"settings"', '"theme"', '"notifications"', '"open"']) {
      expect(p, contains(w));
    }
  });
}
