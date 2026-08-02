import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/ai/ai_exceptions.dart';
import 'package:gopher_jobs/data/ai/artifacts_parser.dart';

void main() {
  const parser = ArtifactsParser();

  String fixture(String name) =>
      File('test/fixtures/ats/$name').readAsStringSync();

  String jsonArtifacts({
    required String resume,
    required String cover,
  }) =>
      jsonEncode({
        'resumeMarkdown': resume,
        'coverLetterMarkdown': cover,
      });

  /// Minimal resume that passes hard-fail (has Experience).
  const minimalResume = '''
# Alex
alex@example.com

## Experience
Developer | Co
''';

  group('ArtifactsParser', () {
    test('parses valid JSON object', () {
      final raw = jsonArtifacts(
        resume: '# Jane Doe\n\n## Experience\n- Built apps',
        cover: 'Dear Hiring Manager,\n\nI am excited.',
      );

      final artifacts = parser.parse(raw);

      expect(artifacts.resumeMarkdown, contains('Jane Doe'));
      expect(artifacts.coverLetterMarkdown, contains('Hiring Manager'));
    });

    test('parses JSON wrapped in markdown fences', () {
      final raw = '''
```json
${jsonArtifacts(resume: minimalResume, cover: 'Cover body with enough tokens')}
```
''';

      final artifacts = parser.parse(raw);

      expect(artifacts.resumeMarkdown, minimalResume);
      expect(
        artifacts.coverLetterMarkdown,
        'Cover body with enough tokens',
      );
    });

    test('extracts JSON object from surrounding prose', () {
      final payload = jsonArtifacts(resume: minimalResume, cover: 'Cover');
      final raw = 'Sure!\n$payload\nThanks';

      final artifacts = parser.parse(raw);

      expect(artifacts.resumeMarkdown, minimalResume);
      expect(artifacts.coverLetterMarkdown, 'Cover');
    });

    test('throws when resumeMarkdown missing', () {
      expect(
        () => parser.parse('{"coverLetterMarkdown": "C"}'),
        throwsA(isA<AiMalformedResponseException>()),
      );
    });

    test('throws when fields are empty strings', () {
      expect(
        () => parser.parse(
          '{"resumeMarkdown": "  ", "coverLetterMarkdown": "C"}',
        ),
        throwsA(isA<AiMalformedResponseException>()),
      );
    });

    test('throws on non-JSON input', () {
      expect(
        () => parser.parse('not json at all'),
        throwsA(isA<AiMalformedResponseException>()),
      );
    });

    test('tryParse returns null on malformed input', () {
      expect(parser.tryParse('nope'), isNull);
    });

    test('tryParse returns artifacts on success', () {
      final result = parser.tryParse(
        jsonArtifacts(resume: minimalResume, cover: 'C'),
      );
      expect(result, isNotNull);
      expect(result!.resumeMarkdown, minimalResume);
    });

    test('populates atsWarnings from structure validator on success', () {
      final artifacts = parser.parse(
        jsonArtifacts(
          resume: fixture('tabled_resume.md'),
          cover: fixture('long_cover_letter.md'),
        ),
      );

      expect(artifacts.atsWarnings, isNotEmpty);
      expect(
        artifacts.atsWarnings.any((w) => w.contains('markdown table')),
        isTrue,
      );
      expect(
        artifacts.atsWarnings.any((w) => w.contains('recommended range')),
        isTrue,
      );
    });

    test('good fixtures parse with empty atsWarnings', () {
      final artifacts = parser.parse(
        jsonArtifacts(
          resume: fixture('good_resume.md'),
          cover: fixture('good_cover_letter.md'),
        ),
      );

      expect(artifacts.atsWarnings, isEmpty);
    });

    test('hard-fails when resume lacks Experience and Skills', () {
      expect(
        () => parser.parse(
          jsonArtifacts(
            resume: '# Title only\n\n## Summary\nHi',
            cover: fixture('good_cover_letter.md'),
          ),
        ),
        throwsA(isA<AiMalformedResponseException>()),
      );
    });

    test('tryParse returns null on ATS hard-fail', () {
      expect(
        parser.tryParse(
          jsonArtifacts(
            resume: '# Not a resume',
            cover: 'Cover text',
          ),
        ),
        isNull,
      );
    });
  });
}
