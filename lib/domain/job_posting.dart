/// Normalized job posting content fetched from a URL.
class JobPosting {
  const JobPosting({
    required this.url,
    required this.plainText,
    required this.fetchedAt,
    this.title,
  });

  final Uri url;
  final String? title;
  final String plainText;
  final DateTime fetchedAt;
}
