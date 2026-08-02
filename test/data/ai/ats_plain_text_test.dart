import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/ai/ats_plain_text.dart';

void main() {
  group('AtsPlainText.toPlain', () {
    test('returns empty string for empty input', () {
      expect(AtsPlainText.toPlain(''), isEmpty);
    });

    test('strips heading markers', () {
      const markdown = '''
# Jane Doe
## Summary
### Details
Contact info
''';

      final plain = AtsPlainText.toPlain(markdown);

      expect(plain, isNot(contains('#')));
      expect(plain, contains('Jane Doe'));
      expect(plain, contains('Summary'));
      expect(plain, contains('Details'));
      expect(plain, contains('Contact info'));
    });

    test('strips bold and italic markers', () {
      const markdown =
          'I built **Flutter** apps with *Dart* and __Riverpod__ plus _care_.';

      final plain = AtsPlainText.toPlain(markdown);

      expect(plain, 'I built Flutter apps with Dart and Riverpod plus care.');
      expect(plain, isNot(contains('*')));
      expect(plain, isNot(contains('_')));
    });

    test('normalizes bullets to dash lines', () {
      const markdown = '''
Skills
- Dart
* Flutter
+ Riverpod
''';

      final plain = AtsPlainText.toPlain(markdown);

      expect(
        plain,
        'Skills\n'
        '- Dart\n'
        '- Flutter\n'
        '- Riverpod',
      );
    });

    test('collapses excess blank lines', () {
      const markdown = '''
Summary


Experience



Education
''';

      final plain = AtsPlainText.toPlain(markdown);

      expect(plain, 'Summary\n\nExperience\n\nEducation');
      expect(plain, isNot(contains('\n\n\n')));
    });

    test('produces readable ATS paste from a resume-like document', () {
      const markdown = '''
# Jane Doe

## Summary

Senior **Flutter** engineer with *ATS* focus.

## Experience

- Shipped **mobile** apps
* Mentored _junior_ engineers

## Skills

Dart, Flutter, Riverpod
''';

      final plain = AtsPlainText.toPlain(markdown);

      expect(plain, startsWith('Jane Doe'));
      expect(plain, contains('Summary'));
      expect(plain, contains('Senior Flutter engineer with ATS focus.'));
      expect(plain, contains('- Shipped mobile apps'));
      expect(plain, contains('- Mentored junior engineers'));
      expect(plain, isNot(contains('#')));
      expect(plain, isNot(contains('**')));
      expect(plain, isNot(contains('\n\n\n')));
    });
  });
}
