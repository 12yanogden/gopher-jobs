import 'job_posting.dart';

/// Fetches and normalizes a job posting from a URL.
/// Implemented in Wave 1 (Fetch agent).
abstract class JobFetchService {
  Future<JobPosting> fetch(Uri url, {String? proxyUrl});
}
