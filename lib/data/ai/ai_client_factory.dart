import 'package:http/http.dart' as http;

import '../../domain/ai_client.dart';
import '../../domain/ai_provider_kind.dart';
import 'anthropic_ai_client.dart';
import 'gemini_ai_client.dart';
import 'openai_ai_client.dart';

export 'ai_exceptions.dart';
export 'anthropic_ai_client.dart' show AnthropicAiClient, kDefaultAnthropicModel;
export 'artifacts_parser.dart';
export 'gemini_ai_client.dart' show GeminiAiClient, kDefaultGeminiModel;
export 'openai_ai_client.dart' show OpenAiClient, kDefaultOpenAiModel;

/// Creates a concrete [AiClient] for [kind].
///
/// [token] is the provider API key. [model] overrides the provider default
/// when non-null and non-empty. Optional [httpClient] is used for tests.
AiClient forProvider(
  AiProviderKind kind, {
  required String token,
  String? model,
  http.Client? httpClient,
}) {
  switch (kind) {
    case AiProviderKind.openai:
      return OpenAiClient(
        token: token,
        model: model,
        httpClient: httpClient,
      );
    case AiProviderKind.anthropic:
      return AnthropicAiClient(
        token: token,
        model: model,
        httpClient: httpClient,
      );
    case AiProviderKind.gemini:
      return GeminiAiClient(
        token: token,
        model: model,
        httpClient: httpClient,
      );
  }
}
