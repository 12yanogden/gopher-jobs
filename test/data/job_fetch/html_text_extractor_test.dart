import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gopher_jobs/data/job_fetch/html_text_extractor.dart';

void main() {
  late HtmlTextExtractor extractor;

  setUp(() {
    extractor = const HtmlTextExtractor();
  });

  String fixture(String name) =>
      File('test/fixtures/$name').readAsStringSync();

  group('HtmlTextExtractor', () {
    test('extracts title and readable text from sample job HTML', () {
      final result = extractor.extract(fixture('sample_job.html'));

      expect(result.title, 'Senior Flutter Engineer — Acme Corp');
      expect(result.plainText, contains('Senior Flutter Engineer'));
      expect(result.plainText, contains('Ship Flutter features'));
      expect(result.plainText, contains('5+ years mobile experience'));
      expect(result.plainText, isNot(contains('injected script noise')));
      expect(result.plainText, isNot(contains('display: none')));
      expect(result.plainText, isNot(contains('Enable JavaScript')));
      expect(result.plainText, isNot(contains(RegExp(r'\s{2,}'))));
    });

    test('collapses whitespace and strips scripts/styles', () {
      final result = extractor.extract(fixture('whitespace_job.html'));

      expect(result.title, 'Whitespace Heavy Listing');
      expect(result.plainText, contains('Backend Engineer'));
      expect(result.plainText, contains('Build reliable APIs.'));
      expect(result.plainText, isNot(contains('do not extract')));
      expect(result.plainText, isNot(contains('margin: 0')));
      expect(result.plainText, isNot(contains('\n')));
    });

    test('returns empty plainText when only scripts/styles remain', () {
      final result = extractor.extract(fixture('script_only_job.html'));

      expect(result.title, 'Empty-ish');
      expect(result.plainText, isEmpty);
    });

    test('caps plainText at configured max length', () {
      final short = HtmlTextExtractor(maxPlainTextLength: 40);
      final result = short.extract(fixture('sample_job.html'));

      expect(result.plainText.length, lessThanOrEqualTo(40));
      expect(result.plainText, isNotEmpty);
    });

    test('falls back to og:title then h1 when title tag missing', () {
      const html = '''
<html><head>
<meta property="og:title" content="OG Role Title">
</head><body><h1>H1 Role</h1><p>Body copy here.</p></body></html>
''';
      final result = extractor.extract(html);
      expect(result.title, 'OG Role Title');
      expect(result.plainText, contains('Body copy here.'));
    });
  });
}
