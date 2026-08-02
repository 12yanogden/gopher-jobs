import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/ai/ai_client_factory.dart';
import 'package:gopher_jobs/domain/ai_provider_kind.dart';
import 'package:gopher_jobs/domain/app_settings.dart';
import 'package:gopher_jobs/domain/generation_request.dart';
import 'package:gopher_jobs/domain/job_posting.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

GenerationRequest _sampleRequest() {
  return GenerationRequest(
    job: JobPosting(
      url: Uri.parse('https://example.com/job'),
      title: 'Engineer',
      plainText: 'Need Dart.',
      fetchedAt: DateTime.utc(2026, 8, 1),
    ),
    sourceMaterial: 'Built Dart apps at Acme.',
    settings: const AppSettings(provider: AiProviderKind.openai),
  );
}

const _stubResumeMarkdown = '''
# Jane Doe
jane.doe@example.com | (555) 123-4567

## Summary
Flutter engineer with experience shipping Dart applications.

## Skills
Dart, Flutter, REST APIs

## Experience
Software Engineer | Acme | 2021 – Present
- Built Dart apps at Acme

## Education
B.S. Computer Science | State University | 2018
''';

const _stubCoverLetterMarkdown =
    'Dear Hiring Manager, I am excited to apply for this role. '
    'My experience building Dart and Flutter applications aligns with your needs. '
    'Thank you for your consideration. Sincerely, Jane Doe.';

String _artifactsJson() => jsonEncode({
      'resumeMarkdown': _stubResumeMarkdown,
      'coverLetterMarkdown': _stubCoverLetterMarkdown,
    });

void main() {
  group('forProvider', () {
    test('returns OpenAiClient for openai', () {
      final client = forProvider(AiProviderKind.openai, token: 'sk-test');
      expect(client, isA<OpenAiClient>());
      expect((client as OpenAiClient).model, kDefaultOpenAiModel);
    });

    test('returns AnthropicAiClient for anthropic', () {
      final client = forProvider(AiProviderKind.anthropic, token: 'ant-test');
      expect(client, isA<AnthropicAiClient>());
      expect((client as AnthropicAiClient).model, kDefaultAnthropicModel);
    });

    test('returns GeminiAiClient for gemini with model override', () {
      final client = forProvider(
        AiProviderKind.gemini,
        token: 'gem-test',
        model: 'gemini-1.5-pro',
      );
      expect(client, isA<GeminiAiClient>());
      expect((client as GeminiAiClient).model, 'gemini-1.5-pro');
    });
  });

  group('OpenAiClient', () {
    test('parses successful chat completion', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/chat/completions'));
        expect(request.headers['Authorization'], 'Bearer sk-test');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['model'], kDefaultOpenAiModel);
        expect(payload['response_format'], {'type': 'json_object'});

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': _artifactsJson()},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OpenAiClient(token: 'sk-test', httpClient: mock);
      final artifacts = await client.generateArtifacts(_sampleRequest());
      expect(artifacts.resumeMarkdown, _stubResumeMarkdown);
      expect(artifacts.coverLetterMarkdown, _stubCoverLetterMarkdown);
    });

    test('throws AiAuthException on 401', () async {
      final mock = MockClient(
        (_) async => http.Response('unauthorized', 401),
      );
      final client = OpenAiClient(token: 'bad', httpClient: mock);

      await expectLater(
        client.generateArtifacts(_sampleRequest()),
        throwsA(isA<AiAuthException>()),
      );
    });

    test('throws AiRateLimitException on 429', () async {
      final mock = MockClient(
        (_) async => http.Response('slow down', 429),
      );
      final client = OpenAiClient(token: 'sk', httpClient: mock);

      await expectLater(
        client.generateArtifacts(_sampleRequest()),
        throwsA(isA<AiRateLimitException>()),
      );
    });

    test('retries once on malformed content then succeeds', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        final content = calls == 1
            ? 'not-json'
            : _artifactsJson();
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': content},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OpenAiClient(token: 'sk', httpClient: mock);
      final artifacts = await client.generateArtifacts(_sampleRequest());
      expect(calls, 2);
      expect(artifacts.resumeMarkdown, _stubResumeMarkdown);
    });

    test('rethrows after second malformed response', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'still bad'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OpenAiClient(token: 'sk', httpClient: mock);
      await expectLater(
        client.generateArtifacts(_sampleRequest()),
        throwsA(isA<AiMalformedResponseException>()),
      );
    });
  });

  group('AnthropicAiClient', () {
    test('parses successful messages response', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, endsWith('/messages'));
        expect(request.headers['x-api-key'], 'ant-key');
        expect(request.headers['anthropic-version'], isNotEmpty);

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': _artifactsJson()},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AnthropicAiClient(token: 'ant-key', httpClient: mock);
      final artifacts = await client.generateArtifacts(_sampleRequest());
      expect(artifacts.coverLetterMarkdown, _stubCoverLetterMarkdown);
    });

    test('throws AiAuthException on 403', () async {
      final mock = MockClient(
        (_) async => http.Response('forbidden', 403),
      );
      final client = AnthropicAiClient(token: 'bad', httpClient: mock);

      await expectLater(
        client.generateArtifacts(_sampleRequest()),
        throwsA(isA<AiAuthException>()),
      );
    });
  });

  group('GeminiAiClient', () {
    test('parses successful generateContent response', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, contains('/models/'));
        expect(request.url.path, contains(':generateContent'));
        expect(request.url.queryParameters['key'], 'gem-key');

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': _artifactsJson()},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = GeminiAiClient(token: 'gem-key', httpClient: mock);
      final artifacts = await client.generateArtifacts(_sampleRequest());
      expect(artifacts.resumeMarkdown, _stubResumeMarkdown);
    });

    test('throws AiRateLimitException on 429', () async {
      final mock = MockClient(
        (_) async => http.Response('quota', 429),
      );
      final client = GeminiAiClient(token: 'gem', httpClient: mock);

      await expectLater(
        client.generateArtifacts(_sampleRequest()),
        throwsA(isA<AiRateLimitException>()),
      );
    });
  });
}
