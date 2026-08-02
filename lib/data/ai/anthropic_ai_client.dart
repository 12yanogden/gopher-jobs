import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/ai_client.dart';
import '../../domain/generation_artifacts.dart';
import '../../domain/generation_request.dart';
import '../../prompts/ats_prompts.dart';
import 'ai_exceptions.dart';
import 'ai_http.dart';
import 'artifacts_parser.dart';

/// Default Anthropic Messages API model.
const String kDefaultAnthropicModel = 'claude-sonnet-4-20250514';

/// Anthropic Messages API client returning JSON artifacts.
class AnthropicAiClient with AiHttpHelpers implements AiClient {
  AnthropicAiClient({
    required this.token,
    String? model,
    http.Client? httpClient,
    ArtifactsParser? parser,
    this.baseUrl = 'https://api.anthropic.com/v1',
    this.anthropicVersion = '2023-06-01',
    this.maxTokens = 8192,
  })  : model = (model == null || model.trim().isEmpty)
            ? kDefaultAnthropicModel
            : model.trim(),
        _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _parser = parser ?? const ArtifactsParser();

  final String token;
  final String model;
  final String baseUrl;
  final String anthropicVersion;
  final int maxTokens;
  final http.Client _http;
  final bool _ownsClient;
  final ArtifactsParser _parser;

  void close() {
    if (_ownsClient) _http.close();
  }

  @override
  Future<GenerationArtifacts> generateArtifacts(
    GenerationRequest request,
  ) async {
    return _generateWithRetry(request, isRetry: false);
  }

  Future<GenerationArtifacts> _generateWithRetry(
    GenerationRequest request, {
    required bool isRetry,
  }) async {
    final uri = Uri.parse('$baseUrl/messages');
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'system': AtsPrompts.systemPrompt(),
      'messages': [
        {'role': 'user', 'content': AtsPrompts.userPrompt(request)},
      ],
    };

    final response = await _http.post(
      uri,
      headers: {
        'x-api-key': token,
        'anthropic-version': anthropicVersion,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throwForStatus(response, provider: 'Anthropic');
    }

    final content = _extractText(decodeUtf8Body(response));
    try {
      return _parser.parse(content);
    } on AiMalformedResponseException {
      if (isRetry) rethrow;
      return _generateWithRetry(request, isRetry: true);
    }
  }

  String _extractText(String responseBody) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException catch (e) {
      throw AiMalformedResponseException(
        'Anthropic envelope JSON could not be decoded: ${e.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AiMalformedResponseException(
        'Anthropic envelope root must be an object.',
      );
    }

    final content = decoded['content'];
    if (content is! List || content.isEmpty) {
      throw const AiMalformedResponseException(
        'Anthropic response missing content blocks.',
      );
    }

    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text') {
        final text = block['text'];
        if (text is String) buffer.write(text);
      }
    }

    final combined = buffer.toString().trim();
    if (combined.isEmpty) {
      throw const AiMalformedResponseException(
        'Anthropic response text was empty.',
      );
    }
    return combined;
  }
}
