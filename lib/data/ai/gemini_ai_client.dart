import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/ai_client.dart';
import '../../domain/generation_artifacts.dart';
import '../../domain/generation_request.dart';
import '../../prompts/ats_prompts.dart';
import 'ai_exceptions.dart';
import 'ai_http.dart';
import 'artifacts_parser.dart';

/// Default Gemini generateContent model.
const String kDefaultGeminiModel = 'gemini-2.0-flash';

/// Google Gemini generateContent client returning JSON artifacts.
class GeminiAiClient with AiHttpHelpers implements AiClient {
  GeminiAiClient({
    required this.token,
    String? model,
    http.Client? httpClient,
    ArtifactsParser? parser,
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  })  : model = (model == null || model.trim().isEmpty)
            ? kDefaultGeminiModel
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
    final uri = Uri.parse(
      '$baseUrl/models/$model:generateContent',
    ).replace(queryParameters: {'key': token});

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': AtsPrompts.systemPrompt()},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': AtsPrompts.userPrompt(request)},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
    };

    final response = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throwForStatus(response, provider: 'Gemini');
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
        'Gemini envelope JSON could not be decoded: ${e.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AiMalformedResponseException(
        'Gemini envelope root must be an object.',
      );
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiMalformedResponseException(
        'Gemini response missing candidates.',
      );
    }

    final first = candidates.first;
    if (first is! Map) {
      throw const AiMalformedResponseException(
        'Gemini candidate was not an object.',
      );
    }

    final content = first['content'];
    if (content is! Map) {
      throw const AiMalformedResponseException(
        'Gemini candidate missing content.',
      );
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const AiMalformedResponseException(
        'Gemini content missing parts.',
      );
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map) {
        final text = part['text'];
        if (text is String) buffer.write(text);
      }
    }

    final combined = buffer.toString().trim();
    if (combined.isEmpty) {
      throw const AiMalformedResponseException(
        'Gemini response text was empty.',
      );
    }
    return combined;
  }
}
