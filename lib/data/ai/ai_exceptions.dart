/// Base class for AI data-layer failures.
sealed class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Invalid or missing API credentials (HTTP 401/403).
final class AiAuthException extends AiException {
  const AiAuthException([
    super.message = 'AI provider rejected the API token (unauthorized).',
  ]);
}

/// Provider rate limit exceeded (HTTP 429).
final class AiRateLimitException extends AiException {
  const AiRateLimitException([
    super.message = 'AI provider rate limit exceeded. Try again later.',
  ]);
}

/// Non-auth, non-rate-limit HTTP or API error from the provider.
final class AiApiException extends AiException {
  const AiApiException(super.message, {this.statusCode});

  final int? statusCode;
}

/// Model output could not be parsed into [GenerationArtifacts].
final class AiMalformedResponseException extends AiException {
  const AiMalformedResponseException([
    super.message = 'AI response was not valid GenerationArtifacts JSON.',
  ]);
}
