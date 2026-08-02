import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai/ai.dart';
import '../data/generation/generation_service_impl.dart';
import '../data/job_fetch/job_fetch.dart';
import '../data/settings/default_models.dart';
import '../data/settings/settings_repository_impl.dart';
import '../core/errors.dart';
import 'ai_client.dart';
import 'app_settings.dart';
import 'generation_artifacts.dart';
import 'generation_service.dart';
import 'job_fetch_service.dart';
import 'settings_repository.dart';

/// Inputs from the last successful Generate submit (for regenerate).
class LastGenerationInput {
  const LastGenerationInput({
    required this.jobUrl,
    required this.sourceMaterial,
  });

  final Uri jobUrl;
  final String sourceMaterial;
}

/// Shared settings repository used by Settings UI (via local aliases) and
/// generation / AI providers.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});

final jobFetchServiceProvider = Provider<JobFetchService>((ref) {
  final service = HttpJobFetchService();
  ref.onDispose(service.dispose);
  return service;
});

/// Sync AI client from the latest loaded [appSettingsProvider] snapshot.
///
/// Throws [SettingsException] when settings are not ready or the token is
/// missing. Prefer [generationServiceProvider] for end-to-end generation.
final aiClientProvider = Provider<AiClient>((ref) {
  final settings = ref.watch(appSettingsProvider).maybeWhen(
        data: (value) => value,
        orElse: () => null,
      );
  if (settings == null) {
    throw const SettingsException('Settings are still loading.');
  }
  final token = settings.apiToken?.trim();
  if (token == null || token.isEmpty) {
    throw const SettingsException(
      'API token is missing. Add one in Settings before generating.',
    );
  }
  final model = DefaultModels.resolve(settings.provider, settings.modelOverride);
  return forProvider(settings.provider, token: token, model: model);
});

final generationServiceProvider = Provider<GenerationService>((ref) {
  final impl = GenerationServiceImpl(
    settingsRepository: ref.watch(settingsRepositoryProvider),
    jobFetchService: ref.watch(jobFetchServiceProvider),
  );
  return _RecordingGenerationService(ref, impl);
});

/// Records successful generate inputs on [lastGenerationInputProvider].
class _RecordingGenerationService implements GenerationService {
  _RecordingGenerationService(this._ref, this._inner);

  final Ref _ref;
  final GenerationService _inner;

  @override
  Future<GenerationArtifacts> generate({
    required Uri jobUrl,
    required String sourceMaterial,
  }) async {
    final artifacts = await _inner.generate(
      jobUrl: jobUrl,
      sourceMaterial: sourceMaterial,
    );
    _ref.read(lastGenerationInputProvider.notifier).state = LastGenerationInput(
      jobUrl: jobUrl,
      sourceMaterial: sourceMaterial,
    );
    return artifacts;
  }
}

/// Latest settings snapshot loaded from [settingsRepositoryProvider].
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(settingsRepositoryProvider).get();
});

/// Latest generation result held for the Results tab.
final generationArtifactsProvider =
    StateProvider<GenerationArtifacts?>((ref) => null);

/// Last Generate form inputs (optional; for regenerate flows).
final lastGenerationInputProvider =
    StateProvider<LastGenerationInput?>((ref) => null);

/// Bottom [NavigationBar] selected index (0 Generate, 1 Results, 2 Settings).
final selectedTabIndexProvider = StateProvider<int>((ref) => 0);
