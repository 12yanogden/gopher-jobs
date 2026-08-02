import 'generation_artifacts.dart';
import 'generation_request.dart';

/// Provider-specific AI client.
/// Implemented in Wave 1 (AI agent).
abstract class AiClient {
  Future<GenerationArtifacts> generateArtifacts(GenerationRequest request);
}
