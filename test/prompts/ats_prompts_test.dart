import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/domain/app_settings.dart';
import 'package:gopher_jobs/domain/ai_provider_kind.dart';
import 'package:gopher_jobs/domain/generation_request.dart';
import 'package:gopher_jobs/domain/job_posting.dart';
import 'package:gopher_jobs/prompts/ats_prompts.dart';

void main() {
  group('AtsPrompts', () {
    test('systemPrompt requires grounding, ATS rules, and JSON schema', () {
      final system = AtsPrompts.systemPrompt();

      expect(system, contains('ONLY facts'));
      expect(system, contains('Do NOT invent'));
      expect(system, contains('ATS'));
      expect(system, contains('No tables'));
      expect(system, contains('resumeMarkdown'));
      expect(system, contains('coverLetterMarkdown'));
      expect(system, contains('JSON'));
    });

    test('systemPrompt encodes required resume headings and experience format', () {
      final system = AtsPrompts.systemPrompt();

      expect(system, contains('Contact, Summary, Skills, Experience, Education'));
      expect(system, contains('Certifications'));
      expect(system, contains('Projects'));
      expect(system, contains('Job Title | Company | Location'));
      expect(system, contains('Mon YYYY'));
      expect(system, contains('Present'));
      expect(system, contains('comma-separated'));
      expect(system, contains('keyword stuffing'));
      expect(system, contains('skill bars'));
      expect(system, contains('Expand critical acronyms'));
    });

    test('systemPrompt encodes cover letter structure and bans', () {
      final system = AtsPrompts.systemPrompt();

      expect(system, contains('250–400 words'));
      expect(system, contains('greeting'));
      expect(system, contains('hook'));
      expect(system, contains('3–6'));
      expect(system, contains('company-specific'));
      expect(system, contains('I am writing to express my interest'));
      expect(system, contains('passionate'));
      expect(system, contains('synergistic'));
      expect(system, contains('thrilled to apply'));
    });

    test('systemPrompt requires mirroring supported JD title and hard skills', () {
      final system = AtsPrompts.systemPrompt();

      expect(system, contains('exact JD job title'));
      expect(system, contains('hard skills'));
      expect(system, contains('Summary, Skills, AND Experience'));
    });

    test('userPrompt includes job, source material, and silent skill extraction', () {
      final job = JobPosting(
        url: Uri.parse('https://example.com/jobs/42'),
        title: 'Staff Flutter Engineer',
        plainText: 'Build Flutter apps. Need Dart and Riverpod.',
        fetchedAt: DateTime.utc(2026, 8, 1),
      );
      final request = GenerationRequest(
        job: job,
        sourceMaterial: 'Ryan — 5 years Dart at Acme Corp.',
        settings: const AppSettings(provider: AiProviderKind.openai),
      );

      final user = AtsPrompts.userPrompt(request);

      expect(user, contains('https://example.com/jobs/42'));
      expect(user, contains('Staff Flutter Engineer'));
      expect(user, contains('Build Flutter apps'));
      expect(user, contains('Ryan — 5 years Dart at Acme Corp.'));
      expect(user, contains('silently extract'));
      expect(user, contains('top required skills'));
      expect(user, contains('ONLY JSON'));
      expect(user, contains('resumeMarkdown'));
      expect(user, contains('coverLetterMarkdown'));
    });

    test('userPromptFromParts handles missing title', () {
      final job = JobPosting(
        url: Uri.parse('https://example.com/j'),
        plainText: 'JD text',
        fetchedAt: DateTime.utc(2026, 1, 1),
      );

      final user = AtsPrompts.userPromptFromParts(
        job: job,
        sourceMaterial: 'My resume notes',
      );

      expect(user, contains('(title unknown)'));
      expect(user, contains('JD text'));
      expect(user, contains('My resume notes'));
    });
  });
}
