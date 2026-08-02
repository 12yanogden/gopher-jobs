import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/core/errors.dart' as core;
import 'package:gopher_jobs/data/ai/ai_exceptions.dart' as ai;
import 'package:gopher_jobs/data/generation/generation_service_impl.dart';
import 'package:gopher_jobs/data/job_fetch/job_fetch_exceptions.dart';
import 'package:gopher_jobs/domain/ai_client.dart';
import 'package:gopher_jobs/domain/ai_provider_kind.dart';
import 'package:gopher_jobs/domain/app_settings.dart';
import 'package:gopher_jobs/domain/generation_artifacts.dart';
import 'package:gopher_jobs/domain/generation_request.dart';
import 'package:gopher_jobs/domain/job_fetch_service.dart';
import 'package:gopher_jobs/domain/job_posting.dart';
import 'package:gopher_jobs/domain/settings_repository.dart';

void main() {
  final jobUrl = Uri.parse('https://example.com/jobs/1');
  const source = 'Senior Flutter engineer with 5 years experience.';

  group('GenerationServiceImpl', () {
    test('throws SettingsException when API token is missing', () async {
      final service = GenerationServiceImpl(
        settingsRepository: _FakeSettingsRepository(
          const AppSettings(provider: AiProviderKind.openai),
        ),
        jobFetchService: _FakeJobFetchService(),
        aiClientFactory: (_) => _FakeAiClient(),
      );

      expect(
        () => service.generate(jobUrl: jobUrl, sourceMaterial: source),
        throwsA(isA<core.SettingsException>()),
      );
    });

    test('throws SettingsException when API token is blank', () async {
      final service = GenerationServiceImpl(
        settingsRepository: _FakeSettingsRepository(
          const AppSettings(
            provider: AiProviderKind.openai,
            apiToken: '   ',
          ),
        ),
        jobFetchService: _FakeJobFetchService(),
        aiClientFactory: (_) => _FakeAiClient(),
      );

      expect(
        () => service.generate(jobUrl: jobUrl, sourceMaterial: source),
        throwsA(isA<core.SettingsException>()),
      );
    });

    test('maps JobFetchError to core JobFetchException', () async {
      final service = GenerationServiceImpl(
        settingsRepository: _FakeSettingsRepository(
          const AppSettings(
            provider: AiProviderKind.openai,
            apiToken: 'sk-test',
            fetchProxyUrl: 'https://proxy.example.com',
          ),
        ),
        jobFetchService: _FakeJobFetchService(
          error: const JobFetchNetworkException('network down'),
        ),
        aiClientFactory: (_) => _FakeAiClient(),
      );

      expect(
        () => service.generate(jobUrl: jobUrl, sourceMaterial: source),
        throwsA(
          isA<core.JobFetchException>().having(
            (e) => e.message,
            'message',
            'network down',
          ),
        ),
      );
    });

    test('maps ai AiException to core AiException', () async {
      final service = GenerationServiceImpl(
        settingsRepository: _FakeSettingsRepository(
          const AppSettings(
            provider: AiProviderKind.openai,
            apiToken: 'sk-test',
          ),
        ),
        jobFetchService: _FakeJobFetchService(),
        aiClientFactory: (_) => _FakeAiClient(
          error: const ai.AiAuthException('bad token'),
        ),
      );

      expect(
        () => service.generate(jobUrl: jobUrl, sourceMaterial: source),
        throwsA(
          isA<core.AiException>().having(
            (e) => e.message,
            'message',
            'bad token',
          ),
        ),
      );
    });

    test('fetches job with proxy and returns AI artifacts', () async {
      final fetch = _FakeJobFetchService();
      final aiClient = _FakeAiClient(
        artifacts: const GenerationArtifacts(
          resumeMarkdown: '# Resume',
          coverLetterMarkdown: '# Cover',
        ),
      );
      AppSettings? settingsSeenByFactory;

      final service = GenerationServiceImpl(
        settingsRepository: _FakeSettingsRepository(
          const AppSettings(
            provider: AiProviderKind.anthropic,
            apiToken: 'sk-ant',
            modelOverride: 'claude-custom',
            fetchProxyUrl: 'https://proxy.example.com',
          ),
        ),
        jobFetchService: fetch,
        aiClientFactory: (settings) {
          settingsSeenByFactory = settings;
          return aiClient;
        },
      );

      final artifacts = await service.generate(
        jobUrl: jobUrl,
        sourceMaterial: source,
      );

      expect(fetch.lastUrl, jobUrl);
      expect(fetch.lastProxyUrl, 'https://proxy.example.com');
      expect(settingsSeenByFactory?.apiToken, 'sk-ant');
      expect(aiClient.lastRequest?.sourceMaterial, source);
      expect(aiClient.lastRequest?.job.plainText, 'Job body');
      expect(artifacts.resumeMarkdown, '# Resume');
      expect(artifacts.coverLetterMarkdown, '# Cover');
    });

    test('wraps unexpected errors in GenerationException', () async {
      final service = GenerationServiceImpl(
        settingsRepository: _FakeSettingsRepository(
          const AppSettings(
            provider: AiProviderKind.openai,
            apiToken: 'sk-test',
          ),
        ),
        jobFetchService: _FakeJobFetchService(
          error: StateError('boom'),
        ),
        aiClientFactory: (_) => _FakeAiClient(),
      );

      expect(
        () => service.generate(jobUrl: jobUrl, sourceMaterial: source),
        throwsA(isA<core.GenerationException>()),
      );
    });
  });
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this._settings);

  final AppSettings _settings;

  @override
  Future<AppSettings> get() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {}
}

class _FakeJobFetchService implements JobFetchService {
  _FakeJobFetchService({this.error});

  final Object? error;
  Uri? lastUrl;
  String? lastProxyUrl;

  @override
  Future<JobPosting> fetch(Uri url, {String? proxyUrl}) async {
    lastUrl = url;
    lastProxyUrl = proxyUrl;
    if (error != null) throw error!;
    return JobPosting(
      url: url,
      plainText: 'Job body',
      fetchedAt: DateTime.utc(2026, 1, 1),
      title: 'Engineer',
    );
  }
}

class _FakeAiClient implements AiClient {
  _FakeAiClient({this.artifacts, this.error});

  final GenerationArtifacts? artifacts;
  final Object? error;
  GenerationRequest? lastRequest;

  @override
  Future<GenerationArtifacts> generateArtifacts(
    GenerationRequest request,
  ) async {
    lastRequest = request;
    if (error != null) throw error!;
    return artifacts ??
        const GenerationArtifacts(
          resumeMarkdown: '',
          coverLetterMarkdown: '',
        );
  }
}
