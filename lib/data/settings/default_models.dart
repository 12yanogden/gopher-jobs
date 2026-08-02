import '../../domain/ai_provider_kind.dart';

/// Sensible default model IDs when [AppSettings.modelOverride] is unset.
abstract final class DefaultModels {
  static const String openai = 'gpt-4o-mini';
  static const String anthropic = 'claude-sonnet-4-20250514';
  static const String gemini = 'gemini-2.0-flash';

  static String forProvider(AiProviderKind provider) => switch (provider) {
        AiProviderKind.openai => openai,
        AiProviderKind.anthropic => anthropic,
        AiProviderKind.gemini => gemini,
      };

  /// Resolves the effective model: override if non-empty, else provider default.
  static String resolve(AiProviderKind provider, String? modelOverride) {
    final trimmed = modelOverride?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return forProvider(provider);
  }
}
