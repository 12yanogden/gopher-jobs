import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Result of stripping markup from a job posting HTML document.
class ExtractedJobText {
  const ExtractedJobText({required this.plainText, this.title});

  final String plainText;
  final String? title;
}

/// Extracts readable plain text from HTML job posting documents.
class HtmlTextExtractor {
  /// Soft cap on returned plain text length (characters).
  static const int defaultMaxPlainTextLength = 60000;

  const HtmlTextExtractor({
    this.maxPlainTextLength = defaultMaxPlainTextLength,
  });

  final int maxPlainTextLength;

  /// Parses [html] and returns collapsed body text plus document title if any.
  ExtractedJobText extract(String html) {
    final document = html_parser.parse(html);
    final title = _extractTitle(document);
    _removeNonContentNodes(document);
    final raw = document.body?.text ?? document.documentElement?.text ?? '';
    final collapsed = _collapseWhitespace(raw);
    final capped = collapsed.length > maxPlainTextLength
        ? collapsed.substring(0, maxPlainTextLength)
        : collapsed;
    return ExtractedJobText(plainText: capped, title: title);
  }

  String? _extractTitle(Document document) {
    final titleEl = document.querySelector('title');
    final fromTitle = _collapseWhitespace(titleEl?.text ?? '');
    if (fromTitle.isNotEmpty) return fromTitle;

    final og = document.querySelector('meta[property="og:title"]');
    final fromOg = _collapseWhitespace(og?.attributes['content'] ?? '');
    if (fromOg.isNotEmpty) return fromOg;

    final h1 = document.querySelector('h1');
    final fromH1 = _collapseWhitespace(h1?.text ?? '');
    if (fromH1.isNotEmpty) return fromH1;

    return null;
  }

  void _removeNonContentNodes(Document document) {
    const removeSelectors = [
      'script',
      'style',
      'noscript',
      'svg',
      'iframe',
      'template',
    ];
    for (final selector in removeSelectors) {
      for (final node in document.querySelectorAll(selector)) {
        node.remove();
      }
    }
  }

  static String _collapseWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
