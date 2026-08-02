/// Markdown artifacts produced by AI generation.
class GenerationArtifacts {
  const GenerationArtifacts({
    required this.resumeMarkdown,
    required this.coverLetterMarkdown,
    this.atsWarnings = const [],
  });

  final String resumeMarkdown;
  final String coverLetterMarkdown;

  /// Soft ATS structure warnings (populated by Wave 1+). Empty until validation lands.
  final List<String> atsWarnings;
}
