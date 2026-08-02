import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_exceptions.dart';

/// Shared HTTP helpers for provider clients.
mixin AiHttpHelpers {
  /// Maps common provider status codes to typed exceptions.
  Never throwForStatus(http.Response response, {String provider = 'AI'}) {
    final code = response.statusCode;
    final body = _safeBodySnippet(response.body);

    if (code == 401 || code == 403) {
      throw AiAuthException(
        '$provider authentication failed (HTTP $code). Check your API token. $body',
      );
    }
    if (code == 429) {
      throw AiRateLimitException(
        '$provider rate limit exceeded (HTTP 429). $body',
      );
    }
    throw AiApiException(
      '$provider request failed (HTTP $code). $body',
      statusCode: code,
    );
  }

  String decodeUtf8Body(http.Response response) {
    return utf8.decode(response.bodyBytes);
  }

  String _safeBodySnippet(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 400) return trimmed;
    return '${trimmed.substring(0, 400)}…';
  }
}
