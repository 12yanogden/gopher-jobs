/// Local typed failures for the job-fetch data layer.
///
/// Kept independent of `lib/core/errors.dart` because core exception types are
/// `final` / `sealed` and cannot be subclassed from this package layer.
sealed class JobFetchError implements Exception {
  const JobFetchError(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a job URL cannot be fetched over the network (direct or proxy).
final class JobFetchNetworkException extends JobFetchError {
  const JobFetchNetworkException(super.message, {super.cause});
}

/// Thrown when the fetched response has no usable HTML/text body.
final class JobFetchEmptyBodyException extends JobFetchError {
  const JobFetchEmptyBodyException(super.message, {super.cause});
}

/// Thrown when HTML was fetched but yielded no readable plain text.
final class JobFetchParseException extends JobFetchError {
  const JobFetchParseException(super.message, {super.cause});
}
