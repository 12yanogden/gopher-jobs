/// Base type for app-level failures.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a job URL cannot be fetched or parsed.
final class JobFetchException extends AppException {
  const JobFetchException(super.message, {super.cause});
}

/// Thrown when an AI provider call fails.
final class AiException extends AppException {
  const AiException(super.message, {super.cause});
}

/// Thrown when settings are missing or invalid for an operation.
final class SettingsException extends AppException {
  const SettingsException(super.message, {super.cause});
}

/// Thrown when generation orchestration fails.
final class GenerationException extends AppException {
  const GenerationException(super.message, {super.cause});
}
