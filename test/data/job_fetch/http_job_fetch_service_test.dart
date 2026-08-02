import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/job_fetch/http_job_fetch_service.dart';
import 'package:gopher_jobs/data/job_fetch/job_fetch_exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response htmlResponse(String body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(body),
    status,
    headers: const {'content-type': 'text/html; charset=utf-8'},
  );
}

void main() {
  final sampleHtml = File('test/fixtures/sample_job.html').readAsStringSync();
  final jobUrl = Uri.parse('https://jobs.example.com/flutter-senior');
  const proxyBase = 'https://cors-proxy.example/fetch';
  final fixedNow = DateTime.utc(2026, 8, 1, 21, 0);

  group('HttpJobFetchService', () {
    test('fetches HTML and returns JobPosting with plain text', () async {
      final client = MockClient((request) async {
        expect(request.url, jobUrl);
        expect(request.headers['User-Agent'], isNotEmpty);
        return htmlResponse(sampleHtml);
      });

      final service = HttpJobFetchService(
        client: client,
        clock: () => fixedNow,
      );

      final posting = await service.fetch(jobUrl);

      expect(posting.url, jobUrl);
      expect(posting.title, 'Senior Flutter Engineer — Acme Corp');
      expect(posting.plainText, contains('Ship Flutter features'));
      expect(posting.plainText, isNot(contains('injected script noise')));
      expect(posting.fetchedAt, fixedNow);
    });

    test('retries via proxy when direct request fails', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        if (request.url == jobUrl) {
          throw const SocketException('Failed host lookup');
        }
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'cors-proxy.example');
        expect(request.url.path, '/fetch');
        expect(request.url.queryParameters['url'], jobUrl.toString());
        return htmlResponse(sampleHtml);
      });

      final service = HttpJobFetchService(
        client: client,
        clock: () => fixedNow,
      );

      final posting = await service.fetch(jobUrl, proxyUrl: proxyBase);

      expect(callCount, 2);
      expect(posting.plainText, contains('Senior Flutter Engineer'));
      expect(posting.title, contains('Acme Corp'));
    });

    test('throws JobFetchNetworkException when direct fails and no proxy',
        () async {
      final client = MockClient((request) async {
        throw http.ClientException('CORS blocked', jobUrl);
      });

      final service = HttpJobFetchService(client: client);

      await expectLater(
        () => service.fetch(jobUrl),
        throwsA(isA<JobFetchNetworkException>()),
      );
    });

    test('throws JobFetchNetworkException when direct and proxy both fail',
        () async {
      final client = MockClient((request) async {
        throw http.ClientException('network down', request.url);
      });

      final service = HttpJobFetchService(client: client);

      await expectLater(
        () => service.fetch(jobUrl, proxyUrl: proxyBase),
        throwsA(isA<JobFetchNetworkException>()),
      );
    });

    test('throws JobFetchEmptyBodyException on empty response body', () async {
      final client = MockClient((request) async {
        return htmlResponse('   ');
      });

      final service = HttpJobFetchService(client: client);

      await expectLater(
        () => service.fetch(jobUrl),
        throwsA(isA<JobFetchEmptyBodyException>()),
      );
    });

    test('throws JobFetchParseException when HTML has no readable text',
        () async {
      final emptyish =
          File('test/fixtures/script_only_job.html').readAsStringSync();
      final client = MockClient((request) async {
        return htmlResponse(emptyish);
      });

      final service = HttpJobFetchService(client: client);

      await expectLater(
        () => service.fetch(jobUrl),
        throwsA(isA<JobFetchParseException>()),
      );
    });

    test('throws JobFetchNetworkException on non-2xx status', () async {
      final client = MockClient((request) async {
        return htmlResponse('Nope', 403);
      });

      final service = HttpJobFetchService(client: client);

      await expectLater(
        () => service.fetch(jobUrl),
        throwsA(isA<JobFetchNetworkException>()),
      );
    });

    test('preserves existing proxy query params when retrying', () async {
      final client = MockClient((request) async {
        if (request.url == jobUrl) {
          throw http.ClientException('CORS', jobUrl);
        }
        expect(request.url.queryParameters['key'], 'abc');
        expect(request.url.queryParameters['url'], jobUrl.toString());
        return htmlResponse(sampleHtml);
      });

      final service = HttpJobFetchService(
        client: client,
        clock: () => fixedNow,
      );

      final posting = await service.fetch(
        jobUrl,
        proxyUrl: '$proxyBase?key=abc',
      );

      expect(posting.plainText, isNotEmpty);
    });
  });
}
