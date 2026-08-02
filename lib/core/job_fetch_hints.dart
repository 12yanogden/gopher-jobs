import 'package:flutter/foundation.dart';

/// True on web when no job-fetch proxy is configured in Settings.
bool shouldWarnMissingFetchProxy({
  String? fetchProxyUrl,
  @visibleForTesting bool? isWeb,
}) {
  final onWeb = isWeb ?? kIsWeb;
  if (!onWeb) return false;
  final proxy = fetchProxyUrl?.trim();
  return proxy == null || proxy.isEmpty;
}

/// Human-readable detail text from an exception [cause], if any.
String? formatErrorDetails(Object? cause) {
  if (cause == null) return null;
  final text = cause.toString().trim();
  if (text.isEmpty) return null;
  return text;
}

/// Heuristic: browser blocked a cross-origin read (CORS / ClientException).
bool isLikelyCorsFailure(Object? cause) {
  if (cause == null) return false;
  final text = cause.toString().toLowerCase();
  return text.contains('cors') ||
      text.contains('clientexception') ||
      text.contains('failed to fetch') ||
      text.contains('xmlhttprequest error') ||
      text.contains('network error');
}

/// Short hint when [cause] looks like a CORS failure.
String corsHintForCause(Object? cause) {
  if (!isLikelyCorsFailure(cause)) return '';
  return 'The browser blocked reading this page (CORS). The URL works in a '
      'tab but not from this app without a fetch proxy.';
}
