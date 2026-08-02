import '../../core/errors.dart' as core;
import '../../domain/ai_client.dart';
import '../../domain/app_settings.dart';
import '../../domain/generation_artifacts.dart';
import '../../domain/generation_request.dart';
import '../../domain/generation_service.dart';
import '../../domain/job_fetch_service.dart';
import '../../domain/settings_repository.dart';
import '../ai/ai.dart' as ai;
import '../job_fetch/job_fetch_exceptions.dart';
import '../settings/default_models.dart';

/// Orchestrates settings → fetch → AI for [GenerationService].
class GenerationServiceImpl implements GenerationService {
  GenerationServiceImpl({
    required this.settingsRepository,
    required this.jobFetchService,
    AiClient Function(AppSettings settings)? aiClientFactory,
  }) : _aiClientFactory = aiClientFactory ?? _defaultAiClient;

  final SettingsRepository settingsRepository;
  final JobFetchService jobFetchService;
  final AiClient Function(AppSettings settings) _aiClientFactory;

  static AiClient _defaultAiClient(AppSettings settings) {
    final token = settings.apiToken?.trim() ?? '';
    final model =
        DefaultModels.resolve(settings.provider, settings.modelOverride);
    return ai.forProvider(settings.provider, token: token, model: model);
  }

  @override
  Future<GenerationArtifacts> generate({
    required Uri jobUrl,
    required String sourceMaterial,
  }) async {
    try {
      final settings = await settingsRepository.get();
      final token = settings.apiToken?.trim();
      if (token == null || token.isEmpty) {
        throw const core.SettingsException(
          'API token is missing. Add one in Settings before generating.',
        );
      }

      final job = await jobFetchService.fetch(
        jobUrl,
        proxyUrl: settings.fetchProxyUrl,
      );

      final client = _aiClientFactory(settings);
      return await client.generateArtifacts(
        GenerationRequest(
          job: job,
          sourceMaterial: sourceMaterial,
          settings: settings,
        ),
      );
    } on core.AppException {
      rethrow;
    } on JobFetchError catch (e) {
      throw core.JobFetchException(e.message, cause: e);
    } on ai.AiException catch (e) {
      throw core.AiException(e.message, cause: e);
    } catch (e) {
      throw core.GenerationException(
        'Generation failed: $e',
        cause: e,
      );
    }
  }
}
