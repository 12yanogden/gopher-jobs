import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/job_fetch_service.dart';
import '../../domain/job_posting.dart';
import 'html_text_extractor.dart';
import 'job_fetch_exceptions.dart';

/// Fetches a job posting URL over HTTP and normalizes it to plain text.
///
/// On direct-request network/CORS failure, retries through [proxyUrl] when
/// provided: `{proxyUrl}?url={encodedJobUrl}`, expecting raw HTML/text.
class HttpJobFetchService implements JobFetchService {
  HttpJobFetchService({
    http.Client? client,
    HtmlTextExtractor? extractor,
    DateTime Function()? clock,
    this.userAgent = defaultUserAgent,
  })  : _client = client ?? http.Client(),
        _extractor = extractor ?? const HtmlTextExtractor(),
        _clock = clock ?? DateTime.now,
        _ownsClient = client == null;

  /// Browser-like User-Agent sent on outbound GETs where the platform allows it.
  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

  final http.Client _client;
  final HtmlTextExtractor _extractor;
  final DateTime Function() _clock;
  final bool _ownsClient;
  final String userAgent;

  /// Closes the underlying [http.Client] when this service created it.
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<JobPosting> fetch(Uri url, {String? proxyUrl}) async {
    final raw = await _fetchRawHtml(url, proxyUrl: proxyUrl);
    final extracted = _extractor.extract(raw);
    if (extracted.plainText.isEmpty) {
      throw const JobFetchParseException(
        'The job page had no readable text. Try a different URL or paste '
        'the posting into your source material.',
      );
    }
    return JobPosting(
      url: url,
      title: extracted.title,
      plainText: extracted.plainText,
      fetchedAt: _clock(),
    );
  }

  Future<String> _fetchRawHtml(Uri url, {String? proxyUrl}) async {
    Object? directError;
    try {
      return await _getBody(url);
    } on JobFetchEmptyBodyException {
      // Successful HTTP with empty body — not a CORS/network failure.
      rethrow;
    } on JobFetchNetworkException {
      // Non-2xx from the origin is not a CORS/network failure — do not proxy-retry.
      rethrow;
    } catch (e) {
      directError = e;
    }

    if (proxyUrl == null || proxyUrl.trim().isEmpty) {
      throw JobFetchNetworkException(
        'Could not fetch the job posting (network or CORS). '
        'On web, set a job fetch proxy URL in Settings and try again.',
        cause: directError,
      );
    }

    final proxyBase = Uri.parse(proxyUrl.trim());
    final proxied = proxyBase.replace(
      queryParameters: {
        ...proxyBase.queryParameters,
        'url': url.toString(),
      },
    );

    try {
      return await _getBody(proxied);
    } on JobFetchEmptyBodyException {
      rethrow;
    } on JobFetchError catch (e) {
      throw JobFetchNetworkException(
        'Could not fetch the job posting via direct request or proxy. '
        'Check the proxy URL in Settings and try again.',
        cause: e,
      );
    } catch (e) {
      throw JobFetchNetworkException(
        'Could not fetch the job posting via direct request or proxy. '
        'Check the proxy URL in Settings and try again.',
        cause: e,
      );
    }
  }

  Future<String> _getBody(Uri requestUrl) async {
    final response = await _client.get(
      requestUrl,
      headers: {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JobFetchNetworkException(
        'HTTP ${response.statusCode} fetching $requestUrl',
      );
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (body.trim().isEmpty) {
      throw const JobFetchEmptyBodyException(
        'The job URL returned an empty response. Check the link or try a proxy.',
      );
    }
    return body;
  }
}
