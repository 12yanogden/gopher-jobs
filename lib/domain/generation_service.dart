import 'generation_artifacts.dart';

/// Orchestrates fetch + AI generation for a job URL and source material.
/// Implemented in Wave 2 (Orchestrate agent).
abstract class GenerationService {
  Future<GenerationArtifacts> generate({
    required Uri jobUrl,
    required String sourceMaterial,
  });
}
