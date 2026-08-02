import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ai_provider_kind.dart';
import '../../domain/app_settings.dart';
import '../../domain/settings_repository.dart';
import 'token_storage.dart';

/// Persists [AppSettings]: API token in secure storage; other fields in
/// SharedPreferences.
///
/// Wave 2 Orchestrate should wire this via [settingsRepositoryProvider].
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    SharedPreferences? sharedPreferences,
    TokenStorage? tokenStorage,
  })  : _prefs = sharedPreferences,
        _tokenStorage = tokenStorage ?? SecureTokenStorage();

  static const _providerKey = 'gopher_jobs_provider';
  static const _modelOverrideKey = 'gopher_jobs_model_override';
  static const _fetchProxyUrlKey = 'gopher_jobs_fetch_proxy_url';

  SharedPreferences? _prefs;
  final TokenStorage _tokenStorage;

  Future<SharedPreferences> _preferences() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<AppSettings> get() async {
    final prefs = await _preferences();
    final providerName = prefs.getString(_providerKey);
    final provider = _parseProvider(providerName) ?? AiProviderKind.openai;
    final modelOverride = _emptyToNull(prefs.getString(_modelOverrideKey));
    final fetchProxyUrl = _emptyToNull(prefs.getString(_fetchProxyUrlKey));
    final apiToken = _emptyToNull(await _tokenStorage.read());

    return AppSettings(
      provider: provider,
      apiToken: apiToken,
      modelOverride: modelOverride,
      fetchProxyUrl: fetchProxyUrl,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await _preferences();
    await prefs.setString(_providerKey, settings.provider.name);

    final model = settings.modelOverride?.trim();
    if (model == null || model.isEmpty) {
      await prefs.remove(_modelOverrideKey);
    } else {
      await prefs.setString(_modelOverrideKey, model);
    }

    final proxy = settings.fetchProxyUrl?.trim();
    if (proxy == null || proxy.isEmpty) {
      await prefs.remove(_fetchProxyUrlKey);
    } else {
      await prefs.setString(_fetchProxyUrlKey, proxy);
    }

    await _tokenStorage.write(settings.apiToken?.trim());
  }

  static AiProviderKind? _parseProvider(String? name) {
    if (name == null) return null;
    for (final kind in AiProviderKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
