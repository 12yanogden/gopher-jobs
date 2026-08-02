/// Converts ATS resume/cover-letter Markdown into paste-friendly plain text.
class AtsPlainText {
  AtsPlainText._();

  /// Strips Markdown formatting while keeping readable line structure.
  ///
  /// - Heading markers (`#` … `######`) are removed
  /// - Bold/italic markers (`**`, `__`, `*`, `_`) are removed
  /// - Bullets (`-`, `*`, `+`) are normalized to `- `
  /// - Runs of blank lines collapse to a single blank line
  static String toPlain(String markdown) {
    if (markdown.isEmpty) {
      return '';
    }

    final lines = markdown.split('\n');
    final converted = <String>[];

    for (final line in lines) {
      converted.add(_convertLine(line));
    }

    return _collapseBlankLines(converted.join('\n'));
  }

  static String _convertLine(String line) {
    var result = line;

    // Strip ATX heading markers (# ## ### …).
    result = result.replaceFirst(RegExp(r'^#{1,6}\s+'), '');

    // Normalize unordered list markers to "- ".
    result = result.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '- ');

    result = _stripEmphasis(result);
    return result.trimRight();
  }

  static String _stripEmphasis(String input) {
    var result = input;

    // Bold before italic so "**x**" is not partially eaten by "*".
    result = result.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (match) => match[1]!,
    );
    result = result.replaceAllMapped(
      RegExp(r'__(.+?)__'),
      (match) => match[1]!,
    );
    result = result.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (match) => match[1]!,
    );
    // Underscore italic; avoid mid-token underscores (e.g. snake_case).
    result = result.replaceAllMapped(
      RegExp(r'(?<![A-Za-z0-9])_(.+?)_(?![A-Za-z0-9])'),
      (match) => match[1]!,
    );

    return result;
  }

  /// Collapses 2+ consecutive blank lines into one blank line.
  static String _collapseBlankLines(String text) {
    final collapsed = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return collapsed.trim();
  }
}
