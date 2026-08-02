import 'app_settings.dart';
import 'job_posting.dart';

/// Input to an AI generation call.
class GenerationRequest {
  const GenerationRequest({
    required this.job,
    required this.sourceMaterial,
    required this.settings,
  });

  final JobPosting job;
  final String sourceMaterial;
  final AppSettings settings;
}
