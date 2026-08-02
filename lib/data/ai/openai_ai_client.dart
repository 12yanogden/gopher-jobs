import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/ai_client.dart';
import '../../domain/generation_artifacts.dart';
import '../../domain/generation_request.dart';
import '../../prompts/ats_prompts.dart';
import 'ai_exceptions.dart';
import 'ai_http.dart';
import 'artifacts_parser.dart';

/// Default OpenAI Chat Completions model.
const String kDefaultOpenAiModel = 'gpt-4o-mini';

/// OpenAI Chat Completions client returning JSON artifacts.
class OpenAiClient with AiHttpHelpers implements AiClient {
  OpenAiClient({
    required this.token,
    String? model,
    http.Client? httpClient,
    ArtifactsParser? parser,
    this.baseUrl = 'https://api.openai.com/v1',
  })  : model = (model == null || model.trim().isEmpty)
            ? kDefaultOpenAiModel
            : model.trim(),
        _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _parser = parser ?? const ArtifactsParser();

  final String token;
  final String model;
  final String baseUrl;
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
    final uri = Uri.parse('$baseUrl/chat/completions');
    final body = <String, dynamic>{
      'model': model,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': AtsPrompts.systemPrompt()},
        {'role': 'user', 'content': AtsPrompts.userPrompt(request)},
      ],
    };

    final response = await _http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throwForStatus(response, provider: 'OpenAI');
    }

    final content = _extractContent(decodeUtf8Body(response));
    try {
      return _parser.parse(content);
    } on AiMalformedResponseException {
      if (isRetry) rethrow;
      return _generateWithRetry(request, isRetry: true);
    }
  }

  String _extractContent(String responseBody) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(responseBody);
    } on FormatException catch (e) {
      throw AiMalformedResponseException(
        'OpenAI envelope JSON could not be decoded: ${e.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AiMalformedResponseException(
        'OpenAI envelope root must be an object.',
      );
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AiMalformedResponseException(
        'OpenAI response missing choices.',
      );
    }

    final first = choices.first;
    if (first is! Map) {
      throw const AiMalformedResponseException(
        'OpenAI choice was not an object.',
      );
    }

    final message = first['message'];
    if (message is! Map) {
      throw const AiMalformedResponseException(
        'OpenAI choice missing message.',
      );
    }

    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AiMalformedResponseException(
        'OpenAI message content was empty.',
      );
    }
    return content;
  }
}
