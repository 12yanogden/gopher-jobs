import 'ai_exceptions.dart';

/// Soft ATS structure checks for resume and cover letter markdown.
///
/// Hard failures throw [AiMalformedResponseException]. Soft issues are
/// returned as warning strings for [GenerationArtifacts.atsWarnings].
class AtsStructureValidator {
  const AtsStructureValidator();

  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',
  );

  /// US-style phone with optional country code, separators, or bare 10 digits.
  static final RegExp _phonePattern = RegExp(
    r'(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}|\d{10})\b',
  );

  static final RegExp _markdownTableSep = RegExp(
    r'\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?',
  );

  static final RegExp _htmlTable = RegExp(
    r'<table\b',
    caseSensitive: false,
  );

  /// Matches `## Section` headings (ATS prompt contract uses h2).
  static final RegExp _h2HeadingPattern = RegExp(
    r'^##\s+(.+?)\s*$',
    multiLine: true,
  );

  /// Ideal cover letter range (inclusive).
  static const int idealMinWords = 250;
  static const int idealMaxWords = 400;

  /// Outside this band is a clearly-bad length soft warning.
  static const int clearlyBadMinWords = 200;
  static const int clearlyBadMaxWords = 500;

  /// Required resume section names checked case-insensitively under `##` headings.
  static const List<String> requiredResumeSections = [
    'Summary',
    'Skills',
    'Experience',
    'Education',
  ];

  /// Validates [resumeMarkdown] and [coverLetterMarkdown].
  ///
  /// Throws [AiMalformedResponseException] when content is empty or the resume
  /// is clearly not a resume (missing both Experience and Skills signals).
  ///
  /// [jobTitle] is accepted for API compatibility; structure checks do not
  /// use it yet.
  List<String> validate({
    required String resumeMarkdown,
    required String coverLetterMarkdown,
    String? jobTitle,
  }) {
    final resume = resumeMarkdown.trim();
    final cover = coverLetterMarkdown.trim();

    if (resume.isEmpty) {
      throw const AiMalformedResponseException(
        'Resume content is empty.',
      );
    }
    if (cover.isEmpty) {
      throw const AiMalformedResponseException(
        'Cover letter content is empty.',
      );
    }

    final resumeHeadings = _sectionHeadings(resume);
    final hasExperience = resumeHeadings.contains('experience');
    final hasSkills = resumeHeadings.contains('skills');

    if (!hasExperience && !hasSkills) {
      throw const AiMalformedResponseException(
        'Resume is missing both Experience and Skills sections.',
      );
    }

    final warnings = <String>[
      ..._resumeWarnings(resume, resumeHeadings),
      ..._coverLetterWarnings(cover),
    ];
    return List.unmodifiable(warnings);
  }

  List<String> _resumeWarnings(String resume, Set<String> headings) {
    final warnings = <String>[];

    for (final section in requiredResumeSections) {
      if (!headings.contains(section.toLowerCase())) {
        warnings.add('Resume is missing ## $section section.');
      }
    }

    final hasEmail = _emailPattern.hasMatch(resume);
    final hasPhone = _phonePattern.hasMatch(resume);
    if (!hasEmail && !hasPhone) {
      warnings.add(
        'Resume appears to lack contact details (email or phone).',
      );
    }

    if (_hasMarkdownTable(resume)) {
      warnings.add(
        'Resume contains a markdown table; ATS parsers often mishandle tables.',
      );
    }
    if (_htmlTable.hasMatch(resume)) {
      warnings.add(
        'Resume contains an HTML <table>; ATS parsers often mishandle tables.',
      );
    }

    return warnings;
  }

  List<String> _coverLetterWarnings(String cover) {
    final warnings = <String>[];
    final words = _wordCount(cover);

    if (words < idealMinWords || words > idealMaxWords) {
      warnings.add(
        'Cover letter word count is $words; recommended range is '
        '$idealMinWords–$idealMaxWords words.',
      );
    }
    if (words < clearlyBadMinWords || words > clearlyBadMaxWords) {
      warnings.add(
        'Cover letter word count ($words) is clearly outside the '
        'acceptable ~$clearlyBadMinWords–$clearlyBadMaxWords range.',
      );
    }

    if (_hasMarkdownTable(cover)) {
      warnings.add(
        'Cover letter contains a markdown table; prefer plain prose.',
      );
    }
    if (_htmlTable.hasMatch(cover)) {
      warnings.add(
        'Cover letter contains an HTML <table>; prefer plain prose.',
      );
    }

    return warnings;
  }

  Set<String> _sectionHeadings(String markdown) {
    final headings = <String>{};
    for (final match in _h2HeadingPattern.allMatches(markdown)) {
      final title = match.group(1)?.trim().toLowerCase();
      if (title == null || title.isEmpty) continue;
      // Match "## Experience" and "## Experience & Work" style headings.
      final firstToken = title.split(RegExp(r'\s+')).first;
      headings.add(firstToken);
      headings.add(title);
    }
    return headings;
  }

  bool _hasMarkdownTable(String markdown) =>
      _markdownTableSep.hasMatch(markdown);

  int _wordCount(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return parts.length;
  }
}
