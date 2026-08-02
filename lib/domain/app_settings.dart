import 'ai_provider_kind.dart';

/// User-configurable app settings for AI and fetch behavior.
class AppSettings {
  const AppSettings({
    required this.provider,
    this.apiToken,
    this.modelOverride,
    this.fetchProxyUrl,
  });

  final AiProviderKind provider;
  final String? apiToken;
  final String? modelOverride;
  final String? fetchProxyUrl;

  AppSettings copyWith({
    AiProviderKind? provider,
    String? apiToken,
    String? modelOverride,
    String? fetchProxyUrl,
    bool clearApiToken = false,
    bool clearModelOverride = false,
    bool clearFetchProxyUrl = false,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      apiToken: clearApiToken ? null : (apiToken ?? this.apiToken),
      modelOverride:
          clearModelOverride ? null : (modelOverride ?? this.modelOverride),
      fetchProxyUrl:
          clearFetchProxyUrl ? null : (fetchProxyUrl ?? this.fetchProxyUrl),
    );
  }
}
