import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/ai_provider_kind.dart';
import '../../domain/app_settings.dart';
import 'default_models.dart';

/// Result of a minimal authenticated provider ping.
class ConnectionTestResult {
  const ConnectionTestResult.success([this.message = 'Connection successful'])
      : success = true;

  const ConnectionTestResult.failure(this.message) : success = false;

  final bool success;
  final String message;
}

/// Minimal authenticated HTTP ping per AI provider (independent of AiClient).
class SettingsConnectionTester {
  SettingsConnectionTester({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Performs a lightweight authenticated request for [settings.provider].
  Future<ConnectionTestResult> test(AppSettings settings) async {
    final token = settings.apiToken?.trim();
    if (token == null || token.isEmpty) {
      return const ConnectionTestResult.failure('API token is required');
    }

    try {
      return switch (settings.provider) {
        AiProviderKind.openai => await _testOpenAi(token),
        AiProviderKind.anthropic => await _testAnthropic(token),
        AiProviderKind.gemini => await _testGemini(token, settings.modelOverride),
      };
    } on http.ClientException catch (e) {
      return ConnectionTestResult.failure('Network error: ${e.message}');
    } catch (e) {
      return ConnectionTestResult.failure('Unexpected error: $e');
    }
  }

  Future<ConnectionTestResult> _testOpenAi(String token) async {
    final response = await _client.get(
      Uri.parse('https://api.openai.com/v1/models'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return _mapStatus(
      response.statusCode,
      response.body,
      okCodes: const {200},
      providerLabel: 'OpenAI',
    );
  }

  Future<ConnectionTestResult> _testAnthropic(String token) async {
    final response = await _client.get(
      Uri.parse('https://api.anthropic.com/v1/models'),
      headers: {
        'x-api-key': token,
        'anthropic-version': '2023-06-01',
      },
    );
    return _mapStatus(
      response.statusCode,
      response.body,
      okCodes: const {200},
      providerLabel: 'Anthropic',
    );
  }

  Future<ConnectionTestResult> _testGemini(
    String token,
    String? modelOverride,
  ) async {
    final model = DefaultModels.resolve(AiProviderKind.gemini, modelOverride);
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model',
    ).replace(queryParameters: {'key': token});

    final response = await _client.get(uri);
    return _mapStatus(
      response.statusCode,
      response.body,
      okCodes: const {200},
      providerLabel: 'Gemini',
    );
  }

  ConnectionTestResult _mapStatus(
    int statusCode,
    String body, {
    required Set<int> okCodes,
    required String providerLabel,
  }) {
    if (okCodes.contains(statusCode)) {
      return ConnectionTestResult.success('$providerLabel connection successful');
    }

    final detail = _extractErrorDetail(body);
    final suffix = detail == null ? '' : ': $detail';
    return ConnectionTestResult.failure(
      '$providerLabel returned HTTP $statusCode$suffix',
    );
  }

  String? _extractErrorDetail(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Non-JSON body — ignore.
    }
    return null;
  }
}
