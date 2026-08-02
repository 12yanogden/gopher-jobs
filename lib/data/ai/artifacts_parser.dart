import 'dart:convert';

import '../../domain/generation_artifacts.dart';
import 'ai_exceptions.dart';
import 'ats_structure_validator.dart';

/// Parses and validates model JSON into [GenerationArtifacts].
class ArtifactsParser {
  const ArtifactsParser({
    this.structureValidator = const AtsStructureValidator(),
  });

  /// Soft ATS structure checks applied after JSON field validation.
  final AtsStructureValidator structureValidator;

  /// Parses [raw] model output into artifacts.
  ///
  /// Accepts a bare JSON object or JSON wrapped in markdown fences.
  /// Throws [AiMalformedResponseException] when validation fails.
  ///
  /// On success, [GenerationArtifacts.atsWarnings] is populated from
  /// [structureValidator] (empty when structure looks fine).
  GenerationArtifacts parse(String raw) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText == null) {
      throw const AiMalformedResponseException(
        'AI response did not contain a JSON object.',
      );
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException catch (e) {
      throw AiMalformedResponseException(
        'AI response JSON could not be decoded: ${e.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AiMalformedResponseException(
        'AI response JSON root must be an object.',
      );
    }

    final resume = decoded['resumeMarkdown'];
    final cover = decoded['coverLetterMarkdown'];

    if (resume is! String || resume.trim().isEmpty) {
      throw const AiMalformedResponseException(
        'Missing or empty resumeMarkdown field.',
      );
    }
    if (cover is! String || cover.trim().isEmpty) {
      throw const AiMalformedResponseException(
        'Missing or empty coverLetterMarkdown field.',
      );
    }

    final atsWarnings = structureValidator.validate(
      resumeMarkdown: resume,
      coverLetterMarkdown: cover,
    );

    return GenerationArtifacts(
      resumeMarkdown: resume,
      coverLetterMarkdown: cover,
      atsWarnings: atsWarnings,
    );
  }

  /// Tries [parse]; returns null instead of throwing on malformation.
  GenerationArtifacts? tryParse(String raw) {
    try {
      return parse(raw);
    } on AiMalformedResponseException {
      return null;
    }
  }

  String? _extractJsonObject(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Strip optional ```json ... ``` fences.
    final fence = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    );
    final fenced = fence.firstMatch(trimmed);
    final candidate = (fenced != null ? fenced.group(1)! : trimmed).trim();

    if (candidate.startsWith('{') && candidate.endsWith('}')) {
      return candidate;
    }

    // Fallback: first balanced-looking object substring.
    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return candidate.substring(start, end + 1);
    }
    return null;
  }
}
