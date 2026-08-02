import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/ai/ai_exceptions.dart';
import 'package:gopher_jobs/data/ai/ats_structure_validator.dart';

void main() {
  const validator = AtsStructureValidator();

  String fixture(String name) =>
      File('test/fixtures/ats/$name').readAsStringSync();

  group('AtsStructureValidator', () {
    test('good resume and cover letter yield no warnings', () {
      final warnings = validator.validate(
        resumeMarkdown: fixture('good_resume.md'),
        coverLetterMarkdown: fixture('good_cover_letter.md'),
      );

      expect(warnings, isEmpty);
    });

    test('accepts optional jobTitle without changing structure checks', () {
      final warnings = validator.validate(
        resumeMarkdown: fixture('good_resume.md'),
        coverLetterMarkdown: fixture('good_cover_letter.md'),
        jobTitle: 'Software Engineer',
      );

      expect(warnings, isEmpty);
    });

    test('warns on missing resume sections (case-insensitive ## headings)', () {
      const resume = '''
# Pat Lee
pat@example.com

## summary
Brief summary.

## experience
Engineer | Co | Remote
''';
      final cover = fixture('good_cover_letter.md');

      final warnings = validator.validate(
        resumeMarkdown: resume,
        coverLetterMarkdown: cover,
      );

      expect(
        warnings,
        containsAll([
          'Resume is missing ## Skills section.',
          'Resume is missing ## Education section.',
        ]),
      );
      expect(warnings, isNot(contains('Resume is missing ## Summary section.')));
      expect(
        warnings,
        isNot(contains('Resume is missing ## Experience section.')),
      );
    });

    test('warns when contact email and phone are absent', () {
      const resume = '''
# No Contact

## Summary
x

## Skills
Dart

## Experience
Role

## Education
School
''';

      final warnings = validator.validate(
        resumeMarkdown: resume,
        coverLetterMarkdown: fixture('good_cover_letter.md'),
      );

      expect(
        warnings,
        contains(
          'Resume appears to lack contact details (email or phone).',
        ),
      );
    });

    test('warns on markdown tables in resume fixture', () {
      final warnings = validator.validate(
        resumeMarkdown: fixture('tabled_resume.md'),
        coverLetterMarkdown: fixture('good_cover_letter.md'),
      );

      expect(
        warnings,
        contains(
          'Resume contains a markdown table; ATS parsers often mishandle tables.',
        ),
      );
    });

    test('warns on HTML tables in resume', () {
      const resume = '''
# Ada
ada@example.com

## Summary
x
## Skills
Dart
## Experience
Role
## Education
School

<table><tr><td>bad</td></tr></table>
''';

      final warnings = validator.validate(
        resumeMarkdown: resume,
        coverLetterMarkdown: fixture('good_cover_letter.md'),
      );

      expect(
        warnings,
        contains(
          'Resume contains an HTML <table>; ATS parsers often mishandle tables.',
        ),
      );
    });

    test('warns when cover letter is outside 250–400 words', () {
      final shortCover = List.filled(100, 'word').join(' ');

      final warnings = validator.validate(
        resumeMarkdown: fixture('good_resume.md'),
        coverLetterMarkdown: shortCover,
      );

      expect(
        warnings.any((w) => w.contains('recommended range is 250–400')),
        isTrue,
      );
      expect(
        warnings.any((w) => w.contains('clearly outside')),
        isTrue,
      );
    });

    test('long cover letter fixture triggers ideal and clearly-bad warnings', () {
      final warnings = validator.validate(
        resumeMarkdown: fixture('good_resume.md'),
        coverLetterMarkdown: fixture('long_cover_letter.md'),
      );

      expect(
        warnings.any((w) => w.contains('recommended range is 250–400')),
        isTrue,
      );
      expect(
        warnings.any((w) => w.contains('clearly outside')),
        isTrue,
      );
    });

    test('warns on markdown tables in cover letter', () {
      final cover = '${fixture('good_cover_letter.md')}\n\n'
          '| A | B |\n| --- | --- |\n| 1 | 2 |\n';

      final warnings = validator.validate(
        resumeMarkdown: fixture('good_resume.md'),
        coverLetterMarkdown: cover,
      );

      expect(
        warnings,
        contains('Cover letter contains a markdown table; prefer plain prose.'),
      );
    });

    test('hard-fails on empty resume', () {
      expect(
        () => validator.validate(
          resumeMarkdown: '   ',
          coverLetterMarkdown: fixture('good_cover_letter.md'),
        ),
        throwsA(
          isA<AiMalformedResponseException>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('hard-fails on empty cover letter', () {
      expect(
        () => validator.validate(
          resumeMarkdown: fixture('good_resume.md'),
          coverLetterMarkdown: '\n',
        ),
        throwsA(isA<AiMalformedResponseException>()),
      );
    });

    test('hard-fails when resume lacks both Experience and Skills', () {
      const resume = '''
# Not A Resume
hello@example.com

## Summary
Just vibes.

## Education
School
''';

      expect(
        () => validator.validate(
          resumeMarkdown: resume,
          coverLetterMarkdown: fixture('good_cover_letter.md'),
        ),
        throwsA(
          isA<AiMalformedResponseException>().having(
            (e) => e.message,
            'message',
            contains('Experience and Skills'),
          ),
        ),
      );
    });

    test('does not hard-fail when only Experience is present', () {
      const resume = '''
# Pat
pat@example.com

## Experience
Role at Co
''';

      expect(
        () => validator.validate(
          resumeMarkdown: resume,
          coverLetterMarkdown: fixture('good_cover_letter.md'),
        ),
        returnsNormally,
      );
    });
  });
}
