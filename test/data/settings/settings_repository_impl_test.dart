import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/settings/default_models.dart';
import 'package:gopher_jobs/data/settings/settings_repository_impl.dart';
import 'package:gopher_jobs/data/settings/token_storage.dart';
import 'package:gopher_jobs/domain/ai_provider_kind.dart';
import 'package:gopher_jobs/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultModels', () {
    test('provides expected defaults per provider', () {
      expect(DefaultModels.forProvider(AiProviderKind.openai), 'gpt-4o-mini');
      expect(
        DefaultModels.forProvider(AiProviderKind.anthropic),
        'claude-sonnet-4-20250514',
      );
      expect(
        DefaultModels.forProvider(AiProviderKind.gemini),
        'gemini-2.0-flash',
      );
    });

    test('resolve prefers non-empty override', () {
      expect(
        DefaultModels.resolve(AiProviderKind.openai, ' gpt-4o '),
        'gpt-4o',
      );
      expect(
        DefaultModels.resolve(AiProviderKind.openai, '  '),
        'gpt-4o-mini',
      );
      expect(
        DefaultModels.resolve(AiProviderKind.openai, null),
        'gpt-4o-mini',
      );
    });
  });

  group('SettingsRepositoryImpl', () {
    late InMemoryTokenStorage tokenStorage;
    late SettingsRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tokenStorage = InMemoryTokenStorage();
      final prefs = await SharedPreferences.getInstance();
      repository = SettingsRepositoryImpl(
        sharedPreferences: prefs,
        tokenStorage: tokenStorage,
      );
    });

    test('get returns openai defaults when empty', () async {
      final settings = await repository.get();
      expect(settings.provider, AiProviderKind.openai);
      expect(settings.apiToken, isNull);
      expect(settings.modelOverride, isNull);
      expect(settings.fetchProxyUrl, isNull);
    });

    test('save then get round-trips all fields', () async {
      const original = AppSettings(
        provider: AiProviderKind.anthropic,
        apiToken: 'sk-test-token',
        modelOverride: 'claude-sonnet-4-20250514',
        fetchProxyUrl: 'https://proxy.example.com',
      );

      await repository.save(original);
      final loaded = await repository.get();

      expect(loaded.provider, AiProviderKind.anthropic);
      expect(loaded.apiToken, 'sk-test-token');
      expect(loaded.modelOverride, 'claude-sonnet-4-20250514');
      expect(loaded.fetchProxyUrl, 'https://proxy.example.com');
    });

    test('token survives in secure storage across repository instances', () async {
      await repository.save(
        const AppSettings(
          provider: AiProviderKind.gemini,
          apiToken: 'gemini-key',
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final second = SettingsRepositoryImpl(
        sharedPreferences: prefs,
        tokenStorage: tokenStorage,
      );
      final loaded = await second.get();

      expect(loaded.provider, AiProviderKind.gemini);
      expect(loaded.apiToken, 'gemini-key');
    });

    test('empty strings clear optional fields', () async {
      await repository.save(
        const AppSettings(
          provider: AiProviderKind.openai,
          apiToken: 'tok',
          modelOverride: 'gpt-4o',
          fetchProxyUrl: 'https://proxy.example.com',
        ),
      );

      await repository.save(
        const AppSettings(
          provider: AiProviderKind.openai,
          apiToken: '  ',
          modelOverride: '',
          fetchProxyUrl: '   ',
        ),
      );

      final loaded = await repository.get();
      expect(loaded.apiToken, isNull);
      expect(loaded.modelOverride, isNull);
      expect(loaded.fetchProxyUrl, isNull);
    });
  });
}
