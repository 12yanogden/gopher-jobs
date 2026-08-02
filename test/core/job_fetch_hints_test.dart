import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/core/job_fetch_hints.dart';

void main() {
  group('shouldWarnMissingFetchProxy', () {
    test('is false off web', () {
      expect(
        shouldWarnMissingFetchProxy(isWeb: false, fetchProxyUrl: null),
        isFalse,
      );
    });

    test('is true on web without proxy', () {
      expect(
        shouldWarnMissingFetchProxy(isWeb: true, fetchProxyUrl: null),
        isTrue,
      );
      expect(
        shouldWarnMissingFetchProxy(isWeb: true, fetchProxyUrl: '  '),
        isTrue,
      );
    });

    test('is false on web with proxy configured', () {
      expect(
        shouldWarnMissingFetchProxy(
          isWeb: true,
          fetchProxyUrl: 'https://proxy.example/fetch',
        ),
        isFalse,
      );
    });
  });

  group('isLikelyCorsFailure', () {
    test('detects common browser CORS errors', () {
      expect(
        isLikelyCorsFailure(Exception('ClientException: CORS blocked')),
        isTrue,
      );
      expect(
        isLikelyCorsFailure(Exception('Failed to fetch')),
        isTrue,
      );
    });

    test('returns false for unrelated errors', () {
      expect(isLikelyCorsFailure(Exception('HTTP 403')), isFalse);
      expect(isLikelyCorsFailure(null), isFalse);
    });
  });
}
