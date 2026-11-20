const List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// What the assistant is told before the conversation starts.
String chatSystemPrompt(DateTime now) {
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return 'You are the assistant inside EtherLex, a desktop app that helps a student '
      'with their Canvas courses. Help with courses, assignments and studying. '
      'Answer clearly and concisely, and use Markdown when it helps. '
      'If you are not sure of something, say so instead of guessing. '
      'Today is ${_weekdays[now.weekday - 1]}, ${now.year}-$month-$day.';
}
