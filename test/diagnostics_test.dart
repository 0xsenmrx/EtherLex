import 'package:etherlex/features/settings/domain/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const d = Diagnostics(
    appVersion: '0.3.0',
    windows: '"Windows 11 Home China"\n 10.0.26200',
    theme: 'dark',
    typeface: 'clean',
    sampleMode: false,
    aiService: 'Anthropic (Claude)',
    notifications: true,
    autoUpdateCheck: false,
    dart: '3.9.0',
  );

  test('lists the facts on separate lines, with odd whitespace flattened', () {
    final lines = d.toText().split('\n');
    expect(lines.first, 'EtherLex 0.3.0');
    expect(lines, contains('Windows: "Windows 11 Home China" 10.0.26200'));
    expect(lines, contains('Dart: 3.9.0'));
    expect(lines, contains('Mode: signed in to Canvas'));
    expect(lines, contains('Look: dark, clean font'));
    expect(lines, contains('AI service chosen: Anthropic (Claude)'));
    expect(lines, contains('Notifications: on'));
    expect(lines, contains('Automatic update check: off'));
  });

  test('sample mode, no AI, no Dart line', () {
    const s = Diagnostics(
      appVersion: '0.3.0',
      windows: 'x',
      theme: 'light',
      typeface: 'handwritten',
      sampleMode: true,
      aiService: null,
      notifications: false,
      autoUpdateCheck: true,
    );
    final text = s.toText();
    expect(text, contains('Mode: sample data'));
    expect(text, contains('AI service chosen: not used'));
    expect(text, isNot(contains('Dart')));
  });

  test('the feedback link opens a new issue of this repo with the diagnostics inside', () {
    final u = feedbackUri(d);
    expect(u.scheme, 'https');
    expect(u.host, 'github.com');
    expect(u.path, '/0xsenmrx/EtherLex/issues/new');
    final body = u.queryParameters['body']!;
    expect(body, contains('EtherLex 0.3.0'));
    expect(body, contains('Diagnostics'));
    expect(u.toString().length, lessThan(2000));
  });
}
